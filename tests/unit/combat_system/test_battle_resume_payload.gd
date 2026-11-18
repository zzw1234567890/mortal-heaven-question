extends GutTest
## 续战载荷（[code]battle_resume_payload.gd[/code]）的纯函数验收。[br]
## [br][b]为什么需要[/b]：这层是「战斗中存档 → 读档回到战斗」的[b]形状定义[/b]
## ——写侧存什么、读侧怎么解释，全在这一个文件里。它错了，症状是「读档回到一场
## 血量不对 / 阶段不对的仗」，而那要到真机上才看得见。[br]
## [br][b]覆盖[/b]：[br]
##   1. [method build] 折出的键与值（进度 / 敌我名册 / 来源）；[br]
##   2. [b]JSON 安全[/b]：折出的载荷必须过 [code]SaveLoadSystem._is_json_compatible[/code]
##      ——带 [code]EnemyBattleState[/code] 对象或 StringName 的载荷会让整份存档
##      被判 [code]VALIDATION_ERROR[/code]（本轮最贵的一个坑）；[br]
##   3. 可续性判据（有探索来源）与不可续时的中文原因；[br]
##   4. 读侧解析（[code]player_stats[/code] / [code]player_layout[/code] /
##      [code]player_ids[/code] / [code]launch_context[/code]）与写侧逐项对应；[br]
##   5. [method is_in_battle] 只认标记位（读档侧「这份档在不在战斗中」的判据）。[br]
## [br]来源: ADR-0002 §存档容器、ADR-0008 §GSM 边界、本轮「战斗存档」任务。
##
## 本文件独占角色 ID 段 8601+。

const PayloadScript := preload("res://src/feature/combat/battle_resume_payload.gd")
const ContextScript := preload("res://src/feature/combat/combat_launch_context.gd")
const Seeding := preload("res://src/feature/combat/combat_roster_seeding.gd")
const SLS := preload("res://src/foundation/save_load_system.gd")

const CHAR_A: int = 8601
const CHAR_B: int = 8602
const ENEMY_A: int = Seeding.ENEMY_ID_BASE          # 100000（第 0 条）
const ENEMY_B: int = Seeding.ENEMY_ID_BASE + Seeding.ENEMY_ID_STRIDE  # 110000
const NODE_ID: int = 42


## 一份齐备的取数包（写侧 [code]CombatResumeCapture._gather[/code] 的形状）。[br]
## [br][b]阵位只用字典[/b]：[code]get_field()[/code] 的产出就是字典数组；
## [code]enemy_roster[/code] 用带 [code]template_id[/code] 的字典模拟
## [code]EnemyBattleState[/code]（对象与字典两种形态载荷模块都要吃得下）。
func _state() -> Dictionary:
	return {
		"scene_id": 4,
		"phase": 3,
		"turn": 5,
		"current_cost": 1,
		"max_cost": 4,
		"origin_node_id": NODE_ID,
		"origin_combat_type": "boss",
		"player_field": [
			{"slot_index": 0, "character_id": CHAR_A, "is_front": true},
			{"slot_index": 3, "character_id": CHAR_B, "is_front": false},
		],
		"player_hp": {
			CHAR_A: {"current_hp": 4, "max_hp": 12, "is_alive": true},
			CHAR_B: {"current_hp": 0, "max_hp": 9, "is_alive": false},
		},
		"enemy_roster": [
			{"template_id": &"san_xiu", "current_hp": 6, "max_hp": 16,
				"field_position": 0, "is_front_row": true, "is_alive": true},
			{"template_id": &"mo_xiu", "current_hp": 30, "max_hp": 30,
				"field_position": 1, "is_front_row": true, "is_alive": true},
		],
		"config": {
			"character_ids": [CHAR_A, CHAR_B],
			"enemy_template_ids": [&"san_xiu", &"mo_xiu"],
			"enemy_level": 2,
			"rewards": {"lingshi": 30},
			"enemy_roster": [{"runtime": "对象——不该进存档"}],
			"layout": [],
			"is_tribulation": false,
		},
	}


# ═══════════════════════════════════════════════════════════════════════════════
# 组装
# ═══════════════════════════════════════════════════════════════════════════════

func test_build_folds_progress_and_origin() -> void:
	var payload: Dictionary = PayloadScript.build(_state())
	assert_eq(int(payload[PayloadScript.KEY_PHASE]), 3, "阶段应如实落存档")
	assert_eq(int(payload[PayloadScript.KEY_TURN]), 5, "回合应如实落存档")
	assert_eq(int(payload[PayloadScript.KEY_CURRENT_COST]), 1, "当前费用应如实落存档")
	assert_eq(int(payload[PayloadScript.KEY_MAX_COST]), 4, "费用上限应如实落存档")
	assert_eq(int(payload[PayloadScript.KEY_ORIGIN_NODE_ID]), NODE_ID, "来源节点应记住")
	assert_eq(str(payload[PayloadScript.KEY_ORIGIN_COMBAT_TYPE]), "boss",
			"战斗类型应记住（Boss 判定靠它）")
	assert_eq(int(payload[PayloadScript.KEY_SCENE_ID]), 4, "存档场景 ID 应记住")


## 我方名册以[b]阵位快照[/b]为准遍历——没上场但有 HP 记录的角色不该混进来
## （读档后会被重新摆上场，等于凭空多一名参战者）。
func test_build_player_roster_follows_field_not_hp_table() -> void:
	var state: Dictionary = _state()
	state["player_hp"][9999] = {"current_hp": 7, "max_hp": 7, "is_alive": true}
	var payload: Dictionary = PayloadScript.build(state)
	var ids: Array = PayloadScript.player_ids(payload)
	assert_eq(ids, [CHAR_A, CHAR_B], "只有上场的两名角色进载荷（9999 不在阵位上）")


func test_build_player_roster_keeps_hp_and_layout() -> void:
	var payload: Dictionary = PayloadScript.build(_state())
	var stats: Dictionary = PayloadScript.player_stats(payload)
	assert_eq(int(stats[CHAR_A]["current_hp"]), 4, "残血应如实落存档")
	assert_eq(int(stats[CHAR_A]["max_hp"]), 12, "HP 上限应如实落存档")
	assert_eq(PayloadScript.player_layout(payload), {CHAR_A: true, CHAR_B: false},
			"前后排应如实落存档（不给 layout，读档会把阵型重排一遍）")


func test_build_enemy_roster_derives_character_ids_from_slots() -> void:
	var payload: Dictionary = PayloadScript.build(_state())
	var enemy: Array = payload[PayloadScript.KEY_ENEMY_ROSTER]
	assert_eq(enemy.size(), 2, "两条敌人都应进载荷")
	assert_eq(int(enemy[0][PayloadScript.KEY_CHARACTER_ID]), ENEMY_A,
			"敌方 character_id 走与开战种子同一套编码（第 0 条 = 100000）")
	assert_eq(int(enemy[1][PayloadScript.KEY_CHARACTER_ID]), ENEMY_B,
			"第 1 条 = 110000")
	assert_eq(str(enemy[0][PayloadScript.KEY_TEMPLATE_ID]), "san_xiu",
			"模板 ID 落 String（StringName 往返会变 String，写侧就统一）")
	assert_eq(int(enemy[0][PayloadScript.KEY_CURRENT_HP]), 6, "敌方残血应如实落存档")
	assert_eq(int(enemy[1][PayloadScript.KEY_SLOT_INDEX]), 1, "敌方阵位应如实落存档")


## 载荷必须过存档那一关的类型校验——带对象 / StringName 的载荷会让[b]整份[/b]存档
## 被判 VALIDATION_ERROR（连探索进度一起写不进去）。
func test_build_output_is_json_compatible() -> void:
	var payload: Dictionary = PayloadScript.build(_state())
	assert_true(SLS._is_json_compatible(payload),
			"折出的载荷必须只含 JSON 兼容类型（对象与 StringName 都要被折叠掉）")
	var config: Dictionary = payload[PayloadScript.KEY_CONFIG]
	assert_false(config.has("enemy_roster"),
			"开战配置按白名单折叠——带运行时对象的键不进存档")
	assert_eq(str(config["enemy_template_ids"][0]), "san_xiu",
			"白名单内的模板 ID 要落成 String")


func test_build_returns_empty_when_not_resumable() -> void:
	var state: Dictionary = _state()
	state["origin_node_id"] = -1
	state["origin_combat_type"] = ""
	assert_eq(PayloadScript.build(state), {},
			"没有探索来源（渡劫等）时不写载荷——写一份读不回来的档比不写更糟")


# ═══════════════════════════════════════════════════════════════════════════════
# 可续性判据
# ═══════════════════════════════════════════════════════════════════════════════

func test_is_resumable_accepts_node_id_or_combat_type() -> void:
	assert_true(PayloadScript.is_resumable({"origin_node_id": 3, "origin_combat_type": ""}),
			"有节点 ID 即可续")
	assert_true(PayloadScript.is_resumable({"origin_node_id": -1, "origin_combat_type": "boss"}),
			"有战斗类型即可续")
	assert_false(PayloadScript.is_resumable({"origin_node_id": -1, "origin_combat_type": ""}),
			"两者都没有 = 没有探索来源")


func test_reason_gives_chinese_text_only_when_not_resumable() -> void:
	assert_eq(PayloadScript.reason({"origin_node_id": NODE_ID}), "",
			"可续时没有原因文案（调用方据此决定不提示）")
	var reason: String = PayloadScript.reason({"origin_node_id": -1, "origin_combat_type": ""})
	assert_true(reason.contains("无法续玩"), "不可续时给中文原因（需求 D：提示不静默）")


# ═══════════════════════════════════════════════════════════════════════════════
# 读侧解析
# ═══════════════════════════════════════════════════════════════════════════════

func test_is_in_battle_checks_marker_only() -> void:
	assert_true(PayloadScript.is_in_battle(PayloadScript.build(_state())),
			"写过的载荷 = 这份档在战斗中")
	assert_false(PayloadScript.is_in_battle({}), "空段 = 没有进行中的战斗")
	assert_false(PayloadScript.is_in_battle(null), "非字典一律按没有处理")


func test_is_resumable_payload_requires_both_rosters() -> void:
	var payload: Dictionary = PayloadScript.build(_state())
	assert_true(PayloadScript.is_resumable_payload(payload), "齐备的载荷可续")
	var no_enemy: Dictionary = payload.duplicate(true)
	no_enemy[PayloadScript.KEY_ENEMY_ROSTER] = []
	assert_false(PayloadScript.is_resumable_payload(no_enemy),
			"敌方名册为空 = 残载荷（重建只会得到一场判不出胜负的战斗）")
	assert_false(PayloadScript.is_resumable_payload({}),
			"空段不可续（老档走这条）")
	assert_true(PayloadScript.payload_reason(payload).is_empty(),
			"可续载荷没有原因文案")
	assert_false(PayloadScript.payload_reason(no_enemy).is_empty(),
			"残载荷要给中文说明")


func test_launch_context_keeps_origin_and_templates() -> void:
	var payload: Dictionary = PayloadScript.build(_state())
	var context: Dictionary = PayloadScript.launch_context(payload)
	assert_eq(int(context.get(ContextScript.KEY_NODE_ID, -1)), NODE_ID,
			"续战要经既有开战链，来源节点必须折回上下文")
	assert_eq(str(context.get(ContextScript.KEY_COMBAT_TYPE, "")), "boss",
			"战斗类型同样折回（Boss 判定读它）")
	assert_eq(int(context.get(ContextScript.KEY_ENEMY_LEVEL, -1)), 2,
			"节点档位折回（难度缩放的输入）")
	assert_eq(context.get(ContextScript.KEY_PLAYER_ROSTER, []), [CHAR_A, CHAR_B],
			"玩家阵容折回（战斗场景的开战校验要它非空）")
	assert_true(ContextScript.validate(context).is_empty(),
			"折回的上下文必须过开战契约校验（否则读档进不了战斗）")
