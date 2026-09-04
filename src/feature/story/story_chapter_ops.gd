extends RefCounted
## StoryChapterOps —— 章节完成/BOSS 解锁编排子模块（从 story_system.gd 拆分）。
##
## 持有对 StorySystem 父节点的引用，通过它访问 CHAPTER_TEMPLATES /
## _get_gsm / is_boss_unlocked 等状态和方法。
##
## [br]来源: ADR-0026 §决策 1/4 + GDD story-system.md §3/§4。
## [br]Sprint 10 Story 5：从 story_system.gd 拆分。

## 父节点引用——StorySystem Autoload 实例。
var _parent: Node = null


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


## 完成当前章节——编排结局分支 flag 设置 + chapter_progress 重置 + 推进下一章（ADR-0026）。[br]
## [br][param branch_id] 玩家选择的结局分支 ID。[br]
## [br][b]返回[/b]: [code]true[/code] 成功完成；[code]false[/code] 条件不满足。[br]
## [br][b]前置条件[/b]: boss_defeated=true 且 ending_chosen 非空。[br]
## [br][b]流程[/b]: 校验前置→查分支 flag→委托 EventSystem 写 story_flags→追加 completed_chapters→推进下一章→发射信号。[br]
## [br]来源: ADR-0026 §决策 1 + GDD §4。
func complete_chapter(branch_id: StringName) -> bool:
	var gsm: Node = _parent.call("_get_gsm")
	if gsm == null:
		return false

	var narrative: Dictionary = gsm.narrative
	var progress: Dictionary = narrative.get("current_chapter_progress", {})

	# 1. 校验前置条件——BOSS 已击败
	if not bool(progress.get("boss_defeated", false)):
		return false

	# 2. 校验前置条件——结局已选择
	var ending: String = str(progress.get("ending_chosen", ""))
	if ending.is_empty():
		return false

	var current_chapter: StringName = StringName(narrative.get("current_chapter", ""))
	var chapter_templates: Dictionary = _parent.get("CHAPTER_TEMPLATES")
	var chapter: Dictionary = chapter_templates.get(current_chapter, {})
	if chapter.is_empty():
		return false

	# 3. 查找结局分支，设置 story_flags（委托 EventSystem / GSM set_narrative_flag）
	var branches: Array = chapter.get("ending_branches", [])
	var found_branch: Dictionary = {}
	for b: Dictionary in branches:
		if str(b.get("branch_id", "")) == str(branch_id):
			found_branch = b
			break
	if found_branch.is_empty():
		return false

	var flags_to_set: Dictionary = found_branch.get("flag_to_set", {})
	for flag: StringName in flags_to_set:
		gsm.set_narrative_flag(flag, flags_to_set[flag])

	# 4. 追加当前章节到 completed_chapters
	var completed: Array = narrative.get("completed_chapters", [])
	if not completed.has(current_chapter):
		completed.append(current_chapter)
		narrative["completed_chapters"] = completed
		gsm._buffer_change("narrative.completed_chapters", completed.duplicate(), completed)

	# 5. 推进下一章或触发通关
	var next_chapter: StringName = chapter["completion"]["unlock_next_chapter"]
	var is_final: bool = str(next_chapter).is_empty()

	if is_final:
		# 最终章——发射 game_victory 而非 chapter_completed
		_emit_safe(&"game_victory", [])
		return true

	# 推进到下一章
	gsm.advance_chapter(next_chapter)
	# 重置 chapter_progress
	var new_progress: Dictionary = {
		"completed_required_events": [],
		"boss_unlocked": false,
		"boss_defeated": false,
		"ending_chosen": "",
	}
	var old_progress: Dictionary = narrative.get("current_chapter_progress", {}).duplicate()
	narrative["current_chapter_progress"] = new_progress
	gsm._buffer_change("narrative.current_chapter_progress", old_progress, new_progress)

	# 发射 chapter_completed Cat 2b 信号
	_emit_safe(&"chapter_completed", [current_chapter, branch_id])

	return true


## 检查当前章节 BOSS 是否已解锁——所有必经事件完成时自动解锁（GDD §公式 2）。[br]
## [br][b]返回[/b]: [code]true[/code] 所有必经事件已完成；[code]false[/code] 未全部完成或无当前章节。[br]
## [br]来源: ADR-0026 §关键接口 is_boss_unlocked + GDD §公式 2。
func is_boss_unlocked() -> bool:
	var gsm: Node = _parent.call("_get_gsm")
	if gsm == null:
		return false

	var current_chapter: StringName = StringName(gsm.narrative.get("current_chapter", ""))
	if str(current_chapter).is_empty():
		return false

	var chapter_templates: Dictionary = _parent.get("CHAPTER_TEMPLATES")
	var chapter: Dictionary = chapter_templates.get(current_chapter, {})
	if chapter.is_empty():
		return false

	var required_events: Array = chapter.get("required_events", [])
	if required_events.is_empty():
		return true  # 无必经事件——自动解锁

	var progress: Dictionary = gsm.narrative.get("current_chapter_progress", {})
	var completed: Array = progress.get("completed_required_events", [])

	for event_id: StringName in required_events:
		if not completed.has(event_id):
			return false

	return true


## BOSS 击败处理——设置 boss_defeated=true 并发射 boss_unlocked 信号（ADR-0026）。[br]
## [br][b]前置条件[/b]: [method is_boss_unlocked] 返回 [code]true[/code]——必经事件已全部完成。[br]
## [br][b]流程[/b]: 校验解锁状态→写入 boss_defeated→发射 Cat 2b 信号。[br]
## [br]来源: ADR-0026 §关键接口 on_boss_defeated + GDD §3。
func on_boss_defeated() -> void:
	var gsm: Node = _parent.call("_get_gsm")
	if gsm == null:
		return

	# 1. 校验 BOSS 已解锁
	if not is_boss_unlocked():
		push_warning("StorySystem.on_boss_defeated: BOSS 尚未解锁，必经事件未全部完成")
		return

	# 2. 写入 boss_defeated=true
	gsm.set_narrative_boss_defeated(true)

	# 3. 发射 boss_unlocked Cat 2b 信号
	var current_chapter: StringName = StringName(gsm.narrative.get("current_chapter", ""))
	var chapter_templates: Dictionary = _parent.get("CHAPTER_TEMPLATES")
	var chapter: Dictionary = chapter_templates.get(current_chapter, {})
	var boss_id: StringName = StringName(str(chapter.get("chapter_boss", {}).get("boss_id", "")))
	_emit_safe(&"boss_unlocked", [current_chapter, boss_id])


## Cat 2b 信号安全发射——经 GSM._emit_signal_safe 路由（ADR-0007 信号链深度追踪）。[br]
## 信号 owner 为 _parent（StorySystem），而非子模块自身。
func _emit_safe(signal_name: StringName, args: Array) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		_parent.callv("emit_signal", [signal_name] + args)
		return
	var gsm = tree.root.get_node_or_null("/root/GameStateManager")
	if gsm != null and gsm.get_script().has_method("_emit_signal_safe"):
		gsm.get_script()._emit_signal_safe(_parent, signal_name, args)
	else:
		var call_args: Array = [signal_name]
		call_args.append_array(args)
		_parent.callv("emit_signal", call_args)
