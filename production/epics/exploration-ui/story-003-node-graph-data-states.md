# Story 003: 节点图数据接入与节点状态渲染

> **Epic**: 探索 UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: [待 sprint 排期填写]
> **Manifest Version**: 2026-09-07
> **Last Updated**: [由 /dev-story 设置]

## Context

**GDD**: `design/gdd/exploration-ui-system.md`
**Requirement**: 节点图 7 条 AC 的渲染部分 + 迷雾视觉 3 条 AC + 节点图标映射公式
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线（主要）；ADR-0014: 探索系统（次要——map_generated 信号/节点状态查询）
**ADR Decision Summary**: 事件驱动更新（map_generated → 构建节点图；node_moved → 状态翻转）；零状态所有权（节点状态从探索系统查询）；node_type_to_icon 纯函数映射。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: 节点控件内建键盘焦点支持（A3——控件创建时即带焦点/双焦点属性，避免 010 返工）；节点图标 48×48px（调优范围 32~64）。

**Control Manifest Rules (this layer)**:
- Required: 节点状态从探索系统 API/信号读取（can_move_to/get_node_detail/map_generated）；节点逐层展开动画 0.8s
- Forbidden: UI 缓存节点可达性自行判定（每次移动后从系统刷新）；轮询节点状态
- Guardrail: 12+ 节点静态渲染 DC 计入 story 001 基准预算

---

## Acceptance Criteria

*From GDD 节点图渲染 AC + 迷雾 AC，scoped to this story:*

- [ ] map_generated 信号 → 节点图构建（真实 DAG 数据替换 stub）+ 逐层从入口向 Boss 展开浮现（0.8s）
- [ ] 当前节点：金色边框+玩家标记（人形图标）
- [ ] 可达节点：彩色正常显示+白色/蓝色脉冲外发光
- [ ] 已访问节点：绿色边框+✓标记，稍暗
- [ ] 不可达节点：灰色+锁标记；行动力不足的节点：灰色+红色斜线（悬停显示「行动力不足」）
- [ ] 迷雾节点（未暴露）：深色覆盖+❓标记，不显示类型；移动到邻近层时迷雾消散（0.3s）
- [ ] 10 种节点类型图标+颜色+标签正确渲染（node_type_to_icon 映射：入口🏁/战斗⚔/精英⚡/Boss👑/事件❓/商店🏪/传送✦/灵泉💧/渡劫台🌩/回复点💚）
- [ ] 渡劫台「修为尚未圆满」不可触发状态渲染（A7——可进入节点但不可触发，视觉区分）
- [ ] 节点连线：已走过金色实线 / 未走过暗色虚线
- [ ] 节点悬停预览：节点名称+简短描述+敌人详情（战斗类节点；迷雾节点按 UX 决策显示「?」不显示敌人构成——A5）
- [ ] 精英节点⚡+红色边框；渡劫台🌩+金色脉冲（与精英区分）
- [ ] 传送节点：本 epic 按普通节点渲染图标与颜色（交互暂不实现——B5 裁决，机制未闭合）

---

## Implementation Notes

*Derived from ADR-0031 §2/§3 + ADR-0014 决策 3:*

- 数据流：`map_generated(map_id, map_data)` Cat 2b 信号 → 遍历 map_data.nodes/graph 构建节点控件（复用 story 001 基座）；节点状态六态+迷雾态从探索系统 `can_move_to()`/`get_node_detail()` 查询。
- node_type_to_icon 为纯函数（GDD 公式 1）——可提为独立可测类，映射表数据驱动。
- 迷雾：邻层迷雾揭散动画（0.3s）由 node_moved 信号驱动——迷雾状态判定归探索系统，UI 只做视觉。
- 焦点内建（A3）：节点控件创建时即注册键盘焦点（方向键空间跳转的跳转目标）与双焦点样式（焦点环）——不在 010 补做。
- 节点悬停 tooltip：0.3s 内浮出（UX AC）；战斗类节点敌人构成来自 get_node_detail 载荷。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: 缩放平移容器与性能基准（本 story 在其基座上接入数据）
- Story 005: 点击移动交互流（本 story 仅渲染+悬停预览）
- Story 006: 节点交互弹窗
- 探索系统域: DAG 生成与迷雾状态判定（数据源）

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not implement new test cases during implementation.*

**[Integration — automated test specs]:**

- **AC-1**: 节点状态渲染映射
  - Given: stub 探索系统返回 10 种类型节点 + 六态（当前/可达/已访问/不可达/行动力不足/迷雾）
  - When: map_generated 信号发射
  - Then: 每个节点控件的视觉属性（图标/颜色/边框/标记）与 GDD 状态表逐项一致（断言 node_type_to_icon 纯函数返回值 + 状态样式查询）
  - Edge cases: 渡劫台修为未满（可进入不可触发态）；传送节点按普通节点渲染（无交互）

- **AC-2**: 迷雾揭散
  - Given: 节点 A 邻层有迷雾节点 B
  - When: node_moved 信号（玩家到达 A）
  - Then: B 的迷雾覆盖视觉移除（0.3s 动画后类型显现）
  - Edge cases: 迷雾节点悬停 tooltip 显示「?」不显示敌人构成

**[UI — manual verification steps]:**

- **AC-3**: 节点图走查
  - Setup: 真实地图数据（含全部 10 类型+六态）
  - Verify: 图标/颜色/连线（金实线/暗虚线）/逐层展开动画/悬停预览内容
  - Pass condition: 与 GDD 视觉表现表逐行一致 + 签批

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/exploration_ui/test_node_graph_render.gd` — must exist and pass
- UI: `production/qa/evidence/node-graph-render-evidence.md` + sign-off

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（渲染基座）
- Unlocks: Story 005（移动交互在渲染节点上）、Story 006（弹窗锚定节点位置）
