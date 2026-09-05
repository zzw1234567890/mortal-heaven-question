extends RefCounted
## GSMNarrativeWrites —— 叙事域原子写入子模块（从 gsm_atomic_writes.gd 拆分）。
##
## RefCounted 子模块——持有 `_gsm: Node` 引用。
## 包含 narrative.* 域的原子写入方法。
##
## [br]来源: ADR-0026 §GSM 第二层新增方法。
## [br]Sprint 12 Story 012：从 gsm_atomic_writes.gd 拆分。


var _gsm: Node = null


func _init(gsm: Node = null) -> void:
	_gsm = gsm


## 追加必经事件完成——写入 narrative.current_chapter_progress.completed_required_events（ADR-0026）。
func add_required_event_completion(event_id: StringName) -> void:
	var progress: Dictionary = _gsm.narrative.get("current_chapter_progress", {})
	if progress.is_empty():
		progress = {"completed_required_events": [], "boss_unlocked": false, "boss_defeated": false, "ending_chosen": ""}
		_gsm.narrative["current_chapter_progress"] = progress

	var events: Array = progress.get("completed_required_events", [])
	if events.has(event_id):
		return  # 去重

	var old_events: Array = events.duplicate()
	events.append(event_id)
	progress["completed_required_events"] = events
	_gsm._buffer_change("narrative.current_chapter_progress.completed_required_events", old_events, events)


## 原子写入 BOSS 解锁状态——仅 StorySystem 调用（ADR-0026）。
func set_narrative_boss_unlocked(value: bool) -> void:
	var progress: Dictionary = _gsm.narrative.get("current_chapter_progress", {})
	if progress.is_empty():
		progress = {"completed_required_events": [], "boss_unlocked": false, "boss_defeated": false, "ending_chosen": ""}
		_gsm.narrative["current_chapter_progress"] = progress

	var old_val: bool = bool(progress.get("boss_unlocked", false))
	if old_val == value:
		return

	progress["boss_unlocked"] = value
	_gsm._buffer_change("narrative.current_chapter_progress.boss_unlocked", old_val, value)


## 原子写入 BOSS 击败状态——仅 StorySystem 调用（ADR-0026）。
func set_narrative_boss_defeated(value: bool) -> void:
	var progress: Dictionary = _gsm.narrative.get("current_chapter_progress", {})
	if progress.is_empty():
		progress = {"completed_required_events": [], "boss_unlocked": false, "boss_defeated": false, "ending_chosen": ""}
		_gsm.narrative["current_chapter_progress"] = progress

	var old_val: bool = bool(progress.get("boss_defeated", false))
	if old_val == value:
		return

	progress["boss_defeated"] = value
	_gsm._buffer_change("narrative.current_chapter_progress.boss_defeated", old_val, value)


## 原子写入结局分支选择——仅 StorySystem 调用（ADR-0026）。
func set_ending_chosen(branch_id: StringName) -> void:
	var progress: Dictionary = _gsm.narrative.get("current_chapter_progress", {})
	if progress.is_empty():
		progress = {"completed_required_events": [], "boss_unlocked": false, "boss_defeated": false, "ending_chosen": ""}
		_gsm.narrative["current_chapter_progress"] = progress

	var old_val: String = str(progress.get("ending_chosen", ""))
	if old_val == str(branch_id):
		return

	progress["ending_chosen"] = str(branch_id)
	_gsm._buffer_change("narrative.current_chapter_progress.ending_chosen", old_val, str(branch_id))


## story_flags 写入——仅 EventSystem.set_flag() 调用（ADR-0003 唯一写入者契约）。
func set_narrative_flag(flag: StringName, value: Variant) -> void:
	var old: Variant = _gsm.narrative.story_flags.get(flag, null)
	if old == value:
		return
	_gsm.narrative.story_flags[flag] = value
	_gsm._buffer_change("narrative.story_flags.%s" % flag, old, value)


## 推进章节——写入 narrative.current_chapter + completed_chapters。
func advance_chapter(chapter_id: StringName) -> void:
	var chapter_str: String = str(chapter_id)
	if chapter_str.is_empty():
		push_warning("GSM.advance_chapter: chapter_id 为空，拒绝写入")
		return

	var old_current: String = _gsm.narrative.current_chapter
	if old_current == chapter_str:
		return  # 相同章节——去重

	var old_completed: Array = _gsm.narrative.completed_chapters.duplicate()
	if not old_current.is_empty():
		_gsm.narrative.completed_chapters.append(old_current)

	_gsm.narrative.current_chapter = chapter_str
	_gsm._buffer_change("narrative.current_chapter", old_current, chapter_str)
	_gsm._buffer_change("narrative.completed_chapters", old_completed, _gsm.narrative.completed_chapters)
