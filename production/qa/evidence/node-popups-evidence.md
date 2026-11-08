# node-popups 006 节点交互弹窗证据——手动+自动化

> **日期**：2026-11-08
> **Story**：exploration-ui 006（节点交互弹窗：战斗/商店/灵泉/回复点/渡劫台）
> **类型**：Integration（含 UI 视觉通道）
> **自动化证据**：`tests/unit/exploration_ui/test_node_interaction_rules.gd`（28 例）+ `tests/integration/exploration_ui/test_node_interaction_popups.gd`（30 例）+ `tests/integration/exploration_ui/test_node_graph_screen_forwarding.gd`（14 例，含本 story 新增 7 例屏幕层装配断言）——exploration_ui 单元 81/81 + 集成 105/105 全绿
> **本文档覆盖**：AC-11 背景模糊 40% / AC-2 AC-6 弹窗视觉可辨识性 / 节点附近弹出定位三项**真实渲染走查**——判定逻辑由 BLOCKING 单元测试覆盖（见 §1）

---

## 1. AC → 证据映射

| AC | 内容 | 证据类型 | 证据位置 |
|---|------|---------|---------|
| AC-1 | 分发表路由（战斗/精英→战斗、商店→商店、灵泉→灵泉、回复点→回复、渡劫台→渡劫台） | 自动化（BLOCKING——纯函数逐行 + 宿主实路由 + 单实例） | `test_node_interaction_rules.gd::test_dispatch_routes_five_interaction_types`、`test_dispatch_routes_combat_and_elite_to_combat_popup`、`test_dispatch_table_covers_every_confirm_action`；`test_node_interaction_popups.gd::test_shop_interaction_opens_shop_popup`、`test_spring_interaction_opens_spring_popup`、`test_rest_interaction_opens_rest_popup`、`test_tribulation_interaction_opens_tribulation_popup`、`test_combat_arrival_opens_combat_popup`、`test_repeat_arrival_replaces_popup_without_duplicates` |
| AC-2 | 战斗弹窗内容（敌人名称+数量+境界+推荐战力/角色数+两按钮） | 自动化（文案四要素逐项 + 按钮原文） | `test_combat_popup_shows_enemy_name_count_realm_and_recommendation`、`test_combat_lines_include_name_count_and_realm`、`test_combat_lines_without_realm_omits_realm_line`、`test_combat_lines_show_unknown_for_nameless_roster`、`test_button_texts_follow_gdd_wireframes`、`test_recommended_deploy_*`（3 例） |
| AC-3 | 「先等等」/「离开」→ 关闭 + 停留该节点（AP 不回退、无场景切换） | 自动化（取消真信号路径 + 零转场 + ESC 等效） | `test_cancel_closes_popup_without_scene_change`、`test_escape_closes_popup`、`test_cancel_button_label_matches_wireframe` |
| AC-4 | 灵泉「使用灵泉」→ 行动力回复全部（系统 API） | 自动化（系统 API 调用一次 + 回复量取系统返回值 + API 缺失退化） | `test_spring_confirm_calls_system_api_and_reports_restored`、`test_spring_without_system_api_reports_zero_and_warns`、`test_spring_restore_all_equals_missing_points` |
| AC-5 | 回复点「休息」→ 全队回复 50% 已损失 HP（系统 API；文案与公式 7 一致） | 自动化（API 调用 + 治疗量透传 + 文案精确匹配） | `test_rest_confirm_calls_system_api_and_reports_healed`、`test_rest_popup_body_states_fifty_percent_lost_hp`、`test_rest_body_matches_formula_wording`、`test_rest_heal_amount_is_half_lost_hp_floored` |
| AC-6 | 渡劫台（修为已满）：80% 警示朱砂红（渡劫专属）+「挑战渡劫/再等等」→ TRIBULATION 转场 | 自动化（80%/50% 分离断言 + #B3424A + 转场枚举）+ 视觉走查 | `test_tribulation_popup_warns_eighty_percent_in_cinnabar`、`test_tribulation_warning_states_eighty_percent`、`test_tribulation_warning_is_cinnabar_red`、`test_tribulation_confirm_requests_tribulation_transition` + §2 表 2 |
| AC-7 | 渡劫台修为未满 → 无弹窗（节点层显示不可触发） | 自动化（快照 tribulation_ready=false 早退） | `test_tribulation_unready_shows_no_popup`、`test_tribulation_ready_defaults_true_when_field_absent` |
| AC-8 | 商店「进入商店」→ UI overlay（节点图冻结、非场景切换） | 自动化（`shop_opened` 载荷透传 + 零转场） | `test_shop_confirm_opens_overlay_without_scene_change` |
| AC-9 | 事件节点无探索 UI 弹窗（EventSystem 接管，防双面板回归） | 自动化（分发表排除 + 宿主忽略 + **屏幕层不连 event_node_reached**） | `test_event_node_produces_no_ui_popup`、`test_dispatch_excludes_event_and_teleport_nodes`、`test_node_graph_screen_forwarding.gd::test_event_node_arrival_does_not_open_popup` |
| AC-10 | 传送节点无交互（B5 裁决） | 自动化 | `test_teleport_node_produces_no_ui_popup`、`test_dispatch_excludes_event_and_teleport_nodes` |
| AC-11 | 弹窗期间背景可见但不可操作 + 模糊 40%（帧率 ≥60fps A8 抽查） | 自动化（冻结/解冻/重复到达幂等/遮罩强度/键盘路径）+ 视觉与性能走查 | `test_popup_freezes_viewport_and_renderer_input`、`test_closing_popup_restores_input_state`、`test_repeat_arrival_then_close_still_unfreezes`、`test_popup_shows_blur_mask_at_forty_percent`、`test_popup_is_positioned_near_node_not_centered_fullscreen`、`test_double_close_emits_closed_once`、`test_reopening_after_close_restores_open_state`、`test_node_graph_screen_forwarding.gd::test_popup_open_freezes_keyboard_path_and_close_restores` + §2 表 1/3/4 |

---

## 1b. 自动化计数

| 套件 | 文件 | 例数 |
|---|---|---:|
| 单元（Logic 内核） | `tests/unit/exploration_ui/test_node_interaction_rules.gd` | 28 |
| 集成（宿主路由与确认派发） | `tests/integration/exploration_ui/test_node_interaction_popups.gd` | 30 |
| 集成（屏幕层装配与转发，本 story 新增 7 例） | `tests/integration/exploration_ui/test_node_graph_screen_forwarding.gd` | 14（新增 7） |

- exploration_ui 单元 **81/81**（5 脚本）、集成 **105/105**（4 脚本）。
- 全量基线：单元 2386 tests / 2385 passing / 1 pending（存量 `test_migration_chain`）/ 1 orphan（存量）；集成 **956/956 passing**（59 脚本）。零回归。

**取数链路的契约边界（重要）**：`ExplorationSystem` 目前**尚未实现** `use_action_spring()` / `rest_at_node()`
（story Out of Scope：效果执行归探索系统域）。宿主以 `has_method` 条件调用，缺失时 `push_warning`
并回传 0，`test_spring_without_system_api_reports_zero_and_warns` 锁定该退化路径（用裸 `Node`
替换接缝，不覆盖 `has_method`）。API 落地后无需改 UI——信号载荷始终是系统返回值（UI 零数值计算）。

---

## 2. 视觉通道手动走查（D3D12 真实渲染路径）

**Setup**：Godot 4.6.3（Windows D3D12 默认渲染器）F6 运行 `tests/manual/node_popup_debug.tscn`；
按键 **1** 战斗 / **2** 商店 / **3** 灵泉 / **4** 回复点 / **5** 渡劫台 / **6** 精英战斗 /
**0** 关闭 / **T** 切换渡劫台修为圆满 / **M** 切换 reduce_motion。
（另可在真实节点图场景复测：stub 快照 入口 0 → 101 → 201 商店、102 → 203 灵泉、
303 回复点、401 渡劫台——stub 中 401 的 `tribulation_ready = false`，需改为 `true` 才能看到弹窗。）

| # | 验证项 | 预期 | 结果 |
|---|--------|------|:----:|
| 1 | 弹窗定位与遮挡 | 弹窗出现在节点**附近**（右下偏移 40/24），不覆盖全屏；靠近屏幕右/下边缘时向左/上翻转且保留 16px 边距 | [ ] 待 QA 走查 |
| 2 | 五类弹窗文案与按钮 | 战斗：「敌人名 ×N / 境界 / 推荐上场角色」+「进入战斗｜先等等」；商店：「离开」；灵泉：「使用灵泉」；回复点：「全队回复50%已损失HP」+「休息」；渡劫台：「挑战渡劫｜再等等」 | [ ] 待 QA 走查 |
| 3 | 渡劫 80% 警示 | 警示行朱砂红 `#B3424A` 可辨识，首行含 80%、次行为对照片尾「——远严于普通战败（50%）」，与 Boss 50% 不混用 | [ ] 待 QA 走查 |
| 4 | 背景模糊 40% + 冻结 | 弹窗期间背景节点图可见但有 40% 模糊 + 25% 压暗；滚轮缩放/拖拽平移/点击节点全部无效；关闭后模糊消失、交互恢复 | [ ] 待 QA 走查 |
| 5 | 开合动画 | 打开 0.2s 放大淡入（0.9→1.0）、关闭 0.15s 缩小淡出，无撕裂/残影；连开两个弹窗时不叠加两个实例 | [ ] 待 QA 走查 |
| 6 | reduce_motion 开启 | 关闭动画后弹窗直跳终态（无缩放淡入淡出），遮罩即时显隐 | [ ] 待 QA 走查 |
| 7 | 键盘路径冻结 | 弹窗期间方向键不再移动焦点环；ESC 关闭弹窗；关闭后方向键恢复跳转 | [ ] 待 QA 走查 |
| 8 | **A8 性能抽查** | 模糊开启时帧率 ≥60fps（16.6ms 帧预算），观察 10s 无掉帧 | [ ] 待 QA 走查 |

**说明**：本轮自动化已把可量化部分（弹窗种类→文案三元组、80%/50% 分离、`#B3424A`、
模糊强度 0.4、冻结与恢复、定位偏移与翻转、单实例）固化为回归测试；§2 仅验证
**真实渲染下的视觉可辨识性、动画手感与 D3D12 帧率**，不可自动化。

**A8 不达标的处置**：按 story Implementation Notes 明文——「不达标记录并上报（不在本 story 内
优化到 010）」。若走查第 8 项低于 60fps，记录实测帧率并转 story 010（全流程终验）优化。

---

## 3. 实现说明

- **Logic 内核集中**（ADR-0031 Logic 内核模式 / ADR-0032 纯函数内核先例）：
  `src/ui/exploration/node_interaction_rules.gd` —— `popup_kind_for` / `confirm_action_for` /
  `combat_lines` / `recommended_deploy` / `tribulation_warning_lines` / `spring_restore_all` /
  `rest_heal_amount` / `popup_position` 全部为无状态静态纯函数，弹窗与宿主只消费不复制。
  分发表 `DISPATCH_TABLE` 是唯一来源（GDD §4c 逐行），单测
  `test_dispatch_table_covers_every_confirm_action` 保证新增 kind 不会缺确认动作。
- **职责拆分**（coding-standards 单文件 ≤300 行）：`node_interaction_rules.gd` 纯函数 /
  `node_interaction_popup.gd` 弹窗单体（渲染 + 开合动画）/ `node_popup_blur_mask.gd`
  背景模糊遮罩（BackBufferCopy + 着色器）/ `node_interaction_popup_host.gd`
  宿主（路由 + 冻结 + 确认派发）/ `node_graph_screen.gd` 唯一装配点。
- **视觉常量单一来源**：模糊强度 40% 与压暗 25% 只定义在
  `NodeInteractionRules.BLUR_AMOUNT` / `DIM_ALPHA`，遮罩组件与测试都读同一常量
  （不在两处各写一个 0.4）。
- **零状态所有权**（ADR-0031 §2）：宿主不缓存节点/AP/HP；弹窗每次按信号载荷重建文案；
  确认只发信号或调系统 API（回复量/治疗量取系统返回值），不写 GSM。
- **零轮询**（ADR-0031 §3）：新增三文件均无 `_process()`——输入/信号驱动，开合与遮罩
  为 Tween（纯视觉变换，豁免）。
- **场景切换唯一入口**（control-manifest Required）：战斗与渡劫经
  `scene_manager.request_scene_change(EXPLORATION, to, type)`，全库无 `change_scene_to_file`。
- **背景模糊复用既有着色器**：`src/ui/hud/pause_blur.gdshader`（暂停菜单同源），
  封装在 `node_popup_blur_mask.gd` 组件内（`BackBufferCopy(copy_mode = COPY_MODE_VIEWPORT)`
  + `ColorRect(ShaderMaterial)`，强度 40%）。不新写 shader（事实单一归属）。
- **冻结/解冻对称**：`_freeze_graph()` 保存原 `viewport.input_frozen` 与
  `renderer.mouse_filter`，`_unfreeze_graph()` 恢复原值（不硬编码 `MOUSE_FILTER_STOP`）。
- **键盘路径冻结在屏幕层**：`popup_opened → interactor.set_process_unhandled_key_input(false)`、
  `popup_closed → true`——屏幕层是唯一装配点（S17-005 审查 H3 原则延续）。
- **事件节点显式排除**（AC-9）：`DISPATCH_TABLE` 不含 `event`，屏幕层
  **不连接** `event_node_reached`（不是"连上再忽略"，而是根本不连）——防双面板的唯一可靠形态。
  三条独立断言锁定（纯函数 / 宿主 / 屏幕层）。
- **渡劫判定数据源**：屏幕层 `_on_map_generated` 下发渲染快照 → 宿主 `apply_snapshot()`；
  宿主不读屏幕私有成员。字段缺失时宽松视为圆满（`Rules.tribulation_ready`），防误拦。
  **`node_moved` 后同样重下发**——战斗弹窗以 `_snapshot.current_node` 锚定坐标，
  不下发会锚在出发节点（本 story 自查发现并补齐，`test_node_moved_pushes_updated_snapshot_to_popup_host` 锁定）。

---

## 4. 已知边界（非遗留阻塞）

- **商店 overlay 内容未实现**：本 story 只提供 overlay 容器与冻结语义（B9 裁决）；
  商店商品列表/购买流归商店 UI epic。`shop_opened(node_id, inventory)` 已带库存载荷。
- **灵泉/回复效果执行未实现**：`ExplorationSystem` 缺 `use_action_spring()` /
  `rest_at_node()`，宿主 `push_warning` + 回传 0（story Out of Scope）。**延后义务**：
  Feature 层补齐两 API 后，宿主无需改动即可生效；届时补一条端到端集成断言替换现有退化断言。
- **AC-4 的行动力指示器逐格亮起**（0.5s）归 004 响应路径，本 story 只发 `spring_used`
  信号；视觉联动待 004 ↔ 006 接线（当前 004 指示器由 GSM 变化驱动，未经本信号）。
- **本地化豁免**：弹窗全部中文文案（标题/按钮/正文/警示）硬编码于
  `node_interaction_rules.gd`（同 S16/S17 各 story 豁免口径），待 localization epic 统一抽 key。
- **`popup_position` 为几何近似**：`POPUP_SIZE = 360×220` 固定尺寸不随正文行数自适应；
  正文超过 3 行时文案可能截断（当前五类弹窗最大 3 行，无实例触发）。
- **Boss 战前确认弹窗**（`boss_node_reached`）不在本 story——归 story 007（独立规格，50% 文案）。

---

## 5. 签收

| 角色 | 签收 |
|------|:----:|
| ui-programmer（实现） | [x] 已签收 |
| lead-programmer（LP-CODE-REVIEW） | [x] 见 story Completion Notes |
| qa-lead（QL-TEST-COVERAGE） | [x] 见 story Completion Notes |
| qa-lead（S17 视觉走查批次 —— 见 `qa-signoff-sprint-17-2026-11-08.md` P0/P1 清单 + A8 帧率抽查） | [ ] 待走查签收（§2 表 8 项） |
