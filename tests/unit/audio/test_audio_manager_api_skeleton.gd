extends GutTest
## audio Story 001 单元测试：AudioManager 11 个 API 签名与 GDD §8 逐字一致。
##
## 覆盖 QA 规格 AC-4：经 [code]Object.get_method_list()[/code] 反射断言方法存在、
## 参数名/类型/默认值匹配——签名漂移（重命名/改类型/删默认值）在此显式失败，
## 而非下游调用点静默编译错误。[br]
## 风格先例：tests/unit/hud/test_cultivation_bar_state.gd（arrange/act/assert）。

const AM_SCRIPT := preload("res://src/ui/audio/audio_manager.gd")
const ADAPTER_SCRIPT := preload("res://src/ui/audio/audio_server_adapter.gd")

## 期望签名表——与 GDD §8 音频事件接口逐字一致（单一真源镜像）。[br]
## 结构：[方法名, [参数名数组], [参数类型数组（Variant.Type 整数）], 返回类型名, [默认值断言]]。
## 类型注记：GDD 枚举参数（AudioBus/AudioState）反射为 int（TYPE_INT = 2）；
## StringName = 21，Dictionary = 27，float = 3，void = TYPE_NIL = 0。
## 默认值断言为 [参数索引, 期望默认值字面] 对（仅对有默认值的参数）。
const EXPECTED_SIGNATURES: Array = [
	["play_sfx", ["sfx_id", "options"], [TYPE_STRING_NAME, TYPE_DICTIONARY], "void",
			[[1, {}]]],
	["play_bgm", ["bgm_id", "options"], [TYPE_STRING_NAME, TYPE_DICTIONARY], "void",
			[[1, {}]]],
	["stop_bgm", ["options"], [TYPE_DICTIONARY], "void",
			[[0, {}]]],
	["pause_all", [], [], "void", []],
	["resume_all", [], [], "void", []],
	["play_ambient", ["ambient_id"], [TYPE_STRING_NAME], "void", []],
	["stop_ambient", ["fade_out_sec"], [TYPE_FLOAT], "void",
			[[0, 1.0]]],
	["set_bus_volume", ["bus", "volume_db"], [TYPE_INT, TYPE_FLOAT], "void", []],
	["get_bus_volume", ["bus"], [TYPE_INT], "float", []],
	["toggle_mute", [], [], "void", []],
	["set_state", ["state"], [TYPE_INT], "void", []],
]


func _find_method(methods: Array, method_name: String) -> Dictionary:
	## 辅助——从 get_method_list 结果中查找指定方法（未找到返回空字典）。
	for m: Dictionary in methods:
		if m.name == method_name:
			return m
	return {}


func test_api_skeleton_all_eleven_methods_exist() -> void:
	## AC-4: 11 个方法全部存在
	# Arrange
	var am: RefCounted = AM_SCRIPT.new(null)
	var methods: Array = am.get_method_list()
	# Act + Assert
	for sig: Array in EXPECTED_SIGNATURES:
		var method_name: String = sig[0]
		assert_ne(_find_method(methods, method_name), {},
				"方法 '%s' 应存在（GDD §8）" % method_name)


func test_api_skeleton_parameter_names_match_gdd() -> void:
	## AC-4: 参数名逐一匹配（GDD §8 逐字——含 snake_case 拼写）
	# Arrange
	var am: RefCounted = AM_SCRIPT.new(null)
	var methods: Array = am.get_method_list()
	# Act + Assert
	for sig: Array in EXPECTED_SIGNATURES:
		var method: Dictionary = _find_method(methods, sig[0])
		if method.is_empty():
			fail_test("方法 '%s' 不存在——无法校验参数名" % sig[0])
			continue
		assert_eq(method.args.size(), sig[1].size(),
				"'%s' 参数个数应为 %d（实际 %d）" % [sig[0], sig[1].size(),
				method.args.size()])
		for i: int in method.args.size():
			assert_eq(method.args[i].name, sig[1][i],
					"'%s' 第 %d 个参数名应为 '%s'（实际 '%s'）" % [sig[0], i,
					sig[1][i], method.args[i].name])


func test_api_skeleton_parameter_types_match_gdd() -> void:
	## AC-4: 参数类型匹配。[br]
	## 注：GDD 签名中的枚举类型（AudioBus/AudioState）在 get_method_list 反射中
	## 以 int 呈现（GDScript 枚举本质）——期望表按 int 断言。
	# Arrange
	var am: RefCounted = AM_SCRIPT.new(null)
	var methods: Array = am.get_method_list()
	# Act + Assert
	for sig: Array in EXPECTED_SIGNATURES:
		var method: Dictionary = _find_method(methods, sig[0])
		if method.is_empty():
			fail_test("方法 '%s' 不存在——无法校验参数类型" % sig[0])
			continue
		for i: int in method.args.size():
			assert_eq(method.args[i].type, sig[2][i],
					"'%s' 第 %d 个参数（%s）类型应匹配（期望 %d，实际 %d）"
					% [sig[0], i, sig[1][i], sig[2][i], method.args[i].type])


func test_api_skeleton_default_values_match_gdd() -> void:
	## AC-4: 默认值匹配——play_sfx/play_bgm/stop_bgm 的 options = {}、
	## stop_ambient 的 fade_out_sec = 1.0（GDD §8 逐字）。[br]
	## 反射结构注记：get_method_list 的默认值在方法级 [code]default_args[/code]
	## 数组（尾部对齐——仅最后 N 个参数有默认值），不在 args 条目内。
	# Arrange
	var am: RefCounted = AM_SCRIPT.new(null)
	var methods: Array = am.get_method_list()
	# Act + Assert
	for sig: Array in EXPECTED_SIGNATURES:
		if sig[4].is_empty():
			continue
		var method: Dictionary = _find_method(methods, sig[0])
		if method.is_empty():
			fail_test("方法 '%s' 不存在——无法校验默认值" % sig[0])
			continue
		var arg_count: int = method.args.size()
		var default_count: int = method.default_args.size()
		assert_eq(default_count, sig[4].size(),
				"'%s' 应有 %d 个默认值参数（实际 %d）" % [sig[0], sig[4].size(),
				default_count])
		for d: Array in sig[4]:
			var param_idx: int = d[0]
			var expected_default: Variant = d[1]
			# default_args 尾部对齐：参数 i 的默认值位于 default_args[i - (arg_count - default_count)]
			var default_slot: int = param_idx - (arg_count - default_count)
			assert_true(default_slot >= 0 and default_slot < default_count,
					"'%s' 参数 '%s' 的默认值槽位应有效" % [sig[0],
					method.args[param_idx].name])
			if default_slot < 0 or default_slot >= default_count:
				continue
			var actual_default: Variant = method.default_args[default_slot]
			if expected_default is Dictionary:
				# Dictionary 默认值反射为 null（不可表达字面字典）——
				# 只验证默认值存在（有 default_args 条目）
				assert_true(actual_default == null,
						"'%s' 参数 '%s' 的 Dictionary 默认值反射为 null" % [sig[0],
						method.args[param_idx].name])
			else:
				assert_almost_eq(float(actual_default), float(expected_default),
						0.0001, "'%s' 参数 '%s' 默认值应为 %s（实际 %s）"
						% [sig[0], method.args[param_idx].name,
						str(expected_default), str(actual_default)])


func test_api_skeleton_return_types_match_gdd() -> void:
	## AC-4: 返回类型匹配——get_bus_volume 返回 float，其余 10 个为 void[br]
	## 反射结构注记：返回类型在方法级 [code]return.type[/code]
	## （void = TYPE_NIL = 0，float = TYPE_FLOAT = 3）。
	# Arrange
	var am: RefCounted = AM_SCRIPT.new(null)
	var methods: Array = am.get_method_list()
	# Act + Assert
	for sig: Array in EXPECTED_SIGNATURES:
		var method: Dictionary = _find_method(methods, sig[0])
		if method.is_empty():
			fail_test("方法 '%s' 不存在——无法校验返回类型" % sig[0])
			continue
		var expected_type: int = TYPE_NIL if sig[3] == "void" else TYPE_FLOAT
		assert_eq(method.return.type, expected_type,
				"'%s' 返回类型应为 %s" % [sig[0], sig[3]])


func test_api_skeleton_audio_bus_enum_six_values() -> void:
	## AC（story Implementation Notes）：AudioBus 枚举 6 值 + 名称映射完整
	# Arrange + Act
	var bus_names: Dictionary = AudioEnums.BUS_NAMES
	# Assert —— 6 个枚举值全部有名称映射
	assert_eq(bus_names.size(), 6, "BUS_NAMES 应含 6 个总线映射")
	assert_eq(bus_names[AudioEnums.AudioBus.MASTER], &"Master")
	assert_eq(bus_names[AudioEnums.AudioBus.BGM], &"BGM")
	assert_eq(bus_names[AudioEnums.AudioBus.SFX], &"SFX")
	assert_eq(bus_names[AudioEnums.AudioBus.UI], &"UI")
	assert_eq(bus_names[AudioEnums.AudioBus.AMBIENT], &"Ambient")
	assert_eq(bus_names[AudioEnums.AudioBus.VOICE], &"Voice")


func test_api_skeleton_audio_state_enum_twelve_values() -> void:
	## AC（story Implementation Notes）：AudioState 枚举 12 值完整
	## （story 004 过渡矩阵直接消费——类型完整性在本 story 保证）
	# Arrange + Act + Assert
	assert_eq(AudioEnums.AudioState.MAIN_MENU, 0)
	assert_eq(AudioEnums.AudioState.IDENTITY_SELECT, 1)
	assert_eq(AudioEnums.AudioState.EXPLORING, 2)
	assert_eq(AudioEnums.AudioState.IN_COMBAT, 3)
	assert_eq(AudioEnums.AudioState.IN_TRIBULATION, 4)
	assert_eq(AudioEnums.AudioState.IN_EVENT, 5)
	assert_eq(AudioEnums.AudioState.IN_SHOP, 6)
	assert_eq(AudioEnums.AudioState.MAP_CLEARED, 7)
	assert_eq(AudioEnums.AudioState.DEFEATED, 8)
	assert_eq(AudioEnums.AudioState.PAUSED, 9)
	assert_eq(AudioEnums.AudioState.DECK_EDITING, 10)
	assert_eq(AudioEnums.AudioState.CULTIVATING, 11)


func test_api_skeleton_no_extra_public_apis_beyond_gdd() -> void:
	## AC-4 守卫：AudioManager 公共方法无 GDD §8 之外的发明——
	## 防止后续 story 前的 API 漂移（除文档注明的 get_bgm_players 访问器）。[br]
	## 实现方式：RegEx 逐行扫描脚本源码声明的公共 func（含 static func——
	## 静态公共方法同样是 API 表面，一并守卫）；内建继承方法不在源码中，
	## 天然不参与匹配。
	# Arrange
	var allowed: Array[String] = []
	for sig: Array in EXPECTED_SIGNATURES:
		allowed.append(sig[0])
	allowed.append("get_bgm_players")  # story 规格：节点池访问器（测试/story 002 消费）
	var source: String = FileAccess.get_file_as_string(
			"res://src/ui/audio/audio_manager.gd")
	assert_false(source.is_empty(), "audio_manager.gd 源码应可读")
	# Act + Assert —— 逐行扫描脚本声明的公共 func——全部须在白名单内
	var func_regex := RegEx.new()
	func_regex.compile("(?m)^(?:static\\s+)?func\\s+(?!_)(\\w+)\\s*\\(")
	for match: RegExMatch in func_regex.search_all(source):
		var method_name: String = match.get_string(1)
		assert_true(allowed.has(method_name),
				"AudioManager 存在 GDD §8 之外的公共方法 '%s'" % method_name)


func test_adapter_unknown_bus_enum_returns_minus1_and_noop() -> void:
	## QA GAP-1：adapter 未知总线枚举防御——BUS_NAMES 之外的枚举值
	## 经 push_error + 返回 -1 / 0.0 / no-op 优雅降级（不崩溃）。
	# Arrange —— 99 不在 AudioBus 枚举 6 值内
	const UNKNOWN_BUS: int = 99
	var adapter: AudioServerAdapter = ADAPTER_SCRIPT.new()
	# Act + Assert —— get 类返回无害默认
	assert_eq(adapter.get_bus_index(UNKNOWN_BUS), -1,
			"未知枚举 get_bus_index 应返回 -1（push_error 不中断）")
	assert_almost_eq(adapter.get_bus_volume_db(UNKNOWN_BUS), 0.0, 0.0001,
			"未知枚举 get_bus_volume_db 应返回无害默认 0.0")
	assert_false(adapter.is_bus_muted(UNKNOWN_BUS),
			"未知枚举 is_bus_muted 应返回 false")
	# set 类 no-op 不崩溃
	adapter.set_bus_volume_db(UNKNOWN_BUS, -12.0)
	adapter.set_bus_mute(UNKNOWN_BUS, true)
	assert_true(true, "未知枚举 set 类调用完成——no-op 不崩溃")


func test_audio_manager_null_scene_manager_pool_empty() -> void:
	## QA GAP-3：null scene_manager 分支正向断言——单元测试直建场景下
	## _setup_node_pool 跳过挂载，节点池应为空（此前仅隐式不崩溃）。
	# Arrange + Act
	var am: AudioManager = AM_SCRIPT.new(null)
	# Assert
	assert_true(am.get_bgm_players().is_empty(),
			"null scene_manager 时不创建节点池（get_bgm_players 应为空）")
