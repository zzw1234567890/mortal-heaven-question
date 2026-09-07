# Story 004: 顶部条——阶段指示器/阵法区/战斗日志

> **Epic**: 战斗 UI——静态布局与角色状态卡
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI（Integration）
> **Estimate**: [待 sprint 排期填写]
> **Manifest Version**: 2026-09-07
> **Last Updated**: [由 /dev-story 设置]

## Context

**GDD**: `design/gdd/combat-ui-system.md`
**Requirement**: 阶段指示器 AC 3 条 + 阵法区 AC 4 条（展示侧 3）+ 战斗日志 AC 6 条
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线
**ADR Decision Summary**: phase_changed 信号驱动（战斗系统已实现，`src/feature/combat_system.gd`）；边界澄清 2026-09-07：阶段 0 指示器名称统一为「准备」（「备战」为阶段 0 面板名）；音频对接（阶段切换音）声明。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: 日志用 RichTextLabel + ScrollContainer（默认折叠为标签）。阶段切换音仅触发音频事件（audio-manager 播放）。

**Control Manifest Rules (this layer)**:
- Required: 阶段指示器信号驱动集成测试；日志自动滚底断言
- Forbidden: 阶段倒计时 UI（策略游戏无时间压力——GDD 明文）；轮询阶段状态
- Guardrail: 日志展开覆盖手牌区上方时不得遮挡费用栏

---

## Acceptance Criteria

*From GDD，scoped to this story:*

- [ ] 阶段指示器：7 阶段（0-6）名称+进度条（表示阶段位置，无倒计时）+回合编号；phase_changed 信号驱动更新
- [ ] 阶段切换动画：阶段名短暂放大/滑入 0.2s + 阶段切换音事件触发
- [ ] 阶段 0 名称显示「准备」；阶段 2 无倒计时元素（节点树无 Timer 驱动 UI）
- [ ] 阵法区：已部署阵法卡（阵名+阵营标签）+空位灰色虚线框，最多 3 位
- [ ] 阵法激活光环（外发光，颜色对应阵营）；阵法悬停详情归 interaction
- [ ] 日志默认折叠小标签；点击展开半屏覆盖（此点击流转归 interaction，展开态渲染归本 story）
- [ ] 日志条目格式 `[回合·阶段] 行动者 → 动作 → 目标 → 数值`；最新在底自动滚底；滚轮可滚动
- [ ] 阶段 2 进入时日志自动收起；战斗结束返回探索后日志清空

---

## Implementation Notes

*Derived from ADR-0031 Implementation Guidelines:*

- 阶段指示器：订阅 combat 系统 `phase_changed` 信号；进度条为 7 格位置指示（非时间进度）。阶段名数据驱动常量（0 准备/1 抽牌/2 出牌/3 攻击声明/4 攻击结算/5 敌方行动/6 结束）。
- 阵法区：订阅阵法系统部署状态信号；3 槽位固定，空位虚线框常驻。第 4 个部署的拒绝判定归阵法系统（本 story 只展示 3 位）。
- 日志：订阅战斗系统行动记录信号追加条目；`scroll_vertical` 追踪最大值实现自动滚底；阶段 2 自动收起（phase_changed(2) 时若展开则折叠）；战斗结束信号清空条目。
- 暂停按钮位与日志入口按钮位在 story 001 已建——本 story 实现日志按钮的展开/收起渲染态。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: 顶部条容器
- interaction epic: 阵法悬停详情 300ms、日志点击展开的输入流转、牌库/弃牌点击
- audio-manager epic: 阶段切换音播放本体
- 阵法部署动作（出牌流程）：interaction epic

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not implement new test cases during implementation.*

**[Integration — automated test specs]:**

- **AC-1**: 阶段指示器信号驱动（`tests/integration/combat_ui/test_phase_indicator_signal.gd`）
  - Given: 指示器已渲染
  - When: phase_changed 信号依次 0→6
  - Then: 名称/进度格/回合编号逐段正确更新；节点树无倒计时 Timer UI 元素
  - Edge cases: 同阶段重复信号（无变化）；回合号递增

- **AC-2**: 日志行为（`tests/integration/combat_ui/test_log_phase2_autocollapse.gd`）
  - Given: 日志展开状态
  - When: phase_changed(2) 触发
  - Then: 日志折叠态恢复；条目追加后 scroll_vertical 位于最大值；战斗结束信号后条目清空
  - Edge cases: 折叠状态下新条目（仍追加，展开后可见）

**[UI — manual verification steps]:**

- **AC-3**: 顶部条视觉
  - Setup: 战斗中经历完整回合
  - Verify: 阶段名滑入动画 0.2s、阵法卡光环、日志展开半屏不遮费用栏
  - Pass condition: 三组件布局在 60px 顶部条内无溢出；减少动态时阶段名直接切换

---

## Test Evidence

**Story Type**: UI（Integration）
**Required evidence**:
- Integration: `tests/integration/combat_ui/test_phase_indicator_signal.gd` + `test_log_phase2_autocollapse.gd` — must exist and pass（BLOCKING）
- UI: `production/qa/evidence/topbar-evidence.md` + sign-off

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（顶部条容器）、Story 009a（合批方案——图标走图集）
- Unlocks: interaction epic（日志/阵法交互消费本 story 渲染态）
