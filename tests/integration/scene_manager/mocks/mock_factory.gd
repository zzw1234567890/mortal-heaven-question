extends Node
## SceneManager 依赖 mock 的共享 fixture（hud Story 001 code-review 修复）。
##
## 供 [code]tests/integration/scene_manager/test_loading_screen.gd[/code] 与
## [code]tests/integration/hud/test_hud_scene_visibility.gd[/code] 共用，
## 消除两文件各自维护的字符串内嵌 mock（双份拷贝漂移风险——
## IM/SL mock 在先例中带计数器、被后起文件削平，正是无声漂移实例）。[br]
## [br]静态 .gd 文件经 [code]preload[/code] 编译期解析——引擎升级时导入期
## 即报错，优于 [code]GDScript.new() + reload()[/code] 的运行时静默失败。
##
## 风格先例：test_loading_screen.gd 的 mock 契约（session Dictionary +
## set_session_scene / push_lock+pop_lock / auto_save）。

const MockGsm := preload("mock_gsm.gd")
const MockIm := preload("mock_im.gd")
const MockSl := preload("mock_sl.gd")


## 构造 mock GSM（session Dictionary + set_session_scene 方法）。
static func build_gsm() -> Node:
	return MockGsm.new()


## 构造 mock IM（push_lock / pop_lock 带调用计数——供断言锁配对）。
static func build_im() -> Node:
	return MockIm.new()


## 构造 mock SL（auto_save 带调用计数）。
static func build_sl() -> Node:
	return MockSl.new()
