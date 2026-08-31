# QA 计划：Sprint 6 — Feature 层叙事经济线

**日期**：2026-08-31
**由**：手动生成（参照 Sprint 5 QA 计划模板）
**范围**：5 Epic × 17 story，形成完整的叙事经济闭环
**引擎**：Godot 4.6
**测试框架**：GUT
**Sprint 文件**：`production/sprints/sprint-6.md`
**Manifest Version**：2026-08-05

> **分类原则**：每个 story 头部 `Type:` 字段分类。17 个 story 全部为 Logic 或 Integration，无 UI/Visual/Config 类。

---

## 一、测试摘要表

| # | Story | Epic | 类型 | 测试文件路径 | 实际测试数 |
|:--:|-------|------|:----:|-------------|:----------:|
| 6-1 | 身份模板 const Dictionary（6 个）+ 查询 API | identity-selection-system | Logic | `tests/unit/identity_selection_system/test_identity_templates.gd` | 13 |
| 6-2 | apply_identity 原子操作（编排现有服务 API） | identity-selection-system | Integration | `tests/unit/identity_selection_system/test_apply_identity.gd` | 11 |
| 6-3 | is_identity_selected / get_current_identity | identity-selection-system | Logic | `tests/unit/identity_selection_system/test_identity_query.gd` | 4 |
| 6-4 | 配方表（const Dictionary, 8 配方）+ 查询 API | alchemy-crafting-system | Logic | `tests/unit/alchemy_system/test_recipe_table.gd` | 12 |
| 6-5 | craft_pill / craft_artifact 炼制编排 | alchemy-crafting-system | Logic | `tests/unit/alchemy_system/test_craft_orchestration.gd` | 10 |
| 6-6 | roll_quality / forge_artifact_stat 品质与属性 | alchemy-crafting-system | Logic | `tests/unit/alchemy_system/test_quality_and_stats.gd` | 9 |
| 6-7 | apply_reroll 品质重掷 + 独立 RNG 实例 | alchemy-crafting-system | Logic | `tests/unit/alchemy_system/test_reroll_and_rng.gd` | 8 |
| 6-8 | generate_candidates 候选属性生成 | inscription-system | Logic | `tests/unit/inscription_system/test_candidate_generation.gd` | 10 |
| 6-9 | inscribe / apply_inscription 铭刻编排 | inscription-system | Logic | `tests/unit/inscription_system/test_inscribe_orchestration.gd` | 10 |
| 6-10 | inscription_cost / dismantle_inscription_refund 成本 | inscription-system | Logic | `tests/unit/inscription_system/test_cost_and_refund.gd` | 10 |
| 6-11 | CHAPTER_TEMPLATES 5 章静态定义 | story-system | Logic | `tests/unit/story_system/test_chapter_templates.gd` | 10 |
| 6-12 | can_enter_chapter / get_chapter_context | story-system | Logic | `tests/unit/story_system/test_chapter_context.gd` | 10 |
| 6-13 | complete_chapter + GSM narrative.* 独占写入 | story-system | Integration | `tests/unit/story_system/test_complete_chapter.gd` | 10 |
| 6-14 | is_boss_unlocked / on_boss_defeated | story-system | Logic | `tests/unit/story_system/test_boss_unlock.gd` | 10 |
| 6-15 | EndingEvaluator 纯函数工具类 + evaluate | ending-branch-system | Logic | `tests/unit/ending_branch_system/test_ending_evaluator.gd` | 10 |
| 6-16 | _calculate_scores / _resolve_tie 评分与平局 | ending-branch-system | Logic | `tests/unit/ending_branch_system/test_scores_and_tie.gd` | 10 |
| 6-17 | _determine_variant / _generate_epilogue 变体与尾声 | ending-branch-system | Logic | `tests/unit/ending_branch_system/test_variant_and_epilogue.gd` | 10 |

**实际测试总数**：**167** 个测试函数（Logic 151 + Integration 16）

### 分类统计

| 类型 | 数量 | 关卡等级 | 证据位置 |
|:----:|:----:|:--------:|---------|
| **Logic** | 15 | BLOCKING（阻塞） | `tests/unit/[system]/` |
| **Integration** | 2 | BLOCKING（阻塞） | `tests/unit/[system]/` |
| **合计** | 17 | — | — |

**Logic 分布**：identity 2、alchemy 4、inscription 3、story 3、ending 3 = 15
**Integration 分布**：identity 1、story 1 = 2

---

## 二、全量测试基线

**最终全量测试结果**（2026-08-31）：

| 指标 | 值 |
|------|----|
| Scripts | 121 |
| Tests | 2227 |
| Passing | 2226 |
| Pending | 1（既有 save_load 迁移测试） |
| Failing | 0 |
| Asserts | 8318 |
| Orphans | 1（既有） |

**零回归**——Sprint 6 新增 17 个测试脚本 / 167 个测试，全部通过。

---

## 三、按 Epic 分组的测试覆盖

### identity-selection-system（3 Story，28 测试）

- **6-1 身份模板**（13 测试）：6 个身份模板 const Dictionary + get_identity_templates + get_identity_by_id + 初始卡组/法宝/灵根验证
- **6-2 apply_identity**（11 测试）：编排 CardSystem.create_instance + DeckEditingSystem.initialize_initial_deck + ResourceSystem 资源注入 + GSM player.* 写入
- **6-3 查询 API**（4 测试）：is_identity_selected + get_current_identity + GSM 读取

### alchemy-crafting-system（4 Story，39 测试）

- **6-4 配方表**（12 测试）：8 配方 const Dictionary + get_recipe + get_all_recipes + 材料验证
- **6-5 炼制编排**（10 测试）：craft_pill + craft_artifact + 材料扣除 + 产出实例创建
- **6-6 品质属性**（9 测试）：roll_quality 概率 + forge_artifact_stat 属性计算 + 品质权重
- **6-7 重掷**（8 测试）：apply_reroll + 独立 RNG 实例 + 重掷成本

### inscription-system（3 Story，30 测试）

- **6-8 候选生成**（10 测试）：11 种副属性权重表 + generate_candidates + 去重采样 + 方向加成
- **6-9 铭刻编排**（10 测试）：inscribe + apply_inscription + 替换/新增逻辑 + MAX_INSCRIPTIONS
- **6-10 成本返还**（10 测试）：inscription_cost 递增 + dismantle_inscription_refund 比例

### story-system（4 Story，40 测试）

- **6-11 章节模板**（10 测试）：5 章 const Dictionary + get_chapter_data + get_all_chapter_ids
- **6-12 章节上下文**（10 测试）：can_enter_chapter 三重校验 + get_chapter_context 地图映射
- **6-13 完成章节**（10 测试）：complete_chapter 编排 + GSM narrative.* 独占写入 + game_victory
- **6-14 Boss 解锁**（10 测试）：is_boss_unlocked 必经事件 + on_boss_defeated + 信号

### ending-branch-system（3 Story，30 测试）

- **6-15 EndingEvaluator**（10 测试）：evaluate 主入口 + ENDING_TEMPLATES 3 条线 + 返回字段
- **6-16 评分平局**（10 测试）：_calculate_scores 权重求和 + _resolve_tie 偏斜+优先级
- **6-17 变体尾声**（10 测试）：_determine_variant 6 变体 + _generate_epilogue 插入段落

---

## 四、Autoload 注册验证

Sprint 6 新增 2 个 Feature 层 Autoload，已注册到 `project.godot`：

| Autoload | 编号 | 脚本路径 | 依赖 |
|----------|:----:|----------|------|
| IdentitySelectionSystem | #21 | `res://src/feature/identity_selection_system.gd` | GSM, CardSystem, DeckEditingSystem |
| StorySystem | #25 | `res://src/feature/story_system.gd` | GSM, EventSystem |

AlchemyCraftingSystem 和 InscriptionSystem 为 RefCounted 服务类，不注册 Autoload。EndingEvaluator 嵌入 StorySystem，不独立注册。

全量测试在 Autoload 注册后零回归——初始化顺序正确。

---

## 五、GSM 基础设施扩展

Sprint 6 扩展了 GSM narrative 域，支撑 StorySystem 独占写入：

| 扩展项 | 文件 | 说明 |
|--------|------|------|
| +4 原子写入方法 | `gsm_atomic_writes.gd` | add_required_event_completion / set_narrative_boss_unlocked / set_narrative_boss_defeated / set_ending_chosen |
| +4 薄转发 wrapper | `game_state_manager.gd` | 第二层→第一层转发 |
| narrative 域默认值扩展 | `gsm_serializer.gd` | completed_required_events / boss_unlocked / boss_defeated / ending_chosen |

---

## 六、已知技术债务（非阻塞）

| 项 | 来源 | 影响 | 计划 |
|----|------|------|------|
| Feature 层文件超 300 行 | Sprint 4/5 QA 遗留 | 多个 Feature 文件超 300 行 | 后续 Sprint 重构 |
| CardSystem 掉落规则接线 | Sprint 5 桩实现遗留 | 战利品桩 | 后续 Sprint 接线 |
| RealmSystem 天劫 Boss 配置接线 | Sprint 5 桩实现遗留 | 天劫 Boss 桩 | 后续 Sprint 接线 |
| StatusEffectSystem 心魔 debuff 接线 | Sprint 5 桩实现遗留 | 心魔桩 | 后续 Sprint 接线 |
| InputManager 锁管理接线 | Sprint 5 桩实现遗留 | 输入锁桩 | 后续 Sprint 接线 |
| save_load 1 pending test | Sprint 1 既有 | 多步迁移未实现 | 首次升级时实现 |
| InputManager 1 orphan | Sprint 1 既有 | 对象清理 | 后续排查 |

---

## 七、冒烟检查清单

- [x] 全量测试通过（121 scripts / 2227 tests / 0 failing）
- [x] 2 个新 Autoload 注册且初始化顺序正确
- [x] Sprint 6 所有 17 Story 状态为 Done
- [x] GSM serialize/deserialize 往返验证（narrative 域扩展）
- [x] 跨 Epic 依赖链验证（identity #002 → DeckEditingSystem；ending #001 → story-system #003）
- [x] 零新增回归（对比 Sprint 5 基线 104 scripts / 2060 tests）

---

## 八、QA 签收建议

**建议**：APPROVED WITH CONDITIONS

**理由**：
- ✅ 17/17 Story 全部完成，167 个新增测试全部通过
- ✅ 零回归（全量 2227 tests / 0 failing）
- ✅ 2 个 Autoload 注册验证通过（IdentitySelectionSystem #21 + StorySystem #25）
- ✅ 跨 Epic 依赖链正确（identity → DeckEditingSystem；ending → story-system narrative 域）
- ✅ GSM narrative 域扩展无回归
- ⚠️ 7 项既有技术债务非阻塞（Sprint 4/5 遗留，非 Sprint 6 引入）

**Conditions**：
1. 后续 Sprint 需接线 CardSystem 掉落规则替换战利品桩实现
2. 后续 Sprint 需接线 RealmSystem 天劫 Boss 配置替换桩默认值
3. 后续 Sprint 需接线 StatusEffectSystem 心魔 debuff 替换桩
4. 后续 Sprint 需接线 InputManager 锁管理替换桩
5. Feature 层文件超 300 行需在后续 Sprint 重构
