extends Node
## HudMockGSM —— hud 信号接线测试专用 mock GSM（TD-007，S15-1）。
##
## 契约对齐 [code]src/foundation/game_state_manager.gd[/code] 的 player 域 +
## [code]realm_changed[/code] / [code]cultivation_changed[/code] /
## [code]batch_updated[/code] 三信号（RealmBar G6 裁决订阅集）。
##
## 与 [code]tests/integration/scene_manager/mocks/mock_gsm.gd[/code] 的分工：
## 那是 SceneManager 用的 session 域最小替身；本 mock 补 hud 组件消费的
## player 域 + 三信号——realm_bar.setup(gsm, realm_table) 依赖注入接口
## 已备好（story 002 裁决），测试传本 mock 即可脱离真实 Autoload 隔离驱动。

## 境界+修为数据域——realm_bar._refresh 每周期从这里读取（零状态所有权：
## UI 不缓存，mock 同步提供最新值）。
var player: Dictionary = {
	"realm": 1,
	"cultivation": 0,
	"max_cultivation": 100,
	"is_fallen": false,
}

## G6 裁决订阅集三信号——realm_bar._connect_gsm_signals 经
## has_signal/get/connect 动态订阅（mock 用原生 signal 声明即可满足契约）。
signal realm_changed(old_realm: int, new_realm: int)
signal cultivation_changed(delta: int, current: int, max_val: int)
signal batch_updated(changes: Dictionary)
