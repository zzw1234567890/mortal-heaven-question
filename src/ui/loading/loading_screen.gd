class_name LoadingScreen
extends Control
## 加载画面场景 —— Phase 3 场景转换期间显示的最小静态 UI。
##
## 在渲染前通过同步方法 [method set_context] 接收上下文。[br]
## 无交互元素，无 grab_focus() 调用（Godot 4.6 双焦点安全）。[br]
## [br]
## [b]D3D12 闪烁缓解[/b]：子节点 ColorRect（纯黑色）遮挡渲染器级闪烁。[br]
## 目标场景的双重保护由 [method SceneManager.create_fade_overlay] 提供。

## 内部存储 `from` SceneID —— 由 SceneManager 通过 set_context() 设置。
var _from_id: int = -1

## 内部存储 `to` SceneID —— 由 SceneManager 通过 set_context() 设置。
var _to_id: int = -1

## 内部存储 TransitionType —— 由 SceneManager 通过 set_context() 设置。
var _type: int = 0


func _ready() -> void:
	# AC-4：绝不调用 grab_focus() —— Godot 4.6 双焦点下鼠标焦点与键盘焦点不一致，
	# 可能导致视觉焦点闪烁（来源: ADR-0005 §输入管理器集成）。
	# 加载画面是纯视觉占位符——无需焦点。
	pass


## 来自 SceneManager Phase 3 的同步上下文注入。
## 在加载画面场景的 [code]await tree_changed[/code] 之后、
## [code]change_scene_to_file(target)[/code] 之前调用。[br]
## [br]
## 存储上下文供子节点潜在使用，但[b]不[/b]启动动画——
## 动画会在实际加载期间冒险导致帧丢失。[br]
## [br]
## [b]参数[/b]:[br]
##   - [param from_id]: 来源场景的 SceneID。[br]
##   - [param to_id]: 目标场景的 SceneID。[br]
##   - [param transition_type]: 来自 SceneManager.TransitionType 枚举的 TransitionType 值。
func set_context(from_id: int, to_id: int, transition_type: int) -> void:
	_from_id = from_id
	_to_id = to_id
	_type = transition_type
