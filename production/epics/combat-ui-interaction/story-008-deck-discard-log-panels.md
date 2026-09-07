# Story 008: 牌库/弃牌堆/日志面板交互

> **Epic**: 战斗 UI——手牌与交互流程
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: [待 sprint 排期填写]
> **Manifest Version**: 2026-09-07
> **Last Updated**: [由 /dev-story 设置]

## Context

**GDD**: `design/gdd/combat-ui-system.md`
**Requirement**: 牌库与弃牌堆 AC 5 条 + 战斗日志 AC 6 条 + §11 战斗日志规则
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线
**ADR Decision Summary**: 零状态所有权（牌库/弃牌内容从卡牌系统读取，日志条目从战斗系统信号追加）+ 事件驱动更新 + 场景内 Control 节点。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: 日志用 RichTextLabel + ScrollContainer（GDD §11）；面板展开动画 ≤0.3s；scroll_vertical 逐帧滚底。

**Control Manifest Rules (this layer)**:
- Required: 面板内容按需读取（展开时构建，关闭时释放）；0ms 面板间切换
- Forbidden: 轮询牌库数量（信号驱动）
- Guardrail: 日志展开覆盖手牌区上方（半屏 50%）不遮挡角色区

---

## Acceptance Criteria

*From GDD 牌库/弃牌堆 AC + 战斗日志 AC，scoped to this story:*

- [ ] 点击牌库计数 → 展开牌库详情（滚轮浏览，卡背展示——顺序未知）
- [ ] 点击弃牌堆计数 → 展开弃牌堆详情（滚轮浏览，卡面展示——内容可见）
- [ ] 面板间切换 0ms：牌库展开时鼠标移到弃牌堆计数 → 牌库立即关闭、弃牌堆立即弹出
- [ ] 点击外部 / ESC 关闭（ESC 归本面板——story 001 仲裁：MODAL 拥有者优先）
- [ ] 日志点击标签展开为半屏覆盖（50% 屏高，覆盖手牌区上方）；再点击折叠
- [ ] 日志展开时新增条目 → 自动滚动到底部（最新条目完全可见且位于容器底边）
- [ ] 日志展开时鼠标滚轮滚动浏览历史；日志条目格式 `[回合·阶段] 行动者 → 动作 → 目标 → 数值`（渲染归 layout 004，本 story 为滚动交互）
- [ ] 阶段 2 进入时日志自动收起（GDD §11——阶段信号驱动，保证出牌不被遮挡）
- [ ] 战斗结束返回探索后日志内容清空（战后清理）
- [ ] 键盘可达：日志标签/牌库/弃牌堆计数器 Tab 聚焦 + Enter 展开；日志展开后方向键滚动（UX 无障碍缺口 #3）

---

## Implementation Notes

*Derived from ADR-0031 Implementation Guidelines:*

- 本 story 合并战斗日志交互（B6 裁决——与牌库/弃牌堆同属面板展开/切换/关闭交互族）。
- 面板开闭状态机：`PanelToggleState`（deck/discard/log 三面板互斥+切换 0ms+外部点击关闭）——可作纯类单测（非 BLOCKING，UI 型 story 建议项）。
- 牌库内容：展开时从卡牌系统读取（只读快照构建卡背网格）；关闭释放节点（池化可选）。
- 日志：战斗系统行动信号追加条目（条目文本组装归 layout 004 渲染管线）；展开时 scroll_vertical = max 值逐帧跟随。
- 阶段 2 自动收起：phase_changed 信号 → 若日志展开且新阶段=2 → 收起。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- layout story 004: 日志条目格式渲染与顶部条入口位
- layout story 005: 牌库/弃牌堆计数数字显示
- 战斗系统域: 日志条目生成（行动记录数据源）
- Story 002: 悬停详情面板（悬停族，本 story 为点击展开族）

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not implement new test cases during implementation.*

**[Integration — automated test specs]:**

- **AC-1**: 面板开闭状态机
  - Given: 日志展开
  - When: 点击牌库计数 / 点击外部 / 按 ESC
  - Then: 点牌库 → 日志关+牌库开（0ms 切换）；点外部 → 全关；ESC → 当前面板关
  - Edge cases: 三面板任意切换序列后状态唯一（无多面板同开）；阶段 2 信号到达 → 日志若开则自动收起（牌库/弃牌不受阶段影响）

- **AC-2**: 日志滚底
  - Given: 日志展开，已有 20 条
  - When: 追加第 21 条
  - Then: scroll 位置定位至底部（最新条目底边=容器底边断言）
  - Edge cases: 用户手动上滚后新条目到达——跟随暂停（不强制拉底，实现定义固化后测试锁定）

**[UI — manual verification steps]:**

- **AC-3**: 三面板走查
  - Setup: 战斗中，牌库 12 张/弃牌 8 张/日志多回合
  - Verify: 卡背（牌库不可见内容）vs 卡面（弃牌可见）、半屏覆盖不遮角色区、滚轮浏览、键盘路径
  - Pass condition: 切换瞬时无残影、日志阶段 2 自动收起、战后清空

---

## Test Evidence

**Story Type**: UI
**Required evidence**:
- Integration: `tests/integration/combat_ui/test_panel_toggle.gd` — must exist and pass
- UI: `production/qa/evidence/deck-discard-log-panel-evidence.md` + sign-off

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（ESC 仲裁）、layout story 004/005（入口位与计数渲染）
- Unlocks: 无直接下游
