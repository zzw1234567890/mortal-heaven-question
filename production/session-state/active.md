## Session Extract — /story-done 2026-08-13

- Verdict：COMPLETE
- Story：`production/epics/school-system/story-002-5-school-effects-undispellable-switch-clear.md` — 5 流派增益公式 + 不可驱散约束 + 切换清空
- Implementation：`src/core/school_system/school_system.gd`（5 个 effects 数组字段名/数值重写匹配 AC-001~005）
- Tests：`tests/unit/school_system/test_school_effects.gd`（20 测试，覆盖 AC-001~018），school_system 套件 53/53 passed
- Next recommended：Story 3-9（拆分 game_state_manager.gd）

---

## Session Extract — Story 3-9 拆分 GSM 2026-08-13

- Verdict：COMPLETE（game_state_manager.gd 1080 → 282 行，达成 ≤300 目标）
- 拆分结构（4 文件）：
  - `src/foundation/game_state_manager.gd`（282 行）——信号/枚举/数据域/生命周期 + 薄转发 wrapper
  - `src/foundation/gsm/gsm_atomic_writes.gd`（429 行）——22 个第二层原子写入方法 + 卡牌校验
  - `src/foundation/gsm/gsm_signal_router.gd`（141 行）——信号缓冲/帧末刷新/域信号路由/订阅
  - `src/foundation/gsm/gsm_serializer.gd`（311 行）——序列化/反序列化/域访问/深拷贝/默认值
- 委托模式：同 event_system 拆分先例（RefCounted delegate + init(gsm) + _init 装配）
- 回归：全量 53 scripts / 1003 tests，993 passed / 8 failing——与拆分前基线一致（8 个既有失败：cost_system 6 + realm 1 + event 1），零新增失败
- 注意：`tests/unit/gsm/` 下 4 个 `*_test.gd` 后缀文件名不以 `test_` 开头，GUT 未发现（孤儿测试）——既有问题，本 Story 未处理（属 3-10 范畴）
- Next recommended：Story 3-10（GSM 第二层方法独立单测补齐）或 3-11（ADR-0003 文档）

---

## 状态同步 2026-08-14

- sprint 进度：12/12 done（3-1~3-12）——Sprint 3 全部完成 ✅
- 剩余：无

---

## Session Extract — Sprint 3 QA 验收（smoke + team-qa）2026-08-15

- Verdict：APPROVED（QA 签收通过）
- 冒烟检查：PASS WITH WARNINGS（`production/qa/smoke-2026-08-15.md`）——1145/1146 通过，0 失败
- QA 签收：APPROVED（`production/qa/qa-signoff-sprint-3-2026-08-15.md`）——12/12 story PASS，零 S1/S2 缺陷
- 冒烟检查期间修复 3 个 EventSystem 测试文件 parse error（28 个哑测试解锁）：
  - `test_event_trigger.gd`（10 处 `var instance := es.trigger_event(...)` → `var instance: EventInstance = ...`）
  - `test_resolve_option.gd`（8 处 `var results := es.resolve_option(...)` → `var results: Array = ...`）
  - `test_select_event.gd`（续行 `+` 卡方表达式缩进错误 → 拆 `heavy_term`/`light_term`）
- 文档审查修复 1 处措辞矛盾：ADR-0003 与 `chain_handler.gd` docstring 中 `get_chain_event()`「不修改 visited_ids」→「不追加、不发射信号，但链结束分支 clear()」
- 全量测试：62 scripts / 1146 tests / 1145 passing / 1 pending（save_load 多步迁移）/ 0 failing
- sprint-3.md 完成定义更新：冒烟检查 ✅、QA 签收 ✅、无 S1/S2 bug ✅；剩「代码已审查并合并」一项未勾（待 /code-review + git 提交，需用户明确指示）
- 3 项 ADVISORY（S3/S4，不阻塞）：orphan 测试内存泄漏 / RealmSystem·SchoolSystem 未注册 Autoload / CardSystem 模板目录缺失
- Next recommended：/code-review 代码审查 → git 提交（需用户指示）→ 启动 Sprint 4（/dev-story combat-system）

---

## Session Extract — 修复 cost_system 既有 8 个测试失败 2026-08-14

- Verdict：FIXED（全量 1118 tests → 1117 passing / 1 pending，0 failing）
- 根因与修复（两类）：
  1. **6 个信号计数失败**（`tests/unit/cost_system/test_cost_signals.gd`）：`_track_signal` 连接晚于 `init_for_battle`，丢失 init 发射的 cost_changed → 移 `_track_signal` 到 `init_for_battle` 之前（test_ac002/003/004/006）
  2. **2 个 lambda 按值捕获 int 失效**（test_ac010/011）：GDScript lambda 对 int 按值捕获，闭包内 `+=`/`=` 不写回外部 → 改用 `Array` 承载可变值（`cat2b_received: Array = [0]`、`ui_cost_current: Array = [-1]`）
  3. **2 个 push_warning 计数失败**（`tests/integration/cost_system/test_cost_system_basic.gd`）：`_write_cost_to_gsm` → `_set_battle_cost` 在 battle=null 时 push_warning，叠加原警告 → 补 `GameStateManager.battle_start({})` / `battle_end({})` 包裹（test_ac006_spend_insufficient_push_warning、test_ac015_clear_then_add_temp_bonus_rejected）
  4. **1 个 risky 测试**（test_ac018_write_to_gsm_silent_when_method_missing）：Story 001 桩模式（has_method 返回 false）已过时，Story 002 已实现 `_set_battle_cost` → 改写为验证 battle=null 时 null 守卫静默跳过
- 变更文件：
  - `tests/unit/cost_system/test_cost_signals.gd`
  - `tests/integration/cost_system/test_cost_system_basic.gd`
- 回归：cost_system 套件 74/74 passed；全量 59 scripts / 1118 tests，1117 passing / 1 pending（save_load test_migration_chain 多步迁移，首版有意延后）
- 附注：`test_event_trigger.gd` 的 parse error（此前发现）已确认不在当前失败列表——event_system 套件 162/162 passed，无需处理
- Next recommended：启动 Sprint 4（Feature 层）——`/dev-story` 从 combat-system 起逐条填充 AC 并实现

---

## Session Extract — Story 3-12 Feature 层 Epic Story 预创建 2026-08-14

- Verdict：COMPLETE
- 范围（用户决策）：全部 18 个 Feature 系统 + 标题级骨架
- 产物：18 个 `production/epics/<name>/EPIC.md`（标题级 story 拆分表，AC 留待 `/dev-story` 填充）+ 更新 `production/epics/index.md`
- 18 个 Epic（Layer=Feature，Status=Backlog）：
  - 战斗子系统 6：combat-system(4) / card-effect-engine(5) / deployment-system(4) / binding-system(4) / formation-system(4) / ai-system(4)
  - 探索经济 6：exploration-system(5) / cultivation-system(4) / tribulation-system(4) / deck-editing-system(4) / alchemy-crafting-system(4) / inscription-system(3)
  - 成长元进度 3：identity-selection-system(3) / reincarnation-talent-system(3) / achievement-system(3)
  - 叙事 3：story-system(4) / dialogue-system(3) / ending-branch-system(3)
  - 合计 67 个 story 标题
- 关键架构事实（写入各 EPIC.md 的 ADR 引用）：
  - Autoload 编号与层定位从各 ADR 的「排序说明」提取
  - 非 Autoload 系统：alchemy/inscription/dialogue 为 RefCounted 服务类；ending 嵌入 StorySystem；reincarnation/achievement 经 ProgressionSystem(ADR-0012) 直写
- Next：Sprint 3 全部 12 个 story 完成。下一步建议用 `/dev-story` 从 combat-system 起逐条填充 AC 并实现 Feature 层（战斗子系统为 MVP 关键路径）。

---

## Session Extract — Story 3-11 ADR-0003 §visited_ids 生命周期文档补充 2026-08-14

- Verdict：COMPLETE
- 文件：`docs/decisions/ADR-0003-event-system-story-flags-owner-resource-templates.md`
- 变更：§循环检测算法 顶部加「2026-08-14 更新」标注（初版 `_check_chain_cycle` 伪代码已提取至 ChainHandler）；新增 §visited_ids 生命周期 小节，权威记录：
  - 所有权：`_chain_visited_ids` 唯一所有者 = EventSystem（`event_system.gd:81`），ChainHandler 经 `init(templates, visited_ids)` 注入引用（Array 引用类型，无副本同步）
  - 初始化：`_init()` 中空数组构造 + 注入共享引用（测试实例 `ES_SCRIPT.new()` 亦可用）
  - 清空语义：4 条链结束分支（无 chain_next / 深度截断 / 选项不匹配 / 循环命中）均 `clear()`
  - 追加语义：仅 `check_chain_cycle()` append；`get_chain_event()` 为纯查询（CQS）不修改
  - 边界：生命周期对齐「事件链」而非「单个事件」；Array 引用共享 → 外部不得在链中直接改写
- Next recommended：Story 3-12（Feature 层 Epic Story 预创建，nice-to-have，1 天）

---

## Session Extract — Story 3-10 GSM 第二层方法独立单测补齐 2026-08-14

- Verdict：COMPLETE
- 完成内容：
  1. **重命名 5 个孤儿测试**（`_test.gd` → `test_*.gd` + `.uid`，git mv）——GUT 前缀规则 `test_` 未匹配导致此前不被发现：
     - `tests/unit/gsm/atomic_write_methods_test.gd` → `test_atomic_write_methods.gd`
     - `tests/unit/gsm/autoload_and_tier1_read_test.gd` → `test_autoload_and_tier1_read.gd`
     - `tests/unit/gsm/serialize_deserialize_test.gd` → `test_serialize_deserialize.gd`
     - `tests/unit/gsm/signal_layer_and_batch_updated_test.gd` → `test_signal_layer_and_batch_updated.gd`
     - `tests/integration/gsm/validation_skip_and_enable_test.gd` → `test_validation_skip_and_enable.gd`
  2. **修复既有失效断言**（零覆盖原因：断言针对拆分前/旧数据模型）：
     - `test_autoload_and_tier1_read.gd`：`ling_cai == 0` → 四品质嵌套字典 `{low,medium,high,top}` 断言
     - `test_atomic_write_methods.gd`：7 个 `gsm.add_resource/spend_resource`（GSM 无此方法，属 ResourceSystem）重写为真实 GSM 第二层方法 `_set_resource_ling_shi`/`_set_resource_ling_cai`；reincarnation_reset 的 ling_cai 字典断言
     - `test_serialize_deserialize.gd`：`owned_cards = [1,2,3]`（int 数组）→ 卡牌实例字典数组（`_recover_card_id_counter` 期望 Dictionary 元素，int 触发类型赋值崩溃）
     - `test_validation_skip_and_enable.gd`：`id: 42` → `card_instance_id: 42`（`add_card_to_collection` 发射信号时读取 `card_instance_id`，非 `id`）
  3. **新增 6 个零覆盖方法独立单测**：`tests/unit/gsm/test_second_layer_methods.gd`（15 测试）
     - `_set_battle_status_snapshot`（写入/null 守卫/同值去重）
     - `set_session_scene`（写入 + 缓冲两条路径）
     - `remove_card_from_collection`（成功/校验跳过拒绝/未找到拒绝）
     - `restore_action_points`（增量/非正拒绝）
     - `unlock_talent`（append/去重）
     - `advance_chapter`（首章/旧章入 completed/同章去重/空拒绝）
- 回归：GSM 套件（unit + integration）119/119 全通过
- 全量：59 scripts / 1118 tests，1108 passing / 8 failing——8 个失败均为 **cost_system 既有失败**（拆分前基线已存在，非本次引入）
  - 6 个 `test_cost_signals.gd`（cost_changed 信号计数）+ 2 个 `test_cost_system_basic.gd`（push_warning 计数）：根源是 `_write_cost_to_gsm` 的 `has_method("_set_battle_cost")` 在动态分派 `GSM_SCRIPT.new()` 实例下返回 false，属 CostSystem↔GSM 接口既有缺陷，非 GSM 拆分/单测改动引入
- Next recommended：Story 3-11（ADR-0003 §visited_ids 生命周期文档补充）或 3-12（Feature 层预创建）

<!-- STATUS -->
Epic: sprint-4
Feature: Feature 层战斗子系统（25 story + 1 task）
Task: 4-0 已注册 RealmSystem+SchoolSystem，待 /dev-story 4-1（card-effect-engine story-001）
<!-- /STATUS -->

## Session Extract — Sprint 4 计划（/sprint-plan new）2026-08-16

- Verdict：COMPLETE（sprint-4.md + sprint-status.yaml 已写入）
- 范围（用户决策）：战斗子系统 6 Epic，25 story + 1 task = 26 项，**全部 must-have**（拒绝了制作人推荐的 must 17 / should 4 / nice 4 分层，接受"Feature 层压缩率可能衰减"的风险）
- 时间盒：7-8 日历日（2026-08-16 至 2026-08-23，8 天，缓冲 1.5d，可用 6.5d）
- 速度基准：改用**日历日**（Sprint 3 回顾行动项 #3）——Sprint 2/3 连续 4 天完成 14 天计划
- PR-SPRINT 关卡（review mode full）：producer 裁决 CONCERNS，三项结构性建议均已采纳：
  1. ai-system 提 must（原误归 should）——Phase 5 敌方行动直接调用 AISystem，无 AI 则回合无法闭环
  2. 新增 4-0 Autoload 注册任务——RealmSystem(#11)/SchoolSystem(#19) 已实现但未注册，combat Phase 4 依赖 get_suppression()
  3. 4-22 预估 1d → 1.5-2d（7 阶段状态机是最高复杂度单故事）
- 依赖排序：card-effect-engine(#10)→deployment(#17)/binding(#13)/formation(#23)→ai(#18)→combat(#9 编排器最后)
- 关键前置：落实 Sprint 3 回顾行动项 #1/#2（/story-done 门禁强化 + 测试清单完整性检查）
- Next recommended：`/qa-plan sprint`（实现前必需）→ `/dev-story` 从 4-0（Autoload 注册）起逐条填充 AC 并实现

---

## Session Extract — Sprint 4 QA 计划（/qa-plan sprint）2026-08-16

- Verdict：COMPLETE（`production/qa/qa-plan-sprint-4-2026-08-16.md` 已写入）
- 分类：25 story 全 Logic/Integration——**Logic 18（BLOCKING）+ Integration 7（BLOCKING）**，无 UI/Visual/Config；+ 4-0 task（冒烟范围）
- 预估测试数：约 **314 个测试函数**（Logic ~194 + Integration ~120），测试数最高 binding 4-11（~22）
- 7 个缺口（qa-lead 标记）：
  - **缺口 #1（已修复）**：9 个测试文件名 `_test.gd` 后缀 → 孤儿测试。已在 9 个 story 文件 `## Test Evidence` 修正为 `test_` 前缀（card-effect-engine 5 + binding 4，与 `.gutconfig.json` `prefix: "test_"` 一致）。实现时按修正后路径创建测试文件
  - **缺口 #5（已解决）**：AI Story 4-20 AC-011 语义冲突——GDD §公式4（AND）vs §边缘情况（OR）。game-designer 裁决 **OR 语义 + 显式哨兵（0=禁用）**：`(hp_below>0 AND hp_pct<=hp_below) OR (turn_after>0 AND turn>=turn_after)`；§公式4 的 `and` 为笔误；「最高难度回合兜底」降为配置层分级（`turn_after>0`）。已同步 GDD（7 处）+ story AC-010/011 + QA 计划。ADR-0017 无公式冲突未改（第 448 行 HP 触发为 OR 子集）
  - 缺口 #2：PRD 累加常数 C 未校准（4-4 AC-002 区间脆弱）
  - 缺口 #3：性能断言 CI/无头波动（建议宽松阈值 ×3 容差）
  - 缺口 #4：assert 守卫仅 debug 生效（4-10）
  - 缺口 #6：call_deferred 帧调度测试需 GUT await（4-22）
  - 缺口 #7（非阻塞）：formation GDD §公式编号错乱
- 冒烟关键点：**4-0 Autoload 顺序矛盾**——控制清单 CombatSystem 列 #9 但其 `_ready()` 依赖 9 子系统（#10~#23 均在 #9 后）；sprint-4.md 已声明「CombatSystem 最后注册」，4-0b 需终验（调顺序 or `_ready()` `_initialized` 延迟初始化）
- Next recommended：`/dev-story` 从 4-0（Autoload 注册）起逐条实现；先裁决缺口 #5（game-designer）+ 落实 Sprint 3 回顾行动项 #1/#2（/story-done 门禁强化）

<!-- QA RUN: 2026-08-15 | Sprint: sprint-3 | Verdict: APPROVED | Report: production/qa/qa-signoff-sprint-3-2026-08-15.md -->
<!-- QA-PLAN: 2026-08-16 | Sprint: sprint-4 | 25 story (Logic 18 / Integration 7) + 1 task | 约 314 测试 | Report: production/qa/qa-plan-sprint-4-2026-08-16.md | 缺口 #1 已修复；缺口 #5 已裁决（OR 语义） -->
<!-- GDD 修订: 2026-08-16 | design/gdd/ai-system.md | Boss 阶段转换触发 OR 语义 + 0=禁用哨兵（game-designer 裁决） -->

---

## Session Extract — Story 4-0 Autoload 注册 2026-08-16

- Verdict：PARTIAL（RealmSystem+SchoolSystem 已注册；6 Feature Autoload 待各系统实现时注册）
- 变更：`project.godot` `[autoload]` 段在 StatusEffectSystem(#10) 后追加 RealmSystem(#11) + SchoolSystem(#19)
- 验证：headless 启动退出码 0（仅 CardSystem 模板目录缺失/GSM 校验空库两个既有 advisory，非本次引入）；全量 GUT 62 scripts / 1146 tests / 1145 passing / 1 pending / 0 failing——与 Sprint 3 QA 基线完全一致，零回归
- 说明：RealmSystem/SchoolSystem 均 `extends Node` 无 `_ready()` 依赖（RealmSystem 有 `get_current_property` GSM 守卫，无 `_ready` 强依赖），注册安全
- 剩余（4-0b 终验）：6 Feature Autoload（CombatSystem#9/CardEffectEngine#10/BindingManager#13/DeploymentSystem#17/AISystem#18/FormationSystem#23）待各系统代码实现时注册，届时终验「CombatSystem 最后注册」顺序矛盾（QA 计划 §四）
- Next：/dev-story 4-1（card-effect-engine story-001 EffectTemplate/EffectInstance 双层对象模型）
---

## Session Extract — Story 4-1 EffectTemplate/EffectInstance 双层对象模型 2026-08-16

- Verdict：COMPLETE（4-1 done，零回归）
- 变更：`src/feature/card_effect_engine/` 新建 8 文件（effect_template.gd / effect_base.gd @abstract / instant_effect.gd / persistent_effect.gd / triggered_effect.gd / replacement_effect.gd / effect_factory.gd / card_effect_engine.gd 5 信号声明，未注册 project.godot）；`event_enums.gd` OutcomeType 扩展 12→17（追加 APPLY_STATUS=12/MODIFY_STAT=13/TRIGGER_CHAIN=14/ACTIVATE_FORMATION=15/MODIFY_COST=16）；`event_outcome.gd` @export_enum 同步 12→17
- 测试：`tests/unit/card_effect_engine/test_template_instance_model.gd` 29 测试 / 71 断言全通过；全量 63 scripts / 1175 tests / 1174 passing / 1 pending / 0 failing——零回归（修正了 event_system 2 个既有断言 12→17）
- 关键裁决：qa-lead GAPS（专属字段存在性 + 未知 type 拒绝 + conditions 深拷贝隔离）→ 补齐 5 测试升 ADEQUATE；lead-programmer CONCERNS（C1 factory 签名 drift）→ technical-director 裁决「两层 API 分离」——低层 `EffectFactory.create_instance(template: EffectTemplate, ...)`（纯构造不查注册表）+ 高层 `CardEffectEngine.create_instance(template_id: StringName, ...)`（查注册表→委托低层，Story 002 实现）
- ADR 回写：ADR-0009 §双层对象模型（L99）、§需求（L57）、§对象生命周期（L309-313）已同步签名，消除 57/99 内部矛盾 + EffectInstance→EffectBase 命名漂移
- Godot 4.6 quirk 记录：`@abstract` 类 `.new()` 是编译期 parse error；`GDScript.can_instantiate()` 对 abstract 返回 true（误），`GDScript.is_abstract()` 正确——测试用 `is_abstract()`
- 清理：删除 12 个 `_scratch_*` 探针文件（首轮 4-1 agent 遗留）
- Next：/dev-story 4-2（ResolutionStack 栈式结算引擎，blocker 4-1 已解除）
<!-- STATUS -->
Epic: sprint-4
Feature: Feature 层战斗子系统（25 story + 1 task）
Task: 4-1 完成（card-effect-engine 对象模型），待 /dev-story 4-2（ResolutionStack）
<!-- /STATUS -->

---

## Session Extract — Story 4-2 ResolutionStack 栈式结算引擎 2026-08-16

- Verdict：COMPLETE（4-2 done，零回归）
- 变更：`src/feature/card_effect_engine/resolution_stack.gd`（class_name ResolutionStack extends RefCounted）——5 级主排序（TIER_ACTIVE_PLAY/FIRST_STRIKE/NORMAL/ENEMY 命名常量）+ 次级 priority 决胜 + 二分中分辨率插入 + LIFO pop_back 出栈 + resolve_all(resolver: Callable)
- 设计决策：排序上下文（先发/阵营/主动出牌）经 `set_sort_context(active_card_id, first_strike_card_ids, player_side_card_ids)` 按 source_card_instance_id 注入——因 EffectBase 是 Story 001 最小字段集，不污染对象模型（lead-programmer APPROVE 确认）
- 测试：`tests/unit/card_effect_engine/test_resolution_stack.gd` 12 测试（AC-001/002 + QA edges + 5 级全序 + 中分辨率插入 + LIFO + 空栈/null 防御）；全量 64 scripts / 1187 tests / 1186 passing / 1 pending / 0 failing 零回归
- 关卡：lead-programmer APPROVE（C1 二分 O(n) 移位注释补充 + C3 tier 魔数→命名常量已采纳；C2 resolve_all 无终止保护由 Story 003 深度截断兜住）；qa-lead ADEQUATE
- 关键经验：新增 class_name 需 `--headless --import` 重建全局类缓存，否则 GUT 报 "Could not find type ResolutionStack"
- 测试修正：中分辨率插入测试初版把残留效果 C 设为「普通己方」导致 C(t 更大)先于 A 出栈——修正为 C=敌方（tier 3）才正确验证「A 触发 B 插入在残留前」
- Next：/dev-story 4-3（触发链硬限制 10 层 + visited_card_ids 循环检测，blocker 4-2 已解除）
<!-- STATUS -->
Epic: sprint-4
Feature: Feature 层战斗子系统（25 story + 1 task）
Task: 4-2 完成（ResolutionStack），待 /dev-story 4-3（触发链硬限制）
<!-- /STATUS -->

---

## Session Extract — Story 4-3 触发链硬限制 10 层 + 循环检测 2026-08-16

- Verdict：COMPLETE（4-3 done，零回归）
- 变更：`src/feature/card_effect_engine/trigger_chain_state.gd`（新类，纯逻辑：MAX_DEPTH=10 + CheckResult 枚举 + check_and_record + build_overflow_message）；`resolution_stack.gd` resolve_all 签名扩展（chain_state/overflow_handler/cycle_skip_handler 可选参数，截断/跳过均 continue 非 break）
- 设计决策：TriggerChainState 纯逻辑无副作用（不日志不发射信号），日志/信号由调用方 CardEffectEngine Autoload 负责；overflow 消息追加截断者 K 到 chain 尾（AC-003 字面 A→B→...→K 为 11 节点）
- 测试：`tests/unit/card_effect_engine/test_trigger_chain_10_layer_cycle.gd` 13 测试（纯状态单测 6 + resolve_all 集成 7）；全量 65 scripts / 1198 tests / 1197 passing / 1 pending / 0 failing 零回归
- 关卡：lead-programmer APPROVE（C1 visited_card_ids→Dictionary[int,bool] 已采纳；C2 chain 追加 K 已采纳；C3 cycle_skip_handler 已加）；qa-lead GAPS→GAP-1 continue vs break 语义已补 12 效果用例锁定
- 关键经验：GDScript lambda 按值捕获标量——overflow_count 需用 Array 包装才能被 lambda 闭包修改
- 全量测试含 1 个 flaky（realm_system test_ac010 GSM.realm_changed 帧末信号，单独跑 14/14 全过，全量偶发 1 失败）——既有问题非本次引入，Sprint 3 回顾行动项 #1（/story-done 门禁强化）已记录
- Next：/dev-story 4-4（PRD 伪随机分布引擎 5% 步进 + 怜悯保护，blocker 4-1 已解除）
<!-- STATUS -->
Epic: sprint-4
Feature: Feature 层战斗子系统（25 story + 1 task）
Task: 4-3 完成（触发链硬限制），待 /dev-story 4-4（PRD 伪随机分布引擎）
<!-- /STATUS -->

---

## Session Extract — Story 4-4 PRD 伪随机分布引擎 2026-08-16

- Verdict：COMPLETE（4-4 done，零回归）
- 变更：`src/feature/card_effect_engine/prd_engine.gd`（class_name PRDEngine extends RefCounted）——标准 PRD：起始=C、失败累加 C、触发重置 C、怜悯 ceil(1/p) 连败强制触发、calibrate_C 二分求解（30%→C≈0.108）
- 关键裁决：原 ADR-0009/GDD 公式「起始=P_base + 累加 P_base×C」结构错误（探针实测 C=0.3 长期触发率 40% > 标示 30%，任何 C∈[0.3,1.0] 均过度触发）→ game-designer 裁决改标准 PRD（起始=C<p，累加 C），runtime calibrate_C 使含怜悯截断的 E[N]=1/p
- 同步：GDD §9 机制 + 调优表（C 恒<p 非 0.3-1.0）+ 待解决问题 #4（已解决）+ ADR-0009 §PRD 伪随机分布引擎 + QA 缺口 #2（已解决）
- 测试：`tests/unit/card_effect_engine/test_prd_distribution.gd` 11 测试（AC-001 怜悯不变式/阈值/5次内触发 + AC-002 [24,36] + C 校准 + 确定性 + 每卡独立 + 非法拒绝 + 重置）；全量 66 scripts / 1208 tests / 1207 passing / 1 pending / 0 failing 零回归
- 关卡：lead-programmer CONCERNS（C1 get_p_current 语义歧义已修正注释 + C2 ADR 伪代码顺序回写 + 二分常量注释）；qa-lead ADEQUATE
- 关键经验：PRD 起始概率必须 < 标示值（业界标准），P_start=p 结构上必过度触发；GDScript lambda 捕获标量需 Array 包装
- Next：/dev-story 4-5（AI 干跑评估接口 GameStateSnapshot 不可变纯计算，blocker 4-3+4-4 已解除）
<!-- STATUS -->
Epic: sprint-4
Feature: Feature 层战斗子系统（25 story + 1 task）
Task: 4-4 完成（PRD 引擎），待 /dev-story 4-5（AI 干跑评估接口）
<!-- /STATUS -->

---

## Session Extract — Story 4-5 AI 干跑评估接口 2026-08-17

- Verdict：COMPLETE（4-5 done，零回归）
- 变更：`src/feature/card_effect_engine/game_state_snapshot.gd`（class_name GameStateSnapshot extends RefCounted，构造+getter 均 deep copy 不可变）+ `effect_evaluation.gd`（EffectEvaluation 结果 DTO，damage/healing/stat_changes/statuses_applied/is_overkill/is_overheal + damage_only/heal_only 静态工厂）+ `card_effect_evaluator.gd`（class_name CardEffectEvaluator extends RefCounted，evaluate_effect/evaluate_effect_probabilistic/simulate_chain/get_effect_categories + EffectCategory 枚举）
- 简化模型：伤害/治疗 = floori(effect_value × binding_multiplier)，分类按 effect_type 字符串前缀（未读 CardType）；simulate_chain 恒单根、would_overflow 恒 false、probability 恒 1.0——完整结算待 CardEffectEngine 接线
- 测试：`tests/unit/card_effect_engine/test_ai_dry_run_snapshot.gd` 17 测试（AC-001~003 + stat_changes/statuses_applied 分支 + 快照深拷贝/未知角色 + 性能单点子断言）；全量 67 scripts / 1225 tests / 1224 passing / 1 pending / 0 failing 零回归
- 关卡：lead-programmer CONCERNS→采纳（C1 签名漂移 card_id→card_data:Variant 记录 + C2 create_evaluation_snapshot defer + C3 简化模型边界标注 + C4 _int_field/_stringname_field 去存疑 `in` 改 get() + C5 文档措辞）；qa-lead GAPS→补齐（G1 stat_changes/statuses_applied + G2 AC-003 单点性能子断言 + G3 would_overflow 简化契约锁定）
- 关键经验：GDScript `in` 运算符不适用于 Object 属性成员测试（用 get() 判空）；性能断言按 QA 缺口 #3 放宽阈值（288 次 <100ms / 单次 <1ms / simulate_chain <5ms）
- Next：/dev-story 4-6（deployment-system 内部状态机 STANDBY→READY→ACTED，blocker 无）
<!-- STATUS -->
Epic: sprint-4
Feature: Feature 层战斗子系统（25 story + 1 task）
Task: 4-5 完成（AI 干跑评估接口），待 /dev-story 4-6（deployment-system 内部状态机）
<!-- /STATUS -->

---

## Session Extract — Story 4-6 deployment-system 内部状态机 2026-08-17

- Verdict：COMPLETE（4-6 done，零回归）
- 变更：`src/feature/deployment_system.gd`（extends Node 不声明 class_name，Autoload #17）——FieldState 枚举（EMPTY/STANDBY/READY/ACTED/DEAD）+ _field 阵位模型 + setup_field（自动/手动分配 + 全部 STANDBY）+ 查询 API（get_field/get_character_slot/get_front_count/get_empty_slots/can_deploy/is_standby/set_acted）
- 关键裁决：ADR-0016 原文阵位算法「顺序填充 [0,1,2,3,4,5]」与 GDD §2 矛盾（金丹 4 人会成前 3 后 1）→ 实现改用 FRONT_CAPACITY_BY_MAX_DEPLOY 表按境界前排配额（2/3/4→前2，5/6→前3），已回写 ADR-0016 retrofit
- 测试：`tests/unit/deployment_system/test_internal_state_machine.gd` 22 测试（AC-001~018 + DEAD/EMPTY set_acted + get_front_count 全灭 0）；全量 68 scripts / 1247 tests / 1246 passing / 1 pending / 0 failing 零回归
- 关卡：lead-programmer CONCERNS→采纳（C1 ADR 算法修正回写 + C2 FRONT_CAPACITY 硬编码上报裁决 + C3 FileAccess 正则测试移除 + C4 手动超配待 game-designer 澄清）；qa-lead GAPS→补齐（G1 DEAD/EMPTY set_acted + G2 全灭 0 + G3 get_character_slot(-1) 哨兵守卫）
- 关键经验：Autoload 测试用 `DS_SCRIPT.new()` + 动态分派；`get_instance_base_type()` 是实例方法不能直接调 preload 类；境界阵位分布是「前排配额」非「顺序填充」
- Next：/dev-story 4-7（deploy/remove/is_targetable 前后排保护 O(1)，blocker 4-6 已解除）
<!-- STATUS -->
Epic: sprint-4
Feature: Feature 层战斗子系统（25 story + 1 task）
Task: 4-6 完成（deployment-system 内部状态机），待 /dev-story 4-7（deploy/remove/is_targetable）
<!-- /STATUS -->

---

## Session Extract — Story 4-7 deployment-system deploy/remove/is_targetable 2026-08-17

- Verdict：COMPLETE（4-7 done，零回归）
- 变更：`src/feature/deployment_system.gd` 增量扩展——deploy（战中补位，前置检查：不可用→已在场→max_deploy 上限→空位→槽位合法性）/ remove_character（阵亡清位，不负责绑定卡洗回）/ is_targetable（6 步前后排保护判断）+ 3 个 Cat 2b 信号（character_deployed/character_removed/front_line_breached 经 GSM._emit_signal_safe 路由）
- 关键裁决：lead-programmer CONCERNS→deploy 内部补 `deployed >= max_deploy → field_full` 防御检查（原 ADR 编排靠 can_deploy 前置，独立调用不安全）；deploy_turn=0 临时桩注释标注
- 测试：`tests/unit/deployment_system/test_deploy_targetable.gd` 22 测试（AC-001~015 + 哨兵守卫/已在场/穿透短路/上限 4 分支回归）；全量 69 scripts / 1269 tests / 1268 passing / 1 pending / 0 failing 零回归
- 关卡：lead-programmer CONCERNS→采纳（C1 deploy 上限 + C2 删 FileAccess 源码 contains 改运行时 + C3 deploy_turn 桩注释）；qa-lead GAPS→补齐（G1 AC-001 前排优先修正 + G2 源码 contains 移除 + G3 front_line_breached 运行时 + G4 deploy_turn + G5 4 分支回归）
- 关键经验：源码 contains 断言违反「单元测试不得依赖文件系统」+ 脆弱——改运行时行为验证；Cat 2b 信号经 `GameStateManager.get_script()._emit_signal_safe`（Script.has_method 识别 static 方法）
- Next：/dev-story 4-8（战斗结束 serialize_field 快照导出 GSM.battle.deployment_snapshot，blocker 4-7 已解除）
<!-- STATUS -->
Epic: sprint-4
Feature: Feature 层战斗子系统（25 story + 1 task）
Task: 4-7 完成（deploy/remove/is_targetable），待 /dev-story 4-8（serialize 快照导出）
<!-- /STATUS -->

---

## Session Extract — Story 4-8 deployment-system serialize snapshot export 2026-08-18

- Verdict：COMPLETE（4-8 done，零回归）
- 变更：`src/feature/deployment_system.gd` 增量扩展——serialize_field（6 阵位，state 用 String 序列化）/ deserialize_field（键归一：int/String key 均接受 + 缺字段默认值填充 + 非法 state 回退 EMPTY）/ sync_unavailable_to_gsm / load_unavailable_from_gsm / write_snapshot_to_gsm + _get_gsm（SceneTree.root 查找，同 StatusEffectSystem 先例）+ _state_to_string/_state_from_string 枚举双向映射；GSM 第二层 `_set_battle_deployment_snapshot` + `_set_player_unavailable_characters`（null 守卫 + deep_equal 去重 + _buffer_change）+ player 默认域补 `unavailable_characters: {}`
- 关键裁决：lead-programmer CONCERNS→C-1 是首要架构隐患（serialize_field int-key 快照 JSON round-trip 后 key 变 String，deserialize 若仅匹配 int key 会静默丢阵位）→ deserialize 键归一修复 + 补 JSON round-trip 回归测试；C-3 死守卫移除；C-4 测试清理直写属性加注释标注
- 测试：`tests/integration/deployment_system/test_serialize_snapshot.gd` 20 测试（AC-001~011 + 双守卫 null/missing-method 子类覆盖 + 缺字段默认值 + 非法 state 回退 + JSON round-trip String key）；全量 70 scripts / 1289 tests / 1288 passing / 1 pending / 0 failing 零回归
- 关卡：qa-lead GAPS→补齐（G1 _get_gsm 返回 null 双守卫路径 + G2 deserialize 缺字段默认值填充 + G3 _state_from_string 非法字符串回退）；lead-programmer CONCERNS→采纳（C-1 键归一 + C-3 死守卫 + C-4 注释）
- 关键经验：Godot 4 JSON.stringify 会把 int-key Dictionary 转 String key——序列化/反序列化成对 API 必须做键归一防御，否则读档静默丢数据；测试子类 `class X extends "res://...gd"` 可覆盖 Autoload 脚本的 `_get_gsm()` 返回值以模拟 GSM 缺失分支
- Next：/dev-story 4-9（clear_standby_state + mark_unavailable + revive_character，blocker 4-7 已解除）
<!-- STATUS -->
Epic: sprint-4
Feature: Feature 层战斗子系统（25 story + 1 task）
Task: 4-8 完成（serialize 快照导出），待 /dev-story 4-9（clear_standby_state + mark_unavailable + revive_character）
<!-- /STATUS -->
