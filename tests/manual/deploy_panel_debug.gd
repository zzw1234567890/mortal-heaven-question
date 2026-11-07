extends Control
## deploy_panel_debug —— 备战面板视觉手动验证 debug 宿主（Story 007）。
##
## F6 运行本场景：以桩名册挂载 [DeployPanel]，按 1-5 切换五个境界的阵位布局，
## 按 D 构造阵亡场景、按 R 重置，供人工截图与走查——生产代码零改动。
##
## 验证剧本（对应 deploy-panel-evidence.md §2 五境界截图清单）：
##   [1] 炼气期 前2后1  [2] 筑基期 前2后2  [3] 金丹期 前2后2
##   [4] 元婴期 前3后2  [5] 化神期 前3后3
##   [D] 构造阵亡（第 3 人不可用）+ 选满制造可替换态
##   [R] 重置为本境界初始态
##
## 来源: combat-ui-layout Story 007 Test Evidence（UI 证据文档）、
## tests/manual/hud_debug.gd 先例（TD-006）。

const PanelScript := preload("res://src/ui/combat/deploy/deploy_panel.gd")
const RealmSystemScript := preload("res://src/core/realm_system.gd")

## 测试名册——6 名角色（与 GDD「6 个角色位」一致）。
const ROSTER_NAMES: Array = ["林渊", "苏剑鸣", "陆青", "白芷", "韩霜", "沈墨"]
const ROSTER_TAGS: Array = [
	[&"qing_yun", &"sword"], [&"qing_yun"], [&"fire"],
	[&"fire", &"alchemy"], [&"sword"], [&"water"],
]

var panel: Control = null
var realm_id: int = 1
var dead_ids: Array = []


func _ready() -> void:
	panel = PanelScript.new()
	panel.position = Vector2(40, 40)
	add_child(panel)
	_apply_realm(1)
	_print_instructions()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_1: _apply_realm(1)
		KEY_2: _apply_realm(2)
		KEY_3: _apply_realm(3)
		KEY_4: _apply_realm(4)
		KEY_5: _apply_realm(5)
		KEY_D: _toggle_dead_scenario()
		KEY_R: _apply_realm(realm_id)


## 切换境界——布局按境界映射重建，名册按 max_deploy 选满以便走查可替换态。
func _apply_realm(p_realm_id: int) -> void:
	realm_id = p_realm_id
	dead_ids = []
	var max_deploy: int = int(RealmSystemScript.realm_table[realm_id]["max_deploy"])
	panel.apply_roster(_make_roster(), max_deploy, realm_id)
	panel.set_battle_title("⚔ 青云剑宗·山门 — 普通战斗（%s 上限 %d）" % [
			str(RealmSystemScript.realm_table[realm_id]["name"]), max_deploy])
	# 选满——展示 4 态中的「已选 ✓」+「可替换 ⊕」
	for i: int in range(mini(max_deploy, ROSTER_NAMES.size())):
		panel.toggle_selection(100 + i)
	print("[deploy_debug] 境界 %d：前%d后%d，上限 %d" % [realm_id,
			int(panel.formation_layout.get("front", 0)),
			int(panel.formation_layout.get("back", 0)), max_deploy])


## 阵亡场景——第 3 名角色标为不可用（💀 灰色），其余保持可选。
func _toggle_dead_scenario() -> void:
	dead_ids = [] if not dead_ids.is_empty() else [102]
	var max_deploy: int = int(RealmSystemScript.realm_table[realm_id]["max_deploy"])
	panel.apply_roster(_make_roster(), max_deploy, realm_id)
	panel.toggle_selection(100)
	panel.toggle_selection(101)
	print("[deploy_debug] 阵亡场景：%s" % ("第 3 人不可用" if not dead_ids.is_empty() else "已复位"))


func _make_roster() -> Array:
	var roster: Array = []
	for i: int in range(ROSTER_NAMES.size()):
		roster.append({
			"character_id": 100 + i,
			"display_name": ROSTER_NAMES[i],
			"hp": 8 + i,
			"attack": 3 + i % 3,
			"binding_count": 1 if i < 2 else 0,
			"faction_tags": (ROSTER_TAGS[i] as Array).duplicate(),
			"is_dead": dead_ids.has(100 + i),
			"slot_index": i,
		})
	return roster


func _print_instructions() -> void:
	print("=== deploy_panel_debug ===")
	print("1-5 切换境界（炼气/筑基/金丹/元婴/化神）  D 阵亡场景  R 重置")
	print("截图清单见 production/qa/evidence/deploy-panel-evidence.md §2")
