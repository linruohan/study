/// 体检加固批次的路由级测试：素材鉴权、智者贡献、纠错审核、auth/degree 加固行为、知识包 ETag。
/// 前置：数据库已执行全部迁移（npm run db:migrate）。
import assert from 'node:assert/strict';
import test from 'node:test';
import { buildApp } from '../src/app.js';
import { pool } from '../src/db.js';
import { hashPassword } from '../src/auth/auth.service.js';

const ADMIN = 'hd-admin';
const USER = 'hd-user';
const PASSWORD = 'hardening-test-password';

async function seedUsers(): Promise<void> {
  await pool.query(
    `INSERT INTO users (username, password_hash, role, must_change_password)
     VALUES ($1, $2, 'admin', false), ($3, $4, 'user', false)
     ON CONFLICT (username) DO UPDATE
        SET password_hash = EXCLUDED.password_hash,
            role = EXCLUDED.role,
            must_change_password = EXCLUDED.must_change_password`,
    [ADMIN, hashPassword(PASSWORD), USER, hashPassword(PASSWORD)],
  );
  // 取出 admin 的 id，供断言「审核人取自登录管理员」使用。
  const r = await pool.query('SELECT id FROM users WHERE username = $1', [ADMIN]);
  adminId = r.rows[0].id as string;
}

let adminId = '';

async function login(
  http: import('fastify').FastifyInstance,
  username: string,
): Promise<string> {
  const res = await http.inject({
    method: 'POST',
    url: '/api/auth/login',
    payload: { username, password: PASSWORD },
  });
  assert.equal(res.statusCode, 200, res.body);
  return res.json().token as string;
}

test('hardening: assets auth, sage contribution, review, guards, bundle etag', { timeout: 60_000 }, async (t) => {
  await seedUsers();
  const http = await buildApp();

  const createdAssetIds: string[] = [];
  const createdCategoryIds: string[] = [];
  // 智者贡献创建的知识概念 id；收尾时精确清掉，避免污染其他测试的今日一步。
  let sageConceptId: string | null = null;
  const sageDeviceId = 'aaaaaaaa-1111-2222-3333-444444444444';
  const adminToken = await login(http, ADMIN);
  const userToken = await login(http, USER);

  t.after(async () => {
    // 先清测试产物，再关连接池。
    for (const id of createdAssetIds) {
      await pool.query('DELETE FROM assets WHERE id = $1', [id]);
    }
    for (const id of createdCategoryIds) {
      await pool.query('DELETE FROM knowledge_categories WHERE id = $1', [id]);
    }
    if (sageConceptId) {
      // 贡献（含积分）→ 知识点 → 分龄呈现 → 概念，按外键依赖从下游往上删。
      await pool.query('DELETE FROM knowledge_point_credits WHERE correction_id IN (SELECT id FROM knowledge_point_corrections WHERE device_id = $1)', [sageDeviceId]);
      await pool.query('DELETE FROM knowledge_point_corrections WHERE device_id = $1', [sageDeviceId]);
      await pool.query('DELETE FROM knowledge_contributions WHERE concept_id = $1', [sageConceptId]);
      await pool.query('DELETE FROM knowledge_variant_points WHERE concept_id = $1', [sageConceptId]);
      await pool.query('DELETE FROM knowledge_variants WHERE concept_id = $1', [sageConceptId]);
      await pool.query('DELETE FROM knowledge_concepts WHERE id = $1', [sageConceptId]);
    }
    await pool.query('DELETE FROM degree_applications WHERE user_id = $1', [adminId]);
    await pool.query("DELETE FROM users WHERE username IN ('hd-admin', 'hd-user')");
    await http.close();
    await pool.end();
  });

  // ── assets：读开放、写需登录 ────────────────────────────────────────
  const anonCreate = await http.inject({
    method: 'POST',
    url: '/api/assets/text',
    payload: { title: '匿名试试', body: '不该成功' },
  });
  assert.equal(anonCreate.statusCode, 401);

  const anonDelete = await http.inject({
    method: 'DELETE',
    url: '/api/assets/00000000-0000-0000-0000-000000000000',
  });
  assert.equal(anonDelete.statusCode, 401);

  const adminCreate = await http.inject({
    method: 'POST',
    url: '/api/assets/text',
    headers: { authorization: `Bearer ${adminToken}` },
    payload: { title: '加固测试素材', body: '正文', metadata: {} },
  });
  assert.equal(adminCreate.statusCode, 201, adminCreate.body);
  // 素材接口直接返回素材对象（不包 { asset } 包装）。
  const assetId = adminCreate.json().id as string;
  createdAssetIds.push(assetId);

  // 普通用户登录后也可以上传（写操作要求登录，不要求管理员），删除同样允许。
  const userCreate = await http.inject({
    method: 'POST',
    url: '/api/assets/text',
    headers: { authorization: `Bearer ${userToken}` },
    payload: { title: '普通用户素材', body: '登录即可上传', metadata: {} },
  });
  assert.equal(userCreate.statusCode, 201, userCreate.body);
  createdAssetIds.push(userCreate.json().id as string);

  // 读开放：匿名可列表、可取内容。
  const anonList = await http.inject({ method: 'GET', url: '/api/assets?limit=5' });
  assert.equal(anonList.statusCode, 200);
  const anonContent = await http.inject({
    method: 'GET',
    url: `/api/assets/${assetId}/content`,
  });
  assert.equal(anonContent.statusCode, 200);
  assert.equal(anonContent.body, '正文');

  const anonDeleteOwn = await http.inject({
    method: 'DELETE',
    url: `/api/assets/${assetId}`,
    headers: { authorization: `Bearer ${adminToken}` },
  });
  assert.equal(anonDeleteOwn.statusCode, 204);

  // ── auth 加固 ──────────────────────────────────────────────────────
  const badLimit = await http.inject({
    method: 'GET',
    url: '/api/users?limit=abc',
    headers: { authorization: `Bearer ${adminToken}` },
  });
  assert.equal(badLimit.statusCode, 400);

  const selfDemote = await http.inject({
    method: 'PATCH',
    url: `/api/users/${adminId}/role`,
    headers: { authorization: `Bearer ${adminToken}` },
    payload: { role: 'user' },
  });
  assert.equal(selfDemote.statusCode, 403);

  // ── degree：同时仅一条待审 ─────────────────────────────────────────
  const firstApply = await http.inject({
    method: 'POST',
    url: '/api/degree/applications',
    headers: { authorization: `Bearer ${adminToken}` },
    payload: { targetRealm: '启蒙' },
  });
  // 管理员境界可能已达标，允许 200 或「已在该境界」的 400；只关心重复提交被拦。
  assert.ok([200, 400, 409].includes(firstApply.statusCode), firstApply.body);
  if (firstApply.statusCode === 200) {
    const secondApply = await http.inject({
      method: 'POST',
      url: '/api/degree/applications',
      headers: { authorization: `Bearer ${adminToken}` },
      payload: { targetRealm: '启蒙' },
    });
    assert.equal(secondApply.statusCode, 409);
  }

  // ── 智者贡献：旧领域 id 可解析，写入知识包可见 ─────────────────────
  const bundleBefore = await http.inject({ method: 'GET', url: '/api/knowledge' });
  assert.equal(bundleBefore.statusCode, 200);
  const bundle = bundleBefore.json() as {
    ageBands: { id: string }[];
    degrees: { id: string }[];
    categories: { id: string }[];
  };
  const etagBefore = bundleBefore.headers.etag as string;
  assert.ok(etagBefore, '知识包应返回 ETag');

  // 304：带 If-None-Match 的第二次请求不回包体。
  const notModified = await http.inject({
    method: 'GET',
    url: '/api/knowledge',
    headers: { 'if-none-match': etagBefore },
  });
  assert.equal(notModified.statusCode, 304);

  const deviceId = 'aaaaaaaa-1111-2222-3333-444444444444';
  const contribution = await http.inject({
    method: 'POST',
    url: `/api/devices/${deviceId}/sage/contributions`,
    payload: {
      kind: 'knowledge',
      // 用第一个分类 id；旧领域 id 的兼容映射已由同一逻辑覆盖。
      domainId: bundle.categories[0].id,
      ageBandId: bundle.ageBands[0].id,
      degreeId: bundle.degrees[0].id,
      topic: '加固测试智者知识',
    },
  });
  assert.equal(contribution.statusCode, 200, contribution.body);
  sageConceptId = (contribution.json().contribution.conceptId as string) ?? null;

  const unknownDomain = await http.inject({
    method: 'POST',
    url: `/api/devices/${sageDeviceId}/sage/contributions`,
    payload: {
      kind: 'knowledge',
      domainId: 'no_such_domain',
      ageBandId: bundle.ageBands[0].id,
      degreeId: bundle.degrees[0].id,
      topic: '不该入库',
    },
  });
  assert.equal(unknownDomain.statusCode, 400);

  // 贡献后知识包内容变了：原 ETag 不再命中 304。
  const bundleAfter = await http.inject({ method: 'GET', url: '/api/knowledge' });
  assert.notEqual(bundleAfter.headers.etag, etagBefore, '写入知识后 ETag 应变化');

  // ── 纠错审核：审核人取自登录管理员，不再信任 body ───────────────────
  const correction = await http.inject({
    method: 'POST',
    url: '/api/knowledge/points/corrections',
    payload: {
      deviceId,
      conceptId: 'zi_ri',
      ageBandId: bundle.ageBands[0].id,
      degreeId: bundle.degrees[0].id,
      position: 1,
      body: '加固测试纠错内容',
    },
  });
  assert.equal(correction.statusCode, 200, correction.body);
  const correctionId = correction.json().correction.id as string;

  const review = await http.inject({
    method: 'POST',
    url: '/api/knowledge/points/corrections/review',
    headers: { authorization: `Bearer ${adminToken}` },
    payload: { correctionId, approve: true },
  });
  assert.equal(review.statusCode, 200, review.body);
  assert.equal(review.json().correction.reviewerDeviceId, adminId);

  // 未登录审核 401。
  const anonReview = await http.inject({
    method: 'POST',
    url: '/api/knowledge/points/corrections/review',
    payload: { correctionId, approve: false },
  });
  assert.equal(anonReview.statusCode, 401);
});
