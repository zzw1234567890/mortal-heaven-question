# Story 007: 终验——三界面闭环+分辨率双输入

> **Epic**: 卡组编辑 UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: [待 sprint 排期填写]
> **Manifest Version**: 2026-09-07
> **Last Updated**: [由 /dev-story 设置]

## Context

**GDD**: `design/gdd/deck-editing-ui-system.md`（全 9 条本域 AC——13 条中 4 条战利品 AC 归 combat-ui）
**Requirement**: EPIC DoD 终验项（2026-09-08 A3 修正后口径：本域 AC + 战利品接口对接验证）
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线（主要）；ADR-0023: 卡组编辑系统（次要——数据流闭环）
**ADR Decision Summary**: 终验 story（exploration-ui 010 同族先例）：不实现新功能，验证前序 story 集成后的全流程闭环、跨界面数据流一致性与全局质量门（分辨率/双输入/减少动态/焦点规范）。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: 全部验证为运行时走查+截图取证；720p 缩放按 1080p 基准比例。

**Control Manifest Rules (this layer)**:
- Required: 三界面（坊市/卡组浏览/超限弃牌）全部 AC 抽查复验
- Forbidden: 新功能实现（发现缺陷→回对应 story 修复后重验）
- Guardrail: 峰值 DC 复测（含商品网格满载+卡组 40 卡）

---

## Acceptance Criteria

*From UX 规范终验类 AC + EPIC DoD，scoped to this story:*

- [ ] 坊市全流程闭环：进入→浏览（悬停详情）→购买→散功→出售→刷新→离开——全程无状态错乱（灵石/卡组计数/库存标记三联动正确）
- [ ] 卡组浏览多入口闭环：HUD 图标/坊市内入口两路径打开→筛选排序→详情→关闭返回来源（战利品面板入口归 combat-ui 实现后补验——记录待验项）
- [ ] 超限弃牌闭环：事件触发（或测试钩子）→知情弹窗→弃牌→确认→返回——补偿入账+卡组数回到上限内
- [ ] 三界面变更后历史标签同步：坊市购买/散功/出售/超限弃牌操作后「历史」标签新增对应条目（来源渠道标注正确）
- [ ] 1280×720 下限：三界面全部元素可见不溢出（网格列数与筛选标签行自适应收缩）
- [ ] 纯键盘全路径：坊市完整流程（浏览→购买→散功→出售→离开）与超限弃牌——焦点环全程可见，顺序：顶部条→网格（行优先）→底部操作条
- [ ] 手柄路径：坊市购买与离开（A/B/LB/RB/方向键）
- [ ] 「减少动态」开启：商品依次出现/碎裂/熔炼/压下动画全部瞬时替代，数字直显终值
- [ ] 所有确认弹窗（购买/散功/出售）打开时焦点默认「取消」侧
- [ ] 峰值 DC 复测：商品满载（6×N）+卡组 40 卡网格在预算内（200 以下）

---

## Implementation Notes

*Derived from EPIC DoD + exploration-ui 010 先例:*

- 战利品入口对接验证（EPIC DoD 项）：combat-ui-interaction story 007 的战利品面板实现后，验证「选前查看卡组」入口打开本界面——**本 sprint 记录为待验项**，不阻塞本 story 验收（跨 epic 排期依赖）。
- 缺陷处理：终验发现的缺陷回写对应 story 的 AC（修复后该 story 重开），本 story 只记录+复验。
- 测试证据按界面分段截图+走查记录。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001-006: 全部功能实现（本 story 仅验证）
- combat-ui-interaction 007: 战利品面板本体与其「查看卡组」入口（待验项记录）
- Feature 层: 系统 API 真实接线复验（各 story 依赖上报项的复验节点）

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not implement new test cases during implementation.*

**[UI — manual verification steps]:**

- **AC-1**: 三界面全流程闭环
  - Setup: 完整存档（灵石充足+35 张卡组+可触发超限的测试钩子）
  - Verify: 三界面 AC-1 抽查项逐条复验+历史标签同步
  - Pass condition: 全流程无状态错乱 + 截图取证 + 签批

- **AC-2**: 全局质量门
  - Setup: 720p 窗口；键盘；手柄；减少动态开启——四种配置
  - Verify: 分辨率不溢出/键盘全路径焦点环/手柄路径/动画瞬时替代/弹窗焦点默认
  - Pass condition: 四配置走查通过 + 签批

---

## Test Evidence

**Story Type**: UI
**Required evidence**:
- `production/qa/evidence/deck-editing-ui-final-evidence.md` + sign-off（含峰值 DC 复测数据）

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001、002、003、004、005、006 全部完成
- Unlocks: EPIC 完结（DoD 终验项）
