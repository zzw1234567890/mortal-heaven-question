extends "res://src/ui/shared/battle_record_scene.gd"
## DefeatScreen —— 战败/撤退占位场景（Sprint 18 结算回流接缝）。[br]
## [br][b]归属[/b]：[method CombatSystem._request_scene_change] 在 DEFEAT / RETREAT
## 两个结局下都转到这里——战败方向同样要能读回本场战绩（否则「我方还剩多少 HP」
## 只在胜利时看得到，口径不对称）。[br]
## [br][b]本文件只做一件事[/b]：指定本场景归属（[constant SCENE_ID] 与 .tscn 的
## [code]screen_id[/code] 对齐）。取数、降级与打印口径继承 [code]BattleRecordScene[/code]，
## 占位契约（标题 / 状态 / 返回按钮）继承 [code]PlaceholderScene[/code]。[br]
## [br][b]出口与胜利屏不同[/b]（2026-11-17）：本屏「返回」是[b]回主菜单[/b]
## （本局已结束，不该继续探索——design/ux/pause-menu.md §Events Fired 战斗投降链、
## design/gdd/audio-system.md §9 把「战败→任意非主菜单状态」列为 N/A 转换）。
## 判据收在 [code]battle_record_exit.gd[/code]，本文件不覆写任何出口逻辑。[br]
## [br]来源: production/session-state/active.md（Sprint 18 结算回流）、ADR-0031。

## 本场景的 SceneID（[code]SceneManager.SceneID.DEFEAT_SCREEN[/code]——与 .tscn 同值）。
const SCENE_ID: int = 9
