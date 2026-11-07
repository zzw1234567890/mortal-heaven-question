# deploy-panel 007 备战面板证据——手动+自动化

> **日期**：2026-11-07
> **Story**：combat-ui-layout 007（备战面板：视觉框架与状态判定）
> **类型**：UI（Logic 内核）
> **自动化证据**：`tests/unit/combat_ui/test_deploy_selection_state.gd`（26 例）+ `test_formation_slot_layout.gd`（14 例）+ `tests/integration/combat_ui/test_deploy_panel.gd`（28 例）+ `test_deploy_panel_host.gd`（7 例）——combat_ui 单元 88/88 + 集成 143/143 全绿
> **本文档覆盖**：4 态视觉可辨识性、五境界阵位布局截图、确认按钮灰态三项**真实渲染走查**——判定逻辑由 BLOCKING 单元测试覆盖（见 §1）

---

## 1. AC → 证据映射

| AC | 内容 | 证据类型 | 证据位置 |
|---|------|---------|---------|
| AC-1 | 备战面板视觉框架（标题 / 角色缩略卡 / 阵位预览 / 两按钮） | 自动化（结构装配 + 数据下发 + 宿主接线）+ 视觉走查 | `test_deploy_panel.gd::test_panel_builds_title_cards_preview_and_buttons`、`test_card_shows_roster_stats`；`test_deploy_panel_host.gd::test_combat_root_has_hidden_deploy_panel`、`test_show_deploy_panel_makes_visible_with_roster`（审查 H6 补宿主接线）+ §2 表 1 |
| AC-2 | 角色选择 4 态渲染（✓／☐／⊕／💀） | 自动化（逐态判定 + 面板下发生效）+ 视觉走查 | `test_cards_start_selectable_and_dead_start_unavailable`、`test_selected_card_becomes_selected_state`、`test_full_selection_makes_others_replaceable`、`test_unknown_character_state_is_empty_not_unavailable`、`test_deploy_selection_state_*`（26 例） + §2 表 2 |
| AC-3 | 4 态判定纯函数（阵亡优先） | 自动化（BLOCKING） | `test_deploy_selection_state.gd` 全部（含阵亡优先三例与 max=1 边界） |
| AC-4 | 境界→阵位映射（数据驱动 / slots ≥ max_deploy / 未知境界报错） | 自动化（BLOCKING） | `test_formation_slot_layout.gd` 全部（五境界逐项 + 不变量 + 三例未知境界；不变量读真实 `FRONT_CAPACITY_BY_MAX_DEPLOY`——审查 H4） |
| AC-5 | 「还可以选择X人」+ 确认按钮 ≥1 才可点 | 自动化 | `test_hint_updates_with_selection_count`、`test_hint_shows_full_state_when_max_reached`、`test_confirm_button_disabled_with_zero_selection`、`test_apply_roster_shrinks_selection_when_limit_drops`（审查 H3）+ §2 表 3 |
| AC-6 | 阵位预览随选择实时更新（信号驱动） | 自动化 | `test_preview_layout_follows_realm`、`test_preview_updates_when_selection_changes`、`test_preview_fills_front_before_back`、`test_preview_clears_when_deselecting_all`、`test_panel_selection_updates_preview_in_scene`（宿主内实时更新） |
| AC-7 | 悬停显示协同信息概览 | 自动化（共享标签纯函数 + 真实 `mouse_entered`/`mouse_exited` 信号路径） | `test_shared_faction_tags_*`（5 例）、`test_hover_shows_shared_faction_tags`、`test_hover_without_synergy_shows_no_synergy_text`、`test_hover_exit_hides_tooltip`（审查 M12 改走真实信号） |

---

## 2. 视觉通道手动走查（D3D12 真实渲染路径）

**Setup**：Godot 4.6.3（Windows D3D12 默认渲染器）F6 运行 `tests/manual/deploy_panel_debug.tscn`；
按键 **1-5** 切换五境界（各自选满以展示可替换态）、**D** 构造阵亡场景、**R** 重置。

| # | 验证项 | 预期 | 结果 |
|---|--------|------|:----:|
| 1 | 备战面板整体框架 | 标题行「⚔ 青云剑宗·山门 — 普通战斗」、角色卡网格 6 张、阵位预览两行、底部两按钮齐备且不重叠 | [ ] 待 QA-17-2 走查 |
| 2 | 4 态视觉可区分 | ✓ 金色高亮加粗边框、☐ 正常墨框、⊕ 淡金边框、💀 灰框灰字 | [ ] 待 QA-17-2 走查 |
| 3 | 五境界阵位布局 | 炼气 前2后1 / 筑基 前2后2 / 金丹 前2后2 / 元婴 前3后2 / 化神 前3后3，逐张与映射表对齐 | [ ] 待 QA-17-2 走查 |
| 4 | 「还可以选择X人」提示 | 未满时随选择递减；满员后不再出现该句式 | [ ] 待 QA-17-2 走查 |
| 5 | 确认按钮灰态 | 0 已选时灰色不可点；选 1 人后恢复可点 | [ ] 待 QA-17-2 走查 |
| 6 | 阵位预览实时更新 | 每次点选后 ≤1 帧内前排优先填入、空位保持虚线框 | [ ] 待 QA-17-2 走查 |
| 7 | 悬停协同信息 | 与已选阵容有共享阵营标签时显示「协同 xx」；无交集显示「暂无协同」；移出即隐藏 | [ ] 待 QA-17-2 走查 |
| 8 | 替换确认弹窗框架 | 名额满点未选角色弹出「用[新]替换[旧]？」；确认后完成替换并发出 `replace_requested` | [ ] 待 QA-17-2 走查 |

**说明**：本轮自动化已把可量化部分（4 态判定、五境界映射、提示文案、按钮态、预览行填充顺序）固化为回归测试；§2 仅验证**真实渲染下的视觉可辨识性与排版**，不可自动化。

---

## 3. 实现说明

- **Logic 内核集中**（ADR-0031 Logic 内核模式）：`src/ui/combat/shared/deploy_panel_rules.gd`
  ——`deploy_selection_state` / `formation_slot_layout` / `confirm_button_enabled` /
  `remaining_hint` / `shared_faction_tags` 全部为无状态纯函数，面板与卡片组件只消费不复制。
- **数据驱动映射**（control-manifest 禁止硬编码境界→阵位映射）：`FORMATION_SLOT_TABLE`
  是唯一来源，新增境界只改表不改函数体；单测 `test_formation_slot_layout_covers_all_realm_table_entries`
  与 `test_formation_slot_layout_front_never_exceeds_deployment_front_capacity` 双重守护。
- **数据读取收敛**：`src/ui/combat/deploy/deploy_roster_reader.gd` 负责
  「GSM `deck.slots` → CardSystem 模板 → 战斗/部署/绑定系统状态」的读取链路，
  全部依赖注入（面板不直连 Autoload）；任一依赖缺失时退化为空名册（不崩溃）。
- **零状态所有权**（ADR-0031 §2）：角色数据为渲染快照；**选择状态为瞬态交互状态**
  （§2.1 豁免）——确认出战前不写系统，确认时只发 `confirm_requested(character_ids)`，
  由上层调用 `DeploymentSystem.setup_field()`。返回探索只发 `back_requested()`，转场归 SceneManager。
- **零轮询**（ADR-0031 §3）：四个新文件无 `_process()`——全部由按钮/悬停/替换弹窗信号驱动，
  预览与 4 态由 `queue_redraw` 或直接字段下发刷新（≤1 帧）。
- **职责拆分**（coding-standards 单文件 ≤300 行）：`deploy_panel.gd` 面板编排 /
  `deploy_character_card.gd` 缩略卡自绘 / `deploy_formation_preview.gd` 阵位预览自绘 /
  `deploy_roster_reader.gd` 数据读取 / `deploy_panel_rules.gd` 纯函数。
- **战斗场景装配**：`CombatLayout` 新增 `deploy_panel`（默认 `visible = false`，全屏覆盖层）
  与 `show_deploy_panel(max_deploy, realm_id, title)` / `hide_deploy_panel()` 两个入口；
  数据注入与信号接线由场景挂载侧完成（本 story 不触碰启动流程）。
  未注入依赖时 `show_deploy_panel` 显式 `push_warning`（审查 H1——不静默空面板），
  并有 `test_show_without_sources_warns_and_keeps_skeleton` 锁定告警次数。
- **与 DeploymentSystem 的一致性**：预览前排位数经单测锁定等于
  `FRONT_CAPACITY_BY_MAX_DEPLOY`（{2:2, 3:2, 4:2, 5:3, 6:3}），预览与实际部署不会分叉。

---

## 4. 已知边界（非遗留阻塞）

- **角色头像为占位色块**：真实立绘走资产管线（当前 `assets/characters/portraits/` 仅 2 张），
  替换点 = `DeployCharacterCard.AVATAR_COLOR` 绘制段。
- **本地化豁免**：`确认出战`/`返回探索`/`还可以选择X人`/`已选满`/`暂无协同`/`协同`/替换弹窗文案
  中文硬编码（同 S16/S17 各 story 豁免口径），已登记技债 **DEBT-CUI-007-1**——
  项目本地化系统落地时统一抽 key。
- **interaction 边界**：点选流转已实现为 `toggle_selection()` 的接口占位（供 interaction epic
  接线），但拖拽阵位调整、数字键选择、替换决策的最终系统调用归 interaction epic（story 明文 Out of Scope）。
- **战斗名称标题数据源**：`set_battle_title()` 由上层传入（战斗配置里的敌人/地点名），
  本 story 不自建命名规则。
- **replace_dialog 为 Godot 原生 ConfirmationDialog**：九宫格皮肤化归打磨 story。

---

## 5. 签收

| 角色 | 签收 |
|------|:----:|
| ui-programmer（实现） | [x] 已签收 |
| lead-programmer（LP-CODE-REVIEW） | [ ] 待审查 |
| qa-lead（QL-TEST-COVERAGE） | [ ] 待审查 |
| qa-lead（QA-17-2 D3D12 视觉走查） | [ ] 待走查签收（§2 表 8 项） |
