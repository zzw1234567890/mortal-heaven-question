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
Epic: sprint-3
Feature: Sprint 3 完成（QA 签收 APPROVED + 代码已合并）
Task: commit 472288d，Sprint 3 完成定义 12/12 全勾选
<!-- /STATUS -->

<!-- QA RUN: 2026-08-15 | Sprint: sprint-3 | Verdict: APPROVED | Report: production/qa/qa-signoff-sprint-3-2026-08-15.md -->