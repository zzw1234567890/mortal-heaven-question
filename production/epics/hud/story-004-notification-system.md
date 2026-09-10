# Story 004: 通知/提示系统

> **Epic**: HUD 系统
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: [待 sprint 排期填写]
> **Manifest Version**: 2026-09-07
> **Last Updated**: 2026-09-10（QL-STORY-READY G1-G8 裁决落地——时间注入/容量锁定/类型映射全值表/战斗事件拆分/请求接口归本 story）

## Context

**GDD**: `design/gdd/hud-system.md`
**Requirement**: AC-hud-008 / AC-hud-009
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线
**ADR Decision Summary**: 通知堆叠/优先级/时长管理是确定性逻辑（Logic 主体），滑入滑出动画为视觉部分（ADVISORY）。通知队列数据结构可存于 HUD 组件本地（瞬态交互状态），不写回 GSM。

**Engine**: Godot 4.6 | **Risk**: HIGH（双焦点变更在 LLM 知识截止后）
**Engine Notes**: 通知点击关闭用 Control 内建 mouse_filter + gui_input，无焦点导航需求。计时器用 SceneTreeTimer 或 Timer 节点。[b]战斗通知边界（code-review H-2 裁决 2026-09-10）[/b]：combat_event_offensive/defensive 类型已在映射表实现（供 combat-ui epic 使用），但 HUD 战斗可见性矩阵在 COMBAT 下隐藏 ContentLayer——战斗期间通知在不可见层静默到期消失。展示宿主归属（战斗专用通知区 vs 调整隐藏矩阵）推迟至 combat-ui epic 裁决，GDD 待解决问题 #4 已登记。

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

- **通知队列管理器**（BLOCKING 单测目标）：`NotificationStack` 类——`push(type, text) -> int`（返回通知 id，0=拒绝入队）、`dismiss(id) -> bool`（立即移除，false=不存在或已移除）、超时移除、容量管理。类型→(时长, 颜色, 重要) 映射表为数据驱动常量。
- **时间注入模式（G1 裁决 2026-09-10）**：时间推进 API `advance(delta_seconds: float) -> Array`——移除所有已到期通知并返回被移除条目（供 UI 播放滑出动画）。单测通过 `advance(3.0)` 注入时间，UI 层 Timer/SceneTreeTimer 每帧调用同一入口；NotificationStack 不持有任何节点/Timer。队列状态查询 `get_active() -> Array`（只读快照）供测试断言与 UI 渲染。
- **容量规则（G2 裁决 2026-09-10，锁定）**：`push` 后若队列超 3 条，移除**除本次 push 外**最早的非重要通知；若不存在可移除项（其余全为重要），则**丢弃本次 push 的普通通知并返回 id=0**。重要通知 push 永不丢弃，允许队列临时 >3 条（在下一条普通通知 push 或超时移除后回落）。
- **类型映射（G3/G6 裁决 2026-09-10）**：映射返回 `{"duration": float, "color": String, "blink": bool, "important": bool}`——color 为 String 标识（"green"/"gold"/"purple"/"red"/"blue"/"white"），Color 构造在 UI 层完成（ADR-0031 先例：Logic 内核不返回 Color）；仅 error 类型 blink=true。**战斗事件拆分（G4 裁决 2026-09-10）**：`combat_event_offensive`（红）/ `combat_event_defensive`（蓝）两个类型，时长同为 3s、均普通优先级——GDD 类型表同步拆行。
- **未知类型安全默认**：按系统提示处理（5s/白/重要）+ push_warning（G3 裁决）。
- 时长统一按 GDD 修正后的类型表：道具/卡牌 3s、灵石/修为 2s、战斗事件（offensive/defensive）3s、系统/错误 5s。
- **通知请求接口（G7 裁决 2026-09-10）**：本 story 实现——HUD 暴露通知显示请求信号接口（信号名/载荷/分类在实现时按 ADR-0007 归类），各系统经该接口请求显示；补最小集成测试规格（请求 → 队列出现对应条目）。HUD 不主动轮询。
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
  - When: `push("item", "获得 回血丹 ×1")` 且 `advance(3.0)`
  - Then: 通知已从队列移除
  - Edge cases: 灵石通知 2s、系统提示 5s、时间推进不足时仍在队列、**t=duration 恰好到达 → 已移除；advance(duration - 0.01) → 仍在队列（G8 裁决边界）**

- **AC-2**: 容量上限与丢弃规则
  - Given: 队列已有 3 条普通通知
  - When: `push` 第 4 条普通通知
  - Then: 最早的普通通知被移除（**除本次 push 外**），队列保持 3 条
  - Edge cases: 3 条中含重要通知时重要通知不被丢弃；3 条全重要 + push 重要通知 → 队列临时 4 条，原 3 条均在（G2 裁决：重要永不丢弃）；3 条全重要 + push 普通通知 → push 被拒绝（返回 id=0），队列保持 3 条重要

- **AC-3**: 重要通知优先级
  - Given: 队列已有 3 条普通通知
  - When: `push` 一条错误提示（重要）
  - Then: 错误提示入队且不被后续普通通知挤出
  - Edge cases: 连续 2 条重要通知

- **AC-4**: 手动关闭
  - Given: 队列有一条活动通知（push 返回 id）
  - When: `dismiss(id)`
  - Then: 通知立即移除（`get_active()` 不含该 id），再次 dismiss 同 id 返回 false
  - Edge cases: 关闭最早一条后其余堆叠重排

- **AC-6**: 类型映射全值表（G3 裁决 2026-09-10）
  - Given: 空栈
  - When: 对全部 8 类型（item/card/lingshi/cultivation/combat_event_offensive/combat_event_defensive/system/error）分别查询映射
  - Then: item/card → (3s, 绿/金, 普通)、lingshi/cultivation → (2s, 金/紫, 普通)、combat_event_offensive → (3s, 红, 普通)、combat_event_defensive → (3s, 蓝, 普通)、system → (5s, 白, 重要)、error → (5s, 红, 重要, blink=true)
  - Edge cases: 未知类型 → 安全默认（按系统提示处理 + push_warning）

**[Integration — request 接口最小规格（G7 裁决 2026-09-10）]:**

- **AC-7**: 通知请求接口
  - Given: HUD 已挂载，通知组件订阅请求信号
  - When: 模拟某系统发通知请求（如获得道具）
  - Then: 队列 `get_active()` 出现对应类型/文本条目
  - Edge cases: 请求载荷非法类型 → 安全默认处理（未知类型规则）

**[Visual/Feel — manual verification steps]:**

- **AC-5**: 滑入/滑出动画
  - Setup: 触发任意通知
  - Verify: 从顶部滑入 0.2s、消失时向上滑出并淡出
  - Pass condition: 动画流畅无瞬跳，堆叠重排无重叠

---

## Test Evidence

**Story Type**: Logic（含通知请求接口最小集成）
**Required evidence**:
- Logic: `tests/unit/hud/notification_stack_test.gd` — must exist and pass（BLOCKING）
- Integration: 请求接口测试（AC-7——路径实现时定，`tests/integration/hud/` 下）
- 视觉部分（滑入滑出/堆叠动画）: `production/qa/evidence/notification-stack-evidence.md` + sign-off（ADVISORY，随证据文档记录）

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（HUD 挂载——通知区域为 HUD 子容器）
- Unlocks: None
