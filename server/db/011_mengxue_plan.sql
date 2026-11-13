-- 蒙学计划：明确包含识文、识数、识物，并更新幼儿年龄档命名与说明。
-- 可重复执行：仅更新描述性字段，不影响既有 id 与关联。

UPDATE knowledge_age_bands
   SET label = '蒙学（3-5岁）',
       short_label = '蒙学',
       how_to_learn = '蒙学计划包含识文、识数、识物。点大图、听人说话，在同一条路线里启蒙。'
 WHERE id = 'toddler';
