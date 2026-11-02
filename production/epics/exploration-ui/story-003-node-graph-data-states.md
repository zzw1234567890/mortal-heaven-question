# Story 003: 节点图数据接入与节点状态渲染

> **Epic**: 探索 UI
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: 1.5d
> **Manifest Version**: 2026-09-07
> **Last Updated**: 2026-10-27（story-done 关闭——S16-3 完成）

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
  *(stub 先行注记，2026-10-26 裁决：探索系统 map_generated 信号 / get_node_detail 单数 API / 六态查询均未实现——本 story 以 UI 侧 stub 信号发射器 + stub 节点数据满足「信号驱动路径」要求；Feature 层补齐后仅替换信号源与数据源，渲染路径不变。)*
- Forbidden: UI 缓存节点可达性自行判定（每次移动后从系统刷新）；轮询节点状态
- Guardrail: 12+ 节点静态渲染 DC 计入 story 001 基准预算

---

## Acceptance Criteria

*From GDD 节点图渲染 AC + 迷雾 AC，scoped to this story:*

- [x] 地图数据加载完成后节点图构建 + 逐层从入口向 Boss 展开浮现（0.8s）——stub 先行：由 UI 侧 stub 信号发射器驱动节点图构建（替换 story-001 的 `setup()` 直连 stub 调用为信号驱动路径）；Feature 层 `map_generated` 信号落盘后仅替换信号源、不改渲染路径
- [x] 当前节点：金色边框+玩家标记（人形图标）
- [x] 可达节点：彩色正常显示+白色/蓝色脉冲外发光
- [x] 已访问节点：绿色边框+✓标记，稍暗
- [x] 不可达节点：灰色+锁标记；行动力不足的节点：灰色+红色斜线（悬停显示「行动力不足」）
- [x] 迷雾节点（未暴露）：深色覆盖+❓标记，不显示类型；移动到邻近层时迷雾消散（0.3s）
- [x] 10 种节点类型图标+颜色+标签正确渲染（node_type_to_icon 映射：入口🏁/战斗⚔/精英⚡/Boss👑/事件❓/商店🏪/传送✦/灵泉💧/渡劫台🌩/回复点💚——可自动化断言契约 = label+color+region，emoji 仅作最终视觉目标，真实图标归资产管线）
- [x] 渡劫台「修为尚未圆满」不可触发状态渲染（A7——可进入节点但不可触发，视觉区分；数据源 = stub 节点详情字段 `tribulation_ready`）
- [x] 节点连线：已走过金色实线 / 未走过暗色虚线
- [x] 节点悬停预览：节点名称+简短描述+敌人详情（战斗类节点；迷雾节点按 UX 决策显示「?」不显示敌人构成——A5；数据源 = stub 节点详情字段 `description`/`enemy_detail`）
- [x] 精英节点⚡+红色边框；渡劫台🌩+金色脉冲（与精英区分）
- [x] 传送节点：本 epic 按普通节点渲染图标与颜色（交互暂不实现——B5 裁决，机制未闭合）

---

## Completion Notes
**Completed**: 2026-10-27
**Criteria**: 12/12 通过（动画时序 0.8s 展开 / 0.3s 迷雾消散 / 0.3s tooltip 浮出归 AC-3 手动走查——Integration 类型正常边界）
**Deviations**: 本地化豁免（`TEXT_AP_PREFIX` 沿用 S16-1 同源豁免；硬编码「返回地图选择」为固定 UI 词条） / stub 载荷先行（map_generated_stub.gd + node_graph_data_stub.gd——Feature 层 `map_generated` 信号 / `get_node_detail()` 单数 API 未实现，补齐后仅替换信号源与数据源，渲染路径不变） / UI evidence 待补（production/qa/evidence/node-graph-render-evidence.md——UI 类证据为 ADVISORY）
**Test Evidence**: 单元 `tests/unit/exploration_ui/test_node_state_logic.gd`（22 例）+ 集成 `tests/integration/exploration_ui/test_node_graph_render.gd`（18 例）——全量 2991/2992 + 1 pending 存量，零回归
**Code Review**: LP-CODE-REVIEW 两轮——首轮 REJECT（1 BLOCKER + 3 HIGH）全部闭环，复验 APPROVE；QL-TEST-COVERAGE 两轮——首轮 GAPS（AC-9/AC-11 缺口）闭环，复验通过

---

## Implementation Notes

*Derived from ADR-0031 §2/§3 + ADR-0014 决策 3:*

- **Logic 内核（BLOCKING 单测目标）——六态分类器 + 样式查询提取为纯函数**：
  - `classify_node_state(node_id, graph, visited, current_node, ap_remaining, node_details) -> int`——输入为渲染快照（邻接表/已访问集合/当前节点/行动力/节点详情），输出六态枚举（当前/可达/已访问/不可达/行动力不足/迷雾）。不可达与行动力不足是**不同状态**（AC-5 视觉不同），分类器必须区分——Feature 层 `can_move_to()` 当前三态混叠返回 false，stub 分类器先行按 GDD 规则判定。
  - `node_state_style(state) -> Dictionary`——六态 → 视觉样式（边框色/标记/发光），纯函数映射表数据驱动。
  - 两者与 `node_type_to_icon`（story-001 NodeIconAtlas 已落地）同为 Logic 内核，GUT 直调可测。
- **数据流（stub 先行）**：UI 侧 stub 信号发射器（模拟 `map_generated(map_id, map_data)` Cat 2b 信号）→ 遍历 map_data.nodes/graph 构建节点控件（复用 story 001 基座）→ 六态经 `classify_node_state` 纯函数判定 → 样式经 `node_state_style` 渲染。Feature 层 `map_generated`/`get_node_detail()`/`can_move_to()` 落盘后仅替换信号源与数据源。
- node_type_to_icon 为纯函数（GDD 公式 1）——story-001 NodeIconAtlas 已落地，映射表数据驱动；本 story 消费。
- **stub 节点数据形状**（Feature 层补齐后沿用契约）：
  - `node_details[node_id] = {type, layer, idx, label, description, enemy_detail, tribulation_ready}`——`description`（悬停简短描述）、`enemy_detail`（战斗类敌人构成）、`tribulation_ready`（渡劫台修为是否圆满，bool）为本 story 新增字段。
  - 六态由 stub 快照驱动：`visited`（已访问）、`current_node`、`ap_remaining`、迷雾揭示集合。
- 迷雾：邻层迷雾揭散动画（0.3s）由 node_moved 信号驱动——迷雾状态判定归探索系统，UI 只做视觉（stub 阶段以 stub 迷雾揭示集合近似）。
- 焦点内建（A3）：节点控件创建时即注册键盘焦点（方向键空间跳转的跳转目标）与双焦点样式（焦点环）——不在 010 补做。
- 节点悬停 tooltip：0.3s 内浮出（UX AC）；战斗类节点敌人构成来自 stub `enemy_detail` 字段（Feature 层补齐后替换为 get_node_detail 载荷）。
- **动画时序验证归手动证据**：0.8s 逐层展开 / 0.3s 迷雾消散 / 0.3s tooltip 浮出均为动画时序，不纳入集成测试自动化断言（Integration 类型正常边界），由 QA Test Cases AC-3 手动走查覆盖。
- **遗留待同步（GAP-5）**：GDD §2 界面规则表渡劫台图标写作 ⚡，与本 story 及 GDD 公式 1 的 🌩 不一致——本 story 按 🌩 实现（与精英⚡区分，AC-11 裁决），GDD 源表待 design 侧同步勘误，本 story 不反向修改 GDD。

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
  - Given: stub 节点数据（10 种类型 + 六态：当前/可达/已访问/不可达/行动力不足/迷雾）
  - When: stub 信号发射器发射 map_generated 信号
  - Then: 每个节点控件的视觉属性（图标/颜色/边框/标记）与六态样式查询逐项一致（断言 `classify_node_state` 纯函数返回值 + `node_state_style` 样式查询 + node_type_to_icon 映射）
  - Edge cases: 渡劫台修为未满（`tribulation_ready=false` → 可进入不可触发态）；传送节点按普通节点渲染（无交互）；不可达 vs 行动力不足分类不混叠

- **AC-2**: 迷雾揭散
  - Given: 节点 A 邻层有迷雾节点 B
  - When: node_moved 信号（玩家到达 A）
  - Then: B 的迷雾覆盖视觉移除（0.3s 动画后类型显现——动画时序归 AC-3 手动走查，自动化只断言迷雾揭示集合变更后 `classify_node_state` 返回非迷雾）
  - Edge cases: 迷雾节点悬停 tooltip 显示「?」不显示敌人构成

**[UI — manual verification steps]:**

- **AC-3**: 节点图走查
  - Setup: stub 节点数据（含全部 10 类型+六态+渡劫台未圆满）
  - Verify: 图标/颜色/连线（金实线/暗虚线）/逐层展开动画（0.8s）/迷雾消散（0.3s）/悬停预览内容（名称+描述+敌人详情）
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
- Feature 层数据源缺口（S16-3 实现时以 UI 侧 stub 先行，2026-10-26 裁决）：探索系统 `map_generated` 信号 / `get_node_detail()` 单数 API / 节点状态六态查询（`can_move_to`/`get_node_detail`）均未实现——本 story 按「stub 载荷先行 + 记录依赖缺口上报」执行（与 story-002 同款裁决），UI 侧模拟 map_generated 信号 + stub 节点数据（10 类型 + 六态）驱动渲染，六态判定用 stub；Feature 层补齐后替换。本 story 同时在薄容器 `exploration_scene.tscn` 内补节点图挂载点（NodeGraphViewport 实例化）。
- Unlocks: Story 005（移动交互在渲染节点上）、Story 006（弹窗锚定节点位置）
