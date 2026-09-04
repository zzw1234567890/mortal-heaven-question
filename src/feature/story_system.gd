extends Node
## StorySystem —— 剧情系统 Autoload #25（ADR-0026）。
##
## Feature 层 Autoload。持有 5 章静态定义 const Dictionary（CHAPTER_TEMPLATES）[br]
## 和章节推进逻辑。运行时叙事状态通过 GSM narrative.* 域持久化。[br]
## StorySystem 是 current_chapter / chapter_progress / completed_chapters 的[br]
## 独占运行时写入者（story_flags 除外——委托 EventSystem）。[br]
## [br][b]Story 6-11 范围[/b]：CHAPTER_TEMPLATES const Dictionary + 5 章数据。[br]
## [br][b]Story 6-12 范围[/b]：can_enter_chapter + get_chapter_context。[br]
## [br][b]Story 6-13 范围[/b]：complete_chapter + GSM narrative.* 独占写入 + Cat 2b 信号。[br]
## [br][b]Story 6-14 范围[/b]：is_boss_unlocked + on_boss_defeated。[br]
## [br]来源: ADR-0026 §决策 1/2/4 / GDD story-system.md §2/§4/§6/§公式2。

## 章节完成编排子模块（惰性初始化，Sprint 10 Story 5 拆分）。
var _chapter_ops: RefCounted = null


# === 章节模板（const Dictionary——编译时常量，运行时只读）==================

## 5 章静态定义（GDD §2 五章详细定义）。[br]
## 键 = 章节 ID（StringName），值 = 章节数据 Dictionary。[br]
## [br]每个章节含：chapter_number / title / subtitle / entry_conditions /[br]
## required_events / chapter_boss / ending_branches / completion / maps。[br]
## [br]来源: GDD story-system.md §2 + ADR-0026 §决策 2。
const CHAPTER_TEMPLATES: Dictionary = {
	# 第一话：青云入世（炼气期）
	&"ch1_qixuan": {
		"chapter_number": 1,
		"title": "第一话：青云入世",
		"subtitle": "仙途问道之始",
		"entry_conditions": {
			"min_realm": 1,
			"prev_chapter_completed": false,
			"required_flags": [],
		},
		"required_events": [
			&"ch1_event_1_trial",
			&"ch1_event_2_su_jianming",
			&"ch1_event_3_blood_trial",
			&"ch1_event_4_mo_duoshe",
			&"ch1_event_5_join_danxia",
		],
		"chapter_boss": {"boss_id": &"mo_yuan_possessed"},
		"ending_branches": [
			{"branch_id": &"ch1_accept_mo", "label": "接受墨渊的提议", "flag_to_set": {&"ch1_accepted_mo_condition": true}},
			{"branch_id": &"ch1_reject_mo", "label": "拒绝墨渊", "flag_to_set": {&"ch1_accepted_mo_condition": false}},
		],
		"completion": {
			"unlock_next_chapter": &"ch2_luanxinghai",
			"unlock_maps": [&"cang_xuan_zhengdao_meng"],
		},
		"maps": [&"qing_yun_jian_zong", &"xue_yuan_mi_jing", &"yueguo_capital", &"dan_xia_gu"],
	},
	# 第二话：碎星流亡（筑基期）——最长章节
	&"ch2_luanxinghai": {
		"chapter_number": 2,
		"title": "第二话：碎星流亡",
		"subtitle": "绝境求生",
		"entry_conditions": {
			"min_realm": 2,
			"prev_chapter_completed": true,
			"required_flags": [],
		},
		"required_events": [
			&"ch2_event_1_zhengmo_evere",
			&"ch2_event_2_zhengmo_battle",
			&"ch2_event_3_realm_drop",
			&"ch2_event_4_flee_suixing",
			&"ch2_event_5_suixing_outer",
			&"ch2_event_6_rebuild_foundation",
			&"ch2_event_7_suixing_inner",
			&"ch2_event_8_kugu_lair",
		],
		"chapter_boss": {"boss_id": &"kugu_laozu_remnant"},
		"ending_branches": [
			{"branch_id": &"ch2_take_bone", "label": "夺取玄骨秘宝", "flag_to_set": {&"ch2_took_bone_secret": true}},
			{"branch_id": &"ch2_destroy_lair", "label": "摧毁洞府", "flag_to_set": {&"ch2_took_bone_secret": false}},
		],
		"completion": {
			"unlock_next_chapter": &"ch3_tiannan",
			"unlock_maps": [&"wan_gu_dian", &"dajin_gulin", &"dajin_bianjing"],
		},
		"maps": [&"cang_xuan_zhengdao_meng", &"cang_xuan_guzhanchang", &"suixing_waihuan", &"suixing_neihai"],
	},
	# 第三话：苍玄之争（金丹期）
	&"ch3_tiannan": {
		"chapter_number": 3,
		"title": "第三话：苍玄之争",
		"subtitle": "正魔之争",
		"entry_conditions": {
			"min_realm": 3,
			"prev_chapter_completed": true,
			"required_flags": [],
		},
		"required_events": [
			&"ch3_event_1_wangu_duo_bao",
			&"ch3_event_2_dajin_youli",
			&"ch3_event_3_mulan_chongtu",
			&"ch3_event_4_zhengmo_xuanze",
		],
		"chapter_boss": {"boss_id": &"faction_boss"},
		"ending_branches": [
			{"branch_id": &"ch3_join_demonic", "label": "加入魔道统一东域", "flag_to_set": {&"ch3_joined_demonic": true}},
			{"branch_id": &"ch3_defend_righteous", "label": "坚守正道护卫东域", "flag_to_set": {&"ch3_joined_demonic": false}},
			{"branch_id": &"ch3_neutral_mediate", "label": "中立调停", "flag_to_set": {&"ch3_joined_demonic": false, &"ch3_neutral": true}},
		],
		"completion": {
			"unlock_next_chapter": &"ch4_lingsheng",
			"unlock_maps": [&"xiyu", &"mulan_caoyuan", &"guixu_tongdao"],
		},
		"maps": [&"wan_gu_dian", &"dajin_gulin", &"dajin_bianjing"],
	},
	# 第四话：归墟飞升（元婴期）
	&"ch4_lingsheng": {
		"chapter_number": 4,
		"title": "第四话：归墟飞升",
		"subtitle": "新的天地",
		"entry_conditions": {
			"min_realm": 4,
			"prev_chapter_completed": true,
			"required_flags": [],
		},
		"required_events": [
			&"ch4_event_1_dajin_jiaoshe",
			&"ch4_event_2_mulan_fazheng",
			&"ch4_event_3_guixu_open",
			&"ch4_event_4_meet_yingling",
		],
		"chapter_boss": {"boss_id": &"guixu_guardian_beast"},
		"ending_branches": [
			{"branch_id": &"ch4_solo_ascend", "label": "独自飞升", "flag_to_set": {&"ch4_took_yinyue": false}},
			{"branch_id": &"ch4_bring_yinyue", "label": "带银翎一起飞升", "flag_to_set": {&"ch4_took_yinyue": true}},
		],
		"completion": {
			"unlock_next_chapter": &"ch5_lingjie",
			"unlock_maps": [&"guixu_fuyun_lu", &"guixu_wanyao_gu", &"guixu_gumo_zhanchang"],
		},
		"maps": [&"xiyu", &"mulan_caoyuan", &"guixu_tongdao"],
	},
	# 第五话：归墟征途（化神期）——最终章
	&"ch5_lingjie": {
		"chapter_number": 5,
		"title": "第五话：归墟征途",
		"subtitle": "仙途问道",
		"entry_conditions": {
			"min_realm": 5,
			"prev_chapter_completed": true,
			"required_flags": [],
		},
		"required_events": [
			&"ch5_event_1_guixu_liche",
			&"ch5_event_2_gezu_fenzheng",
			&"ch5_event_3_gumo_jijie",
		],
		"chapter_boss": {"boss_id": &"gumo_final_form"},
		"ending_branches": [
			{"branch_id": &"ch5_ascend_immortal", "label": "飞升仙界", "flag_to_set": {&"ch5_ending": &"ascend"}},
			{"branch_id": &"ch5_guard_guixu", "label": "留在归墟守护", "flag_to_set": {&"ch5_ending": &"guard"}},
			{"branch_id": &"ch5_return_dongyu", "label": "回归东域", "flag_to_set": {&"ch5_ending": &"return"}},
		],
		"completion": {
			"unlock_next_chapter": &"",  # 最终章无下一章
			"unlock_maps": [],
		},
		"maps": [&"guixu_fuyun_lu", &"guixu_wanyao_gu", &"guixu_gumo_zhanchang"],
	},
}


# === 章节模板查询 API（Story 6-11）==========================================

## 获取章节模板数据。[br]
## [br][param chapter_id] 章节 ID。[br]
## [br][b]返回[/b]: 章节数据 Dictionary，无效 ID 返回空字典。[br]
## [br]来源: ADR-0026 §关键接口 get_chapter_data。
func get_chapter_data(chapter_id: StringName) -> Dictionary:
	return CHAPTER_TEMPLATES.get(chapter_id, {})


## 获取全部章节 ID 列表（按章节序号排序）。[br]
## [br][b]返回[/b]: Array[StringName]——5 个章节 ID。[br]
## [br]来源: ADR-0026 §关键接口。
func get_all_chapter_ids() -> Array:
	var ids: Array = CHAPTER_TEMPLATES.keys()
	ids.sort_custom(func(a, b): return int(CHAPTER_TEMPLATES[a]["chapter_number"]) < int(CHAPTER_TEMPLATES[b]["chapter_number"]))
	return ids


# === 章节进入条件验证（Story 6-12）============================================

## 章节进入条件验证——境界+前置章节+flag 三重校验（GDD §公式 1）。[br]
## [br][param chapter_id] 目标章节 ID。[br]
## [br][b]返回[/b]: {allowed: bool, reason: String}——allowed=true 时 reason 为空。[br]
## [br][b]流程[/b]: 查模板→境界校验→前置章节校验→flag 校验。[br]
## [br]来源: ADR-0026 §决策 4 + GDD §公式 1。
func can_enter_chapter(chapter_id: StringName) -> Dictionary:
	var chapter: Dictionary = CHAPTER_TEMPLATES.get(chapter_id, {})
	if chapter.is_empty():
		return {"allowed": false, "reason": "未知章节: " + str(chapter_id)}

	var gsm: Node = _get_gsm()
	if gsm == null:
		return {"allowed": false, "reason": "GSM 不可用"}

	var entry: Dictionary = chapter["entry_conditions"]

	# 1. 境界校验
	var min_realm: int = int(entry["min_realm"])
	var current_realm: int = int(gsm.player.get("realm", 1))
	if current_realm < min_realm:
		return {"allowed": false, "reason": "需要达到境界 L%d" % min_realm}

	# 2. 前置章节校验
	if bool(entry.get("prev_chapter_completed", false)):
		var prev_chapter: StringName = _get_prev_chapter_id(chapter_id)
		var completed: Array = gsm.narrative.get("completed_chapters", [])
		if not completed.has(prev_chapter):
			var prev_data: Dictionary = CHAPTER_TEMPLATES.get(prev_chapter, {})
			var prev_title: String = str(prev_data.get("title", str(prev_chapter)))
			return {"allowed": false, "reason": "需要先完成「" + prev_title + "」"}

	# 3. flag 前置校验
	var required_flags: Array = entry.get("required_flags", [])
	var story_flags: Dictionary = gsm.narrative.get("story_flags", {})
	for flag: StringName in required_flags:
		if not bool(story_flags.get(flag, false)):
			return {"allowed": false, "reason": "未满足剧情条件: " + str(flag)}

	return {"allowed": true, "reason": ""}


## 获取前一章节 ID（按 chapter_number 降序查找）。[br]
## [br][param chapter_id] 当前章节 ID。[br]
## [br][b]返回[/b]: 前一章节的 StringName，无前章时返回空 StringName。[br]
func _get_prev_chapter_id(chapter_id: StringName) -> StringName:
	var chapter: Dictionary = CHAPTER_TEMPLATES.get(chapter_id, {})
	if chapter.is_empty():
		return &""
	var target_num: int = int(chapter["chapter_number"])
	for id: StringName in CHAPTER_TEMPLATES:
		if int(CHAPTER_TEMPLATES[id]["chapter_number"]) == target_num - 1:
			return id
	return &""


# === 章节上下文查询（Story 6-12）============================================

## 获取地图对应的章节上下文——供 ExplorationSystem 过滤事件池（GDD §6）。[br]
## [br][param map_id] 地图 ID。[br]
## [br][b]返回[/b]: {chapter_id, required_events, maps}——未知地图返回空字典。[br]
## [br]来源: ADR-0026 §关键接口 get_chapter_context + GDD §6。
func get_chapter_context(map_id: StringName) -> Dictionary:
	for chapter_id: StringName in CHAPTER_TEMPLATES:
		var chapter: Dictionary = CHAPTER_TEMPLATES[chapter_id]
		var maps: Array = chapter.get("maps", [])
		if maps.has(map_id):
			return {
				"chapter_id": chapter_id,
				"required_events": chapter.get("required_events", []),
				"maps": maps,
			}
	return {}


# === 系统引用辅助 ==============================================================

## 获取 GSM 引用——通过 SceneTree Autoload。
func _get_gsm() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("/root/GameStateManager")


## 惰性获取章节编排子模块（Sprint 10 Story 5 拆分）。
func _get_chapter_ops() -> RefCounted:
	if _chapter_ops == null:
		_chapter_ops = load("res://src/feature/story/story_chapter_ops.gd").new(self)
	return _chapter_ops


# === 章节完成编排（Story 6-13）==============================================

## 章节完成信号——Cat 2b。ExplorationSystem 监听以解锁下一章地图。
signal chapter_completed(chapter_id: StringName, branch_id: StringName)

## BOSS 解锁信号——Cat 2b。探索 UI 监听。
signal boss_unlocked(chapter_id: StringName, boss_id: StringName)

## 章节开始信号——Cat 2b。UI 标题卡监听。
signal chapter_started(chapter_id: StringName)

## 通关信号——Cat 2b。第 5 章完成时替代 chapter_completed。
signal game_victory()


## 完成当前章节——编排结局分支 flag 设置 + chapter_progress 重置 + 推进下一章（ADR-0026）。
## [br][param branch_id] 玩家选择的结局分支 ID。[br]
## [br][b]返回[/b]: [code]true[/code] 成功完成；[code]false[/code] 条件不满足。[br]
## [br][b]前置条件[/b]: boss_defeated=true 且 ending_chosen 非空。[br]
## [br][b]流程[/b]: 校验前置→查分支 flag→委托 EventSystem 写 story_flags→追加 completed_chapters→推进下一章→发射信号。[br]
## [br]来源: ADR-0026 §决策 1 + GDD §4。
func complete_chapter(branch_id: StringName) -> bool:
	return _get_chapter_ops().complete_chapter(branch_id)


# === BOSS 解锁判定与击败处理（Story 6-14）==================================

## 检查当前章节 BOSS 是否已解锁——所有必经事件完成时自动解锁（GDD §公式 2）。[br]
## [br][b]返回[/b]: [code]true[/code] 所有必经事件已完成；[code]false[/code] 未全部完成或无当前章节。[br]
## [br]来源: ADR-0026 §关键接口 is_boss_unlocked + GDD §公式 2。
func is_boss_unlocked() -> bool:
	return _get_chapter_ops().is_boss_unlocked()


## BOSS 击败处理——设置 boss_defeated=true 并发射 boss_unlocked 信号（ADR-0026）。[br]
## [br][b]前置条件[/b]: [method is_boss_unlocked] 返回 [code]true[/code]——必经事件已全部完成。[br]
## [br][b]流程[/b]: 校验解锁状态→写入 boss_defeated→发射 Cat 2b 信号。[br]
## [br]来源: ADR-0026 §关键接口 on_boss_defeated + GDD §3。
func on_boss_defeated() -> void:
	_get_chapter_ops().on_boss_defeated()

