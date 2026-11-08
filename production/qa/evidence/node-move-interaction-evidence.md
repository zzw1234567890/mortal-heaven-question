# node-move-interaction 005 节点移动交互证据——手动+自动化

> **日期**：2026-11-07
> **Story**：exploration-ui 005（节点移动交互流与教程覆盖）
> **类型**：Integration（含 UI 视觉通道）
> **自动化证据**：`tests/integration/exploration_ui/test_node_move_interaction.gd`（43 例）+ `test_node_graph_screen_forwarding.gd`（7 例）+ `test_node_graph_render.gd`（18 例，S16-3 回归）+ `tests/unit/exploration_ui/test_node_keyboard_navigator.gd`（7 例）+ `test_node_move_overlays.gd`（5 例）——exploration_ui 套件 68/68 集成 + 53/53 单元全绿；全量 3166 tests / 3165 passing / 1 pending（存量 `test_migration_chain`）/ 3 orphans（存量），零回归
> **本文档覆盖**：AC-5 悬停 110% / AC-6 已访问翻转 / AC-1 移动动画与迷雾揭示三条**视觉通道**的真实渲染走查——其余 AC 由自动化断言覆盖（见 §1 映射表）

---

## 1. AC → 证据映射

| AC | 内容 | 证据类型 | 证据位置 |
|---|------|---------|---------|
| AC-1 | 点击可达节点 → move_to_node → 标记移动 ≤0.5s/节点 → AP 扣减 → 迷雾揭示 | 自动化（委托/AP/标记终位/时长上限）+ 视觉（迷雾消散） | `test_click_reachable_node_move_called_once`、`test_node_moved_drives_marker_and_ap_consistent`、`test_move_animation_duration_within_ux_limit`、`test_node_graph_render.gd::test_node_moved_reveals_adjacent_layer` |
| AC-2 | 到达需确认节点 → 移动完成后触发到达通知（弹窗归 006/007） | 自动化（三路到达分支 + 不预弹 + 延迟转发 + 屏幕层公开契约） | `test_combat_arrival_notification_exactly_once_not_pre_fired`、`test_arrival_deferred_until_move_animation_finishes`、`test_boss_arrival_forwarded_once`、`test_node_interaction_arrival_forwarded_once` + `test_node_graph_screen_forwarding.gd` 三条转发用例 |
| AC-3 | 点击不可达 → 抖动 + toast（原因由系统返回驱动） | 自动化（文案映射 / 失败不变量 / 屏幕层 toast 转发） | `test_ap_insufficient_feedback_toast_and_shake`、`test_unreachable_feedback_maps_reason_to_toast`、`test_failure_keeps_ap_and_marker_position` + `test_node_graph_screen_forwarding.gd::test_screen_forwards_move_feedback`（**toast 渲染本体待 006 接 HUD 通知区域——见 §4 延后义务**） |
| AC-4 | 点击已访问 → 无反应，悬停显示已探索标记 | 自动化（静默）+ 静态标记（S16-3） | `test_visited_node_click_silent_no_feedback` |
| AC-5 | 悬停可达 → 放大 110% + tooltip 浮出（0.3s 内） | 自动化（倍率精确值）+ **视觉走查** | `test_hover_visited_node_no_scale_vs_reachable_scale`、`test_hover_unreachable_node_no_scale`、`test_hit_test_node_grows_with_hover_scale` + §2 表 |
| AC-6 | 已访问翻转：边框变绿 + ✓ 浮现（0.2s，到达动画后） | 自动化（脉冲生命周期/时长/时序）+ **视觉走查** | `test_visited_flip_pulse_after_move_animation`、`test_visited_flip_ordering_after_arrival_notification` + §2 表 |
| AC-7 | 连续点击防抖（缓冲队列语义锁定） | 自动化 | `test_click_during_animation_buffered_and_executed_after`、`test_buffered_duplicate_target_not_queued_twice`、`test_buffered_move_preserves_device_type` |
| AC-8 | 教程覆盖：首次 3 步 / 任意点击跳过 / 二次进入不显示 | 自动化（含真实输入分派） | `test_tutorial_first_entry_shows_three_steps`、`test_tutorial_click_gui_input_skips`、`test_tutorial_enter_key_gui_input_skips`、`test_tutorial_release_event_does_not_skip`、`test_tutorial_completed_payload_distinguished_from_step_one`、`test_tutorial_second_entry_not_shown`、`test_tutorial_uses_event_system_not_gsm_direct` |
| AC-9 | 方向键空间跳转 + Enter 确认移动 | 自动化（纯函数 7 例 + 集成 + 输入接线 + 焦点转发） | `test_keyboard_navigate_and_confirm_moves` + `test_node_keyboard_navigator.gd` 全部 + `test_node_graph_screen_forwarding.gd::test_screen_forwards_keyboard_focus_to_renderer` |

---

## 2. 视觉通道手动走查（D3D12 真实渲染路径）

**Setup**：Godot 4.6.3 编辑器 / 导出构建（Windows D3D12 默认渲染器），进入探索节点图（stub 快照：入口 0、层1 节点 101/102、Boss 500），鼠标+键盘。

| # | 验证项 | 预期 | 结果 |
|---|--------|------|:----:|
| 1 | 悬停可达节点 101 | 图标、边框、外发光同步放大到 110%，无撕裂/错位；标签跟随图标下沿 | [ ] 待 QA 走查 |
| 2 | 悬停 tooltip 浮出 | 0.3s 内出现、内容为节点名+描述；移出后立即消失（无残留） | [ ] 待 QA 走查 |
| 3 | 悬停已访问节点 0 | **不放大**，显示已探索标记（✓） | [ ] 待 QA 走查 |
| 4 | 移动动画（非 reduce_motion） | 玩家标记沿 0→101 平滑移动约 0.4s，落点精确居中节点 | [ ] 待 QA 走查 |
| 5 | 到达后已访问翻转 | 翻转脉冲 0.2s：绿环浮现后淡出，落在到达节点；同时边框转绿 + ✓ 浮现 | [ ] 待 QA 走查 |
| 6 | 迷雾揭示 | 移动完成后相邻层节点从迷雾中显现（0.3s 消散），未邻接节点保持迷雾 | [ ] 待 QA 走查 |
| 7 | 不可达点击反馈 | 节点左右抖动约 0.3s + toast「行动力不足」/「路径不可达」 | [ ] 待 QA 走查 |
| 8 | 键盘焦点环 | 方向键跳转后松石青 2px 外环出现；鼠标悬停同一节点时焦点环让位（悬停优先） | [ ] 待 QA 走查 |
| 9 | 教程覆盖 | 首次进入 3 步提示可读、任意点击/Enter 跳过；二次进入不出现 | [ ] 待 QA 走查 |
| 10 | reduce_motion 开启 | 关闭动画后移动直跳终位、抖动与翻转脉冲跳过 | [ ] 待 QA 走查 |

**说明**：本轮交付的自动化断言已把上述项中可量化的部分（倍率=1.1、翻转时长=0.2s、移动时长=0.4s、提示框与覆盖层几何中心、焦点环条件）固化为回归测试，第 2 节仅验证**真实渲染下的视觉可辨识性与动画手感**，不可自动化。

---

## 3. 实现说明

- **委托流**（ADR-0014 §决策 3 + control-manifest Forbidden 红线）：点击 → `ExplorationSystem.move_to_node(current, clicked)`——
  **UI 零预判**，不可达也提交，反馈完全由系统返回的 `reason` 驱动。
  `test_ui_no_precheck_unreachable_still_submitted` + `test_ap_zero_boss_exempt_node_still_submitted` 双重锁定。
- **到达通知时序**（B4「先移动后弹窗」）：系统到达信号在动画进行中即到，载荷暂存
  `_pending_arrival`，动画完成回调才统一转发——弹窗不会先于移动出现。
- **职责拆分**（coding-standards 单文件 ≤300 行软上限）：
  `NodeMoveInteractor`（交互编排 401 行，含约 115 行文档注释）/ `NodeMoveAnimator`（Tween 与
  overlay 生命周期 177 行）/ `NodeMoveOverlays`（overlay 工厂与坐标语义 67 行）/
  `NodeKeyboardNavigator`（键盘空间跳转纯函数 59 行）/ `NodeTutorialOverlay`（175 行）。
  interactor 仍超软上限 → 已登记技术债（下一次触碰时拆出到达中转 `node_arrival_relay.gd`）。
- **视觉单一来源**（ADR-0031 §4）：悬停 110% 放大与键盘焦点环均在
  `NodeGraphRenderer._draw_node_stated` 绘制；交互组件只发 `keyboard_focus_changed`，
  不再叠加第二套悬停视觉。
- **坐标语义**（审查 H1 回归锁定）：`get_node_position()` 返回节点**中心**；overlay 经
  `NodeMoveOverlays.place_at_center()` 定位为 `center - size * 0.5`，三处 overlay
  （标记/抖动环/翻转环）共用同一契约，单元测试 5 例锁定。
- **生命周期**：`setup()` 幂等（先 `teardown()`）；`teardown()` 复位
  `_animating`/`_pending_arrival`/`_click_buffer`（终审 M1——Tween 被 kill 后回调不再
  触发，不复位会让后续点击永久进缓冲）；`NOTIFICATION_PREDELETE` 兜底清理；
  `NodeMoveAnimator.clear()` 以非类型化遍历 + `is_instance_valid` 防已释放对象。
- **零轮询**（ADR-0031 §3）：全部 six 文件零 `_process()`；动画由 Tween 驱动，
  输入由 `gui_input`/`unhandled_key_input` 驱动。

---

## 4. 已知边界（非遗留阻塞）

- **AC-3 toast 渲染延后接线（LP H1 裁决）**：屏幕层已暴露公开信号
  `NodeGraphScreen.move_feedback_forwarded`（含 1 条集成断言），但 HUD 目前尚未由启动流程
  通过 `SceneManager.register_persistent()` 挂载（`Hud.request_notification` 已就绪、全库无
  调用方）。**延后义务**：HUD 挂载落地后，由 `exploration-ui 006` 或 HUD 接线 story 连接该信号
  到 `request_notification("white", toast_text)`；在此之前走查第 7 项只能验证抖动。
- **教程文案占位**：3 步文案为 UX OQ#6 占位（writer 定稿不阻塞结构）。
- **本地化豁免**：`行动力不足`/`路径不可达`/`无法移动`/教程 3 步文案中文硬编码——
  待 localization epic 统一收口（同 S16 各 story 豁免口径）。
- **tooltip 尺寸估算**：`_tooltip_rect` 按字符数 × 12px 近似，真实字体测量归字体资产管线。
- **系统 reason 为中文散文键**：`REASON_TEXTS` 以系统文案作精确匹配键，系统文案变更会
  静默退化为「无法移动」——已登记技术债（改为错误码枚举）。
- **双份渲染快照**：`NodeGraphScreen._current_snapshot` 与 `NodeMoveInteractor._snapshot`
  各自维护 visited/current_node/ap_remaining——已登记技术债（合并为单一快照下发）。
- **抖动时间曲线**：`play_shake` 的左右摆动幅度/频率曲线只由 Tween 实现，自动化断言
  锁定「ShakeOverlay 已创建、可见、圆心落在点击节点」，摆动**手感**走第 2 节第 7 项走查。

---

## 5. 签收

| 角色 | 签收 |
|------|:----:|
| ui-programmer（实现） | [x] 已签收 |
| lead-programmer（LP-CODE-REVIEW） | [x] CONCERNS → 2 项 MEDIUM 已修复/登记技债；放行 |
| qa-lead（QL-TEST-COVERAGE） | [x] GAPS → 关键缺口已补测（翻转脉冲/到达三路通道/点击输入接线/AP 不变量/时长上限）；余项登记技债 |
| qa-lead（S17 视觉走查批次 —— 见 `qa-signoff-sprint-17-2026-11-08.md` P0/P1 清单） | [ ] 待走查签收（§2 表 10 项） |
