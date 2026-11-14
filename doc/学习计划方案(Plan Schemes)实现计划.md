# 学习计划方案(Plan Schemes)实现计划

## Context

`doc/分阶段学习方案.md` 已定义 23 个培养阶段方案(蒙学、小学一~六年级、初一~初三、高一~高三、大一~大四、研一~研三、硕一~硕三),每个方案按「维度(领域)→ 知识内容 → 学习程度」组织。目前系统中没有「方案」实体(只有单条学习计划 `study_plans`)。本次新增:系统内置默认方案 + 用户自建方案,含数据库迁移、服务端路由、路由级测试与 Flutter 端展示/创建。

已确认设计:

- 维度条目存文档文字内容,并**可选关联** `knowledge_concepts`(能匹配的挂上)。
- 自建方案支持**空白创建**与**一键复制内置方案**。

## 1. 数据库迁移 `server/db/024_plan_schemes.sql`(纯 SQL、幂等,风格同 020-023)

三张表:

```sql
plan_schemes (
  id text PK,
  name text NOT NULL,            -- 如「蒙学」「小学一年级」
  stage text NOT NULL,           -- mengxue/primary/junior/senior/college/graduate/master
  stage_sort int NOT NULL,       -- 阶段排序:蒙学0 … 硕士6
  sort_order int NOT NULL,       -- 阶段内排序(年级)
  description text,
  is_builtin boolean NOT NULL DEFAULT false,
  owner_user_id text REFERENCES users(id),  -- 内置为 NULL,自建为创建者
  created_at timestamptz DEFAULT now()
)
plan_scheme_dimensions (
  id text PK,
  scheme_id text NOT NULL REFERENCES plan_schemes(id) ON DELETE CASCADE,
  name text NOT NULL,            -- 维度名,如「语言与识字」「语文」
  sort_order int NOT NULL
)
plan_scheme_items (
  id text PK,
  dimension_id text NOT NULL REFERENCES plan_scheme_dimensions(id) ON DELETE CASCADE,
  content text NOT NULL,         -- 知识内容(文档文字)
  expected_level text,           -- 学习程度/能力表现
  concept_id text REFERENCES knowledge_concepts(id),  -- 可选关联
  sort_order int NOT NULL
)
```

种子数据:23 个内置方案(`is_builtin=true`),维度与条目取自 `doc/分阶段学习方案.md` 各表格(蒙学 6 维、小学各年级 5 维等),条目尽量关联到 020-023 已灌的概念(如语文→language 类概念);无匹配的 `concept_id` 置空。ID 用稳定前缀:`scheme_mengxue`、`scheme_p1`…`scheme_g3`、`scheme_c1`…、`scheme_r1`…、`scheme_m1`…,维度 `schm_<scheme>_<n>`,条目 `schi_<scheme>_<d>_<n>`,便于幂等 upsert。

## 2. 服务端 `server/src/plan_scheme/` 新模块(routes + repository,风格同 knowledge 模块)

路由,注册进 `server/src/app.ts`:

- `GET /api/plan-schemes` — 返回内置 + 本人自建方案列表(不含条目),按 stage_sort、sort_order 排。
- `GET /api/plan-schemes/:id` — 详情(维度+条目,条目带 concept 概要)。内置方案任何人可读;自建仅 owner。
- `POST /api/plan-schemes` — 自建(需 `requireAuth`):name/stage/description + dimensions[](name + items[{content, expected_level, concept_id?}])。zod 校验,失败 400 `invalid_request`。
- `PUT /api/plan-schemes/:id` — 仅 owner(403 否则);整体替换维度/条目(事务内删旧插新)。
- `DELETE /api/plan-schemes/:id` — 仅 owner;内置方案不可删(403)。
- `POST /api/plan-schemes/:id/clone` — `requireAuth`:复制任意可读方案为本人自建(name 加「(副本)」),返回新方案详情。

Repository 用 `pool` 参数化查询;所有写操作事务包裹。

## 3. 服务端测试 `server/test/plan_scheme.routes.test.ts`

仿 `server/test/routes.test.ts`:`buildApp()` + `http.inject()`,前置 seedUsers,`t.after()` 先删测试数据再 `http.close()` → `pool.end()`。覆盖:内置列表可见、匿名读详情 401/公开读 200、创建/更新/删除仅 owner、clone 复制条目、非 owner 修改 403、内置不可删改。

## 4. Flutter 端 `app/`

- 模型 `app/lib/plan_scheme/plan_scheme.dart`:`PlanScheme{id,name,stage,stageSort,sortOrder,description,isBuiltin,ownerUserId}`、`PlanSchemeDimension`、`PlanSchemeItem`,`fromJson`。
- API:`app/lib/data/study_api.dart` 增加 `listPlanSchemes/createPlanScheme/getPlanScheme/updatePlanScheme/deletePlanScheme/clonePlanScheme`。
- Repository:`study_repository.dart` 增加对应方法(带本地缓存,离线可读最近拉取的方案列表)。
- UI:
  - `app/lib/ui/plan_scheme/plan_schemes_page.dart`:方案列表,按阶段分组(蒙学/小学/…),内置方案标「内置」徽标;
  - `plan_scheme_detail_page.dart`:维度分节展示条目(知识内容+学习程度,关联概念可点进 `knowledge_detail_page`);
  - 自建入口:空白创建(简单表单:名称/阶段/维度+条目动态增删)与「复制为我的方案」按钮;
  - 从 `home_page.dart` 规划 Tab(`plan_view.dart`)加入口。

## 5. 文档同步(项目硬性约定)

- `README.md`:接口清单加 plan-schemes 各端点;
- `doc/数据库使用说明.md`:补 024 三表说明;
- `doc/进展.md`:记录本次改动;
- `doc/分阶段学习方案.md` 顶部加一句「本方案已作为系统内置学习计划方案灌库(迁移 024)」。

## 验证

1. `server`:确认 Docker 的 PostgreSQL 可用 → `npm run db:migrate`(024 落库)→ `npm run typecheck` → `npm test`(含新路由测试)。
2. `app`(在 `app/`):`flutter pub get` → `flutter analyze --no-fatal-infos` → `flutter test --reporter expanded`。
3. 手工冒烟:`npm run dev` 后 curl `GET /api/plan-schemes` 应返回 23 个内置方案;clone 一个后可在自建列表看到。

不提交 git,完成后汇报结果由你决定是否提交。
