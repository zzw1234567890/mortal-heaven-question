extends "res://src/meta/progression_system_contract.gd"
## ProgressionSystem 信号与生命周期面（继承链第 2 段）——[b]2 信号 / 装配 / 序列化 / 脏标志 / 内部辅助[/b]。
##
## [b]本层职责[/b]：把「开局装载 → 落盘 → 脏标记」这一整套会话生命周期收在一处。[br]
##   · [b]装配入口[/b]——[method _ready]：借 Godot 顺序 [code]_ready()[/code] 保证
##     （Autoload #12 晚于 #4 SaveLoadSystem），直接读档填充 6 域并发
##     [signal progression_initialized]；[br]
##   · [b]序列化会话[/b]——[method initialize] / [method serialize] / [method deserialize]
##     三个 [code]SaveLoadSystem[/code] 侧入口，全部委托惰性子模块
##     [code]progression_serializer.gd[/code]；[method _get_serializer] 是其唯一创建点
##     （Sprint 9 Story 6 拆分产物），[method _init_empty_stores] /
##     [method _load_progression_data] 两个下划线入口供测试直接驱动；[br]
##   · [b]脏标志[/b]——[method has_unsaved_changes] / [method mark_saved]，
##     SaveLoadSystem 据此决定是否写 [code]progression.dat[/code]；[br]
##   · [b]内部辅助[/b]——[method _mark_dirty_and_emit]（[b]全部域写入的唯一出口[/b]：置脏 +
##     尊重 [method batch_update_begin] 的暂缓语义）与 [method _get_save_load_system]
##     （注入优先、否则回退 Autoload #4；子模块按名字符串 [code]call[/code] 它）。[br]
## [b]为什么这两条辅助落本段而不是链尾[/b]：第 3 段与链尾的每一个域写入方法都要调
## [method _mark_dirty_and_emit]，[code]progression_serializer.gd[/code] 要调
## [method _get_save_load_system]——「被调方必须在本段或祖先段」，故它们只能靠前。
##
## 来源: ADR-0012 §关键接口（initialize / serialize / deserialize + 初始化策略）、
## production/epics/progression-system/story-005-batch-update-integration.md。

# === 信号 ====================================================================

## ProgressionSystem 初始化完成信号——_ready() 中数据填充后发射。[br]
## 特征系统在此信号后可安全查询 ProgressionSystem。
signal progression_initialized()

## 跨局数据变更信号——任何写入后发射。[br]
## SaveLoadSystem 监听此信号 → 被动持久化到 progression.dat。[br]
## [param domain] 变更的领域（achievements/talents/gallery/endings/stats/meta）。
signal progression_updated(domain: String)


# === 生命周期 =================================================================

## Autoload #12 _ready()——利用 Godot 顺序 _ready() 保证。[br]
## SaveLoadSystem (#4) 已完成 _ready()，直接调用 load_progression()。
func _ready() -> void:
	_get_serializer().init_empty_stores()
	var data: Dictionary = _get_serializer().load_progression_data()
	_get_serializer().initialize(data)
	_initialized_and_loaded = true
	progression_initialized.emit()

## 惰性获取序列化子模块。
func _get_serializer() -> RefCounted:
	if _serializer == null:
		_serializer = load("res://src/meta/progression/progression_serializer.gd").new(self)
	return _serializer


## 初始化 6 个空领域存储——委托给子模块。
func _init_empty_stores() -> void:
	_get_serializer().init_empty_stores()


## 从 SaveLoadSystem 加载 progression 数据——委托给子模块。
func _load_progression_data() -> Dictionary:
	return _get_serializer().load_progression_data()


## 从 progression.dat 的已解析 JSON 填充全部 6 个域。[br]
## 缺失字段 → 默认值填充（向前兼容）。
func initialize(data: Dictionary) -> void:
	_get_serializer().initialize(data)


# === 序列化（供 SaveLoadSystem 使用）==========================================

## 返回全量 progression 数据的 JSON 兼容 Dictionary。[br]
## 不包含 _dirty / _batch_depth / _initialized_and_loaded 内部标志。
func serialize() -> Dictionary:
	return _get_serializer().serialize()


## 从 progression.dat 的已解析 JSON 填充全部 6 个域。[br]
## 缺失字段 → 默认值填充（向前兼容）。[br]
## [b]返回[/b]: true 表示反序列化成功。
func deserialize(data: Dictionary) -> bool:
	return _get_serializer().deserialize(data)


# === 脏标志 ===================================================================

## 返回 _dirty 标志——SaveLoadSystem 用于确定是否需要写入。
func has_unsaved_changes() -> bool:
	return _dirty


## SaveLoadSystem 在成功写入后调用——设置 _dirty = false。
func mark_saved() -> void:
	_dirty = false


# === 内部辅助 =================================================================

## 标记数据为脏 + 发射 progression_updated 信号（受批量更新控制）。
func _mark_dirty_and_emit(domain: String) -> void:
	_dirty = true
	if _batch_depth > 0:
		_batch_pending_domains[domain] = true
	else:
		progression_updated.emit(domain)


## 获取 SaveLoadSystem 引用——注入优先，否则 Autoload #4。
func _get_save_load_system() -> Node:
	if _save_load_override != null:
		return _save_load_override
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var root: Window = tree.root
	if root == null:
		return null
	for i: int in range(root.get_child_count()):
		var child: Node = root.get_child(i)
		if child != null and child.name == &"SaveLoadSystem":
			return child
	return null


# --- 序列化/初始化辅助（已提取到 progression_serializer.gd 子模块）---
