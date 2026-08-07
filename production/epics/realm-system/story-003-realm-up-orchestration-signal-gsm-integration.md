# Story 003: realm_up() 突破编排 + realm_upgraded 信号 + GSM 集成

> **Epic**: realm-system
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration（需集成测试）
> **Estimate**: 3h
> **Manifest Version**: 2026-08-05
> **Last Updated**: 2026-08-06

## Context

**GDD**: `design/gdd/realm-system.md`
**Requirement**: `TR-realm-003`（境界提升流程——突破成功后 realm_up() 协调多方状态变更）
*（需求文本见 `docs/architecture/tr-registry.yaml`——审查时读取最新版）*

**ADR Governing Implementation**: ADR-0010（境界系统——专用 Autoload 服务 + 静态数据表 + GSM 状态所有权分离）
**ADR Decision Summary**: `realm_up(current_level)` 是原子编排器——调用 `GSM.change_realm(new_level)` 写入新境界 + 发射 `realm_upgraded(old, new)` Cat 2b 信号委托给下游系统（CultivationSystem 溢出结算、TribulationSystem 行动力回满、ExplorationSystem 地图解锁、CardSystem 扩展掉落池）。RealmSystem 不直接调用下游系统内部方法。

**Engine**: Godot 4.6.3 | **Risk**: LOW
**Engine Notes**: Autoload 顺序保证 GSM #1 先于 RealmSystem #11 就绪。

**Control Manifest Rules (Core 层 + Foundation 层)**:
- **Required**: `realm_up()` 原子编排器：`GSM.change_realm()` → `realm_upgraded` 信号 → 子系统委托
- **Required**: `realm_upgraded` 信号为 Cat 2b 动作通知（ADR-0007）
- **Required**: 信号载荷 ≤3 参数优先
- **Required**: Foundation Autoload 测试用动态分派模式（控制清单 2026-08-05 新增规则）
- **Forbidden**: Foundation 层原则 #3 —— RealmSystem（Core）调用 GSM（Foundation）方向正确；但 RealmSystem 不直接调用 Feature 层系统（CultivationSystem 等）——通过信号委托
- **Forbidden**: 绝不绕过 `realm_up()` 直接写 `GSM.player.realm_level` —— 始终通过编排器

---

## Acceptance Criteria

*From ADR-0010 §关键接口 + §验证标准 + GDD §4 境界提升流程 + §验收标准:*

- [x] **AC-001**: `realm_up(current_level: int) -> void` 方法签名
- [x] **AC-002**: `realm_up(2)` 后 GSM.player.realm_level 变为 3
- [x] **AC-003**: `realm_up(2)` 后发射 `realm_upgraded(2, 3)` 信号（old=2, new=3）
- [x] **AC-004**: `realm_up(5)`（已是最高境界）→ `push_error` + 不修改 GSM
- [x] **AC-005**: `realm_up` 内部调用 `GSM.change_realm(new_level)` 原子写入
- [x] **AC-006**: `signal realm_upgraded(old_level: int, new_level: int)` 信号声明（Cat 2b）
- [x] **AC-007**: `realm_upgraded` 信号载荷为 2 个 int 参数（old_level, new_level）
- [x] **AC-008**: `realm_up` 不直接调用 CultivationSystem/ExplorationSystem/CardSystem/TribulationSystem 方法（信号委托——代码审查 grep 验证）
- [x] **AC-009**: 突破后 GSM.player.cultivation 保留不变（如 800/1000 → 800/1500，由 GSM 管理非 RealmSystem 职责）
- [x] **AC-010**: `realm_up` 调用前 GSM.change_realm 可被观察（通过 GSM.realm_changed Cat 1 信号间接验证）

---

## Implementation Notes

*Derived from ADR-0010 §关键接口 §realm_up 编排器:*

1. **文件位置**: `src/core/realm_system.gd`（同 Story 001/002，扩展编排方法 + 信号声明）
2. **信号声明**（ADR-0010 §关键接口）:
   ```gdscript
   ## Cat 2b 动作通知信号 —— realm_up() 完成后发射
   ## 消费者：CultivationSystem（溢出结算）、TribulationSystem（行动力回满）、
   ## ExplorationSystem（地图解锁）、CardSystem（扩展掉落池）
   signal realm_upgraded(old_level: int, new_level: int)
   ```
3. **realm_up 实现**（ADR-0010 §关键接口）:
   ```gdscript
   ## 突破升级编排 —— 原子多方协调
   ## 仅在渡劫突破成功后由 TribulationSystem 调用
   func realm_up(current_level: int) -> void:
       var new_level: int = current_level + 1
       if new_level > realm_table.size():
           push_error("RealmSystem: cannot upgrade beyond max realm (%d)" % realm_table.size())
           return

       # 1. 更新 GSM 中的境界等级（原子写入）
       GSM.change_realm(new_level)

       # 2. 发射 Cat 2b 信号委托给下游系统
       realm_upgraded.emit(current_level, new_level)
       # CultivationSystem 监听 → 执行 overflow_pool → 属性丹结算
       # TribulationSystem 监听 → 回满行动力
       # ExplorationSystem 监听 → 解锁新地图入口
       # CardSystem 监听 → 扩展掉落池
   ```
4. **信号委托模式**（ADR-0010 §积极的）:
   - `realm_up()` 遵循 ADR-0004 确立的"编排器通过信号委托给子系统"模式
   - RealmSystem 不直接调用 CultivationSystem/ExplorationSystem/CardSystem/TribulationSystem 的内部方法
   - 下游系统在各自 Epic 实现时监听 `realm_upgraded` 信号并执行响应逻辑
5. **与 GSM.realm_changed 的语义区分**（ADR-0010 §风险）:
   - `GSM.realm_changed` (Cat 1) 表示"GSM 中 realm_level 值已变更"——任何写入都触发
   - `RealmSystem.realm_upgraded` (Cat 2b) 表示"突破升级流程已完成"——仅在 realm_up() 成功后触发
   - 语义不同，文档明确区分
6. **突破后不重置的内容**（GDD §4）: 卡组、角色位、灵石、事件进度、轮回天赋状态——这些由各自系统管理，RealmSystem 不触碰
7. **突破后更新内容**（GDD §4）: 境界数值上限（通过 realm_table 查询自动更新）、行动力回满（TribulationSystem 监听信号处理）、卡牌掉落池扩展（CardSystem 监听）、新地图解锁（ExplorationSystem 监听）
8. **测试模式**: 测试用 `var rs: Node = RS_SCRIPT.new()` 动态分派 + 真实 GSM Autoload（before_each/after_each 清理 GSM 状态，同 test_apply_outcomes.gd 模式）

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: realm_table + 查询接口
- **Story 002**: 压制计算 + 稀有度权重
- **溢出池结算**: CultivationSystem Epic 职责（监听 realm_upgraded 信号）
- **行动力回满**: TribulationSystem/ActionPointSystem Epic 职责（监听信号）
- **地图解锁**: ExplorationSystem Epic 职责（监听信号）
- **掉落池扩展**: CardSystem Epic 职责（监听信号）
- **渡劫突破战斗**: TribulationSystem Epic 职责（调用 realm_up 的触发方）
- **苍玄古战场境界跌落**: 特殊剧情机制，GDD §6 明确"境界系统直接赋值，不经过 realm_up()"——属 StorySystem/ExplorationSystem Epic 职责

---

## QA Test Cases

*Derived from ADR-0010 §验证标准 + GDD §验收标准:*

- **AC-001**: realm_up 方法签名
  - Given: `var rs: Node = RS_SCRIPT.new()`；GSM Autoload 可用
  - When: `rs.realm_up(2)`
  - Then: 无返回值（void）；不崩溃
  - Edge cases: GSM 状态在调用前后可观察

- **AC-002**: realm_up(2) 后 GSM.player.realm_level 变为 3
  - Given: rs 已创建；GSM.player.realm_level = 2（测试前设置）
  - When: `rs.realm_up(2)`
  - Then: `assert_eq(GSM.player.realm_level, 3)`
  - Edge cases: ADR-0010 §验证标准直接引用

- **AC-003**: realm_up(2) 后发射 realm_upgraded(2, 3) 信号
  - Given: rs 已创建；`var received := {"old": -1, "new": -1}`；`rs.realm_upgraded.connect(func(o: int, n: int): received.old = o; received.new = n)`
  - When: `rs.realm_up(2)`
  - Then: `assert_eq(received.old, 2)`；`assert_eq(received.new, 3)`
  - Edge cases: 信号仅发射 1 次（assert_signal_emit_count）

- **AC-004**: realm_up(5)（最高境界）→ push_error + 不修改 GSM
  - Given: rs 已创建；GSM.player.realm_level = 5
  - When: `rs.realm_up(5)`
  - Then: `assert_push_error_count(1)`；`assert_eq(GSM.player.realm_level, 5)`（未变）
  - Edge cases: ADR-0010 §验证标准直接引用——new_level=6 > realm_table.size()=5

- **AC-005**: realm_up 内部调用 GSM.change_realm(new_level)
  - Given: rs 已创建；GSM.player.realm_level = 2
  - When: `rs.realm_up(2)`
  - Then: 间接验证——GSM.player.realm_level == 3（change_realm 已执行）；GSM.realm_changed Cat 1 信号已发射（若监听）
  - Edge cases: 接受间接验证——GSM.change_realm 已在 Sprint 1 实现，无 spy 接缝

- **AC-006**: realm_upgraded 信号声明（Cat 2b）
  - Given: RealmSystem 脚本已加载
  - When: 读取 `rs.get_signal_list()` 查找 `realm_upgraded`
  - Then: 信号存在；参数列表含 2 个 int 参数（old_level, new_level）
  - Edge cases: 确认信号参数类型均为 TYPE_INT

- **AC-007**: realm_upgraded 信号载荷为 2 个 int 参数
  - Given: rs 已创建；watch_signals(rs)
  - When: `rs.realm_up(3)`
  - Then: `var params = get_signal_parameters(rs, "realm_upgraded", 0)`；`assert_eq(params.size(), 2)`；`assert_eq(params[0], 3)`；`assert_eq(params[1], 4)`
  - Edge cases: 信号载荷 ≤3 参数（符合 ADR-0007）

- **AC-008**: realm_up 不直接调用下游系统方法（信号委托）
  - Given: realm_system.gd 源码
  - When: grep `CultivationSystem|ExplorationSystem|CardSystem|TribulationSystem` 在 realm_system.gd 中
  - Then: 仅文档注释中提及（作为信号消费者），无代码级直接调用
  - Edge cases: 代码审查检查点——同 card-system Story 004 AC-016 模式

- **AC-009**: 突破后 GSM.player.cultivation 保留不变
  - Given: rs 已创建；GSM.player.realm_level = 2；GSM.player.cultivation = 800；GSM.player.max_cultivation = 1500
  - When: `rs.realm_up(2)`
  - Then: `assert_eq(GSM.player.cultivation, 800)`（保留）；max_cultivation 由 GSM/其他系统管理（非 RealmSystem 职责）
  - Edge cases: GDD §4——突破后 cultivation 保留旧值

- **AC-010**: realm_up 调用前 GSM.change_realm 可观察
  - Given: rs 已创建；GSM.player.realm_level = 2；`var realm_changed_emitted := false`；`GSM.realm_changed.connect(func(o, n): realm_changed_emitted = true)`
  - When: `rs.realm_up(2)`
  - Then: `assert_true(realm_changed_emitted)`（GSM Cat 1 信号已发射）
  - Edge cases: 间接验证 realm_up 内部调用了 GSM.change_realm

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/realm_system/test_realm_up.gd` — must exist and pass
**Status**: [x] Created and passing（14 测试，覆盖 AC-001..AC-012）

---

## Dependencies

- Depends on: Story 001（realm_table + realm_table.size() 用于上限检查）、Story 002（同文件基础结构）、Sprint 1 GSM（change_realm + realm_changed 信号已实现）
- Unlocks: CultivationSystem Epic（监听 realm_upgraded）、TribulationSystem Epic（调用 realm_up + 监听信号）、ExplorationSystem Epic（监听信号解锁地图）、CardSystem Epic（监听信号扩展掉落池）

---

## Completion Notes

**Completed**：2026-08-06
**Criteria**：10/10 通过（AC-001..AC-010 故事定义全部 COVERED + 新增 AC-011 边界/AC-012 参数校验）

**Deviations**（全部 ADVISORY，已修复）：
- **BLOCKER**（已修复）`GSM.change_realm` 重复发射 `realm_changed`——立即 emit + 帧末 `_emit_domain_signal` 各一次。修复为统一走 `_buffer_change` 帧末发射，与 `add_cultivation`/`reincarnation_reset` 等所有第二层方法一致（Cat 1 信号契约一致性）。AC-010 测试同步改为 `await get_tree().process_frame` 后断言。
- **HIGH**（已修复）测试中 `GameStateManager.realm_changed` 连接未断开（Autoload 持久信号泄漏）。`after_each` 补 `disconnect`。
- **LOW**（已修复）`realm_up` 信任外部传入 `current_level` 不校验——新增 `current_level == GSM.player.realm` 校验，防 Cat 2b 信号载荷与 GSM 状态漂移。新增 AC-012 测试覆盖。
- **LOW**（已修复）AC-009 未断言 `max_cultivation` 不被修改——已补断言。
- **LOW**（已修复）`_reset_gsm_state` 清理不彻底——补 `cultivation`/`max_cultivation`/`overflow_pool`/`cultivation_full` 重置。
- **LOW**（已修复）AC-008 grep 逻辑无法识别行内注释——改为基于 `#` 与 `forbidden` 位置关系判断。
- **MINOR DEVIATION**（信息性）实现新增 `current_level != GSM.player.realm` 校验，ADR-0010 §关键接口示例中未包含——属 ADR 契约增强，非偏离。可选后续将校验补入 ADR-0010。

**Test Evidence**：Integration — `tests/integration/realm_system/test_realm_up.gd`（14 测试，覆盖 AC-001..AC-012）
**Code Review**：已完成——godot-gdscript-specialist CHANGES REQUIRED→修复后 lead-programmer APPROVED + qa-lead ADEQUATE + qa-tester PASS

**测试结果**：realm_system 三文件合计 56 测试通过；全量套件 684 测试 / 683 通过 / 1 pending（save_load 多步迁移占位，与本 Story 无关）
