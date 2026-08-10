# Story 002: 3 叠加规则 + 免疫多级检查 + 20 活跃上限

> **Epic**: status-effect
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 1d
> **Manifest Version**: 2026-08-05
> **Last Updated**: 2026-08-10

## Context

**GDD**: `design/gdd/status-system.md`
**Requirement**: `TR-status-002`（状态叠加规则、免疫机制、活跃上限）
*（需求文本见 `docs/architecture/tr-registry.yaml`——审查时读取最新版）*

**ADR Governing Implementation**: ADR-0011（状态效果系统——双层对象模型 + 叠加规则 + 免疫 + 上限驱逐）
**ADR Decision Summary**: apply_status 管线在 NEW 路径之上实现 3 种叠加规则（独立/刷新/叠加上限）、3 级免疫短路（type → template → element）、20 活跃上限 + 溢出驱逐策略（按 priority 降序 + applied_turn 升序移除最低优先级旧状态）。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: 叠加判定用 Dictionary 查找（O(1)），免疫检查短路返回。20 上限驱逐遍历活跃列表（O(n)，n≤20，常数级）。

**Control Manifest Rules (Core 层)**:
- **Required**: 叠加判定必须原子——`_instances` + `_by_target` 同步更新（同 Story 001）
- **Required**: 免疫检查短路——一旦命中立即返回 reason="immune"，不创建实例
- **Forbidden**: 免疫标志不存储在 GSM——`_immunity_flags` 内部注册表
- **Forbidden**: 驱逐策略不得随机——确定性排序（priority 降序 + applied_turn 升序）

---

## Acceptance Criteria

*From ADR-0011 §叠加规则 §免疫机制 §活跃上限 + GDD status-system.md §验收标准:*

- [ ] **AC-001**: `stack_rule=独立`（independent）——同名状态可并存，各自独立 duration/层数
- [ ] **AC-002**: `stack_rule=刷新`（refresh）——同名施加刷新 duration 至 base_duration，current_stacks 不变
- [ ] **AC-003**: `stack_rule=叠加上限`（cumulative）——同名施加 current_stacks+1，至 max_stacks 封顶，不刷新 duration
- [ ] **AC-004**: 独立规则施加 3 次同名状态 → 3 个独立 status_id，各自 duration 倒计时
- [ ] **AC-005**: 刷新规则施加 2 次同名状态 → 1 个 status_id，duration=base_duration（重置），current_stacks=1
- [ ] **AC-006**: 叠加上限规则（max_stacks=3）施加 4 次 → 1 个 status_id，current_stacks=3（封顶），第 4 次返回 reason="max_stacks"
- [ ] **AC-007**: 叠加上限封顶后第 4 次施加 applied=false，不发射 status_applied
- [ ] **AC-008**: 免疫检查 3 级短路：type → template → element
- [ ] **AC-009**: 目标对 `StatusType.POISON` 免疫 → 施加 poison_3 返回 reason="immune"，applied=false
- [ ] **AC-010**: 目标对 `template_id="poison_3"` 免疫（但不对 POISON type 免疫）→ 施加返回 reason="immune"
- [ ] **AC-011**: 目标对 `element=FIRE` 免疫 → 施加火元素状态返回 reason="immune"（模板标记 element）
- [ ] **AC-012**: 免疫命中时不发射 `status_applied`，改发射 `status_immunity_blocked`（载荷含 target_id/template_id/immune_level）
- [ ] **AC-013**: `set_immunity(target_id, level, key)` 设置免疫标志——level ∈ {"type","template","element"}，key 为对应值
- [ ] **AC-014**: `clear_immunity(target_id, level, key)` 清除指定免疫标志
- [ ] **AC-015**: 单目标活跃状态达 20 个上限——第 21 次施加触发驱逐
- [ ] **AC-016**: 驱逐策略：按 priority 升序（最低优先级）+ applied_turn 升序（最旧）选首个驱逐
- [ ] **AC-017**: 驱逐被移除状态发射 `status_removed`（reason="overflow"）
- [ ] **AC-018**: 驱逐后新状态成功注册，applied=true，reason="new"
- [ ] **AC-019**: 永久状态（duration=-1）同样受 20 上限约束——可被驱逐
- [ ] **AC-020**: `get_active_count(target_id)` 返回该目标活跃状态数（含 is_expired 未移除的）

---

## Implementation Notes

*Derived from ADR-0011 §叠加规则 §免疫机制 §活跃上限驱逐:*

1. **叠加判定流程**: apply_status 在 NEW 路径前查询 `_by_target[target_id]` 中是否有同 template_id 的活跃实例
2. **独立规则**: 跳过叠加判定，直接创建新实例（同 Story 001 NEW 路径）
3. **刷新规则**: 命中同名实例 → `instance.duration = template.base_duration` → reason="refreshed" → 发射 status_updated（非 status_applied）
4. **叠加上限规则**: 命中同名实例 → 检查 current_stacks < max_stacks → +1 → reason="stacked"；否则 reason="max_stacks" + applied=false
5. **免疫检查顺序**: type 级（_immunity_flags[target_id]["type"][StatusType.POISON]）→ template 级（["template"][template_id]）→ element 级（["element"][Element.FIRE]）——首个命中即返回
6. **_immunity_flags 结构**: `Dictionary[int, Dictionary]`（key=target_id），内层 `{"type": Dictionary, "template": Dictionary, "element": Dictionary}`
7. **20 上限检查**: apply_status 在叠加判定后、注册前检查 `get_active_count(target_id) >= 20` → 触发 `_evict_lowest(target_id)`
8. **_evict_lowest 实现**: 遍历 `_by_target[target_id]` → 排序 (priority ASC, applied_turn ASC) → 移除首位 → 发射 status_removed（reason="overflow"）
9. **status_immunity_blocked 信号**: 载荷 {target_id, template_id, immune_level}——immune_level ∈ {"type","template","element"}

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: StatusTemplate/Instance 双层模型 + 8 阶段管线核心（apply_status NEW 路径 + 注册表 + 倒计时）——已实现
- **Story 003**: snapshot 导出 GSM + 暂挂/恢复排序
- **CardEffectEngine 集成**: 调用 set_immunity/clear_immunity ——卡牌效果 Epic 职责

---

## QA Test Cases

*From QA 计划 qa-plan-sprint-3-2026-08-10.md §Story 3-5 + ADR-0011 §验证标准:*

- **AC-001**: 独立叠加规则
  - Given: 模板 buff_atk（stack_rule=独立, duration=3）
  - When: 连续 `ses.apply_status(target_id, &"buff_atk", src)` 3 次
  - Then: 3 个独立 status_id，各自 duration=3
  - Edge cases: 3 次倒计时独立递减

- **AC-002**: 刷新叠加规则
  - Given: 模板 poison_3（stack_rule=刷新, duration=3）
  - When: 施加 1 次 → tick 1 回合（duration=2）→ 再施加 1 次
  - Then: 同一 status_id，duration 重置为 3，current_stacks=1
  - Edge cases: reason="refreshed"

- **AC-003**: 叠加上限规则
  - Given: 模板 vuln_stack（stack_rule=叠加上限, max_stacks=3, duration=3）
  - When: 连续施加 4 次
  - Then: 前 3 次 current_stacks=1/2/3（reason="new"/"stacked"/"stacked"），第 4 次 applied=false
  - Edge cases: duration 不刷新（保持首次施加的倒计时）

- **AC-004**: 独立规则多实例独立倒计时
  - Given: 3 个独立 buff_atk 实例
  - When: tick_all 1 回合
  - Then: 3 个实例各自 duration-1（互不影响）
  - Edge cases: 一个过期不影响其他

- **AC-005**: 刷新规则 duration 重置
  - Given: poison_3 已施加，duration 已减至 1
  - When: 再次施加同名
  - Then: duration=3（重置），current_stacks 保持 1
  - Edge cases: 发射 status_updated（非 status_applied）

- **AC-006**: 叠加上限封顶
  - Given: vuln_stack（max_stacks=3），已施加 3 次（current_stacks=3）
  - When: 第 4 次施加
  - Then: applied=false + reason="max_stacks" + current_stacks 保持 3
  - Edge cases: 不发射 status_applied

- **AC-007**: 叠加上限封顶不发射信号
  - Given: 监听 status_applied
  - When: 第 4 次施加（已封顶）
  - Then: status_applied 不发射
  - Edge cases: applied=false 的 ApplyResult 仍返回

- **AC-008**: 免疫 3 级短路顺序
  - Given: 目标对 type=POISON + template=poison_3 + element=FIRE 均免疫
  - When: 施加 poison_3
  - Then: type 级最先命中，reason="immune"，immune_level="type"
  - Edge cases: 移除 type 免疫后 template 级命中

- **AC-009**: type 级免疫
  - Given: `ses.set_immunity(target_id, "type", StatusType.POISON)`
  - When: 施加 poison_3
  - Then: applied=false + reason="immune" + immune_level="type"
  - Edge cases: 其他 type 状态不受影响

- **AC-010**: template 级免疫
  - Given: `ses.set_immunity(target_id, "template", &"poison_3")`（未设 type 免疫）
  - When: 施加 poison_3
  - Then: applied=false + reason="immune" + immune_level="template"
  - Edge cases: 其他 poison 模板（poison_1）可施加

- **AC-011**: element 级免疫
  - Given: `ses.set_immunity(target_id, "element", Element.FIRE)`
  - When: 施加 fire_burn（element=FIRE）
  - Then: applied=false + reason="immune" + immune_level="element"
  - Edge cases: 非 FIRE 元素状态不受影响

- **AC-012**: 免疫命中发射 status_immunity_blocked
  - Given: 监听 status_immunity_blocked
  - When: 免疫命中施加
  - Then: 发射 status_immunity_blocked，载荷 {target_id, template_id, immune_level}；status_applied 不发射
  - Edge cases: 三级免疫各自发射对应 immune_level

- **AC-013**: set_immunity 设置标志
  - Given: ses 已创建
  - When: `ses.set_immunity(target_id, "type", StatusType.POISON)`
  - Then: `_immunity_flags[target_id]["type"][POISON] == true`
  - Edge cases: 重复设置幂等

- **AC-014**: clear_immunity 清除标志
  - Given: 已设 type 免疫
  - When: `ses.clear_immunity(target_id, "type", StatusType.POISON)`
  - Then: 施加 poison_3 成功（applied=true）
  - Edge cases: 清除不存在的免疫不报错

- **AC-015**: 20 上限触发驱逐
  - Given: 目标已有 20 个活跃状态
  - When: 施加第 21 个
  - Then: 触发驱逐 1 个 + 新状态成功注册
  - Edge cases: 驱逐后 active_count 仍为 20

- **AC-016**: 驱逐策略确定性排序
  - Given: 20 个状态（priority 混合 1-5，applied_turn 混合 1-5）
  - When: 施加第 21 个（触发驱逐）
  - Then: 被驱逐的是 priority 最低 + applied_turn 最旧的那个
  - Edge cases: 同 priority 取 applied_turn 最旧；同 applied_turn 取 priority 最低

- **AC-017**: 驱逐发射 status_removed
  - Given: 监听 status_removed
  - When: 驱逐触发
  - Then: 发射 status_removed，reason="overflow"
  - Edge cases: 载荷含被驱逐的 target_id/status_id/template_id

- **AC-018**: 驱逐后新状态注册成功
  - Given: 驱逐完成
  - When: 检查新施加结果
  - Then: applied=true + reason="new" + status_id 已分配
  - Edge cases: 新状态正常发射 status_applied

- **AC-019**: 永久状态可被驱逐
  - Given: 20 个活跃状态含 1 个 duration=-1 永久状态（priority 最低）
  - When: 施加第 21 个
  - Then: 永久状态被驱逐（duration=-1 不豁免）
  - Edge cases: 驱逐策略仅看 priority + applied_turn

- **AC-020**: get_active_count 查询
  - Given: 目标有 5 个活跃状态（含 1 个 is_expired 未移除）
  - When: `ses.get_active_count(target_id)`
  - Then: 返回 5（含未移除的过期状态）
  - Edge cases: tick_all 后 remove_expired 会减少计数

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/status_effect/test_stacking_immunity.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（apply_status 管线 + 注册表 + 4 信号声明）
- Unlocks: Story 003（snapshot 需读取完整注册表含叠加/免疫状态）
