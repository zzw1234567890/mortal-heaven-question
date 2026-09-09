extends Node
## Mock GSM——SceneManager 依赖注入的最小 GSM 替身（共享 fixture）。
##
## 契约对齐 [code]src/foundation/godot_state_manager.gd[/code] 的
## session Dictionary + [code]set_session_scene(id, path)[/code] 方法
## （SceneManager Phase 4 写入路径）。

## 会话域——current_scene 路径与 scene_id（Phase 4 写入点）。
var session: Dictionary = {"current_scene": "", "scene_id": 0}


## SceneManager._execute_post_load 写入当前场景标记。
func set_session_scene(id: int, path: String) -> void:
	session.scene_id = id
	session.current_scene = path
