-- 旧字段名清理：016 迁移把「领域」并入分类后，用户数据表里残留的 domain 列名
-- 改为 category 口径，与 DTO/客户端字段名对齐。值在 016 时已迁移为分类 id，无需改写。
ALTER TABLE study_profiles
  RENAME COLUMN focus_domain_id TO focus_category_id;

ALTER TABLE study_plans
  RENAME COLUMN domain_id TO category_id;

ALTER TABLE learning_records
  RENAME COLUMN domain_id TO category_id;
