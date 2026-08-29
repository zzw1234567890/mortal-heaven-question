# Story 001: gain_cultivation 统一获取入口 + 溢出判定

> **Epic**: cultivation-system
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 0.5d
> **Manifest Version**: 2026-08-05
> **Last Updated**: 2026-08-29

## Context

**GDD**: `design/gdd/cultivation-system.md`
**Requirement**: `TR-cult-001`
*（需求文本见 `docs/architecture/tr-registry.yaml`——审查时读取最新版）*

**ADR Governing Implementation**: 待定（CultivationSystem ADR 尚未编写——本 Story 遵循 GDD §5 修为获取流程 + GSM 已有 add_cultivation 接口）
**ADR Decision Summary**: CultivationSystem 作为 Feature 层 Autoload，提供 gain_cultivation 统一获取入口。修为值和溢出池由 GSM player.* 域管理（GSM.add_cultivation 已实现溢出转化逻辑）。CultivationSystem 是 GSM 的薄封装 + 信号传播 + 查询接口。

**Engine**: Godot 4.6 | **Risk**: LOW（GSM.add_cultivation 已实现溢出逻辑，CultivationSystem 是薄封装层）
**Engine Notes**: GSM 第二层 add_cultivation 方法已实现修为获取+溢出转化+buffer_change。CultivationSystem 委托 GSM，不重复逻辑。均为 4.0+ 稳定 API。

**Control Manifest Rules (Feature 层)**:
- **Required**: 修为值与溢出池由 GSM player.* 域管理 —— 来源: GDD §5 + GSM 现有接口
- **Required**: gain_cultivation 是所有修为获取途径的统一入口 —— 来源: GDD §5
- **Forbidden**: 绕过 GSM 直接修改 player.cultivation / player.overflow_pool —— 来源: ADR-0001

---

## Acceptance Criteria

*From GDD §5 修为获取流程 + §1 修为获取途径 + §3 溢出转化:*

- [ ] **AC-001**: `gain_cultivation(amount, source)` 统一获取入口——委托 GSM.add_cultivation，amount <= 0 时 push_error 并返回
- [ ] **AC-002**: 溢出判定——修为满后继续获取，溢出存入 overflow_pool（GSM.add_cultivation 已实现）
- [ ] **AC-003**: amount <= 0 拒绝（push_error + return，不调用 GSM）
- [ ] **AC-004**: 修为满值时 GSM cultivation_full 信号被触发（GSM 已实现，CultivationSystem 验证传播）
- [ ] **AC-005**: cultivation_changed 信号携带 (delta, current, max) 载荷（GSM 已实现）
- [ ] **AC-006**: `check_cultivation_full()` 查询方法——返回 cultivation >= max_cultivation 的 bool
- [ ] **AC-007**: `get_cultivation_status()` 返回 {current, max, overflow_pool, is_full} Dictionary

---

## Implementation Notes

*Derived from GDD §5 修为获取流程 + GSM 现有接口:*

1. **文件位置**: `src/feature/cultivation_system.gd` — 新建 CultivationSystem Autoload 骨架
2. **extends Node 不声明 class_name** — 同 ExplorationSystem/CombatSystem 先例
3. **不注册进 project.godot** — 待各系统接线后统一注册（同 Sprint 4 模式）
4. **gain_cultivation(amount, source)** — 委托 GSM.add_cultivation(amount, source)
5. **溢出逻辑由 GSM 处理** — GSM.add_cultivation 已实现：amount <= space → 直接加；否则 cultivation=max，overflow_pool += excess
6. **信号由 GSM 路由** — cultivation_changed / cultivation_full 由 GSM._emit_domain_signal 帧末发射，CultivationSystem 不重复发射
7. **查询接口** — check_cultivation_full() / get_cultivation_status() 从 GSM player.* 读取
8. **CONVERSION_RATE** — 默认 1.0（100%溢出转入溢出池），GSM 已实现

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 002**: GSM player.* 数据存储 + batch_updated 传播——本 Story 只封装 GSM 已有接口
- **Story 003**: settle_overflow + 突破后溢出结算——本 Story 只处理获取，不处理结算
- **Story 004**: realm_upgraded 信号订阅 + check_breakthrough——本 Story 不处理突破
- **丹药使用**: 丹药增加修为通过 gain_cultivation 统一入口——炼丹系统职责

---

## QA Test Cases

*From GDD §5 修为获取流程 + §边界情况:*

- **AC-001**: gain_cultivation 统一入口
  - Given: GSM 已初始化
  - When: gain_cultivation(50, "combat")
  - Then: player.cultivation += 50

- **AC-002**: 溢出判定
  - Given: cultivation=950, max=1000
  - When: gain_cultivation(100, "combat")
  - Then: cultivation=1000, overflow_pool += 50

- **AC-003**: amount <= 0 拒绝
  - Given: 任意状态
  - When: gain_cultivation(0, "test") / gain_cultivation(-10, "test")
  - Then: push_error，cultivation 不变

- **AC-004**: 修为满值信号
  - Given: cultivation=950, max=1000
  - When: gain_cultivation(50, "combat")
  - Then: cultivation_full 信号发射

- **AC-005**: cultivation_changed 信号
  - Given: 任意状态
  - When: gain_cultivation(50, "combat")
  - Then: cultivation_changed(delta=50, current, max) 发射

- **AC-006**: check_cultivation_full
  - Given: cultivation=1000, max=1000
  - When: check_cultivation_full()
  - Then: true

- **AC-007**: get_cultivation_status
  - Given: cultivation=800, max=1000, overflow_pool=50
  - When: get_cultivation_status()
  - Then: {current:800, max:1000, overflow_pool:50, is_full:false}

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/cultivation_system/test_gain_cultivation.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: GSM add_cultivation + cultivation_changed/cultivation_full 信号（已实现）
- Unblocks: Story 002（GSM 存储传播）；Story 003（溢出结算需要 gain_cultivation）；Story 004（突破检查需要 check_cultivation_full）
