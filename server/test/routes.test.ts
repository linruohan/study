/// 路由级集成测试：连真实的 PostgreSQL(本地 Docker 或 CI 服务容器)。
/// 前置:数据库已执行全部迁移(npm run db:migrate)。
import assert from 'node:assert/strict';
import test from 'node:test';
import { buildApp } from '../src/app.js';
import { pool } from '../src/db.js';
import { hashPassword } from '../src/auth/auth.service.js';

const ADMIN = 'test-admin';
const USER = 'test-user';
const PASSWORD = 'route-test-password';

let createdCategoryId: string | null = null;

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
}

test('routes: health, auth, write permission, degree, device data', { timeout: 60_000 }, async (t) => {
  await seedUsers();
  const http = await buildApp();

  t.after(async () => {
    // 先清测试产物(分类垃圾),再关连接池。
    if (createdCategoryId) {
      await pool.query('DELETE FROM knowledge_categories WHERE id = $1', [createdCategoryId]);
    }
    await http.close();
    await pool.end();
  });

  // 1. 健康检查。
  const health = await http.inject({ method: 'GET', url: '/healthz' });
  assert.equal(health.statusCode, 200);

  // 2. 登录:管理员与普通用户;错误密码 401。
  const adminLogin = await http.inject({
    method: 'POST',
    url: '/api/auth/login',
    payload: { username: ADMIN, password: PASSWORD },
  });
  assert.equal(adminLogin.statusCode, 200);
  const adminToken = adminLogin.json().token as string;
  const userLogin = await http.inject({
    method: 'POST',
    url: '/api/auth/login',
    payload: { username: USER, password: PASSWORD },
  });
  assert.equal(userLogin.statusCode, 200);
  const userToken = userLogin.json().token as string;
  assert.equal(userLogin.json().user.role, 'user');
  const badLogin = await http.inject({
    method: 'POST',
    url: '/api/auth/login',
    payload: { username: ADMIN, password: 'wrong' },
  });
  assert.equal(badLogin.statusCode, 401);

  // 3. 知识内容写权限:未登录 401,普通用户 403,管理员 200。
  const noAuth = await http.inject({
    method: 'POST',
    url: '/api/knowledge/categories',
    payload: { id: 'rt_cat_x', name: '路由测试' },
  });
  assert.equal(noAuth.statusCode, 401);
  const forbidden = await http.inject({
    method: 'POST',
    url: '/api/knowledge/categories',
    headers: { authorization: `Bearer ${userToken}` },
    payload: { id: 'rt_cat_x', name: '路由测试' },
  });
  assert.equal(forbidden.statusCode, 403);
  const categoryId = `rt_cat_${Date.now()}`;
  const created = await http.inject({
    method: 'POST',
    url: '/api/knowledge/categories',
    headers: { authorization: `Bearer ${adminToken}` },
    payload: { id: categoryId, name: '路由测试子类', parentId: 'education' },
  });
  assert.equal(created.statusCode, 200, created.body);
  createdCategoryId = created.json().category.id as string;

  // 4. 学位:普通用户申请,管理员审核通过后境界提升。
  const apply = await http.inject({
    method: 'POST',
    url: '/api/degree/applications',
    headers: { authorization: `Bearer ${userToken}` },
    payload: { targetRealm: 'shi', evidence: { note: 'route-test' } },
  });
  assert.equal(apply.statusCode, 200, apply.body);
  const applicationId = apply.json().application.id as string;
  const review = await http.inject({
    method: 'POST',
    url: `/api/degree/applications/${applicationId}/review`,
    headers: { authorization: `Bearer ${adminToken}` },
    payload: { approve: true },
  });
  assert.equal(review.statusCode, 200, review.body);
  const degree = await http.inject({
    method: 'GET',
    url: '/api/degree',
    headers: { authorization: `Bearer ${userToken}` },
  });
  assert.equal(degree.json().degree.realm, 'shi');

  // 5. 设备数据:categoryId 口径的计划可整份替换并读回。
  const deviceId = '11111111-2222-3333-4444-555555555555';
  const put = await http.inject({
    method: 'PUT',
    url: `/api/devices/${deviceId}/data`,
    payload: {
      profile: { band: 'toddler', focusCategoryId: 'language' },
      plans: [
        {
          id: 'rt_plan_1',
          categoryId: 'language',
          depth: 'deep',
          conceptId: 'zi_ri',
          degree: 'beginner',
          startAt: '2026-11-14T10:00:00.000Z',
          remind: false,
          done: false,
        },
      ],
      records: [
        {
          id: 'rt_rec_1',
          at: '2026-11-14T10:00:00.000Z',
          source: 'route-test',
          subject: '语',
          body: 'route test record',
        },
      ],
    },
  });
  assert.equal(put.statusCode, 200, put.body);
  const get = await http.inject({ method: 'GET', url: `/api/devices/${deviceId}/data` });
  assert.equal(get.statusCode, 200);
  assert.equal(get.json().plans.length, 1);
  assert.equal(get.json().plans[0].domainId, 'language');
  assert.equal(get.json().profile.band, 'toddler');
});
