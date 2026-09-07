# Story 004: 通知/提示系统

> **Epic**: HUD 系统
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: [待 sprint 排期填写]
> **Manifest Version**: 2026-09-07
> **Last Updated**: [由 /dev-story 设置]

## Context

**GDD**: `design/gdd/hud-system.md`
**Requirement**: AC-hud-008 / AC-hud-009
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线
**ADR Decision Summary**: 通知堆叠/优先级/时长管理是确定性逻辑（Logic 主体），滑入滑出动画为视觉部分（ADVISORY）。通知队列数据结构可存于 HUD 组件本地（瞬态交互状态），不写回 GSM。

**Engine**: Godot 4.6 | **Risk**: HIGH（双焦点变更在 LLM 知识截止后）
**Engine Notes**: 通知点击关闭用 Control 内建 mouse_filter + gui_input，无焦点导航需求。计时器用 SceneTreeTimer 或 Timer 节点。

**Control Manifest Rules (this layer)**:
- Required: 通知类型/时长/优先级判定提取为纯函数或独立可测类
- Forbidden: 通知内容携带游戏状态变更（通知只读展示，玩家点击仅关闭通知本身）
- Guardrail: 通知弹出/消失动画 0.2s；同时显示上限 3 条

---

## Acceptance Criteria

*From GDD `design/gdd/hud-system.md`，scoped to this story:*

- [ ] 获得道具等通知从顶部滑入，按类型时长后消失（普通 2~3s、重要 5s）（AC-hud-008）
- [ ] 同时多个通知最多 3 条堆叠显示，超出时丢弃最早的非重要通知（AC-hud-009）
- [ ] 重要通知（系统提示/错误提示）优先级高，不被普通通知挤掉
- [ ] 通知可点击关闭；不阻塞玩家操作（非弹窗）
- [ ] 通知类型→时长/颜色映射：「重要」判定 = 类型属于系统提示或错误提示（边界澄清 2026-09-07）

---

## Implementation Notes

*Derived from ADR-0031 Implementation Guidelines:*

- **通知队列管理器**（BLOCKING 单测目标）：`NotificationStack` 类——`push(type, text)`、超时移除、容量管理（>3 时移除最早的非重要通知；若全是重要通知则不丢弃，允许临时超限或按实现定义的确定性规则）。类型→(时长, 颜色, 重要) 映射表为数据驱动常量。
- 时长统一按 GDD 修正后的类型表：道具/卡牌 3s、灵石/修为 2s、战斗事件 3s、系统/错误 5s。
- 通知触发来源：各系统通过事件/信号请求通知显示（HUD 暴露通知显示请求接口），HUD 不主动轮询。
- 滑入/滑出动画（0.2s）属视觉部分——证据中手动验证即可。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: HUD 挂载与可见性
- Story 007: 场景切换过渡提示（独立组件，非通知队列）
- 音效（通知音调）：归 audio-manager epic，本 story 仅触发音频事件
- 通知点击执行操作（如点击打开背包）：GDD 待解决问题 #2，当前设计仅关闭通知

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

**[Logic — automated test specs]:**

- **AC-1**: 通知自动消失
  - Given: 队列为空
  - When: `push("item", "获得 回血丹 ×1")` 且时间推进 3s
  - Then: 通知已从队列移除
  - Edge cases: 灵石通知 2s、系统提示 5s、时间推进不足时仍在队列

- **AC-2**: 容量上限与丢弃规则
  - Given: 队列已有 3 条普通通知
  - When: `push` 第 4 条普通通知
  - Then: 最早的普通通知被移除，队列保持 3 条
  - Edge cases: 3 条中含重要通知时重要通知不被丢弃；全重要通知时的新 push 行为（确定性规则并锁定）

- **AC-3**: 重要通知优先级
  - Given: 队列已有 3 条普通通知
  - When: `push` 一条错误提示（重要）
  - Then: 错误提示入队且不被后续普通通知挤出
  - Edge cases: 连续 2 条重要通知

- **AC-4**: 手动关闭
  - Given: 队列有一条活动通知
  - When: 调用关闭（模拟点击）
  - Then: 通知立即移除，不等待超时
  - Edge cases: 关闭最早一条后其余堆叠重排

**[Visual/Feel — manual verification steps]:**

- **AC-5**: 滑入/滑出动画
  - Setup: 触发任意通知
  - Verify: 从顶部滑入 0.2s、消失时向上滑出并淡出
  - Pass condition: 动画流畅无瞬跳，堆叠重排无重叠

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/hud/notification_stack_test.gd` — must exist and pass（BLOCKING）
- 视觉部分（滑入滑出/堆叠动画）: `production/qa/evidence/notification-stack-evidence.md` + sign-off（ADVISORY，随证据文档记录）

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（HUD 挂载——通知区域为 HUD 子容器）
- Unlocks: None
