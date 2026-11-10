extends "res://src/ui/shared/battle_record_scene.gd"
## DefeatScreen —— 战败/撤退占位场景（Sprint 18 结算回流接缝）。[br]
## [br][b]归属[/b]：[method CombatSystem._request_scene_change] 在 DEFEAT / RETREAT
## 两个结局下都转到这里——战败方向同样要能读回本场战绩（否则「我方还剩多少 HP」
## 只在胜利时看得到，口径不对称）。[br]
## [br][b]本文件只做一件事[/b]：指定本场景归属（[constant SCENE_ID] 与 .tscn 的
## [code]screen_id[/code] 对齐）。取数、降级与打印口径继承 [code]BattleRecordScene[/code]，
## 占位契约（标题 / 状态 / 返回按钮 / 返回探索）继承 [code]PlaceholderScene[/code]。[br]
## [br]来源: production/session-state/active.md（Sprint 18 结算回流）、ADR-0031。

## 本场景的 SceneID（[code]SceneManager.SceneID.DEFEAT_SCREEN[/code]——与 .tscn 同值）。
const SCENE_ID: int = 9
