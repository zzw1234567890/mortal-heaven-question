extends "res://tests/integration/tribulation/tribulation_reward_fixture.gd"
## 渡劫胜负判据的接线守卫——[b]渡劫战收到什么结果就走哪条结算[/b]。[br]
## [br][b]为什么单开一份用例[/b]：渡劫曾有一个只在生产里发作的缺陷——
## [code]tribulation_combat.gd[/code] 用字面量 [code]0[/code] 判胜，而
## [code]battle_ended[/code] 发的是 [code]CombatResult[/code] 的真实取值
## （[code]VICTORY = 1[/code]）。于是[b]打赢也走失败结算[/b]：境界不升、修为被扣、
## 金卡不发，渡劫永不进境。既有用例没抓到它，是因为它们[b]按实现现状传值[/b]
## （传 0 当胜利）——用例与实现犯了同一个错，两边一起错就互相印证了。[br]
## [br][b]本文件的纪律[/b]：结果一律引 [code]CombatResult[/code] 枚举本身，
## [b]不出现任何表示「第几种结果」的裸数字[/b]——若实现再退回字面量，
## 这些用例立刻变红。附带一条不变量：四个枚举值互不相同且 VICTORY 不是
## 「未结束」，故「把 VICTORY 重新编号成 0」这种改法也拦得住。[br]
## [br]装置（真实 GSM / 真实 RealmSystem / 真实状态机 + 注入的 CardSystem）
## 见基类 [code]tribulation_reward_fixture.gd[/code]。[br]
## [br]来源: src/feature/combat_system.gd §CombatResult（判据真理来源）、
## ADR-0021 §_on_battle_ended、design/gdd/tribulation-system.md §4-5。
## [br][b]枚举出处[/b]： [constant CombatScript] 与两个结果常量都在基类里
## （子类重复声明会编译不过）。


# ═══════════════════════════════════════════════════════════════════════════════
# 0. 判据的真理来源——枚举本身的不变量
# ═══════════════════════════════════════════════════════════════════════════════

func test_result_enum_values_are_distinct_and_victory_is_not_none() -> void:
	# 若有人把 VICTORY 重新编号成「未结束」，下面的接线用例会一起失效——
	# 这条把不变量先钉住，失败的定位因此更直接。
	assert_ne(CombatScript.CombatResult.VICTORY, CombatScript.CombatResult.NONE,
			"VICTORY 不得等于「未结束」")
	assert_ne(CombatScript.CombatResult.DEFEAT, CombatScript.CombatResult.NONE,
			"DEFEAT 不得等于「未结束」")
	assert_ne(CombatScript.CombatResult.RETREAT, CombatScript.CombatResult.NONE,
			"RETREAT 不得等于「未结束」")
	assert_ne(CombatScript.CombatResult.VICTORY, CombatScript.CombatResult.DEFEAT,
			"胜与败必须是两个取值")
	assert_ne(CombatScript.CombatResult.DEFEAT, CombatScript.CombatResult.RETREAT,
			"败与撤退必须是两个取值")


func test_fixture_constants_track_the_real_enum() -> void:
	# 用例侧常量与生产判据同源——两处若分叉，本文件其余用例的结论都会失真。
	assert_eq(COMBAT_VICTORY, CombatScript.CombatResult.VICTORY,
			"用例的胜利取值应等于 CombatResult.VICTORY")
	assert_eq(COMBAT_DEFEAT, CombatScript.CombatResult.DEFEAT,
			"用例的失败取值应等于 CombatResult.DEFEAT")


# ═══════════════════════════════════════════════════════════════════════════════
# 1. VICTORY —— 必须走成功结算（境界升、修为不扣、金卡发）
# ═══════════════════════════════════════════════════════════════════════════════

func test_victory_raises_realm() -> void:
	# Arrange
	var realm_before: int = _realm()
	var cards_before: int = _owned_count()
	_enter_combat()
	# Act——发真实枚举的 VICTORY（战斗系统发的就是这个值）
	ts.call("_on_battle_ended", CombatScript.CombatResult.VICTORY, {})
	# Assert
	assert_eq(_realm(), realm_before + 1,
			"渡劫战收到 VICTORY 必须进境——旧缺陷下这里纹丝不动")


func test_victory_does_not_deduct_cultivation() -> void:
	# Arrange
	_enter_combat()
	var cultivation_before: int = _cultivation()
	# Act
	ts.call("_on_battle_ended", CombatScript.CombatResult.VICTORY, {})
	# Assert——胜利扣修为是「打赢被判成输」最刺眼的表征
	assert_eq(_cultivation(), cultivation_before,
			"渡劫战收到 VICTORY 不得扣修为")


func test_victory_grants_gold_card() -> void:
	# Arrange
	var cards_before: int = _owned_count()
	_enter_combat()
	# Act
	ts.call("_on_battle_ended", CombatScript.CombatResult.VICTORY, {})
	# Assert
	assert_eq(_owned_count(), cards_before + PoolScript.CARDS_NORMAL,
			"渡劫战收到 VICTORY 应发金卡")


func test_victory_attaches_reward_report_to_payload() -> void:
	# Arrange——载荷是结算屏取数的唯一载体
	_enter_combat()
	var rewards: Dictionary = {}
	# Act
	ts.call("_on_battle_ended", CombatScript.CombatResult.VICTORY, rewards)
	# Assert
	assert_true(rewards.has(PoolScript.KEY_PAYLOAD),
			"VICTORY 的 battle_ended 载荷应带金卡报告")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. DEFEAT / RETREAT —— 必须走失败结算（境界不动、修为扣、不发卡）
# ═══════════════════════════════════════════════════════════════════════════════

func test_defeat_keeps_realm_and_deducts_cultivation() -> void:
	# Arrange
	gsm.player.cultivation = BASE_MAX
	var realm_before: int = _realm()
	_enter_combat()
	# Act
	ts.call("_on_battle_ended", CombatScript.CombatResult.DEFEAT, {})
	# Assert
	var penalty: int = int(floor(float(BASE_MAX) * SettlementScript.FAILURE_PENALTY_RATIO))
	assert_eq(_realm(), realm_before, "渡劫战 DEFEAT 不得进境")
	assert_eq(_cultivation(), BASE_MAX - penalty,
			"渡劫战 DEFEAT 应按 max_cultivation × %f 扣修为"
			% SettlementScript.FAILURE_PENALTY_RATIO)


func test_defeat_grants_no_card() -> void:
	# Arrange
	var cards_before: int = _owned_count()
	_enter_combat()
	# Act
	ts.call("_on_battle_ended", CombatScript.CombatResult.DEFEAT, {})
	# Assert
	assert_eq(_owned_count(), cards_before, "渡劫战 DEFEAT 不得发卡")


func test_retreat_takes_the_failure_path() -> void:
	# Arrange——渡劫战里撤退按钮不可用，但枚举一旦被发出来也必须走失败结算
	gsm.player.cultivation = BASE_MAX
	var realm_before: int = _realm()
	var cards_before: int = _owned_count()
	_enter_combat()
	# Act
	ts.call("_on_battle_ended", CombatScript.CombatResult.RETREAT, {})
	# Assert
	var penalty: int = int(floor(float(BASE_MAX) * SettlementScript.FAILURE_PENALTY_RATIO))
	assert_eq(_realm(), realm_before, "渡劫战 RETREAT 不得进境")
	assert_eq(_cultivation(), BASE_MAX - penalty, "渡劫战 RETREAT 应按失败扣修为")
	assert_eq(_owned_count(), cards_before, "渡劫战 RETREAT 不得发卡")


func test_none_does_not_settle() -> void:
	# Arrange——「未结束」不是结局：误当结局会把一盘未打完的仗结算掉
	var realm_before: int = _realm()
	var cards_before: int = _owned_count()
	_enter_combat()
	# Act
	ts.call("_on_battle_ended", CombatScript.CombatResult.NONE, {})
	# Assert
	assert_eq(_realm(), realm_before, "NONE 不得触发任何结算")
	assert_eq(_owned_count(), cards_before, "NONE 不得触发任何结算")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 真实信号路径 —— 经 battle_ended 发出来同样走对分支
# ═══════════════════════════════════════════════════════════════════════════════

func test_real_battle_ended_signal_routes_victory_to_success() -> void:
	# Arrange——真战斗系统的信号（不是直调私有方法）：生产路径正是这一条。
	# 载荷走字面量字典会触发引用传递，故这里让信号自己带一份。
	var combat: Node = CombatScript.new()
	add_child_autofree(combat)
	combat.connect(&"battle_ended", Callable(ts, &"_on_battle_ended"))
	var realm_before: int = _realm()
	_enter_combat()
	# Act
	combat.battle_ended.emit(CombatScript.CombatResult.VICTORY, {})
	# Assert
	assert_eq(_realm(), realm_before + 1,
			"经真实 battle_ended 信号发出的 VICTORY 应进境")
