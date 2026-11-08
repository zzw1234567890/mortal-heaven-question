# Story 007: 备战面板（视觉框架与状态判定）

> **Epic**: 战斗 UI——静态布局与角色状态卡
> **Status**: Complete
> **Layer**: Presentation
> **Type**: UI（Logic 内核）
> **Estimate**: 2.0d（sprint-17 排期）
> **Manifest Version**: 2026-09-07
> **Last Updated**: 2026-11-07

## Context

**GDD**: `design/gdd/combat-ui-system.md`
**Requirement**: 备战阶段 AC 6 条（静态侧 5 条）+ §8 备战界面规则
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线
**ADR Decision Summary**: 划界裁决 2026-09-07：**视觉框架+状态判定纯函数+信号驱动渲染归本 story**；输入流转（点选/拖拽阵位/替换确认流）归 interaction epic。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: 阵位布局按境界动态调整（炼气前2后1/筑基前2后2/金丹前2后2/元婴前3后2/化神前3后3）；max_deploy 炼气2~化神6。

**Control Manifest Rules (this layer)**:
- Required: 4 态判定/max_deploy 阵位映射/确认按钮状态纯函数单测
- Forbidden: 硬编码境界→阵位映射（数据驱动配置）
- Guardrail: 阵位预览更新 ≤1 帧（渲染侧；拖拽触发归 interaction）

---

## Acceptance Criteria

*From GDD，scoped to this story:*

- [x] 备战面板视觉框架：战斗名称标题、角色缩略卡列表（头像/HP/ATK/绑定概览）、阵位布局预览（前后排）、确认出战/返回按钮
- [x] 角色选择 4 态渲染：已选（✓+金色高亮）/可选未选（☐）/可替换（⊕，名额满时）/不可用（💀灰色，阵亡）
- [x] 4 态判定纯函数：输入 (is_dead, is_selected, selected_count, max_deploy) → 4 态之一（阵亡优先）
- [x] 阵位布局映射：境界 → (前排位数, 后排位数) 数据驱动（炼气 2/1 … 化神 3/3）；slots 总数 ≥ max_deploy
- [x] 已选人数不满上限显示「还可以选择X人」；确认按钮在 ≥1 已选角色时才可点
- [x] 阵位预览随选择状态实时更新（信号驱动渲染）
- [x] 悬停角色显示协同信息概览（渲染态；tooltip 交互归 interaction）

*（AC-1/AC-2 的「真实渲染可辨识性与排版」为视觉通道，见证据文档 §2 八项，待 QA-17-2 D3D12 走查签收——自动化已覆盖判定与装配。）*

---

## Implementation Notes

*Derived from ADR-0031 Implementation Guidelines:*

**Logic 内核（BLOCKING 单测目标）**：
- `deploy_selection_state(is_dead, is_selected, selected_count, max_deploy) -> String`——4 态判定（阵亡优先于可替换）。
- `formation_slot_layout(realm_id) -> Dictionary`——境界→前后排位数映射（数据驱动常量；slots ≥ max_deploy 不变量校验；未知 realm 显式报错）。
- `confirm_button_enabled(selected_count) -> bool`——≥1 可点。

- 可选角色列表从上场系统/卡牌系统读取（含阵亡状态）；选择状态为**瞬态交互状态**（UI 本地合法，ADR-0031 §2.1）——确认出战前不写回系统。
- 「返回探索」触发 SceneManager 转场。
- 替换确认弹窗（名额满点 ⊕）：弹窗框架归本 story，替换决策流与 character_undeployed/deployed 事件归 interaction。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- interaction epic: 角色点选流转/阵位拖拽调整（1 帧更新交互侧）/替换确认决策/数字键选择
- Story 008: 渡劫战前 warning（在备战面板前弹出的对话框——归 008 弹窗框架）
- Story 002: 角色卡组件（备战用缩略卡独立实现）
- audio-manager epic: 选择/确认音

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

**[Logic 内核 — automated test specs]**（`tests/unit/combat_ui/test_deploy_selection_state.gd` + `test_formation_slot_layout.gd`）

- **AC-1**: 4 态判定
  - Given: (is_dead, is_selected, selected_count, max_deploy)
  - When: 调用 `deploy_selection_state()`
  - Then: 阵亡 → 不可用（优先）；已选 → ✓；未选+未满 → ☐；未选+已满+未阵亡 → ⊕
  - Edge cases: 阵亡且名额未满（仍不可用——阵亡优先）；selected_count==max 恰好边界；max=1

- **AC-2**: 境界→阵位映射
  - Given: realm_id
  - When: 调用 `formation_slot_layout()`
  - Then: 炼气(2,1)/筑基(2,2)/金丹(2,2)/元婴(3,2)/化神(3,3)；slots 总数 ≥ max_deploy（炼气 3≥2）
  - Edge cases: 未知 realm → 显式报错（非静默默认）

- **AC-3**: 确认按钮状态
  - Given: selected_count
  - When: 调用 `confirm_button_enabled()`
  - Then: 0 → false；1 → true；满员 → true
  - Edge cases: 0/1 边界

**[UI — manual verification steps]:**

- **AC-4**: 备战面板视觉
  - Setup: 五个境界分别进入备战
  - Verify: 4 态标记正确（构造阵亡/满员场景）；五个阵位布局截图对比；「还可以选择X人」提示
  - Pass condition: 布局与境界映射表一致、4 态视觉可区分、确认按钮灰态正确

---

## Test Evidence

**Story Type**: UI（Logic 内核）
**Required evidence**:
- Logic 内核: `tests/unit/combat_ui/test_deploy_selection_state.gd` + `test_formation_slot_layout.gd` — must exist and pass（BLOCKING）
- UI: `production/qa/evidence/deploy-panel-evidence.md` + sign-off（五境界截图）

**Status**: [x] Created — 单元 57 例（27 + 14 + 16）+ 集成 54 例（28 + 7 宿主接线 + 19 取数/替换/悬停），combat_ui 单元 105/105、集成 162/162 全绿
**Manual debug host**: `tests/manual/deploy_panel_debug.tscn`（F6 运行，按键 1-5 切境界 / D 阵亡场景 / R 重置）

---

## Dependencies

- Depends on: Story 001（布局骨架）— 已完成
- Unlocks: interaction epic（备战交互流消费本 story 框架与判定函数）

---

## Completion Notes

**Completed**: 2026-11-07
**Criteria**: 7/7 通过（AC-1/AC-2 的视觉通道归 QA-17-2 D3D12 走查，与 17-1 同口径）
**Test Evidence**:
- Logic 内核（BLOCKING）: `tests/unit/combat_ui/test_deploy_selection_state.gd`（27 例）+ `test_formation_slot_layout.gd`（14 例）+ `test_deploy_roster_reader.gd`（16 例——生产取数链路）
- UI: `tests/integration/combat_ui/test_deploy_panel.gd`（28 例）+ `test_deploy_panel_host.gd`（7 例宿主接线）+ `test_deploy_panel_sources.gd`（19 例——setup 订阅/load_roster 成功路径/替换弹窗/跨系统 ID 契约/悬停并集）
- 计数: combat_ui 单元 105/105、集成 162/162 全绿；全量 **3277 tests / 3276 passing / 1 pending（存量） / 3 orphans（存量）**，较 17-1 收尾基线 3166 净增 111 例，零回归
- 证据文档: `production/qa/evidence/deploy-panel-evidence.md`（§1b QL 补测表 + §2 八项视觉走查待 QA-17-2 签收）
- Debug 宿主: `tests/manual/deploy_panel_debug.tscn`
**Code Review**: LP-CODE-REVIEW = CONCERNS（0 BLOCKING / 6 HIGH / 7 MEDIUM / 3 LOW），已全部处理：
- H1 未注入依赖静默空面板 → `push_warning` + `has_sources()` + 宿主测试锁定告警次数
- H2 双次全量重建 → `load_roster()` 单次取数下发
- H3 境界回落不收缩已选 → `apply_roster` 内 slice 到 max_deploy + 回归测试
- H4 单测复制部署常量 → 改读真实 `FRONT_CAPACITY_BY_MAX_DEPLOY`
- H5 替换固定取首位 → `request_replace(new, replaced)` + `_pending_replaced_id` + 回归测试
- H6 宿主接线零断言 → 新增 `test_deploy_panel_host.gd`（7 例）
- M7 卡片成员裸读 → `get_character_id()`/`get_state()`/`get_faction_tags()` 类型化访问器
- M8 内联字号 → 卡片与预览统一走 `CombatUiFont.font_size_responsive`
- M10 名册脏数据无订阅 → 连 `character_unavailable`/`character_revived` → `_on_roster_dirty`
- M11 未知 ID 伪装成不可用 → 返回 `""`
- M12 悬停测试绕过信号 → 改发真实 `mouse_entered`/`mouse_exited`
- M13 面板超 300 行 → 拆出 `deploy_panel_view.gd`（96 行）；残量登记 DEBT-CUI-007-2
- LOW14 `max_deploy <= 0` 提示语义 → 「上场人数上限未初始化」
- LOW15 非容器子节点尺寸 → `size = custom_minimum_size`
- LOW16 `draw.connect` vs `_draw()` → 登记 DEBT-CUI-007-3（同目录两种风格均有先例）
**QA Coverage**: QL-TEST-COVERAGE = GAPS → 8 项缺口全补测：
- G1 `DeployRosterReader` 读取链路零覆盖 → 新增 `test_deploy_roster_reader.gd`（16 例，桩依赖，不触碰 Autoload）
- G2 `setup()` 阵亡/复活订阅零覆盖（M10「改了但没测」）→ 4 例（含重复 setup 以模板查询次数锁定不重复订阅）
- G3 `load_roster()`/`refresh_roster()` 成功路径零覆盖（H2 单次取数从未被断言）→ 5 例
- G4 跨系统 ID 域契约 → 2 例用**真实 DeploymentSystem** 验证 `mark_unavailable`/`revive_character` 与读取器同域
- G5 `remaining_hint` 未初始化上限分支 → 1 例
- G6/G7 替换弹窗打开环节、默认被替换者、守卫与回退分支 → 5 例
- G8 悬停自身排除与多人并集 → 2 例
**Deviations**:
- ADVISORY（已登记技债 DEBT-CUI-007-1）：面向玩家文案中文硬编码（项目尚无本地化系统，同 S16/S17 豁免口径）
- ADVISORY（已登记技债 DEBT-CUI-007-2）：`deploy_panel.gd` 364 行 / `combat_layout.gd` 310 行超 300 行软上限（有效代码约 224 / 202 行，渐进超限）
- ADVISORY（已登记技债 DEBT-CUI-007-3）：自绘入口 `draw.connect` 与 `_draw()` 覆写风格并存
- 范围说明：`combat_layout.gd`（+43 行）在故事「files to create/modify」之外，但属必需宿主接线（故事 Implementation Notes 明示「CombatLayout 新增 deploy_panel」），非范围蔓延

### 新增文件
- `src/ui/combat/shared/deploy_panel_rules.gd`（132 行——4 态判定/阵位映射/提示文案/协同标签纯函数）
- `src/ui/combat/deploy/deploy_panel.gd`（364 行——编排/刷新/交互）
- `src/ui/combat/deploy/deploy_panel_view.gd`（96 行——控件树与布局常量）
- `src/ui/combat/deploy/deploy_roster_reader.gd`（93 行——GSM→CardSystem→部署/绑定读取链路）
- `src/ui/combat/deploy/deploy_character_card.gd`（212 行——缩略卡自绘）
- `src/ui/combat/deploy/deploy_formation_preview.gd`（147 行——阵位预览自绘）
- `tests/unit/combat_ui/test_deploy_selection_state.gd`、`test_formation_slot_layout.gd`、`test_deploy_roster_reader.gd`
- `tests/integration/combat_ui/test_deploy_panel.gd`、`test_deploy_panel_host.gd`、`test_deploy_panel_sources.gd`
- `tests/integration/combat_ui/mocks/mock_deploy_sources.gd`
- `tests/manual/deploy_panel_debug.gd` + `.tscn`
- `production/qa/evidence/deploy-panel-evidence.md`

### 修改文件
- `src/ui/combat/layout/combat_layout.gd`（+43 行——面板实例化 + `show_deploy_panel`/`hide_deploy_panel`）
