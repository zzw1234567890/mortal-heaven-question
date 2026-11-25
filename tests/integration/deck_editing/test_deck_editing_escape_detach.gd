extends "res://tests/integration/deck_editing/deck_editing_fixture.gd"
## 「取消键 = 返回」的屏在转场之后还在往下写——[code]get_viewport()[/code] 已为 null。[br]
## [br][b]钉住的是什么[/b]：真机走查现场（第三轮）——卡组编辑屏按 Esc 回主菜单，
## 转场[b]其实成功了[/b]，但控制台每次都留一条
## [code]Cannot call method 'set_input_as_handled' on a null value[/code]
## （[code]deck_editing_screen.gd:221[/code]），「保存并返回」那条路各一条。[br]
## [br][b]机制（探针实测，不是推断）[/b]：这几种屏的 [code]_input[/code] 结构都是
## 「先问导航器 → 导航器里发出 [code]request_scene_change[/code] → 转场管线调
## [code]change_scene_to_file[/code]」。而该调用[b]当场[/b]就把旧场景从树上摘下来——
## 探针输出：转场前 [code]inside_tree=true viewport=true[/code]，同帧转场后
## [code]inside_tree=false viewport=false[/code]（对象仍在，只是已离树）。
## 控制权回到 [code]_input[/code] 的下一行时，[code]get_viewport()[/code] 已经是
## [code]null[/code]。引擎对「已离树的 Control」照样派发这次事件（它此刻仍在派发栈上），
## 所以这条路每次按 Esc 都会走到。[br]
## [br][b]为什么是对外可感的缺陷[/b]：玩家侧无感（转场照常发生），但控制台红字会淹掉
## 真问题；且它是「拿已失效的节点继续操作」这一类写法里最容易复现的一个样本
## ——[code]cultivation_screen[/code] / [code]shop_screen[/code] 同构，用的是同一个
## 包装。[br]
## [br][b]修法[/b]：消费走 [method UiInputConsume.mark_handled]（空安全包装）。
## 本文件同时钉住「包装没改变正向行为」——在树的节点照样能把事件标记为已处理。[br]
##
## 来源: 2026-11-25 真机走查第三轮、[code]src/ui/shared/ui_input_consume.gd[/code]。

const ConsumeScript := preload("res://src/ui/shared/ui_input_consume.gd")


# ═══════════════════════════════════════════════════════════════════════════════
# 1：包装本身——在树时照常消费
# ═══════════════════════════════════════════════════════════════════════════════

func test_consume_marks_handled_when_node_is_in_tree() -> void:
	# Arrange——一个真在树上的控件
	var node := Control.new()
	add_child_autofree(node)
	# Act
	ConsumeScript.mark_handled(node)
	# Assert——正向行为不变（不是「为了不报错就什么都不做」）
	assert_true(node.get_viewport().is_input_handled(),
			"在树上的节点应把这次输入标记为已处理（消费语义原样保留）")


func test_consume_is_noop_when_node_has_no_viewport() -> void:
	# Arrange——一个从未进树的控件（get_viewport() 为 null，同「已离树」）
	var node := Control.new()
	autofree(node)
	assert_null(node.get_viewport(), "前置：未进树的控件没有 viewport")
	# Act + Assert——不抛错（旧写法在这里报 null 方法调用）
	ConsumeScript.mark_handled(node)


func test_consume_tolerates_null_node() -> void:
	# Act——null 入参（转场后调用方可能连节点引用都失效了）
	ConsumeScript.mark_handled(null)
	# Assert——没有留下引擎错误（旧写法在这里报 null 方法调用，GUT 判为失败）
	assert_false(_engine_error_seen(), "null 入参不得留下引擎错误")


# ═══════════════════════════════════════════════════════════════════════════════
# 2：真实屏——Esc 走到转场之后，本屏已离树，仍不得报错
# ═══════════════════════════════════════════════════════════════════════════════

func test_deck_editing_esc_after_leaving_tree_does_not_error() -> void:
	# Arrange——挂上界面，然后把它摘出树（= 转发场景被 change_scene_to_file 摘走的
	## 那一瞬；对象仍在，只是 get_viewport() 已经是 null）
	seed_collection()
	seed_deck()
	mount_screen()
	assert_not_null(screen.get_viewport(), "前置：进树后的界面有 viewport")
	remove_child(screen)
	assert_null(screen.get_viewport(), "前置：离树后取不到 viewport（本用例的要害）")
	# Act——真按 Esc（界面读的就是这个动作），导航器会发出转场请求
	screen._input(action_event(&"ui_cancel"))
	# Assert——转场照旧发出（修的是崩溃，不是把这条路堵死）
	assert_eq(sm.requests.size(), 1, "Esc 的返回请求仍应发出（离树只是消费不了事件）")
	# 旧写法在这里会 push 一条 null 方法调用的引擎错误，GUT 默认把引擎错误判为失败
	# ——故本用例在修复前必红，无需额外断言。


# ═══════════════════════════════════════════════════════════════════════════════
# 3：「保存并返回」同一条路（另一个调用点，同一个失效窗口）
# ═══════════════════════════════════════════════════════════════════════════════

func test_deck_editing_save_exit_after_leaving_tree_does_not_error() -> void:
	# Arrange——同上，离树后点「保存并返回」
	seed_collection()
	seed_deck()
	mount_screen()
	remove_child(screen)
	# Act——真实出口（写盘 + 转场；写盘走本用例组的测试存档目录）
	screen.call(&"_on_save_exit_pressed")
	# Assert——转场照旧发出
	assert_eq(sm.requests.size(), 1, "「保存并返回」的转场请求仍应发出")


# ═══════════════════════════════════════════════════════════════════════════════
# 小工具
# ═══════════════════════════════════════════════════════════════════════════════

## 本用例期间是否留下过引擎级错误（GUT 的 [code]treat_engine_errors_as[/code] 口径）。
## [br][br][b]为什么不消费[/b]：计数即可——消费掉会让 GUT 自己的失败判定失去依据。
func _engine_error_seen() -> bool:
	for err: Variant in gut.error_tracker.get_errors_for_test():
		if err.is_engine_error():
			return true
	return false
