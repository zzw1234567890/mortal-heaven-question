## CardSystem —— 卡牌模板注册表 + 异步加载 + 实例工厂 Autoload（#6）。
##
## Core 层第 6 个 Autoload。持有 222 个 CardTemplate 的运行时注册表，
## 通过 ResourceLoader.load_threaded_request() 异步加载，每帧 10 个分批处理。
## 模板加载完成后主动调用 GSM.enable_validation() 启用卡牌校验（AC-006 偏差实现）。
##
## [b]Autoload 顺序[/b]：GSM → ... → CardSystem（#6）
## [b]原则[/b]：模板只读（ADR-0006），实例工厂 create_instance 分配 GSM ID。
extends Node
# class_name CardSystem —— 不声明：Autoload 全局单例，
# 声明 class_name 会与全局名冲突，导致 CS_SCRIPT.new() 测试实例无法解析。
# 测试以 var cs: Node 持有 + 动态分派访问（同 EventSystem 先例，控制清单 2026-08-05 规则）。


# === 信号声明 =====================================================================

## 模板加载完成后发射。[param count] 为入库的模板数量（templates.size()）。
## Cat 2b 动作通知（ADR-0007）——携带事实"加载了 N 个模板"。
## 重复 card_id 或加载失败的资源不计入 count。
signal templates_loaded(count: int)


# === 常量 ========================================================================

## 默认模板目录路径。
const DEFAULT_TEMPLATE_PATH: StringName = &"res://assets/cards/templates/"

## 每帧最多查询的异步加载状态数——节流上限（222/10 ≈ 23 帧 ≈ 380ms @ 60fps）。
const MAX_PER_FRAME: int = 10

## 章节字符串 → 章节编号映射（ADR-0026 5 章结构）。
## 用于 create_instance 将 GSM.narrative.current_chapter (String) 解析为 CardInstance.acquired_chapter (int)。
## 未匹配或空字符串 → 0（表示"章节未开始/未知"）。
## 方案 A（2026-08-06 决策）：GDD 定义 acquired_chapter 为 int，GSM 存 String，需此映射桥接。
const CHAPTER_NUMBER_MAP: Dictionary = {
	&"chapter_1": 1,
	&"chapter_2": 2,
	&"chapter_3": 3,
	&"chapter_4": 4,
	&"chapter_5": 5,
}


# === 模板注册表 ===================================================================

## 模板注册表——键为 [member CardTemplate.card_id]: StringName，值为 CardTemplate Resource。
## NOTE: 裸 Dictionary——GDScript 4.6 class_name 跨文件解析限制（同 EventSystem.templates）。
var templates: Dictionary = {}

## 待加载路径队列——_load_templates_from 填充，_process 消费。
var _pending_paths: Array[StringName] = []

## 本帧已处理的 pending 计数器——_process 入口重置为 0，每查询一次 load_threaded_get_status 递增。
## 测试可通过反射读取以验证节流上限（同 EventSystem._chain_visited_ids 先例）。
var _frame_processed_count: int = 0


# === 内置虚方法 ===================================================================

func _ready() -> void:
	_load_templates_from(DEFAULT_TEMPLATE_PATH)


func _process(delta: float) -> void:
	_frame_processed_count = 0
	# 防御性检查：_load_templates_from 在空目录时直接 emit 并 return（不调 set_process），
	# 非空目录时 _pending_paths 必然非空。此分支理论上不可达，保留以防 Autoload 重载等边缘场景。
	if _pending_paths.is_empty():
		set_process(false)
		_on_all_templates_loaded()
		return

	var i: int = 0
	while i < _pending_paths.size() and _frame_processed_count < MAX_PER_FRAME:
		var path: StringName = _pending_paths[i]
		var status: int = ResourceLoader.load_threaded_get_status(path)
		_frame_processed_count += 1
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var res := ResourceLoader.load_threaded_get(path)
			_pending_paths.remove_at(i)
			if _validate_template(res, path):
				var tpl: CardTemplate = res as CardTemplate
				templates[tpl.card_id] = tpl
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("CardSystem: 加载失败 '%s'（status=%d）" % [path, status])
			_pending_paths.remove_at(i)
		else:
			# IN_PROGRESS——保留在队列中，下次再查
			i += 1

	if _pending_paths.is_empty():
		set_process(false)
		_on_all_templates_loaded()


# === 公共 API =====================================================================

## 获取模板注册表中的一个模板。[br]
## [br][b]复杂度[/b]: O(1) 字典查询。[br]
## [br][b]返回[/b]: [CardTemplate] 或 [code]null[/code]（ID 不存在时）。
func get_template(id: StringName) -> CardTemplate:
	return templates.get(id, null) as CardTemplate


## 按类型筛选模板。[br]
## [br][b]复杂度[/b]: O(n) 遍历——非热路径（仅收藏浏览/战利品生成调用）。[br]
## [br][param type]: CardType 枚举值（int——避免 class_name 依赖，CardSystem 不声明 class_name）。[br]
## [br][b]返回[/b]: [Array] 含所有匹配类型的 CardTemplate；无匹配返回空数组。[br]
## NOTE: 返回裸 Array 而非 Array[CardTemplate]——GDScript 4.6 在不声明 class_name 的脚本中，
## 跨文件 typed array 返回类型解析不稳定（同 EventSystem.templates 裸 Dictionary 先例）。
func get_templates_by_type(type: int) -> Array:
	var result: Array = []
	for id: StringName in templates.keys():
		var tpl: CardTemplate = templates[id] as CardTemplate
		if tpl.type == type:
			result.append(tpl)
	return result


## 创建卡牌实例——CardSystem 实例工厂。[br]
## [br][b]流程[/b]:[br]
##   1. 查询 [member templates] 获取模板；未知 ID → [method @GlobalScope.push_error] + return [code]null[/code][br]
##   2. [code]CardInstance.new()[/code] 创建实例[br]
##   3. 调用 [method GameStateManager.allocate_card_id] 分配全局唯一 ID[br]
##   4. 设置 [code]template_id[/code] + [code]acquired_chapter[/code]（从 GSM.narrative.current_chapter 解析为 int）[br]
##   5. 返回实例（[b]不入库[/b]——入库由调用方显式调 [method GameStateManager.add_card_to_collection]）[br]
## [br][b]返回[/b]: [CardInstance] 或 [code]null[/code]（template_id 未知时）。[br]
## [br][b]架构偏差声明[/b]（AC-006）：ADR-0006 §启动合约原定 GSM 监听 templates_loaded 信号；
## 本实现改为 CardSystem 主动调 GSM.enable_validation，符合 Core→Foundation 依赖方向（Foundation 原则 #3）。
func create_instance(template_id: StringName) -> CardInstance:
	var tmpl: CardTemplate = get_template(template_id)
	if tmpl == null:
		push_error("CardSystem.create_instance: 未知 template_id '%s'" % template_id)
		return null
	var inst: CardInstance = CardInstance.new()
	inst.card_instance_id = GameStateManager.allocate_card_id()
	inst.template_id = template_id
	inst.acquired_chapter = _resolve_chapter_number(GameStateManager.narrative.current_chapter)
	return inst


# === 模板加载 =====================================================================

## 从指定目录异步加载所有 [code].tres[/code] CardTemplate 文件。[br]
## [br][b]加载生命周期[/b]（ADR-0006 §模板加载生命周期）:[br]
##   1. DirAccess 枚举 .tres 文件[br]
##   2. 对每个文件调用 [method ResourceLoader.load_threaded_request][br]
##   3. [method set_process] 启用帧轮询[br]
##   4. [method _process] 每帧查询最多 [constant MAX_PER_FRAME] 个状态[br]
##   5. 全部完成后发射 [signal templates_loaded][br]
## [br][b]空目录处理[/b]（时序方案 B）：检测到 0 pending 时直接发射信号，
## 不调用 [method set_process]，避免空帧调度。[br]
## [br][param path]: 模板目录路径（可注入——测试接缝）。
func _load_templates_from(path: StringName) -> void:
	templates.clear()
	_pending_paths.clear()

	var path_str: String = String(path)
	var dir := DirAccess.open(path_str)
	if dir == null:
		push_error("CardSystem: 无法打开模板目录 '%s'" % path_str)
		# DirAccess 失败也走统一收尾——_on_all_templates_loaded 会调 enable_validation(空 templates)
		# 并由 GSM 决定是否启用校验（空 templates 会 push_error 不启用）。统一两条失败路径行为。
		_on_all_templates_loaded()
		return

	dir.include_hidden = false
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var full_path: String = path_str + file_name
			ResourceLoader.load_threaded_request(full_path)
			_pending_paths.append(StringName(full_path))
		file_name = dir.get_next()
	dir.list_dir_end()

	if _pending_paths.is_empty():
		# 空目录——时序方案 B：直接发射信号，不启用 _process
		_on_all_templates_loaded()
		return

	set_process(true)


## 全部模板加载完成后的统一收尾——启用 GSM 校验 + 发射 templates_loaded 信号。[br]
## [br]由 [method _process]（加载完成）和 [method _load_templates_from]（空目录/DirAccess 失败）调用。[br]
## [br][b]AC-006 偏差实现[/b]：主动调用 [method GameStateManager.enable_validation]，
## 而非让 GSM 监听 [signal templates_loaded]——符合 Core→Foundation 依赖方向（Foundation 原则 #3）。[br]
## [br]GSM.enable_validation 对空 templates 会 push_error 不启用校验——这是预期行为：
## 空模板目录意味着游戏无法正常初始化，应尽早暴露问题。
func _on_all_templates_loaded() -> void:
	GameStateManager.enable_validation(templates)
	templates_loaded.emit(templates.size())


## 将 GSM.narrative.current_chapter (String) 解析为章节编号 (int)。[br]
## [br]GDD 定义 CardInstance.acquired_chapter 为 int，但 GSM 存储章节为 String（如 "chapter_2"）。[br]
## 此方法通过 [constant CHAPTER_NUMBER_MAP] 桥接类型差异（方案 A，2026-08-06 决策）。[br]
## [br][param chapter_str]: 章节字符串（来自 [code]GameStateManager.narrative.current_chapter[/code]）。[br]
## [br][b]返回[/b]: 章节编号（1-5）；空字符串或未匹配返回 0（"章节未开始/未知"）。
func _resolve_chapter_number(chapter_str: String) -> int:
	if chapter_str.is_empty():
		return 0
	var key: StringName = StringName(chapter_str)
	return int(CHAPTER_NUMBER_MAP.get(key, 0))


# === 序列化 / 反序列化 ===========================================================

## 序列化 [CardInstance] 为纯 [Dictionary]——用于存档往返。[br]
## [br][b]ADR-0006 §GSM 集成合约[/b]：GSM 持有序列化的 Dictionary（模型 A），
## 通过 [method reconstitute_instances] 批量重构 CardInstance 对象。[br]
## [br][b]9 字段[/b]：card_instance_id、template_id、level、inscriptions、
## breakthrough_layers、binding_target_id、acquired_chapter、acquired_event_id、acquired_method。[br]
## [br][param inst]: 待序列化的卡牌实例。[br]
## [br][b]返回[/b]: 含全部 9 字段的 Dictionary，inscriptions 为深拷贝（避免共享引用）。
func serialize_instance(inst: CardInstance) -> Dictionary:
	return {
		"card_instance_id": inst.card_instance_id,
		"template_id": inst.template_id,
		"level": inst.level,
		"inscriptions": inst.inscriptions.duplicate(true),
		"breakthrough_layers": inst.breakthrough_layers,
		"binding_target_id": inst.binding_target_id,
		"acquired_chapter": inst.acquired_chapter,
		"acquired_event_id": inst.acquired_event_id,
		"acquired_method": inst.acquired_method,
	}


## 从 [Dictionary] 反序列化为 [CardInstance]——恢复全部 9 字段。[br]
## [br][b]AC-003 StringName 显式转换[/b]：template_id、binding_target_id、acquired_event_id
## 三个 StringName 字段经 JSON 往返后为 String，必须 [code]StringName()[/code] 转换，
## 否则 [member templates] 字典查找失败（Godot 4.6 字典键类型敏感）。[br]
## [br][b]AC-007 缺失字段容错[/b]：使用 [code].get(key, default)[/code]，默认值与 Story 002 一致。[br]
## [br][b]AC-008 未知字段[/b]：仅读取已知 9 字段，Dictionary 中其他键被自然忽略。[br]
## [br][b]AC-009 类型不匹配[/b]：对 5 个 int 字段做 [code]typeof[/code] 检查 + [code]int()[/code] 强制转换，
## 非数字值 → [method @GlobalScope.push_error] + 使用默认值（AC-007 一致）。[br]
## [br][param data]: 序列化的 Dictionary（可能来自 JSON 反序列化，字段类型可能为 String）。[br]
## [br][b]返回[/b]: 恢复的 CardInstance 实例。
func deserialize_instance(data: Dictionary) -> CardInstance:
	var inst: CardInstance = CardInstance.new()
	inst.card_instance_id = _get_int_field(data, "card_instance_id", 0)
	inst.template_id = _to_stringname(data.get("template_id", &""))
	inst.level = _get_int_field(data, "level", 1)
	inst.inscriptions = _get_inscriptions_field(data, "inscriptions")
	inst.breakthrough_layers = _get_int_field(data, "breakthrough_layers", 0)
	inst.binding_target_id = _to_stringname(data.get("binding_target_id", &""))
	inst.acquired_chapter = _get_int_field(data, "acquired_chapter", 0)
	inst.acquired_event_id = _to_stringname(data.get("acquired_event_id", &""))
	inst.acquired_method = _get_int_field(data, "acquired_method", 0)
	return inst


## 批量反序列化——将存档中的 Dictionary 数组重构为 CardInstance 数组。[br]
## [br]用于 SaveLoadSystem 读档后重构 GSM [code]collection.owned_cards[/code] 对应的实例对象。[br]
## [br][b]复杂度[/b]: O(n) 遍历——非热路径（仅读档时调用）。[br]
## [br][param dicts]: 序列化的 Dictionary 数组。[br]
## [br][b]返回[/b]: [Array] 含反序列化的 CardInstance；空数组返回空数组（非 null）。[br]
## NOTE: 返回裸 Array 而非 Array[CardInstance]——GDScript 4.6 在不声明 class_name 的
## 脚本中跨文件 typed array 返回类型解析不稳定（同 get_templates_by_type 先例）。
func reconstitute_instances(dicts: Array) -> Array:
	var result: Array = []
	result.resize(dicts.size())
	for i: int in range(dicts.size()):
		result[i] = deserialize_instance(dicts[i])
	return result


## 从 Dictionary 读取 int 字段——AC-009 类型不匹配容错。[br]
## [br][b]策略[/b]：[br]
##   - int 类型 → 直接返回[br]
##   - float 类型 → [code]int()[/code] 截断转换（JSON 数字可能为 float）[br]
##   - String 类型且为数字 → [code]int()[/code] 转换（兼容 JSON 数字字符串）[br]
##   - String 类型且非数字 → [method @GlobalScope.push_error] + 返回默认值[br]
##   - 其他类型 → [method @GlobalScope.push_error] + 返回默认值[br]
## [br][param data]: 源 Dictionary。[br]
## [br][param key]: 字段键名。[br]
## [br][param default_value]: 类型不匹配或缺失时的默认值。[br]
## [br][b]返回[/b]: int 字段值或默认值。
func _get_int_field(data: Dictionary, key: String, default_value: int) -> int:
	if not data.has(key):
		return default_value
	var value: Variant = data[key]
	if typeof(value) == TYPE_INT:
		return value
	if typeof(value) == TYPE_FLOAT:
		return int(value)
	if typeof(value) == TYPE_STRING:
		var s: String = value
		if s.is_valid_int():
			return int(s)
		push_error("CardSystem.deserialize_instance: 字段 '%s' 类型不匹配（String 非数字 '%s'）——使用默认值 %d" % [key, s, default_value])
		return default_value
	push_error("CardSystem.deserialize_instance: 字段 '%s' 类型不匹配（期望 int，实际类型 %d）——使用默认值 %d" % [key, typeof(value), default_value])
	return default_value


## 将 Variant 值安全转换为 StringName——处理 JSON 往返产生的 String/null。[br]
## [br]Godot 4.6 的 [code]StringName(null)[/code] 构造函数不存在（运行时报错），
## 此方法对 null/非 String 类型统一返回默认 [code]&""[/code]。[br]
## [br][param value]: 输入值（可能为 String、StringName、null 或其他）。
func _to_stringname(value: Variant) -> StringName:
	if value == null:
		return &""
	if value is StringName:
		return value
	if value is String:
		return StringName(value)
	return &""


## 从 Dictionary 读取 inscriptions 字段——显式深拷贝 + null/类型容错。[br]
## [br]AC-002 元素级深拷贝：[method Array.duplicate] 递归拷贝 Array 容器及内部 Dictionary 元素，
## 避免反序列化后的实例修改影响原存档 Dictionary。[br]
## [br]容错：null 或非 Array 值（存档损坏）→ 空数组，不崩溃。[br]
## [br][param data]: 源 Dictionary。[br]
## [br][param key]: 字段键名。[br]
## [br][b]返回[/b]: 深拷贝的 Array[Dictionary]，或空数组（值缺失/无效时）。
func _get_inscriptions_field(data: Dictionary, key: String) -> Array[Dictionary]:
	var raw: Variant = data.get(key, [])
	if not raw is Array:
		return []
	var result: Array[Dictionary] = []
	for item: Variant in raw:
		if item is Dictionary:
			result.append((item as Dictionary).duplicate(true))
	return result


## 校验加载的资源是否为有效的 CardTemplate 模板。[br]
## [br]校验项：[br]
##   - 资源非 null（文件损坏时 load_threaded_get 返回 null）[br]
##   - 资源是 CardTemplate 类型[br]
##   - card_id 非空[br]
##   - card_id 未重复[br]
## [br]校验失败时调用 [method @GlobalScope.push_error] 并返回 [code]false[/code]。[br]
## [br][b]架构偏差声明[/b]（AC-009）：ADR-0006 L402 区分 EDITOR/RELEASE 构建；
## 本实现采用统一 [method @GlobalScope.push_error] 策略（不区分构建模式），
## 保证 GUT headless 模式下可通过 assert_push_error_count 验证。
func _validate_template(res: Resource, path: StringName) -> bool:
	if res == null:
		push_error("CardSystem: 文件 '%s' 加载返回 null（文件损坏）" % path)
		return false
	if not is_instance_of(res, CardTemplate):
		push_error("CardSystem: 文件 '%s' 不是 CardTemplate 类型" % path)
		return false
	var tpl: CardTemplate = res as CardTemplate
	if tpl.card_id == &"":
		push_error("CardSystem: 文件 '%s' 的 card_id 为空——跳过" % path)
		return false
	if templates.has(tpl.card_id):
		push_error("CardSystem: card_id '%s' 重复（文件 '%s'）——跳过" % [tpl.card_id, path])
		return false
	return true
