extends GutTest
## hud Story 004 集成测试：通知请求接口（AC-7——G7 裁决 2026-09-10 最小规格）。
##
## 覆盖 AC-7 全部规格与 edge case：[br]
##   - 主体：HUD 已挂载（NotificationArea 下组件实例存在），模拟某系统发通知
##     请求（如获得道具——调组件 request_notification）→ 队列 get_active()
##     出现对应类型/文本条目[br]
##   - edge：请求载荷非法类型 → 安全默认处理（未知类型规则——按系统提示 +
##     push_warning）[br]
##
## 测试策略：HUD.tscn 真实实例化（挂载验证——组件在 HUD 内容分支下存在）+
## 组件注入独立 NotificationStack 断言（内核行为已由 unit/hud 全覆盖，此处仅
## 验证接口转发链路）。风格先例：tests/integration/hud/test_gsm_signal_binding.gd
## （before/after_each 复原 + add_child_autofree）。

const HUD_SCENE: PackedScene = preload("res://src/ui/hud/HUD.tscn")
const STACK_SCRIPT: Script = preload("res://src/ui/hud/notification_stack.gd")

var hud: CanvasLayer = null
var area: Control = null
var stack: RefCounted = null


func before_each() -> void:
	hud = HUD_SCENE.instantiate()
	# 注入前先实例化再改 _stack 不可行（_ready 已自建并启动 Timer）——改为
	# 实例化后替换组件的内核实例（组件 _on_tick 读成员引用，替换即时生效；
	# 集成断言直接读注入实例的 get_active）。
	add_child(hud)
	area = hud.get_node_or_null("ContentLayer/NotificationArea/NotificationToastArea") as Control
	if area == null:
		fail_test("HUD.tscn 应在 NotificationArea 下挂载 NotificationToastArea 组件")
		return
	stack = STACK_SCRIPT.new()
	area._stack = stack
	# 关闭动画——集成断言只验证接口转发链路与队列内容（story AC-3 规格同源
	## 先例：test_gsm_signal_binding before_each 置 bar.animate = false）。
	area.animate = false


func after_each() -> void:
	if hud != null and is_instance_valid(hud):
		hud.free()
	hud = null
	area = null
	stack = null


func _active_entries() -> Array:
	return stack.get_active()


# ═══════════════════════════════════════════════════════════════════════════════
# AC-7：通知请求接口（G7 裁决最小规格）
# ═══════════════════════════════════════════════════════════════════════════════

func test_ac007_component_mounted_under_notification_area() -> void:
	## AC-7 前置: HUD 已挂载——NotificationArea 区域容器下组件实例存在
	## （Story 001 骨架容器 + 本 story 组件挂载）
	# Arrange —— before_each 已实例化 HUD
	# Act
	var container: Node = hud.get_node_or_null("ContentLayer/NotificationArea")
	# Assert
	assert_not_null(container, "ContentLayer 下应存在 NotificationArea 容器")
	assert_not_null(area, "NotificationArea 下应挂载 NotificationToastArea 组件")
	assert_eq(area.get_parent(), container, "组件应为 NotificationArea 直接子节点")


func test_ac007_item_request_appears_in_queue() -> void:
	## AC-7 主体: 模拟某系统发通知请求（获得道具）→ get_active() 出现对应
	## 类型/文本条目
	# Arrange —— before_each 已挂载
	# Act
	var id: int = area.request_notification("item", "获得 回血丹 ×1")
	# Assert
	assert_ne(id, 0, "获得道具请求应成功入队（返回非 0 id）")
	var entries: Array = _active_entries()
	assert_eq(entries.size(), 1, "队列应出现 1 条通知")
	assert_eq(str(entries[0][&"type"]), "item", "条目类型应为 item")
	assert_eq(str(entries[0][&"text"]), "获得 回血丹 ×1", "条目文本应为请求文本")


func test_ac007_request_spawns_toast_node() -> void:
	## AC-7 主体补充: 请求后 UI 渲染同步——Toast 节点出现在堆叠容器下
	# Arrange
	# Act
	var id: int = area.request_notification("lingshi", "+25 灵石")
	# Assert
	var toast: Node = area.get_node_or_null("StackContainer/Toast%d" % id)
	assert_not_null(toast, "请求后应生成 Toast 节点（Toast%d）" % id)


func test_ac007_invalid_type_request_safe_default() -> void:
	## AC-7 edge: 请求载荷非法类型 → 安全默认处理（未知类型规则——按系统提示
	## 处理 + push_warning）
	# Arrange
	# Act
	var id: int = area.request_notification("nonexistent_type", "异常载荷")
	# Assert —— 条目按系统提示安全默认入队（white/重要/5s）
	assert_ne(id, 0, "非法类型应安全默认入队（不崩溃不拒绝）")
	var entries: Array = _active_entries()
	assert_eq(entries.size(), 1, "队列应出现 1 条安全默认条目")
	assert_eq(str(entries[0][&"color"]), "white", "非法类型条目应按系统提示 white")
	assert_true(bool(entries[0][&"important"]), "非法类型条目应按系统提示判为重要")
	assert_push_warning_count(1, "非法类型请求应 push_warning 1 次")


func test_ac007_request_signal_emitted() -> void:
	## AC-7 补充（G7 裁决信号接口）: 请求触发 notification_requested 信号——
	## 供未来系统经信号链路连接（ADR-0007 Cat 2b）
	# Arrange
	watch_signals(area)
	# Act
	area.request_notification("card", "新卡：青云剑诀")
	# Assert —— 两步式（先发射后参数）。注意 GUT 签名陷阱：
	## assert_signal_emitted_with_parameters(obj, name, params, index)——
	## 若多传第 5 个消息参数，SignalAssertParameters 会把消息吃进 index
	## 槽位（"String"=='int' 比较报引擎错误）——消息不传，失败信息由
	## GUT 默认 disp 提供
	assert_signal_emitted(area, "notification_requested",
			"请求应发射 notification_requested 信号")
	assert_signal_emitted_with_parameters(area, "notification_requested",
			["card", "新卡：青云剑诀"])


func test_ac007_capacity_rule_via_request_interface() -> void:
	## AC-7 补充: 容量规则经请求接口生效——4 条普通请求后队列 3 条（AC-2
	## 内核规则在 UI 接口链路上的贯通验证）
	# Arrange
	# Act
	area.request_notification("item", "第1条")
	area.request_notification("item", "第2条")
	area.request_notification("item", "第3条")
	area.request_notification("item", "第4条")
	# Assert
	assert_eq(_active_entries().size(), 3, "4 条普通请求后队列应保持 3 条（容量上限）")
	var texts: Array = []
	for entry: Dictionary in _active_entries():
		texts.append(str(entry[&"text"]))
	assert_eq(texts, ["第2条", "第3条", "第4条"], "最早一条应被挤出（FIFO）")
