extends Node
## MockHandSignals —— combat-ui-layout Story 006 手牌区信号接线测试 mock。
##
## [b]契约对齐[/b]：[code]src/feature/combat_system.gd[/code] 的
## [code]phase_changed[/code] + 手牌信号（card_drawn / card_overflow /
## hand_changed——占位契约，CombatSystem 抽牌管线归后续 story）。参照
## [code]mock_bottombar_signals.gd[/code] 先例——自建 stub Node 带原生 signal
## 声明，不需要完整 Autoload。
signal phase_changed(old_phase: int, new_phase: int, turn: int)
signal card_drawn(card_id: int)
signal card_overflow(card_id: int)
signal hand_changed(hand: Array)
