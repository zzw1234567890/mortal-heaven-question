extends GutTest
## 事件资源加载验收——7 个事件 .tres 能被 ExplorationEventSystem 全量注册。
##
## 覆盖：注册数量、event_id 唯一、必填文案非空、选项 2~3 个、每个选项至少一条效果、
## 效果种类落在枚举范围内；以及「按序号取事件」的稳定性与越界取模。

const EventSystemScript := preload("res://src/feature/exploration_event_system.gd")

const EXPECTED_EVENT_COUNT: int = 7
const KIND_MIN: int = 0
const KIND_MAX: int = 3

var _system: RefCounted = null


func before_each() -> void:
	_system = EventSystemScript.new()


# === 加载 =====================================================================

func test_loads_all_bundled_events() -> void:
	var count: int = int(_system.call(&"load_events"))
	assert_eq(count, EXPECTED_EVENT_COUNT, "assets/events 下应有 7 个事件")
	assert_eq(int(_system.call(&"event_count")), EXPECTED_EVENT_COUNT)


func test_no_load_error() -> void:
	_system.call(&"load_events")
	assert_eq(str(_system.call(&"last_error")), "", "加载应无错误")


func test_event_ids_are_unique() -> void:
	_system.call(&"load_events")
	var ids: Array = _system.call(&"event_ids")
	var seen: Dictionary = {}
	for raw: Variant in ids:
		var id: String = str(raw)
		assert_false(seen.has(id), "event_id 不应重复：%s" % id)
		seen[id] = true


# === 字段完整性 ================================================================

func test_every_event_has_title_and_body() -> void:
	_system.call(&"load_events")
	for raw: Variant in _system.call(&"event_ids"):
		var def: Variant = _system.call(&"get_event", str(raw))
		assert_not_null(def, "事件应可取：%s" % str(raw))
		assert_false(str(def.get(&"title")).strip_edges().is_empty(),
				"标题不应为空：%s" % str(raw))
		assert_false(str(def.get(&"body")).strip_edges().is_empty(),
				"正文不应为空：%s" % str(raw))


func test_every_event_has_two_or_three_options() -> void:
	_system.call(&"load_events")
	for raw: Variant in _system.call(&"event_ids"):
		var def: Variant = _system.call(&"get_event", str(raw))
		var options: Array = def.get(&"options")
		assert_between(options.size(), 2, 3,
				"选项应为 2~3 个：%s" % str(raw))


func test_every_option_has_text_result_and_effect() -> void:
	_system.call(&"load_events")
	for raw: Variant in _system.call(&"event_ids"):
		var def: Variant = _system.call(&"get_event", str(raw))
		var options: Array = def.get(&"options")
		for i in range(options.size()):
			var option: Variant = options[i]
			assert_not_null(option, "选项不应为空")
			assert_false(str(option.get(&"text")).strip_edges().is_empty(),
					"选项文案不应为空：%s#%d" % [str(raw), i])
			assert_false(str(option.get(&"result_text")).strip_edges().is_empty(),
					"结果文案不应为空：%s#%d" % [str(raw), i])
			var effects: Array = option.get(&"effects")
			assert_gt(effects.size(), 0, "每个选项至少一条效果：%s#%d" % [str(raw), i])
			for effect_raw: Variant in effects:
				assert_not_null(effect_raw, "效果不应为空")
				var kind: int = int(effect_raw.get(&"kind"))
				assert_between(kind, KIND_MIN, KIND_MAX,
						"效果种类越界：%s" % str(kind))


# === 取事件 ====================================================================

func test_pick_by_index_is_stable_in_range() -> void:
	_system.call(&"load_events")
	var first: Variant = _system.call(&"pick_by_index", 0)
	var again: Variant = _system.call(&"pick_by_index", 0)
	assert_not_null(first)
	assert_eq(str(first.get(&"event_id")), str(again.get(&"event_id")),
			"同一序号的取事件结果应稳定")


func test_pick_by_index_wraps_around() -> void:
	_system.call(&"load_events")
	var base: Variant = _system.call(&"pick_by_index", 0)
	var wrapped: Variant = _system.call(&"pick_by_index", EXPECTED_EVENT_COUNT)
	assert_eq(str(base.get(&"event_id")), str(wrapped.get(&"event_id")),
			"越界序号应按数量取模")


func test_missing_event_returns_null() -> void:
	_system.call(&"load_events")
	assert_null(_system.call(&"get_event", "no_such_event"))
	assert_false(bool(_system.call(&"has_event", "no_such_event")))
