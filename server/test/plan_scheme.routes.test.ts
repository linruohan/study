/// 学习计划方案路由级集成测试：连真实的 PostgreSQL(本地 Docker 或 CI 服务容器)。
/// 前置:数据库已执行全部迁移(npm run db:migrate)。
import assert from 'node:assert/strict';
import test from 'node:test';
import { buildApp } from '../src/app.js';
import { pool } from '../src/db.js';
import { hashPassword } from '../src/auth/auth.service.js';

const ADMIN = 'ps-admin';
const USER = 'ps-user';
const OTHER = 'ps-other';
const PASSWORD = 'plan-scheme-test-password';

/// 记录测试创建的自建方案 id,收尾清理。
const createdSchemeIds: string[] = [];

async function seedUsers(): Promise<void> {
  await pool.query(
    `INSERT INTO users (username, password_hash, role, must_change_password)
     VALUES ($1, $2, 'admin', false), ($3, $4, 'user', false), ($5, $6, 'user', false)
     ON CONFLICT (username) DO UPDATE
        SET password_hash = EXCLUDED.password_hash,
            role = EXCLUDED.role,
            must_change_password = EXCLUDED.must_change_password`,
    [ADMIN, hashPassword(PASSWORD), USER, hashPassword(PASSWORD), OTHER, hashPassword(PASSWORD)],
  );
}

async function login(http: import('fastify').FastifyInstance, username: string): Promise<string> {
  const res = await http.inject({
    method: 'POST',
    url: '/api/auth/login',
    payload: { username, password: PASSWORD },
  });
  assert.equal(res.statusCode, 200, res.body);
  return res.json().token as string;
}

const CREATE_BODY = {
  name: '我的自建方案',
  stage: 'primary',
  description: '路由测试用',
  dimensions: [
    {
      name: '语文',
      items: [{ content: '拼音与基础汉字', expectedLevel: '能正确拼读', conceptId: 'zi_ri' }],
    },
    { name: '数学', items: [{ content: '20以内加减法' }] },
  ],
};

test('plan schemes: builtin list, create/read/update/delete/clone permissions', { timeout: 60_000 }, async (t) => {
  await seedUsers();
  const http = await buildApp();

  t.after(async () => {
    // 先清测试产物(自建方案,维度/条目级联删除),再关连接池。
    for (const id of createdSchemeIds) {
      await pool.query('DELETE FROM plan_schemes WHERE id = $1', [id]);
    }
    await http.close();
    await pool.end();
  });

  const userToken = await login(http, USER);
  const otherToken = await login(http, OTHER);

  // 1. 匿名可见内置方案列表(23 个),且不含任何自建方案。
  const anonList = await http.inject({ method: 'GET', url: '/api/plan-schemes' });
  assert.equal(anonList.statusCode, 200);
  const builtinList = anonList.json().schemes as { id: string; isBuiltin: boolean }[];
  assert.ok(builtinList.length >= 23, `内置方案应至少 23 个,实际 ${builtinList.length}`);
  assert.ok(builtinList.every((s) => s.isBuiltin));

  // 2. 内置方案详情匿名可读;蒙学含 6 个维度,「语言与识字」条目关联了概念。
  const mengxue = await http.inject({ method: 'GET', url: '/api/plan-schemes/scheme_mengxue' });
  assert.equal(mengxue.statusCode, 200);
  const mengxueScheme = mengxue.json().scheme as {
    dimensions: { name: string; items: { conceptId: string | null }[] }[];
  };
  assert.equal(mengxueScheme.dimensions.length, 6);
  const langDim = mengxueScheme.dimensions.find((d) => d.name === '语言与识字');
  assert.ok(langDim && langDim.items.length > 0);
  assert.equal(langDim.items[0].conceptId, 'zi_ri');

  // 3. 不存在的方案 404。
  const missing = await http.inject({ method: 'GET', url: '/api/plan-schemes/scheme_nope' });
  assert.equal(missing.statusCode, 404);

  // 4. 未登录创建 401。
  const noAuth = await http.inject({ method: 'POST', url: '/api/plan-schemes', payload: CREATE_BODY });
  assert.equal(noAuth.statusCode, 401);

  // 5. 登录创建自建方案,详情含维度与条目。
  const created = await http.inject({
    method: 'POST',
    url: '/api/plan-schemes',
    headers: { authorization: `Bearer ${userToken}` },
    payload: CREATE_BODY,
  });
  assert.equal(created.statusCode, 200, created.body);
  const scheme = created.json().scheme as { id: string; isBuiltin: boolean; dimensions: unknown[] };
  createdSchemeIds.push(scheme.id);
  assert.equal(scheme.isBuiltin, false);
  assert.equal(scheme.dimensions.length, 2);

  // 6. 自建方案:匿名与他人的列表/详情都看不到(按 404 处理)。
  const anonDetail = await http.inject({ method: 'GET', url: `/api/plan-schemes/${scheme.id}` });
  assert.equal(anonDetail.statusCode, 404);
  const otherDetail = await http.inject({
    method: 'GET',
    url: `/api/plan-schemes/${scheme.id}`,
    headers: { authorization: `Bearer ${otherToken}` },
  });
  assert.equal(otherDetail.statusCode, 404);
  const ownerDetail = await http.inject({
    method: 'GET',
    url: `/api/plan-schemes/${scheme.id}`,
    headers: { authorization: `Bearer ${userToken}` },
  });
  assert.equal(ownerDetail.statusCode, 200);

  // 7. 非 owner 修改/删除 403;owner 修改成功(整体替换维度)。
  const otherPut = await http.inject({
    method: 'PUT',
    url: `/api/plan-schemes/${scheme.id}`,
    headers: { authorization: `Bearer ${otherToken}` },
    payload: CREATE_BODY,
  });
  assert.equal(otherPut.statusCode, 403);
  const updated = await http.inject({
    method: 'PUT',
    url: `/api/plan-schemes/${scheme.id}`,
    headers: { authorization: `Bearer ${userToken}` },
    payload: { ...CREATE_BODY, name: '改名后的方案', dimensions: [CREATE_BODY.dimensions[0]] },
  });
  assert.equal(updated.statusCode, 200, updated.body);
  assert.equal((updated.json().scheme as { name: string }).name, '改名后的方案');
  assert.equal((updated.json().scheme as { dimensions: unknown[] }).dimensions.length, 1);

  // 8. 参数错误 400(维度为空不算错,但条目缺 content 算)。
  const badBody = await http.inject({
    method: 'POST',
    url: '/api/plan-schemes',
    headers: { authorization: `Bearer ${userToken}` },
    payload: { name: 'x', stage: 'primary', dimensions: [{ name: 'd', items: [{ expectedLevel: '' }] }] },
  });
  assert.equal(badBody.statusCode, 400);

  // 9. 关联不存在的概念 400;且不留孤儿方案(创建失败必须整体回滚)。
  const badConcept = await http.inject({
    method: 'POST',
    url: '/api/plan-schemes',
    headers: { authorization: `Bearer ${userToken}` },
    payload: {
      name: '坏概念',
      stage: 'primary',
      dimensions: [{ name: 'd', items: [{ content: 'c', conceptId: 'no_such_concept' }] }],
    },
  });
  assert.equal(badConcept.statusCode, 400);
  const afterBad = await http.inject({
    method: 'GET',
    url: '/api/plan-schemes',
    headers: { authorization: `Bearer ${userToken}` },
  });
  const schemesAfterBad = (afterBad.json().schemes as { name: string }[]).filter(
    (s) => !s.isBuiltin || s.name === '坏概念',
  );
  assert.ok(
    !schemesAfterBad.some((s) => s.name === '坏概念'),
    '失败创建不应留下孤儿方案',
  );

  // 9b. 更新时维度写入失败:基本信息也不应被改掉(同一事务回滚)。
  const badUpdate = await http.inject({
    method: 'PUT',
    url: `/api/plan-schemes/${scheme.id}`,
    headers: { authorization: `Bearer ${userToken}` },
    payload: { ...CREATE_BODY, name: '不该被改成', dimensions: [{ name: 'd', items: [{ content: 'c', conceptId: 'no_such_concept' }] }] },
  });
  assert.equal(badUpdate.statusCode, 400);
  const afterBadUpdate = await http.inject({
    method: 'GET',
    url: `/api/plan-schemes/${scheme.id}`,
    headers: { authorization: `Bearer ${userToken}` },
  });
  const afterBadUpdateScheme = afterBadUpdate.json().scheme as { name: string; dimensions: unknown[] };
  assert.equal(afterBadUpdateScheme.name, '改名后的方案');
  assert.equal(afterBadUpdateScheme.dimensions.length, 1);

  // 10. clone 内置方案:生成自建副本,含全部维度条目。
  const cloneRes = await http.inject({
    method: 'POST',
    url: '/api/plan-schemes/scheme_mengxue/clone',
    headers: { authorization: `Bearer ${userToken}` },
  });
  assert.equal(cloneRes.statusCode, 200, cloneRes.body);
  const clone = cloneRes.json().scheme as { id: string; name: string; isBuiltin: boolean };
  createdSchemeIds.push(clone.id);
  assert.equal(clone.isBuiltin, false);
  assert.equal(clone.name, '蒙学（副本）');
  const cloneDetail = await http.inject({
    method: 'GET',
    url: `/api/plan-schemes/${clone.id}`,
    headers: { authorization: `Bearer ${userToken}` },
  });
  assert.equal((cloneDetail.json().scheme as { dimensions: unknown[] }).dimensions.length, 6);

  // 11. 内置方案不可改不可删。
  const putBuiltin = await http.inject({
    method: 'PUT',
    url: '/api/plan-schemes/scheme_mengxue',
    headers: { authorization: `Bearer ${userToken}` },
    payload: CREATE_BODY,
  });
  assert.equal(putBuiltin.statusCode, 403);
  const delBuiltin = await http.inject({
    method: 'DELETE',
    url: '/api/plan-schemes/scheme_mengxue',
    headers: { authorization: `Bearer ${userToken}` },
  });
  assert.equal(delBuiltin.statusCode, 403);

  // 12. owner 删除自建方案成功,再删 404。
  const del = await http.inject({
    method: 'DELETE',
    url: `/api/plan-schemes/${scheme.id}`,
    headers: { authorization: `Bearer ${userToken}` },
  });
  assert.equal(del.statusCode, 200);
  const delAgain = await http.inject({
    method: 'DELETE',
    url: `/api/plan-schemes/${scheme.id}`,
    headers: { authorization: `Bearer ${userToken}` },
  });
  assert.equal(delAgain.statusCode, 404);
  const index = createdSchemeIds.indexOf(scheme.id);
  if (index >= 0) {
    createdSchemeIds.splice(index, 1);
  }
});
