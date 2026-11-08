# settlement-retreat 008 结算与撤退面板证据——手动+自动化

> **日期**：2026-11-08
> **Story**：combat-ui-layout 008（结算与撤退面板框架——胜利/战败/撤退双变体/渡劫战前警示）
> **类型**：UI（Logic 内核）
> **自动化证据**：`tests/unit/combat_ui/test_settlement_rules.gd`（47 例，Logic 内核）+ `tests/integration/combat_ui/test_loot_delay_clickable.gd`（48 例，0.5s 延迟可点判定 + 键盘可达 + 宿主接线集成）——combat_ui 单元 152/152 + 集成 210/210 全绿
> **本文档覆盖**：五场景（胜利 / 胜利·卡组已满 / 战败 / 普通撤退 / 渡劫撤退 / 渡劫战前警示）的**真实渲染走查**——判定逻辑由 BLOCKING 自动化覆盖（见 §1）

---

## 1. AC → 证据映射

| AC | 内容 | 证据类型 | 证据位置 |
|---|------|---------|---------|
| AC-1 | 胜利面板战利品三选一网格（卡牌/灵石/消耗品），均匀等宽 + 垂直居中 | 自动化（等宽几何逐项 + 三卡实测宽度）+ 视觉走查 | `test_settlement_rules.gd::test_loot_grid_layout_three_equal_columns`、`test_loot_grid_layout_cells_are_identical_width`、`test_loot_grid_layout_narrow_panel_clamps_to_zero`、`test_loot_grid_layout_columns_zero_treated_as_one`、`test_card_option_label_*`（3 例）、`test_lingshi_option_label_shows_amount`、`test_consumable_option_label_shows_consumable_tag`；`test_loot_delay_clickable.gd::test_victory_panel_builds_three_equal_width_cards`（渲染层三卡实测宽度相等 + 等于内核对宽 + 铺满内容宽）、`test_loot_card_uses_kernel_vertical_centering`（卡片实测高度 = 卡格高度，上下留白之和 + 块高 = 卡高）、`test_loot_card_content_top_centers_block_vertically`、`test_loot_card_content_top_clamps_for_short_cell`；键盘可达 `test_loot_cards_are_focusable`、`test_focus_chain_forms_a_ring`、`test_victory_panel_grabs_first_card_focus` + §2 表 1 |
| AC-2 | 战利品展示 0.5s 后才可点击（防误触，先看清再选择） | 自动化（BLOCKING 集成——Timer 到点翻转，非真实等待） | `test_loot_delay_clickable.gd::test_loot_options_disabled_right_after_victory_panel_opens`、`test_loot_options_enabled_after_delay_elapses`、`test_selection_before_delay_is_ignored`、`test_delay_boundary_constant_is_half_second`、`test_delay_timer_started_on_show_and_stopped_on_close`、`test_keyboard_enter_ignored_before_delay`（键盘与鼠标同口径）；边界 `test_settlement_rules.gd::test_loot_clickable_true_exactly_at_delay_boundary`、`test_loot_clickable_false_just_before_delay`、`test_loot_clickable_negative_elapsed_treated_as_zero` |
| AC-3 | 点击战利品高亮选中（非立即确认）；未选中时确认按钮灰色不可点 | 自动化（选中不确认 + 移位 + 按钮三态） | `test_loot_delay_clickable.gd::test_clicking_loot_highlights_without_confirming`、`test_selection_moves_between_options`、`test_confirm_button_enabled_only_after_selection_and_delay`、`test_confirm_emits_confirmed_and_closes`、`test_keyboard_enter_selects_focused_card_after_delay`（键盘 Enter 与鼠标同源）；`test_settlement_rules.gd::test_confirm_button_disabled_without_selection`、`test_confirm_button_disabled_before_delay_even_with_selection`、`test_confirm_button_enabled_with_selection_after_delay` |
| AC-4 | 卡组已满时卡牌选项灰显「卡组已满」不可选中（灵石/消耗品不受限） | 自动化（判定 + 文案原文 + 点击被拒 + 仅卡牌受限） | `test_settlement_rules.gd::test_is_deck_full_true_at_limit`、`test_is_deck_full_false_below_limit`、`test_is_deck_full_false_when_limit_uninitialized`、`test_card_option_greys_out_when_deck_full`、`test_lingshi_option_remains_available_when_deck_full`、`test_consumable_option_remains_available_when_deck_full`、`test_deck_full_option_is_not_clickable`、`test_deck_full_option_note_matches_gdd_wording`；`test_loot_delay_clickable.gd::test_card_option_greyed_when_deck_full`、`test_greyed_card_option_does_not_select`、`test_greyed_card_ignores_real_gui_input`、`test_host_victory_uses_deck_summary_for_card_greyout` + §2 表 2 |
| AC-5 | 战败面板损失摘要（修为 50% / 阵亡角色列表 / 绑定卡失去）+ 返回探索按钮 | 自动化（摘要三要素逐行 + 标题/按钮原文） | `test_settlement_rules.gd::test_cultivation_loss_percent_normal_is_fifty`、`test_defeat_lines_state_fifty_percent_lost`、`test_defeat_lines_without_dead_names_says_none`；`test_loot_delay_clickable.gd::test_defeat_panel_shows_loss_summary`、`test_defeat_confirm_emits_signal`、`test_defeat_panel_grabs_confirm_button_focus`（无卡片时焦点落返回按钮）、`test_host_opens_defeat_panel_on_battle_ended_defeat` + §2 表 3 |
| AC-6 | 撤退确认面板（普通变体）：保留非绑定物品 / 阵亡角色绑定卡失去 + 确认/继续战斗 | 自动化（正文逐条 + 按钮文案 + 取消不确认） | `test_settlement_rules.gd::test_normal_retreat_lines_keep_non_binding_items`、`test_retreat_title_differs_between_variants`、`test_retreat_loss_ratio_normal_is_half`；`test_loot_delay_clickable.gd::test_retreat_dialog_normal_variant`、`test_retreat_cancel_does_not_emit_confirm`、`test_retreat_confirm_emits_signal` + §2 表 4 |
| AC-7 | 撤退确认面板（渡劫变体）：红色边框 +「畏劫而退，修为散尽」+ 损失 80% 修为 + 失去渡劫机会 | 自动化（朱砂红 `#B3424A` + 80%/50% 分离 + 三行正文）+ 视觉走查 | `test_settlement_rules.gd::test_tribulation_retreat_warning_is_cinnabar_only_for_tribulation`、`test_tribulation_retreat_border_is_cinnabar`、`test_tribulation_retreat_lines_mention_eighty_percent_and_lost_chance`、`test_retreat_loss_ratio_tribulation_is_eighty_percent`、`test_retreat_loss_percent_integers`；`test_loot_delay_clickable.gd::test_retreat_dialog_tribulation_variant`、`test_host_tribulation_retreat_uses_tribulation_variant` + §2 表 5 |
| AC-8 | 渡劫战前 warning：「天劫在前，退路将断。确认进战？」+ 确认进战/返回 | 自动化（GDD 明文逐字 + 条件判定 + 已确认短路） | `test_settlement_rules.gd::test_pre_battle_body_matches_gdd_wording`、`test_pre_battle_buttons_match_gdd`、`test_pre_battle_warning_only_for_unconfirmed_tribulation`；`test_loot_delay_clickable.gd::test_tribulation_warning_shows_gdd_body`、`test_tribulation_warning_confirm_marks_confirmed`、`test_non_tribulation_shows_no_pre_battle_warning` + §2 表 6 |
| AC-9 | 撤退按钮（右上角常驻，story 001 位）启用渲染态——战斗中始终可点 | 自动化（恒真判定 + 场景树实例存在且 `disabled == false` + 点击开面板） | `test_settlement_rules.gd::test_retreat_button_always_enabled`；`test_loot_delay_clickable.gd::test_combat_root_has_always_enabled_retreat_button`、`test_combat_root_retreat_button_opens_dialog`、`test_host_opens_retreat_dialog_on_retreat_requested` |
| AC-10 | 结算面板不自动关闭（需手动确认——GDD 调优参数「无穷」） | 自动化（推进时间与延迟到点后仍 visible + 关闭幂等 + 无内建关闭计时器） | `test_loot_delay_clickable.gd::test_panel_stays_open_after_delay_and_time`、`test_delay_timeout_does_not_close_panel`、`test_panel_holds_only_the_loot_delay_timer`、`test_close_panel_is_idempotent`、`test_panels_do_not_cover_fullscreen` |

---

## 1b. 自动化计数

| 套件 | 文件 | 例数 |
|---|---|---:|
| 单元（Logic 内核） | `tests/unit/combat_ui/test_settlement_rules.gd` | 47 |
| 集成（0.5s 延迟可点 + 键盘可达 + 宿主接线 + 场景树装配） | `tests/integration/combat_ui/test_loot_delay_clickable.gd` | 48 |

- combat_ui 单元 **152/152**（11 脚本，427 asserts）、集成 **210/210**（14 脚本，566 asserts）。
- 全量基线：单元 **2433 tests / 2432 passing / 1 pending**（存量 `test_migration_chain`）/ 1 orphan（存量）；集成 **1004/1004 passing**（60 脚本，3847 asserts）。较 S17-3 基线（单元 2430 / 集成 956）集成净增 48 例，零回归。

**判定内核归属（重要）**：所有可量化判定（0.5s 边界、等宽网格几何、卡组满态、50%/80% 损失比、
朱砂红常量、GDD 文案逐字）集中在 `src/ui/combat/shared/settlement_rules.gd` 与
`retreat_rules.gd` 两个无状态纯函数内核；面板类只消费不复制，测试直接打内核，不经 UI。
`test_retreat_loss_ratio_*` 与 `test_cultivation_loss_percent_*` 分离断言 50% / 80%，
防止渡劫与普通战败两套数值互相污染（GDD §10 边界情况）。

---

## 2. 视觉通道手动走查（D3D12 真实渲染路径）

**Setup**：Godot 4.6.3（Windows D3D12 默认渲染器）F6 运行 `tests/manual/settlement_panel_debug.tscn`；
按键 **1** 胜利 / **2** 胜利·卡组已满 / **3** 战败 / **4** 撤退(普通) / **5** 撤退(渡劫) /
**6** 渡劫战前警示 / **0** 关闭全部 / **T** 切换渡劫标识 / **M** 切换 reduce_motion。
（另可在真实战斗场景复测：`CombatRoot.tscn` 右上角「撤退」按钮 → 普通撤退面板；
`battle_ended(VICTORY)` 信号 → 胜利面板。）

| # | 验证项 | 预期 | 结果 |
|---|--------|------|:----:|
| 1 | 胜利面板三选一布局 | 720×520 居中面板，三张等宽卡（内容宽 656px 三分 → 各 208px）横向排布、垂直居中，卡内含卡牌正面框 + 标题 + 副标题，无溢出/截断 | [ ] 待 QA 走查 |
| 2 | 0.5s 延迟体感 + 选中高亮 | 面板刚弹出时提示「战利品展示中…」且确认按钮灰；约 0.5s 后提示变「点击战利品选中，再点确认生效」；点击某张卡出现金色 `#E8C06A` 高亮边框，再次点另一张则高亮迁移（不同时两张亮） | [ ] 待 QA 走查 |
| 3 | 卡组已满灰显 | 卡组满时卡牌选项整卡压暗 + 右下角「卡组已满」，点击无高亮反应；同屏灵石/消耗品选项仍可选中 | [ ] 待 QA 走查 |
| 4 | 战败摘要可读性 | 标题「💀 战败」，正文三行（修为损失 50% / 阵亡角色 / 绑定卡失去），左对齐不拥挤；按钮「返回探索」可见 | [ ] 待 QA 走查 |
| 5 | 普通撤退变体 | 560×300 淡墨边框，标题「⚠ 确认撤退？」，正文含「保留非绑定物品」与「阵亡角色绑定卡失去」，按钮「确认撤退｜继续战斗」，默认焦点在「继续战斗」（不误按确认） | [ ] 待 QA 走查 |
| 6 | 渡劫撤退变体 | 同尺寸但**边框朱砂红 `#B3424A` + 标题同红**，「畏劫而退，修为散尽」警示行朱砂红独立成行，正文含 80% 修为损失与「失去渡劫机会」，与普通变体一眼可辨 | [ ] 待 QA 走查 |
| 7 | 渡劫战前警示 | 520×220 朱砂红边框，「⚠ 渡劫战」标题 + 「天劫在前，退路将断。确认进战？」正文 + 「确认进战｜返回」，默认焦点在「返回」 | [ ] 待 QA 走查 |
| 8 | 开合动画 + reduce_motion | 打开 0.2s 淡入、关闭 0.15s 淡出，无残影；按 **M** 开启 reduce_motion 后直跳终态、无过渡 | [ ] 待 QA 走查 |
| 9 | 不自动关闭 | 停留在任一面板 30s 不动，面板仍可见（无自动关闭计时器） | [ ] 待 QA 走查 |
| 10 | 不覆盖全屏 | 所有面板外框远小于 1920×1080（最大 720×520），遮罩只做压暗隔离，不接管全屏点击 | [ ] 待 QA 走查 |

**说明**：本轮自动化已把可量化部分（0.5s 边界、等宽几何、四态判定、50%/80% 分离、
`#B3424A`、GDD 文案逐字、不自动关闭）固化为回归测试；§2 仅验证
**真实渲染下的视觉可辨识性、动画手感与两变体的区分度**，不可自动化。

---

## 3. 实现说明

- **双 Logic 内核**（ADR-0031 Logic 内核模式 / `DeployPanelRules` 先例）：
  `src/ui/combat/shared/settlement_rules.gd`（321 行）——`loot_clickable` / `loot_hint_text` /
  `loot_grid_layout` / `is_deck_full` / `loot_option_state` / `option_clickable` /
  `loot_option_label` / `confirm_button_enabled` / `panel_kind_for` / `cultivation_loss_percent` /
  `defeat_lines` / `panel_fits_within_viewport`；
  `src/ui/combat/shared/retreat_rules.gd`（131 行）——`retreat_cultivation_loss_ratio` /
  `retreat_title` / `retreat_warning_lines` / `retreat_lines` / `retreat_border_color` /
  `should_show_pre_battle_warning` / `retreat_button_always_enabled`。
  全部为无状态静态纯函数，面板与宿主只消费不复制。
- **职责拆分**（coding-standards 单文件 ≤300 行）：两个内核（`shared/`）、四个面板组件
  （`settlement/settlement_panel.gd` 302 行 / `retreat_dialog.gd` 200 行 /
  `tribulation_warning_dialog.gd` 178 行）+ 四个共享构件
  （`settlement_frame.gd` 外框 / `settlement_fade.gd` 开合 / `settlement_panel_view.gd` 控件树 /
  `loot_option_card.gd` 自绘卡）+ 一个宿主 `settlement_host.gd`（300 行），
  唯一装配点在 `combat_layout.gd`（370 行，超 300 软上限已登记 DEBT-CUI-008-2）。
- **视觉常量单一来源**：0.5s 延迟 `LOOT_CLICK_DELAY_SEC`、等宽网格 `LOOT_COLUMNS`/`LOOT_GAP`、
  朱砂红 `COLOR_DANGER`（`#B3424A`）、50%/80% 损失比、全部文案常量只在两个内核里定义一次，
  面板与测试读同一常量（不在两处各写一个 0.5 或 `#B3424A`）。
- **零状态所有权**（ADR-0031 §2）：面板不读 GSM、不执行撤退/战利品应用——只发
  `loot_selected` / `loot_confirmed` / `loot_skipped` / `defeat_confirmed` /
  `retreat_confirmed` / `retreat_cancelled` / `battle_confirmed` / `battle_cancelled`；
  选中态与延迟窗口是 §2.1 豁免的瞬态交互状态，确认前不写任何系统。
- **零轮询**（ADR-0031 §3）：五个新增面板/宿主编排文件均无 `_process()`——0.5s 延迟由
  一次性 `Timer` 驱动（`loot_delay_timer`，测试直接 `timeout.emit()` 推进，不真实等待），
  开合为 Tween（`SettlementFade`，纯视觉变换豁免）。
- **不自动关闭**（AC-10 / GDD 调优参数「无穷」）：`SettlementPanel` 不持有任何自动关闭计时器；
  `close_panel()` 是唯一关闭入口且幂等（`kind == KIND_NONE` 早退不重发信号）。
  延迟 `Timer` 只翻转可点态，不关闭面板。
- **渡劫 vs 普通不混用**：`retreat_warning_lines()` 普通变体返回空数组（警示行隐藏），
  渡劫变体三行且边框/标题同走 `COLOR_DANGER`；`cultivation_loss_percent` 与
  `retreat_cultivation_loss_ratio` 均对两变体分别断言，防数值串味。
- **撤退按钮恒可点**（AC-9）：`retreat_button_always_enabled()` 恒 `true`，
  `CombatLayout` 建按钮时 `disabled = not RetreatRulesScript.retreat_button_always_enabled()`
  ——判定走内核而非 UI 内写死 `false`，测试可在场景树断言 `disabled == false`。
- **响应式字号统一入口**：三面板的字号经 [code]SettlementFrame.apply_font()[/code]
  下发（内部调 [code]CombatUiFont.font_size_responsive[/code]）——遵守 story 001
  「共享纯函数唯一落地处，后续 story 不得各自内联」强制条款；面板在
  [code]NOTIFICATION_READY[/code] 时按真实视口高度下发（1280×720 档位生效）。
- **宿主换源幂等**：`SettlementHost.setup()` 记录 `_bound_combat_system`，
  重新注入另一战斗系统前先 `_disconnect_source()` 断开旧源——避免一次战斗
  结束触发两次面板；`NOTIFICATION_PREDELETE` 同样断开。
- **战场数据来自信号载荷**（不自行推算）：`SettlementHost.on_battle_ended(result, rewards)`
  用 `CombatSystem.battle_ended` 的 `rewards` 载荷生成选项与损失摘要；
  `rewards` 缺字段时才回退到 `set_defeat_context(dead_names, binding_card_count)` 的注入值，
  再缺则用 0/空。宿主**不**从 GSM 反查阵亡名单（`battle` 域无该字段，已检索确认）——
  数据源诚实标注在 `_defeat_summary()` 文档注释中。
- **键盘/手柄可达**（`.claude/rules/ui-code.md`）：`LootOptionCard` 显式 `FOCUS_ALL`
  （自绘 Control 默认不可聚焦），`SettlementPanelView.wire_focus_chain` 把「卡片 → 确认 →
  跳过」串成首尾互指的焦点环（容器不会自动推导自绘控件的邻接，否则键盘玩家被困在
  第一个可聚焦控件）；打开时 `grab_initial_focus` 落到首卡（战败面板落到「返回探索」）；
  Enter/Space 走 `_gui_input` 焦点通道，与鼠标**同源同口径**（都受 0.5s 延迟与灰显态约束）。
- **内核口径真被消费**（不是「写了没接线」）：`Rules.loot_clickable(elapsed)` 是 0.5s
  阈值的唯一裁决处——面板累加 `_elapsed_sec` 后交给内核判定，不在面板里重写 `>= 0.5`；
  `Rules.loot_card_content_top` 承载卡片垂直居中几何，自绘组件只调用；
  `Rules.loot_grid_layout` 经 `SettlementPanelView.loot_cell_width` 转发。

---

## 4. 已知边界（非遗留阻塞）

- **确认后的持久写入未实现**（Out of Scope）：`loot_confirmed` / `retreat_confirmed` 的
  实际生效（战利品入卡组、`CombatSystem.confirm_retreat()`、`retreat_confirmed` 落 GSM）
  归 interaction epic。本 story 只发信号；面板关闭不代表系统已变更。
- **战利品选项生成只做透传**：`_victory_options()` 把 `rewards.cards` 逐项转卡牌选项、
  `rewards.lingshi > 0` 追加灵石选项；**不补足到 3 项**。若上游只给 1~2 项，
  面板按实际数量排布（网格流式，不硬凑），补足逻辑归战斗/资源系统。
- **本地化豁免**：面板全部中文文案硬编码在两个内核（同 S16/S17 各 story 豁免口径），
  待 localization epic 统一抽 key。
- **`reduce_motion` 需宿主显式下发**：`set_reduce_motion()` 未与全局无障碍设置自动联动
  （当前项目尚无全局动态偏好读取入口），接线归后续无障碍 story。
- **自绘卡尺寸固定**：`LootOptionCard` 用 `LOOT_CELL_HEIGHT = 210` 固定高度，
  正文超过 3 行时副标题可能截断（当前三类选项最大 2 行，无实例触发）。

---

## 5. 签收

| 角色 | 签收 |
|------|:----:|
| ui-programmer（实现） | [x] 已签收 |
| lead-programmer（LP-CODE-REVIEW） | [ ] 见 story Completion Notes |
| qa-lead（QL-TEST-COVERAGE） | [ ] 见 story Completion Notes |
| qa-lead（D3D12 五场景视觉走查） | [ ] 待走查签收（§2 表 10 项） |
