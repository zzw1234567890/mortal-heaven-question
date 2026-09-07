# Story 001: HUD CanvasLayer 挂载与场景可见性切换

> **Epic**: HUD 系统
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: [待 sprint 排期填写]
> **Manifest Version**: 2026-09-07
> **Last Updated**: [由 /dev-story 设置]

## Context

**GDD**: `design/gdd/hud-system.md`
**Requirement**: AC-hud-001 / AC-hud-004（可见性维度）+ 边界澄清（2026-09-05/09-07）
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线
**ADR Decision Summary**: HUD 为场景内 CanvasLayer 结构、零新增 Autoload、零状态所有权（UI 只读）、事件驱动更新（仅 Cat 1/Cat 2b 信号）。战斗场景 HUD 整体不渲染；暂停菜单为全局层例外。

**Engine**: Godot 4.6 | **Risk**: HIGH（双焦点变更在 LLM 知识截止后）
**Engine Notes**: 4.6 双焦点破坏性变更——鼠标焦点 ≠ 键盘/手柄焦点。本 story 不涉及焦点交互（纯可见性切换），但实现时须验证 CanvasLayer 层级在 SceneManager 转场管线中的行为。

**Control Manifest Rules (this layer)**:
- Required: UI 场景以 Control/CanvasLayer 节点挂载于场景内（非 Autoload）
- Forbidden: 新增 Autoload；UI 写入 GSM 或各系统状态
- Guardrail: 场景切换期间不得产生额外 Draw Call 峰值（转场本身 <200 DC）

---

## Acceptance Criteria

*From GDD `design/gdd/hud-system.md`，scoped to this story:*

- [ ] HUD 以 CanvasLayer 场景挂载，在探索/地图选择/商店/事件场景中渲染（AC-hud-001 / AC-hud-004 的可见性前提）
- [ ] 进入战斗场景时 HUD 整体不渲染（含所有子元素，边界澄清 2026-09-05）
- [ ] 战斗中暂停菜单仍可由 HUD 渲染（豁免于战斗隐藏规则——菜单为 PROCESS_MODE_ALWAYS 的独立 overlay 分支，ADR-0031 §1.1）
- [ ] 场景切换由 SceneManager 信号驱动（`pre_transition` / `post_transition` 或等效场景状态信号），非轮询
- [ ] HUD 不持有任何游戏状态副本——显示时从 GSM/源系统直接读取

---

## Implementation Notes

*Derived from ADR-0031 Implementation Guidelines:*

- HUD 场景结构：`HUD.tscn` 根节点 CanvasLayer，子 Control 节点按区域（左上/右上/右下/顶部通知/暂停 overlay）分容器。各容器由后续 story 填充，本 story 只搭骨架与可见性切换。
- 可见性切换：订阅 SceneManager 转场信号，按目标 SceneID 映射 HUD 可见性（战斗 → 隐藏；其余 → 显示）。战斗中的暂停 overlay 分支单独控制（Story 005 实现，本 story 预留挂载点）。
- 信号到达时从源系统读取，不在 UI 内缓存游戏状态（瞬态交互状态除外，须命名 `_cache`/`_last` 前缀并注释）。
- 不新增任何 Autoload——HUD 场景由 SceneManager 管线加载或挂入对应场景树。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: 境界+修为条组件内容
- Story 003: 灵石+卡组计数组件内容
- Story 005: 暂停菜单本体（本 story 仅预留 overlay 挂载点）
- Story 007: 过渡提示（订阅同一 pre_transition 信号但为独立组件）
- 敌方境界标记（⬆）：归 combat-ui，HUD 不实现（边界澄清 2026-09-07）

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

**[Integration — automated test specs]:**

- **AC-1**: 探索场景 HUD 渲染
  - Given: 游戏进入探索场景
  - When: 场景加载完成
  - Then: HUD CanvasLayer 存在于场景树且 visible == true
  - Edge cases: 地图选择/商店/事件场景同样可见

- **AC-2**: 战斗场景 HUD 整体不渲染
  - Given: 游戏处于探索场景，HUD 可见
  - When: SceneManager 执行探索→战斗转场完成
  - Then: HUD CanvasLayer visible == false（所有子元素无一渲染）
  - Edge cases: 战斗→探索返回后 HUD 恢复可见；转场中途（pre_transition 已发、post_transition 未发）状态由实现定义但须确定性

- **AC-3**: 可见性切换由信号驱动
  - Given: HUD 已挂载
  - When: 检查 HUD 脚本的场景切换逻辑
  - Then: 切换由 SceneManager 信号（或场景状态信号）回调触发，`_process` 中无场景类型轮询

- **AC-4**: HUD 零状态副本
  - Given: HUD 脚本源码
  - When: grep 检查成员变量
  - Then: 无对 GSM 域的赋值语句；`_cache`/`_last` 前缀成员均有瞬态交互状态注释

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/hud/hud_scene_visibility_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None（SceneManager/GSM Foundation 层已 Complete）
- Unlocks: Story 002、003、005、006（挂载点与可见性骨架）
