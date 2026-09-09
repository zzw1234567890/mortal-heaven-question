# Tech Debt Register

> 技术债务登记册——建议性偏差与遗留项追踪。按登记日期排序，修复后划线或移除。

- **2026-09-09**（hud Story 001）：真实转场存活测试以 LOADING 场景为目标（两段式退化路径——loading_screen 加载自身）；场景 .tscn 资产齐备后（audio 001 或后续 UI story 复用 register_persistent 时）补一条非退化真实转场测试 — 从 production/epics/hud/story-001-hud-canvas-mount-and-visibility.md 追踪
- **2026-09-09**（hud Story 001）：hud.gd `has_method(&"get_current_scene_id")` 守卫失败时静默跳过初始可见性同步（无日志）——mock 不实现该方法时静默退回 Control 默认可见；可选补 push_warning — 从 production/epics/hud/story-001-hud-canvas-mount-and-visibility.md 追踪
- **2026-09-09**（hud Story 001，QL 关卡 N-1）：`test_mid_transition_keeps_previous_state` 仅验证可见方向的单向转场中途保持——Story 007（过渡提示，订阅同一 pre_transition）落地时补 COMBAT 中途反向对照 — 从 production/epics/hud/story-001-hud-canvas-mount-and-visibility.md 追踪
- **2026-09-09**（hud Story 001，QL 关卡 N-2）：HUD 初始可见性同步仅测 MAIN_MENU 启动分支——「启动即游戏场景」（存档直入 EXPLORATION）分支未测；Story 002 接入真实启动流时补 — 从 production/epics/hud/story-001-hud-canvas-mount-and-visibility.md 追踪
- **2026-09-09**（hud Story 001，预存技债确认）：`scene_manager.gd:277/286` `_emit_pre_transition`/`_emit_post_transition` 直引全局 GameStateManager，绕过自身 DI 体系——pre/post_transition 发射无法用纯 mock 隔离（Sprint 10 遗留，非 hud 001 引入；信号链深度追踪走真实 GSM） — 从 production/epics/hud/story-001-hud-canvas-mount-and-visibility.md 追踪
