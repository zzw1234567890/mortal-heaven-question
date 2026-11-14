extends RefCounted
## StoryChapterTemplates —— 剧情系统的[b]章节静态定义表[/b]（GDD §2 五章详细定义）。[br]
## [br][b]为什么单独一个文件[/b]：这张表是纯数据（约 142 行），与运行时编排逻辑
## 混居会让 [StorySystem] 越过 300 行软上限（.claude/docs/coding-standards.md）。
## 拆出后 [StorySystem] 只保留「查表 + 编排」，数据改动不必翻逻辑代码。[br]
## [br][b]零行为改动[/b]：[StorySystem.CHAPTER_TEMPLATES] 仍是同一个名字、同一份
## 内容——那边用 [code]const[/code] 别名指过来，调用方（
## [code]story_chapter_ops.gd[/code] / 既有测试的 [code]_story.CHAPTER_TEMPLATES[/code]）
## 逐字无感。[br]
## [br]来源: GDD story-system.md §2、ADR-0026 §决策 2、Story 6-11。

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
			"unlock_maps": [&"cang_xuan_zheng_dao_meng"],
		},
		"maps": [&"qing_yun_jian_zong", &"xue_yuan_mi_jing", &"yun_lan_cheng", &"dan_xia_gu"],
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
			"unlock_maps": [&"wan_gu_dian", &"xi_yu_gu_lin", &"xi_yu_bian_jing"],
		},
		"maps": [&"cang_xuan_zheng_dao_meng", &"cang_xuan_gu_zhan_chang", &"sui_xing_wai_huan", &"sui_xing_nei_hai"],
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
			"unlock_maps": [&"xi_yu_gu_lin", &"mu_lan_cao_yuan", &"gui_xu_tong_dao"],
		},
		"maps": [&"wan_gu_dian", &"xi_yu_gu_lin", &"xi_yu_bian_jing"],
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
			"unlock_maps": [&"gui_xu_fu_yun_lu", &"gui_xu_wan_yao_gu", &"gui_xu_gu_mo_zhan_chang"],
		},
		"maps": [&"xi_yu_gu_lin", &"mu_lan_cao_yuan", &"gui_xu_tong_dao"],
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
		"maps": [&"gui_xu_fu_yun_lu", &"gui_xu_wan_yao_gu", &"gui_xu_gu_mo_zhan_chang"],
	},
}
