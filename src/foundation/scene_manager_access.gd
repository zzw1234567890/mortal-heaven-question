## SceneManager 依赖与访问面（继承链第 2 段）——[b]依赖注入 + 子模块惰性获取 + 音频门面[/b]。
##
## [b]本层职责[/b]：把「外部世界怎么接进来」收在一处。[br]
##   · 依赖注入——[method set_dependencies] 与三个取用器（[method _get_gsm] /
##     [method _get_im] / [method _get_save_load]：注入优先、否则回退 Autoload 单例）；[br]
##   · 子模块惰性获取——[method _get_transition]（异步管线实现体
##     [code]scene_transition.gd[/code]）与 [method _get_persistent_layer]
##     （跨场景持久层，ADR-0031 §1.2）；[br]
##   · 音频门面——[method _get_audio_manager] 惰性创建、[method get_audio_manager]
##     供各系统消费（零新增 Autoload）、[method set_audio_manager] 测试注入口；[br]
##   · 持久节点注册出口——[method register_persistent]（HUD / 音频节点池经此挂载）。
## [b]不管什么[/b]：不发起转场（[method request_scene_change] 在下一段）、不装配
## （[method _ready] 在链尾）、不做注册路径自检。
##
## [b]为什么本层排在链首之后、管线之前[/b]：管线段的 [method request_scene_change] 与链尾的
## [method _ready] 都要取这些依赖与子模块，而被调方必须在本段或祖先段——
## 「谁调谁靠后」定死链序（探针 [code]tools/probe_sm_order.gd[/code] 实测）。
##
## [b]继承链[/b]（各段守 300 行内，成员名与访问路径逐字不变）：[br]
## [code]  scene_manager_contract.gd [/code] ← 声明面：2 枚举 / 2 信号 / 2 常量表 / 11 实例字段[br]
## [code]  scene_manager_access.gd   [/code] ← 依赖与访问面：注入 / 惰性获取 / 音频门面 / 持久层注册[br]
## [code]  scene_manager_pipeline.gd [/code] ← 转场管线面：请求入口 / 信号发射包装 / 异步管线[br]
## [code]  scene_manager.gd          [/code] ← 本层：装配与出口面（_ready / 查询 / 自检 / 静态工具）[br]
##
## 来源: ADR-0005 §5（依赖注入为单元测试接缝）、ADR-0031 §1.2、audio Story 001。

extends "res://src/foundation/scene_manager_contract.gd"

## === 依赖注入方法 ==============================================================

## 设置依赖引用。不传参数则使用 Autoload 默认值。
func set_dependencies(gsm: Node = null, im: Node = null, save_load: Node = null) -> void:
	if gsm != null:
		_gsm = gsm
	if im != null:
		_im = im
	if save_load != null:
		_save_load = save_load

## 获取当前使用的 GSM 引用——注入对象优先，否则回退到 Autoload。
func _get_gsm() -> Node:
	if _gsm != null:
		return _gsm
	return GameStateManager

## 获取当前使用的 InputManager 引用。
func _get_im() -> Node:
	if _im != null:
		return _im
	return InputManager

## 获取当前使用的 SaveLoad 引用。
func _get_save_load() -> Node:
	if _save_load != null:
		return _save_load
	return SaveLoadSystem


## 惰性获取转换管线子模块（Sprint 10 Story 7 拆分）。
func _get_transition() -> RefCounted:
	if _transition == null:
		_transition = load("res://src/foundation/scene_transition.gd").new(self)
	return _transition


## 惰性获取持久层子模块（hud Story 001 / GAP-2 裁决）。
func _get_persistent_layer() -> ScenePersistentLayer:
	if _persistent_layer == null:
		_persistent_layer = ScenePersistentLayer.new(self)
	return _persistent_layer


## 惰性获取 AudioManager 实例（audio Story 001）。[br]
## 优先消费外部已设置实例（测试经 [method set_audio_manager] 注入 mock）；
## 否则新建 AudioManager 并将节点池挂入 PersistentLayer。[br]
## [br][param scene_manager]: 经 [code]preload[/code] 常量静态解析——
## 路径错误在解析期暴露（优于运行期 [code]load()[/code] 的 null 风险）。
const _AUDIO_MANAGER_SCRIPT: GDScript = \
		preload("res://src/ui/audio/audio_manager.gd")


func _get_audio_manager() -> AudioManager:
	if _audio_manager == null:
		_audio_manager = _AUDIO_MANAGER_SCRIPT.new(self)
	return _audio_manager


## 获取 AudioManager 公共入口（各系统经此消费音频 API——零新增 Autoload）。
func get_audio_manager() -> AudioManager:
	return _get_audio_manager()


## 注入 AudioManager 实例（测试专用——mock 替代真实创建）。
func set_audio_manager(am: AudioManager) -> void:
	_audio_manager = am


## === 公共 API ==================================================================

## 注册跨场景持久节点——挂入 PersistentLayer（ADR-0031 §1.2 契约）。[br]
## HUD CanvasLayer、audio 节点池等需要跨场景存活的节点均经此 API 挂载。[br]
## [br][b]防呆规则[/b]：重复注册（节点已在 PersistentLayer 下）push_warning 并忽略；
## null 节点或已有其他父节点的节点 push_error 并忽略。
func register_persistent(node: Node) -> void:
	_get_persistent_layer().register(node)
