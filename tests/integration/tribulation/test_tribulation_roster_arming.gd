extends "res://tests/integration/tribulation/tribulation_reward_fixture.gd"
## 渡劫战敌方名册配装守卫——[b]开战前名册必须真的有人[/b]。（DEBT-TRB-001）[br]
## [br][b]为什么单开一份用例[/b]：渡劫开战时 [code]config["enemy_roster"][/code] 恒为
## [code][][/code]，而 [code]CombatEndCheck._all_enemies_dead[/code] 对空名册返回 false
## （判据本身是对的——「信息不足则不判」，是数据没给）。后果：把敌人打光也判不出胜负，
## 对局永远打不完、结算永远不触发。[br]
## [br][b]本文件的纪律[/b]：名册一律看「能不能打」——非空、每个单位有模板 id、
## [code]max_hp > 0[/code]；数值断言一律从模板现读，不在用例里写死第二个数字。[br]
## [br][b]装置[/b]（真实 GSM / 真实 RealmSystem / 真实状态机 + 注入 CardSystem）
## 见基类 [code]tribulation_reward_fixture.gd[/code]；[code]AISystem[/code] 用真实
## Autoload——名册正是由它现建（[code]EnemyBattleState[/code]）。[br]
## [br]来源: design/gdd/tribulation-system.md §3 天劫Boss 雷灵 / §6 越阶渡劫、
## ADR-0021 §get_tribulation_boss_config、ADR-0032。

const BossRoster := preload("res://src/feature/tribulation/tribulation_boss_roster.gd")
const EndCheckScript := preload("res://src/feature/combat/combat_end_check.gd")

## 四个渡劫档的 Boss 境界（GDD §3 表的 Boss境界 列 + §6 越阶）。
const BOSS_REALMS: Array = [1, 2, 3, 4]


func _ai() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/AISystem")


# ═══════════════════════════════════════════════════════════════════════════════
# 1. boss_config 里的名册字段——四档都要有人
# ═══════════════════════════════════════════════════════════════════════════════

func test_boss_config_carries_non_empty_roster_for_every_tier() -> void:
	for boss_realm: int in BOSS_REALMS:
		var boss: Dictionary = ts.call("get_tribulation_boss_config", boss_realm)
		assert_true(boss.has("enemy_roster"),
				"档 %d 的 boss_config 必须带 enemy_roster（缺失即开战时无人可打）" % boss_realm)
		var ids: Array = boss["enemy_roster"]
		assert_gte(ids.size(), 1, "档 %d 的名册至少 1 个单位" % boss_realm)


func test_boss_config_roster_ids_all_resolve_with_positive_hp() -> void:
	for boss_realm: int in BOSS_REALMS:
		var ids: Array = ts.call("get_tribulation_boss_config", boss_realm)["enemy_roster"]
		for tid: StringName in ids:
			var tpl: Resource = BossRoster.template_for(boss_realm)
			assert_not_null(tpl, "档 %d 的模板 id %s 必须能解析" % [boss_realm, tid])
			if tpl == null:
				continue
			assert_eq(StringName(str(tpl.get("template_id"))), tid,
					"档 %d 的表内 id 与模板自报 id 必须一致" % boss_realm)
			assert_gt(int(tpl.get("base_hp")), 0, "档 %d 的雷灵 HP 必须 > 0" % boss_realm)


func test_boss_config_hp_matches_template_not_a_hardcoded_number() -> void:
	# 数值的真理来源是模板——配置里的 hp/atk 必须与模板逐位相等。
	# 若实现在 get_tribulation_boss_config 里另算一组数，这条立刻红。
	for boss_realm: int in BOSS_REALMS:
		var boss: Dictionary = ts.call("get_tribulation_boss_config", boss_realm)
		var tpl: Resource = BossRoster.template_for(boss_realm)
		assert_eq(int(boss["hp"]), int(tpl.get("base_hp")),
				"档 %d 的 hp 应现读模板（非硬编码）" % boss_realm)
		assert_eq(int(boss["atk"]), int(tpl.get("base_attack")),
				"档 %d 的 atk 应现读模板（非硬编码）" % boss_realm)


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 运行时名册——真的建得出来，且判得动
# ═══════════════════════════════════════════════════════════════════════════════

func test_runtime_roster_is_buildable_with_positive_hp() -> void:
	var ai: Node = _ai()
	assert_not_null(ai, "前置：AISystem Autoload 在册")
	var roster: Array = BossRoster.build(ai, 1)
	assert_gte(roster.size(), 1, "境界 1 的天劫名册至少 1 个单位")
	for enemy: Variant in roster:
		assert_gt(int(enemy.get("max_hp")), 0, "敌方单位的 max_hp 必须 > 0")
		assert_gt(int(enemy.get("current_hp")), 0, "敌方单位的 current_hp 必须 > 0")
		assert_ne(StringName(str(enemy.get("template_id"))), &"", "敌方单位必须带模板 id")


func test_runtime_roster_is_written_back_to_ai_system() -> void:
	# AI 决策读 AISystem.get_enemy_roster()——不写回，敌方回合会拿到空候选池。
	var ai: Node = _ai()
	BossRoster.build(ai, 2)
	var current: Array = ai.call(&"get_enemy_roster")
	assert_gte(current.size(), 1, "名册必须写回 AISystem（AI 决策读的就是它）")


func test_runtime_roster_is_not_empty_so_end_check_can_judge() -> void:
	# 名册非空 + 全员阵亡 ⇒ 胜负判定必须给得出胜利。
	# 空名册时 _all_enemies_dead 返回 false（判不出胜负）——这正是本用例守的边界。
	var ai: Node = _ai()
	var roster: Array = BossRoster.build(ai, 3)
	assert_false(EndCheckScript.evaluate(roster, [], [], false)
			== EndCheckScript.RESULT_VICTORY, "前置：全员存活时不得判胜利")
	for enemy: Variant in roster:
		enemy.set("is_alive", false)
	assert_eq(EndCheckScript.evaluate(roster, [], [], false),
			EndCheckScript.RESULT_VICTORY, "名册打光后必须判得出胜利")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 接线——名册真的经开战路径进到 battle_start 的 config
# ═══════════════════════════════════════════════════════════════════════════════

func test_start_tribulation_combat_passes_roster_into_battle_start_config() -> void:
	# 名册建得出来还不够——它必须真的出现在 battle_start 收到的 config 里。
	# 放错层（塞进 tribulation_data 而没放顶层）同样是一场判不出胜负的仗。
	var combat: Node = CombatScript.new()
	add_child_autofree(combat)
	combat.call("set_auto_advance", false)
	combat.call("set_scene_change", false)
	ts.set("_combat_override", combat)
	var captured: Array = []
	combat.battle_started.connect(func(config: Dictionary) -> void:
		captured.append(config))
	# Arrange——修为满 + 触发 + 进战斗
	ts.call("trigger_tribulation", TS_SCRIPT.TribulationType.NORMAL)
	ts.call("start_tribulation_combat")
	# Assert
	assert_eq(captured.size(), 1, "battle_start 应被调用一次")
	if captured.is_empty():
		return
	var config: Dictionary = captured[0]
	assert_true(config.has("enemy_roster"),
			"config 顶层必须带 enemy_roster（CombatSystem 认的就是这个键）")
	var roster: Array = config.get("enemy_roster", [])
	assert_gte(roster.size(), 1,
			"渡劫开战必须带得出可打的名册——空名册即打不完（DEBT-TRB-001）")
	for enemy: Variant in roster:
		assert_gt(int(enemy.get("max_hp")), 0, "名册单位必须有正 HP")


# ═══════════════════════════════════════════════════════════════════════════════
# 4. 一条完整链路——名册打空 → battle_end(VICTORY) → 境界 +1 且修为不扣
# ═══════════════════════════════════════════════════════════════════════════════

func test_cleared_roster_through_battle_ended_raises_realm_without_deducting() -> void:
	# Arrange——名册真的建出来并打光（不是手工塞一个空字典）
	var ai: Node = _ai()
	var roster: Array = BossRoster.build(ai, int(gsm.player.realm))
	assert_gte(roster.size(), 1, "前置：名册非空")
	for enemy: Variant in roster:
		enemy.set("is_alive", false)
	assert_eq(EndCheckScript.evaluate(roster, [], [], false),
			EndCheckScript.RESULT_VICTORY, "前置：打光后判定为胜利")
	var realm_before: int = _realm()
	var cultivation_before: int = _cultivation()
	_enter_combat()
	# Act——经真实 battle_ended 信号发 VICTORY（生产路径正是这一条）
	var combat: Node = CombatScript.new()
	add_child_autofree(combat)
	combat.connect(&"battle_ended", Callable(ts, &"_on_battle_ended"))
	combat.battle_ended.emit(CombatScript.CombatResult.VICTORY, {})
	# Assert
	assert_eq(_realm(), realm_before + 1,
			"名册打空 → VICTORY 必须进境（空名册的旧缺陷下这里纹丝不动）")
	assert_eq(_cultivation(), cultivation_before,
			"胜利不得扣修为")
