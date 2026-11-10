extends "res://src/ui/shared/battle_record_scene.gd"
## CombatResultScreen —— 战斗结算占位场景（Sprint 18 结算回流接缝）。[br]
## [br][b]职责[/b]：把本场战绩（[code]CombatResultView[/code]）读出来并展示。
## 取数、降级与打印口径全部继承 [code]BattleRecordScene[/code]——胜利与战败两个
## 方向必须看到同一份数据，逻辑只写一份。[br]
## [br][b]本文件只做一件事[/b]：指定本场景归属（[constant SCENE_ID] 与 .tscn 的
## [code]screen_id[/code] 对齐），便于后续按场景差异化展示时在此覆写。[br]
## [br][b]占位契约不变[/b]：标题 / 状态 / 返回按钮 / 返回探索经 SceneManager 全部
## 继承自 [code]PlaceholderScene[/code]。[br]
## [br]来源: production/session-state/active.md（Sprint 18 结算回流）、ADR-0031。

## 本场景的 SceneID（[code]SceneManager.SceneID.RESULT_SCREEN[/code]——与 .tscn 同值）。
const SCENE_ID: int = 8
