extends "res://tests/unit/combat_system/combat_scene_resume_fixture.gd"
## 读档续战的战斗侧落地验收（[code]combat_scene_resume.gd[/code]）。[br]
## [br][b]补的断链[/b]：存档里的续战段要变成[b]一场接着打的仗[/b]，中间这一段（取意图 →
## 折上下文 → 按存档重建 → 落位阶段/回合/费用）此前没有任何断言——它错了的症状是
## 「血量对、敌人都对，但回合与阶段被重置」，而那要到真机上按一遍才看得见。[br]
## [br][b]覆盖[/b]：[br]
##   1. 取意图时[b]折出开战上下文[/b]（读档进战斗靠它过开战守卫）；[br]
##   2. 重建顺序：布阵 → 写回敌方名册 → 开战 → 落位（顺序错了阵型会被重排、
##      落位会被开战覆盖）；[br]
##   3. 落位期间的自动推进开关：开战前关、落位后原样还原并重排调度；[br]
##   4. 我方 HP 种子与阵型取存档值（不过备战面板）；[br]
##   5. 守卫：战斗系统缺失 / 模板已不存在时给中文原因且不开战。[br]
## [br]装置见 [code]combat_scene_resume_fixture.gd[/code]（全替身，不跑真实战斗）。[br]
## [br]注：[code]PayloadScript[/code] / [code]ContextScript[/code] / [code]IntentScript[/code]
## 与角色 ID 段由夹具提供，此处不重复声明——GDScript 子类重复同名成员是解析错误，
## 整个文件会被 GUT 静默忽略。[br]
## [br]来源: ADR-0008 §GSM 边界、ADR-0017 §EnemyFactory、
## 本轮「战斗中存档 → 读档回到战斗」（B 项）。


# ═══════════════════════════════════════════════════════════════════════════════
# 取意图
# ═══════════════════════════════════════════════════════════════════════════════

func test_consume_folds_payload_into_launch_context() -> void:
	## 战斗场景的开战链只认 [code]CombatLaunchContext[/code]——不折上下文就进不去。
	# Arrange
	IntentScript.request(payload())
	# Act
	assert_true(resume.call(&"consume"), "有续战意图时应取到")
	# Assert——折出的上下文能过开战校验（否则场景侧停在开战失败）
	var context: Dictionary = ContextScript.peek()
	assert_true(ContextScript.validate(context).is_empty(),
			"折回的上下文必须过开战校验：%s" % ContextScript.validate(context))
	assert_eq(int(context[ContextScript.KEY_NODE_ID]), NODE_ID, "来源节点应折回")
	assert_eq(context[ContextScript.KEY_PLAYER_ROSTER], [CHAR_A, CHAR_B], "阵容应折回")
	# Assert——意图一次性
	assert_false(IntentScript.has_pending(), "取走即清（不会让下一场仗串到这一场）")
	assert_false(bool(resume.call(&"consume")), "第二次没有可取的（返回 false）")


func test_consume_without_intent_returns_false_and_publishes_nothing() -> void:
	# Arrange——没有任何意图（常规开战路径）
	# Act + Assert
	assert_false(bool(resume.call(&"consume")), "没有意图时应如实返回 false")
	assert_eq(ContextScript.peek(), {}, "不得凭空发布一份上下文（会盖掉探索侧那份）")


# ═══════════════════════════════════════════════════════════════════════════════
# 重建
# ═══════════════════════════════════════════════════════════════════════════════

func test_start_rebuilds_battle_from_saved_state() -> void:
	# Arrange
	IntentScript.request(payload())
	resume.call(&"consume")
	# Act
	var reason: String = resume.call(&"start", combat, root, interaction, deps(), 1)
	# Assert——重建成功
	assert_eq(reason, "", "重建不应有拒绝原因")
	# Assert——落位取的是存档值（回合 / 阶段 / 费用逐项）
	assert_eq(combat.turn, TURN, "回合应落回存档值")
	assert_eq(combat.phase, PHASE, "阶段应落回存档值")
	assert_eq(combat.cost, COST, "当前费用应落回存档值")
	assert_eq(combat.max_cost, MAX_COST, "费用上限应落回存档值")


## 顺序错了症状各异：布阵晚于开战 → 阵型被重排；落位早于开战 → 被开战的出厂值盖掉；
## 牌面接管早于开战 → 被 [code]battle_start[/code] 的发牌与状态表清空盖掉。
func test_start_orders_field_roster_then_launch_then_restore() -> void:
	# Arrange
	IntentScript.request(payload())
	resume.call(&"consume")
	# Act
	resume.call(&"start", combat, root, interaction, deps(), 1)
	# Assert——开战早于落位
	assert_true(combat.calls.has("battle_start"), "应开战")
	assert_true(combat.calls.has("restore"), "应落位")
	assert_lt(combat.calls.find("battle_start"), combat.calls.find("restore"),
			"落位必须在开战之后（否则被开战的出厂值覆盖）")
	assert_eq(deployment.setups.size(), 1, "应布阵一次")
	# Assert——布阵用的是存档阵容与阵型（不过备战面板，layout 必须带上）
	assert_eq(deployment.setups[0]["ids"], [CHAR_A, CHAR_B], "布阵阵容应取存档值")
	assert_eq(deployment.setups[0]["layout"], {CHAR_A: true, CHAR_B: false},
			"阵型应取存档值（不给 layout 会把玩家的前后排重排一遍）")
	# Assert——敌方名册写回 AI（不写回则敌方回合选不出目标）
	assert_eq(ai.roster_written.size(), 1, "敌方名册应写回 AISystem")
	assert_eq(int(ai.roster_written[0].get("current_hp")), ENEMY_HP,
			"写回的应是存档残血（满血重开等于白存）")


# ═══════════════════════════════════════════════════════════════════════════════
# 牌面接续（本轮：手牌 / 抽牌堆 / 弃牌堆按存档还原）
# ═══════════════════════════════════════════════════════════════════════════════

## 三堆牌逐 ID、逐顺序取存档值——顺序就是抽牌顺序，接错了等于换了一副牌。
func test_start_restores_three_piles_from_save() -> void:
	# Arrange
	IntentScript.request(payload())
	resume.call(&"consume")
	# Act
	resume.call(&"start", combat, root, interaction, deps(), 1)
	# Assert——三堆各自逐 ID 与顺序
	assert_eq(combat.hand, HAND_IDS, "手牌应按存档原样接管（顺序即存档顺序）")
	assert_eq(combat.draw_pile, DRAW_IDS, "抽牌堆应按存档原样接管")
	assert_eq(combat.discard_pile, DISCARD_IDS, "弃牌堆应按存档原样接管")


## 接管的时机必须在开战[b]之后[/b]：开战会按开局手牌发一轮牌，早于它的接管会被覆盖。
func test_start_restores_piles_after_battle_start() -> void:
	# Arrange
	IntentScript.request(payload())
	resume.call(&"consume")
	# Act
	resume.call(&"start", combat, root, interaction, deps(), 1)
	# Assert
	assert_true(combat.calls.has("restore_piles"), "应接管三堆牌")
	assert_lt(combat.calls.find("battle_start"), combat.calls.find("restore_piles"),
			"牌面接管必须在开战之后（否则被开局手牌覆盖）")


## 没有牌面快照的档（v3 老档经迁移补出的空形状）不得接管——接管会把刚发的开局手牌清空。
func test_start_without_card_snapshot_keeps_opening_hand() -> void:
	# Arrange——把牌面段换成空形状（老档迁移后的形态）
	var legacy: Dictionary = payload()
	legacy[CardsScript.KEY_CARDS] = {}
	IntentScript.request(legacy)
	resume.call(&"consume")
	# Act
	resume.call(&"start", combat, root, interaction, deps(), 1)
	# Assert——不接管（战斗照常，手牌是开战发的那一轮）
	assert_false(combat.calls.has("restore_piles"),
			"没有牌面快照时不得接管（照空数组接管会把开局手牌清成空手）")
	assert_true(combat.calls.has("battle_start"), "老档仍应能续战")


## 战斗系统不支持接管时的降级：不崩、不开空手，战斗照常（老实现的兼容半边）。
func test_start_without_pile_api_degrades_to_opening_hand() -> void:
	# Arrange——换成没有 [method restore_piles] 的替身（半截接线的实现）
	var legacy_combat: Node = Stubs.PilelessCombatStub.new()
	add_child_autofree(legacy_combat)
	IntentScript.request(payload())
	resume.call(&"consume")
	# Act
	var reason: String = resume.call(&"start", legacy_combat, root, interaction, deps(), 1)
	# Assert
	assert_eq(reason, "", "缺少牌面 API 不该阻断续战（缺的是牌面接续，不是整场仗）")
	assert_true(legacy_combat.calls.has("battle_start"), "战斗仍应开起来")


# ═══════════════════════════════════════════════════════════════════════════════
# debuff 接续（本轮：逐条灌回状态表）
# ═══════════════════════════════════════════════════════════════════════════════

## 存档里的 debuff 要逐条灌回——不灌的话 [code]battle_start[/code] 清表后凭空蒸发。
func test_start_restores_debuffs_into_state_table() -> void:
	# Arrange
	IntentScript.request(payload())
	resume.call(&"consume")
	# Act
	resume.call(&"start", combat, root, interaction, deps(), 1)
	# Assert——层数 / 剩余回合 / 数值三项都按存档落位
	var manager: RefCounted = (combat.roster as Stubs.RosterStub).debuff
	assert_eq(int(manager.call(&"get_stacks", DEBUFF_TARGET, DebuffManagerScript.TYPE_ATK)), 1,
			"存档里的一条降攻应还原成 1 层")
	assert_eq(int(manager.call(&"get_duration", DEBUFF_TARGET, DebuffManagerScript.TYPE_ATK)),
			DEBUFF_DURATION, "剩余回合应取存档值")
	# Assert——数值真的作用到战斗取数上（不是只挂在表里）
	var base_atk: int = 20
	assert_eq(int(manager.call(&"get_atk_with_debuff", DEBUFF_TARGET, base_atk)),
			base_atk - DEBUFF_AMOUNT,
			"降攻应真的从攻击力里扣掉（挂上了但数值不生效等于没存）")


## debuff 接续同样必须在开战之后——[code]battle_start[/code] 会清空状态表。
func test_start_applies_debuffs_after_battle_start() -> void:
	# Arrange
	IntentScript.request(payload())
	resume.call(&"consume")
	# Act
	resume.call(&"start", combat, root, interaction, deps(), 1)
	# Assert
	var manager: RefCounted = (combat.roster as Stubs.RosterStub).debuff
	assert_gt(int(manager.call(&"get_duration", DEBUFF_TARGET, DebuffManagerScript.TYPE_ATK)), 0,
			"debuff 必须在开战清表之后才灌回（早于开战会被清掉）")
	assert_lt(combat.calls.find("battle_start"), combat.calls.find("restore"),
			"前置：落位在开战之后（同一批接管的顺序口径）")


## 没有 debuff 快照的老档不得灌——空段表示「存档那一刻本来就没有 debuff」。
func test_start_without_debuff_snapshot_leaves_state_clean() -> void:
	# Arrange
	var legacy: Dictionary = payload()
	legacy[DebuffsScript.KEY_DEBUFFS] = []
	IntentScript.request(legacy)
	resume.call(&"consume")
	# Act
	resume.call(&"start", combat, root, interaction, deps(), 1)
	# Assert——表里没有凭空多出的 debuff
	var manager: RefCounted = (combat.roster as Stubs.RosterStub).debuff
	assert_eq(int(manager.call(&"get_stacks", DEBUFF_TARGET, DebuffManagerScript.TYPE_ATK)), 0,
			"老档读回来不应挂着任何 debuff（空段 = 当时没有）")


## 落位期间必须有自动推进关着——否则开战那一刻排下的推进会在落位前先跑掉一格。
func test_start_disables_auto_advance_during_restore_then_restores_it() -> void:
	# Arrange
	combat.auto_advance = true
	IntentScript.request(payload())
	resume.call(&"consume")
	# Act
	resume.call(&"start", combat, root, interaction, deps(), 1)
	# Assert——开关的进出轨迹
	assert_eq(combat.calls.find("auto=false"),
			combat.calls.find("battle_start") - 1,
			"应在开战前一步关掉自动推进")
	assert_lt(combat.calls.find("restore"), combat.calls.find("auto=true"),
			"应在落位[b]之后[/b]才恢复开关")
	# Assert——恢复之后还要重排调度（只改字段不排，玩家会停在永不推进的阶段里）
	assert_true(combat.calls.has("resume_auto"), "应显式恢复自动推进（排上下一格）")
	assert_true(combat.auto_advance, "开关最终应回到调用前的值")


func test_start_seeds_player_hp_from_save_not_template() -> void:
	# Arrange
	IntentScript.request(payload())
	resume.call(&"consume")
	# Act
	resume.call(&"start", combat, root, interaction, deps(), 1)
	# Assert——HP 种子取存档（比模板 base_hp 优先）
	var stats: Dictionary = combat.config.get("player_stats", {})
	assert_eq(int(stats[CHAR_A]["current_hp"]), 4, "我方残血应作为种子传入（不是满血）")
	assert_eq(int(stats[CHAR_A]["max_hp"]), 12, "HP 上限应取存档值")
	# Assert——开战配置里的阵容与模板也取存档
	assert_eq(combat.config.get("character_ids"), [CHAR_A, CHAR_B], "阵容取存档值")
	assert_eq(combat.config.get("enemy_level"), 2, "节点档位取存档值（难度缩放输入）")
	assert_eq(bool(combat.config.get("is_tribulation", true)), false,
			"续战不该被当成渡劫战（那条路没有探索来源）")


func test_start_builds_roster_cards_and_enables_interaction() -> void:
	# Arrange
	IntentScript.request(payload())
	resume.call(&"consume")
	# Act
	resume.call(&"start", combat, root, interaction, deps(), 1)
	# Assert——UI 侧跟上（建卡 + 放行出牌）
	assert_eq(root.built, [CHAR_A, CHAR_B], "战场应按存档阵容重建角色卡")
	assert_eq(interaction.enabled, 1, "重建后应放行出牌交互")


# ═══════════════════════════════════════════════════════════════════════════════
# 守卫
# ═══════════════════════════════════════════════════════════════════════════════

func test_start_without_combat_system_refuses_with_chinese_reason() -> void:
	# Arrange
	IntentScript.request(payload())
	resume.call(&"consume")
	# Act
	var reason: String = resume.call(&"start", null, root, interaction, deps(), 1)
	# Assert
	assert_false(reason.is_empty(), "战斗系统缺失时必须拒绝（不得静默进一场空仗）")
	assert_true(reason.contains("无法续战"), "原因应为中文可读文案：%s" % reason)


func test_start_with_missing_template_refuses_instead_of_guessing() -> void:
	## 模板已不存在（图鉴改版 / 手改档）：宁可不续，也不臆造一个敌人。
	# Arrange——名册重建出来是空的
	ai.templates.clear()
	IntentScript.request(payload())
	resume.call(&"consume")
	# Act
	var reason: String = resume.call(&"start", combat, root, interaction, deps(), 1)
	# Assert
	assert_false(reason.is_empty(), "重建不出名册时应拒绝")
	assert_true(reason.contains("无法续战"), "原因应为中文可读文案：%s" % reason)
	assert_false(combat.calls.has("battle_start"), "拒绝时不得开战（半场仗比不进更糟）")
