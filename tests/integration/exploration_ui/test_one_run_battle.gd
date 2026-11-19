extends "res://tests/integration/exploration_ui/one_run_battle_fixture.gd"
## 一周目冒烟（战斗段）—— 走到 Boss → 弹窗 → 确认 → 开战上下文齐备。[br]
## [br][b]为什么与前三步分开[/b]：那三段（主菜单 / 身份 / 探索）在这条链路里是
## 「进得去」，这一段是「打得起来」；装置能力也只在后半段用得上
## （见 [code]one_run_battle_fixture.gd[/code] 文件头）。[br]
## [br][b]本文件只到「开战那一刻」[/b]：真的打完那一仗与通关回写见
## [code]test_one_run_clear.gd[/code]（它要另挂战斗场景，装置又是一层）。[br]
##
## 来源: design/gdd/exploration-system.md §5、design/gdd/combat-system.md §2、
## design/gdd/exploration-ui-system.md §4b、ADR-0005、ADR-0014 §决策 3。

const SM := preload("res://src/foundation/scene_manager.gd")
const ContextScript := preload("res://src/feature/combat/combat_launch_context.gd")


# ═══════════════════════════════════════════════════════════════════════════════
# 5. 触发 Boss → 弹窗 → 开战上下文
# ═══════════════════════════════════════════════════════════════════════════════

func test_boss_arrival_opens_popup_with_enemy_roster() -> void:
	# Arrange——走完真实开局前三步（身份落地才有出战阵容），再走到 Boss
	start_new_run()
	prepare_battle_path()

	# Act——走到 Boss（末跳会触发到达通知 → 弹窗）
	var path: Array[int] = walk_to_boss()
	assert_true(path.size() > 0, "前置：应有一条到 Boss 的路径")

	# Assert——Boss 弹窗真的弹出来了，且正文里有敌人（不是空弹窗）
	assert_eq(popup_kind(), RulesScript.KIND_BOSS, "走到 Boss 应弹出 Boss 弹窗")
	assert_ne(popup_body(), "", "Boss 弹窗正文不应为空（应带本图与敌情）")


func test_confirm_boss_popup_publishes_complete_launch_context() -> void:
	# Arrange——走完真实开局（身份落地 → 出战阵容入 deck.slots）再走到 Boss
	start_new_run()
	prepare_battle_path()
	walk_to_boss()
	var max_deploy: int = max_deploy_limit()

	# Act
	confirm_popup()

	# Assert——上下文齐备：敌方名单非空、我方不超上限、战斗类型是 boss
	var context: Dictionary = launch_context()
	assert_false(context.is_empty(), "确认开战应发布开战上下文（跨场景缓存）")
	var enemies: Array = context.get(ContextScript.KEY_ENEMY_ROSTER, [])
	assert_true(enemies.size() > 0, "敌方名单不应为空")
	var roster: Array = context.get(ContextScript.KEY_PLAYER_ROSTER, [])
	assert_true(roster.size() > 0, "我方出战名单不应为空（身份落地才有阵容）")
	assert_true(roster.size() <= max_deploy,
			"我方出战名单不应超过上场上限（%d 人，上限 %d）" % [roster.size(), max_deploy])
	assert_eq(StringName(str(context.get(ContextScript.KEY_COMBAT_TYPE, ""))),
			ContextScript.COMBAT_TYPE_BOSS, "Boss 战的开战类型应为 boss")


func test_confirm_boss_popup_navigates_to_combat() -> void:
	# Arrange
	start_new_run()
	prepare_battle_path()
	walk_to_boss()

	# Act
	confirm_popup()

	# Assert——真的请求了转场，且目标是战斗场景（注册表里有对应资源）
	assert_eq(last_nav_target(), SM.SceneID.COMBAT, "确认 Boss 弹窗应导航到战斗场景")
	assert_eq(mock_sm.call(&"target_path"), str(SM.SCENE_PATHS[SM.SceneID.COMBAT]),
			"转场目标应在生产注册表里（不是悬空路径）")
	assert_true(visited().has(boss_node_id()), "确认开战不应把 Boss 从已访问里抹掉")
