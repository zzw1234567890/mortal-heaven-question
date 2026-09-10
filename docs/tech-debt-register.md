# Tech Debt Register

> 技术债务登记册——建议性偏差与遗留项追踪。按登记日期排序，修复后划线或移除。

- **2026-09-09**（hud Story 001）：真实转场存活测试以 LOADING 场景为目标（两段式退化路径——loading_screen 加载自身）；场景 .tscn 资产齐备后（audio 001 或后续 UI story 复用 register_persistent 时）补一条非退化真实转场测试 — 从 production/epics/hud/story-001-hud-canvas-mount-and-visibility.md 追踪
- **2026-09-09**（hud Story 001）：hud.gd `has_method(&"get_current_scene_id")` 守卫失败时静默跳过初始可见性同步（无日志）——mock 不实现该方法时静默退回 Control 默认可见；可选补 push_warning — 从 production/epics/hud/story-001-hud-canvas-mount-and-visibility.md 追踪
- **2026-09-09**（hud Story 001，QL 关卡 N-1）：`test_mid_transition_keeps_previous_state` 仅验证可见方向的单向转场中途保持——Story 007（过渡提示，订阅同一 pre_transition）落地时补 COMBAT 中途反向对照 — 从 production/epics/hud/story-001-hud-canvas-mount-and-visibility.md 追踪
- **2026-09-09**（hud Story 001，QL 关卡 N-2）：HUD 初始可见性同步仅测 MAIN_MENU 启动分支——「启动即游戏场景」（存档直入 EXPLORATION）分支未测；Story 002 接入真实启动流时补 — 从 production/epics/hud/story-001-hud-canvas-mount-and-visibility.md 追踪
- **2026-09-09**（hud Story 001，预存技债确认）：`scene_manager.gd:277/286` `_emit_pre_transition`/`_emit_post_transition` 直引全局 GameStateManager，绕过自身 DI 体系——pre/post_transition 发射无法用纯 mock 隔离（Sprint 10 遗留，非 hud 001 引入；信号链深度追踪走真实 GSM） — 从 production/epics/hud/story-001-hud-canvas-mount-and-visibility.md 追踪
- **2026-09-10（TD-006）**（hud Story 002，G4 裁决）：AC-5/6/7 视觉手动验证路径未建——`tests/manual/hud_debug.tscn` debug 宿主场景 + `production/qa/evidence/cultivation-bar-evidence.md` 证据文档（四档颜色截图/脉动/落难闪烁/可飞升/tooltip）+ lead-programmer 签批；冲刺 QA 签收前须补 — 从 production/epics/hud/story-002-realm-cultivation-bar.md 追踪
- **2026-09-10（TD-007）**（hud Story 002）：realm_bar.gd 信号接线逻辑零自动化覆盖——batch 过滤四路径（含 player.realm/is_fallen）、setup 重入防重复连接、G-H1 脉动合成翻转序列（化神期满→回落重显→脉动恢复）、_refresh 幂等；依赖注入接口 setup(gsm, realm_table) 已备好，需建含 player 域+三信号的 hud 专用 mock GSM — 从 production/epics/hud/story-002-realm-cultivation-bar.md 追踪
- **2026-09-10（TD-008）**（hud Story 002，ui-code.md 强制规则）：金色脉动（1.0s 循环）与落难闪烁（0.8s 循环）无 reduce-motion 退出路径——设置系统归 main-menu epic，接入后：脉动→静态金色、闪烁→静态半透明 — 从 production/epics/hud/story-002-realm-cultivation-bar.md 追踪
- **2026-09-10（TD-009）**（hud Story 002）：进度条 2px 淡墨线框（design/ux/hud.md L192 视觉规格）未实现——ColorRect 占位无 StyleBoxFlat 边框；九宫格皮肤化归打磨 story，替换点 = BarBackground/BarFill 两节点 — 从 production/epics/hud/story-002-realm-cultivation-bar.md 追踪
- **2026-09-10（TD-008 追加，hud Story 003）**：LingshiDeckBar 的 0.3s 灵石滚动 / 0.8s delta 浮动 / 0.8s 超限闪烁循环动画均无 reduce-motion 用户设置读取——`animate` 开关已就绪（三类动画全覆盖，含超限静态降级半透明红），设置系统（main-menu epic）入库后接线 — 从 production/epics/hud/story-003-lingshi-deck-counter.md 追踪
- **2026-09-10（TD-011）**（hud Story 003）：emoji 占位图标（🪙📜）依赖系统字体回退——U+1FA99（🪙）等较新码位在目标机（Windows 精简字体集/Steam Deck）可能显示豆腐块；图标图集 story 替换（替换点 = ICON_LINGSHI/ICON_DECK 常量 → TextureRect 节点） — 从 production/epics/hud/story-003-lingshi-deck-counter.md 追踪
