extends Node
## MockBottombarSignals —— combat-ui-layout Story 005 底部条信号接线测试 mock。
##
## [b]契约对齐[/b]：[code]src/feature/combat_system.gd[/code] 的
## [code]phase_changed[/code] + [code]src/core/cost_system.gd[/code] 的
## [code]cost_changed(current, max_show, total_max)[/code]。参照
## [code]mock_topbar_signals.gd[/code] 先例——自建 stub Node 带原生 signal
## 声明，不需要完整 Autoload。
signal phase_changed(old_phase: int, new_phase: int, turn: int)
signal cost_changed(current: int, max_show: int, total_max: int)
