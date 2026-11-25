class_name UiInputConsume
extends RefCounted
## UiInputConsume —— 「消费这次输入」的空安全包装（全 UI 屏共用）。[br]
## [br][b]为什么不直接写 [method Viewport.set_input_as_handled][/b]：那几个屏的处理
## 链里可能[b]中途把自己拆掉[/b]。最典型的是「取消键 = 返回」——[code]_input[/code]
## 里经导航器调到 [method SceneManager.request_scene_change]，而
## [code]change_scene_to_file[/code] 会立刻把当前场景从树上摘走；等控制权回到
## [code]_input[/code] 的下一行，本节点已不在树里，[method Node.get_viewport]
## 返回 [code]null[/code]，于是 [code]null.set_input_as_handled()[/code] 抛
## [code]Cannot call method 'set_input_as_handled' on a null value[/code]
## ——真机走查现场：卡组编辑屏按 Esc 返回，转场其实成功了，但每按一次都在控制台
## 留一条红字（[code]deck_editing_screen.gd[/code] 的 Esc / 「保存并返回」两条路
## 各一条）。[br]
## [br][b]只做这一件事[/b]：[code]null[/code] 时不抛错。事件本身早已被处理过
## ——转场一旦发出，这次输入的去向也已定，没消费成就没消费成，不值得为它崩一帧。[br]
## [br][b]不静默吞别的错[/b]：不判类型、不 try/catch，只判 [code]null[/code]。
##
## 来源: 2026-11-25 真机走查（第三轮，卡组编辑 Esc 返回）。


## 把当前输入标记为已处理——节点已不在树上时安静跳过。[br]
## [br][param p_node] 发起消费的节点（通常是 [code]self[/code]）。
static func mark_handled(p_node: Node) -> void:
	if p_node == null:
		return
	var vp: Viewport = p_node.get_viewport()
	if vp == null:
		return
	vp.set_input_as_handled()
