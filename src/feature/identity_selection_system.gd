extends Node
## IdentitySelectionSystem —— 开局身份选择系统 Autoload（ADR-0022 #21）。
##
## Feature 层 Autoload。持有 6 个身份模板的 const Dictionary + 查询 API。[br]
## 身份选择是每局游戏的第一个决策点——6 种预设身份（5 默认 + 1 轮回解锁），[br]
## 每种绑定固定初始卡组、两名初始角色、专属天赋和初始灵石。[br]
## 不持有运行时可变状态——身份选择完成后所有状态存 GSM。[br]
## [br][b]Story 6-1 范围[/b]：身份模板表 + get_available_identities + get_identity_preview。[br]
## [b]已注册进 project.godot[/b]——Autoload（IdentitySelectionSystem）。[br]
## [br]来源: ADR-0022 §关键接口 / GDD identity-selection-system.md §1-2。


# === 信号（Cat 2b）=============================================================

## 身份选择完成信号——apply_identity() 全部初始状态写入后发射（Story 6-2 实现）。[br]
## [br][param identity_id] 已选择的身份 ID。[br]
## [br]来源: ADR-0022 §信号定义。
signal identity_selected(identity_id: StringName)

## 身份模板表子模块（Sprint 12 Story 013 拆分）。
const _Templates := preload("res://src/feature/identity/identity_templates.gd")

## 解锁/就绪判定子模块（纯函数——解锁双来源 + 卡组模板齐备性）。
const _Unlock := preload("res://src/feature/identity/identity_unlock.gd")

## 6 个开局身份模板——委托给 _Templates 子模块（Sprint 12 Story 013 拆分）。
## 保留 const 引用以兼容测试直接访问 ISS.IDENTITY_TEMPLATES。
const IDENTITY_TEMPLATES: Dictionary = _Templates.IDENTITY_TEMPLATES


# === 内部状态 ====================================================================

## 可注入 ProgressionSystem 引用——测试时设置，绕过 Autoload 查找（同 TribulationSystem _combat_override 模式）。
var _progression_override: Node = null

## 可注入 CardSystem 引用——测试时设置，绕过 Autoload 查找。
var _card_override: Node = null

## 可注入 ResourceSystem 引用——测试时设置，绕过 Autoload 查找。
var _resource_override: Node = null

## 可注入 DeckEditingSystem 引用——测试时设置，绕过 Autoload 查找。
var _deck_override: Node = null

## 初始化子模块——惰性初始化（Sprint 9 Story 4 拆分）。
var _initializer: RefCounted = null


# === 子模块（Sprint 9 Story 4 拆分）=================================================

## 惰性获取初始化子模块。
func _get_initializer() -> RefCounted:
	if _initializer == null:
		_initializer = load("res://src/feature/identity/identity_initializer.gd").new(self)
	return _initializer


# === 查询 API ====================================================================

## 查询可用身份列表——结合轮回天赋解锁状态 + 开局就绪度。[br]
## [br][b]返回[/b]: Array[Dictionary]，每个条目含：[br]
## [code]{identity_id, name, description, style_tag, initial_ling_shi,[br]
##   talent_name, talent_desc, character_display_names, is_unlocked,[br]
##   is_ready, block_reason, is_recommended}[/code][br]
## [br][b]ProgressionSystem 不可用时[/b]: 5 个默认身份解锁，阵道双杰锁定。[br]
## [br][b]is_unlocked ≠ is_ready[/b]（本子模块的要点）：[code]is_unlocked[/code] 只答
## 「轮回天赋到位没」，[code]is_ready[/code] 还答「这套卡组的模板齐不齐」。
## 未解锁必然不就绪；已解锁但模板缺失同样不就绪——UI 据此拦住开局，
## 而不是放它走到 [code]apply_identity[/code] 里失败回滚。[br]
## [br]来源: ADR-0022 §get_available_identities + GDD §7 身份影响范围。
func get_available_identities() -> Array[Dictionary]:
	var unlocked: Array[String] = _get_unlocked_talents()
	var has_template: Callable = _make_template_probe()
	var result: Array[Dictionary] = []

	for id: StringName in IDENTITY_TEMPLATES:
		var tmpl: Dictionary = IDENTITY_TEMPLATES[id]
		var ready: Dictionary = _Unlock.readiness(tmpl, id, unlocked, has_template)

		var entry: Dictionary = {
			"identity_id": id,
			"name": tmpl["name"],
			"description": tmpl["description"],
			"style_tag": tmpl["style_tag"],
			"initial_ling_shi": tmpl["initial_resources"]["ling_shi"],
			"talent_name": tmpl["talent"]["name"],
			"talent_desc": tmpl["talent"]["description"],
			"character_display_names": _get_character_names(tmpl),
			"is_unlocked": ready["is_unlocked"],
			"is_ready": ready["is_ready"],
			"block_reason": ready["block_reason"],
			"is_recommended": tmpl.get("recommended_for_new_player", false),
		}
		result.append(entry)

	return result


## 构造 [code]CardSystem.has_template[/code] 形态的探测 Callable——CardSystem 不可用时
## 返回无效 Callable（就绪度判定据此判「无法校验 → 不就绪」，不放行）。[br]
## [br]来源: ADR-0022 §apply_identity ② 前置校验（同一份模板存在性口径）。
func _make_template_probe() -> Callable:
	var card_sys: Node = _get_card_system()
	if card_sys == null or not card_sys.has_method("has_template"):
		return Callable()
	return card_sys.has_template


## 获取完整身份预览——供 UI 预览面板使用。[br]
## [br][param identity_id] 身份 ID。[br]
## [br][b]返回[/b]: 完整模板 Dictionary（含所有字段），无效 ID 返回空字典。[br]
## [br]来源: ADR-0022 §get_identity_preview。
func get_identity_preview(identity_id: StringName) -> Dictionary:
	var tmpl: Dictionary = IDENTITY_TEMPLATES.get(identity_id, {})
	if tmpl.is_empty():
		return {}

	return {
		"identity_id": identity_id,
		"name": tmpl["name"],
		"description": tmpl["description"],
		"flavor_text": tmpl["flavor_text"],
		"style_tag": tmpl["style_tag"],
		"initial_deck_cards": tmpl["initial_deck"]["cards"],
		"character_slots": tmpl["initial_deck"]["character_slots"],
		"character_details": tmpl["character_details"],
		"initial_ling_shi": tmpl["initial_resources"]["ling_shi"],
		"talent": tmpl["talent"],
		"unlock_condition": tmpl["unlock_condition"],
		"playstyle_hint": tmpl.get("playstyle_hint", ""),
	}


# === 工具方法 ===================================================================

## 检查是否已选择身份——读 GSM.player.identity_id。[br]
## [br][b]返回[/b]: true 已选择，false 未选择。[br]
## [br]来源: ADR-0022 §is_identity_selected。
func is_identity_selected() -> bool:
	var gsm: Node = _get_gsm()
	if gsm == null:
		return false
	return not str(gsm.player.identity_id).is_empty()


## 获取当前已选身份 ID——读 GSM.player.identity_id。[br]
## [br][b]返回[/b]: StringName 身份 ID，未选择时返回空 StringName。[br]
## [br]来源: ADR-0022 §get_current_identity。
func get_current_identity() -> StringName:
	var gsm: Node = _get_gsm()
	if gsm == null:
		return &""
	return StringName(gsm.player.identity_id)


## 查询身份天赋值——从 GSM.player.talent_map 查（apply_identity 写入）。[br]
## [br][param talent_id] 天赋 ID。[br]
## [br][b]返回[/b]: 天赋 magnitude 值，未注册返回 0。[br]
## [br]来源: ADR-0022 §get_identity_talent_value + GDD §公式#1 天赋效果注册。
func get_identity_talent_value(talent_id: StringName) -> int:
	var gsm: Node = _get_gsm()
	if gsm == null:
		return 0
	var talent_map: Dictionary = gsm.player.get("talent_map", {})
	return int(talent_map.get(talent_id, 0))


# === apply_identity 原子操作（Story 6-2）=========================================

## 应用身份——编排多系统写入的原子操作。[br]
## [br][param identity_id] 身份 ID。[br]
## [br][b]返回[/b]: [code]true[/code] 成功，[code]false[/code] 失败（GSM 不变或已回滚）。[br]
## [br][b]流程[/b]（ADR-0022 §apply_identity 8 步原子操作）:[br]
##   ① 验证 identity_id 有效 + 已解锁 + 已就绪（卡组模板齐备）[br]
##   ② 验证所有 card_id 在 CardSystem.templates 中存在[br]
##   ③ 写入 GSM.player.identity_id[br]
##   ④ 设置初始灵石——通过 ResourceSystem（ADR-0019 强制契约）[br]
##   ⑤ 创建初始卡牌实例——通过 CardSystem + DeckEditingSystem[br]
##   ⑥ 创建初始角色实例——写入 deck.slots[br]
##   ⑦ 注册身份天赋——写入 GSM talent_map[br]
##   ⑧ 写入开局叙事文本 + 发射 identity_selected 信号[br]
## [br][b]回滚[/b]: ResourceSystem 失败时回滚 identity_id 为空字符串。[br]
## [br]来源: ADR-0022 §apply_identity + GDD §3 身份选择流程。
func apply_identity(identity_id: StringName) -> bool:
	var gsm: Node = _get_gsm()
	if gsm == null:
		push_error("IdentitySelectionSystem.apply_identity: GSM 不可用")
		return false

	# ① 前置校验——identity_id 有效
	var tmpl: Dictionary = IDENTITY_TEMPLATES.get(identity_id, {})
	if tmpl.is_empty():
		push_error("IdentitySelectionSystem.apply_identity: 未知 identity_id '%s'" % identity_id)
		return false

	# 校验解锁状态 + 开局就绪度（解锁双来源 + 卡组模板齐备性）
	var ready: Dictionary = _Unlock.readiness(tmpl, identity_id,
			_get_unlocked_talents(), _make_template_probe())
	if not bool(ready["is_unlocked"]):
		push_error("IdentitySelectionSystem.apply_identity: 身份 '%s' 未解锁" % identity_id)
		return false
	if not bool(ready["is_ready"]):
		push_error("IdentitySelectionSystem.apply_identity: 身份 '%s' 未开放（原因 %s，缺模板 %s）"
				% [identity_id, ready["block_reason"], str(ready["missing_templates"])])
		return false

	# ② 卡牌模板有效性——就绪度已用同一份 CardSystem.has_template 口径查过一遍；
	# 此处只补「CardSystem 本身不可用」的兜底（readiness 对无效探测 Callable
	# 一律判不就绪，走到这里即说明 CardSystem 可用，故只为可读性保留守卫）。
	var card_sys: Node = _get_card_system()
	if card_sys == null or not card_sys.has_method("has_template"):
		push_error("IdentitySelectionSystem.apply_identity: CardSystem 不可用")
		return false

	# ③ 写入 GSM.player.identity_id（先写以满足"选择身份"语义）
	gsm.set_identity(identity_id)

	# ④ 设置初始灵石——通过 ResourceSystem（ADR-0019 强制契约）
	var ling_shi: int = int(tmpl["initial_resources"]["ling_shi"])
	var res_sys: Node = _get_resource_system()
	if res_sys == null or not res_sys.has_method("add_resource"):
		push_error("IdentitySelectionSystem.apply_identity: ResourceSystem 不可用")
		_rollback_identity(gsm)
		return false
	if not res_sys.add_resource(&"ling_shi", ling_shi):
		push_error("IdentitySelectionSystem.apply_identity: 设置初始灵石失败")
		_rollback_identity(gsm)
		return false

	# ⑤ 创建初始卡牌实例——通过 CardSystem + DeckEditingSystem
	_get_initializer().create_initial_cards(tmpl["initial_deck"]["cards"])

	# ⑥ 创建初始角色实例——写入 deck.slots
	_get_initializer().create_initial_characters(tmpl["initial_deck"]["character_slots"])

	# ⑦ 注册身份天赋——写入 GSM talent_map
	var talent_def: Dictionary = tmpl["talent"]
	gsm.set_talent(StringName(talent_def["id"]), int(talent_def["magnitude"]))

	# ⑧ 写入开局叙事文本 + 发射 identity_selected 信号
	gsm.set_narrative_flag(&"opening_text", tmpl["flavor_text"])
	_emit_safe(&"identity_selected", [identity_id])

	return true


# --- 初始卡牌/角色创建（已提取到 identity_initializer.gd 子模块）---



## 获取 CardSystem 引用——优先使用注入的覆盖引用，否则通过 SceneTree Autoload 查找。[br]
## [br][b]返回[/b]: CardSystem 节点或 null（未注册时）。
func _get_card_system() -> Node:
	if _card_override != null and is_instance_valid(_card_override):
		return _card_override
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("/root/CardSystem")


## 获取 ResourceSystem 引用——优先使用注入的覆盖引用，否则通过 SceneTree Autoload 查找。[br]
## [br][b]返回[/b]: ResourceSystem 节点或 null（未注册时）。
func _get_resource_system() -> Node:
	if _resource_override != null and is_instance_valid(_resource_override):
		return _resource_override
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("/root/ResourceSystem")


## 获取 DeckEditingSystem 引用——优先使用注入的覆盖引用，否则通过 SceneTree Autoload 查找。[br]
## [br][b]返回[/b]: DeckEditingSystem 节点或 null（未注册时）。
func _get_deck_editing_system() -> Node:
	if _deck_override != null and is_instance_valid(_deck_override):
		return _deck_override
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("/root/DeckEditingSystem")


# === 内部辅助 ====================================================================

## 获取身份的角色显示名列表——委托给 _Templates 子模块（Sprint 12 Story 013 拆分）。
func _get_character_names(tmpl: Dictionary) -> Array[String]:
	return _Templates.get_character_names(tmpl)


## 获取已解锁的轮回天赋列表——从 ProgressionSystem 查询。[br]
## [br][b]ProgressionSystem 不可用时[/b]返回空数组（5 个默认身份仍解锁）。[br]
## [br]来源: ADR-0022 §get_available_identities 依赖 ProgressionSystem。
func _get_unlocked_talents() -> Array[String]:
	var prog: Node = _get_progression_system()
	if prog == null:
		return []
	if not prog.has_method("get_talent_tree_state"):
		return []
	var state: Dictionary = prog.get_talent_tree_state()
	var unlocked: Array = state.get("unlocked", [])
	var result: Array[String] = []
	for t: Variant in unlocked:
		result.append(str(t))
	return result


## 获取 ProgressionSystem 引用——优先使用注入的覆盖引用，否则通过 SceneTree Autoload 查找。[br]
## [br][b]返回[/b]: ProgressionSystem 节点或 null（未注册时）。
func _get_progression_system() -> Node:
	if _progression_override != null and is_instance_valid(_progression_override):
		return _progression_override
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("/root/ProgressionSystem")


## 获取 GSM 引用——通过 SceneTree Autoload（同 TribulationSystem/DeckEditingSystem 模式）。
func _get_gsm() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("/root/GameStateManager")


## Cat 2b 信号安全发射——经 GSM._emit_signal_safe 路由（ADR-0007 信号链深度追踪）。[br]
## [br][b]GSM 不可用时回退[/b]到直接 emit_signal + push_warning 告警。[br]
## [br]来源: ADR-0022 §信号分类 / ADR-0007 §_emit_signal_safe（同 TribulationSystem 模式）。
func _emit_safe(signal_name: StringName, args: Array) -> void:
	var gsm = _get_gsm()
	if gsm != null and gsm.has_method("_emit_signal_safe"):
		gsm._emit_signal_safe(self, signal_name, args)
		return
	push_warning("IdentitySelectionSystem: GSM 不可用，%s 信号绕过 _emit_signal_safe 路由" % signal_name)
	var call_args: Array = [signal_name]
	call_args.append_array(args)
	callv("emit_signal", call_args)


## 回滚 identity_id——set_identity 去重导致空字符串无法覆盖已有值。[br]
## [br]GSM.set_identity 内部对相同值去重，已写入的 identity_id 无法用空字符串覆盖[br]
## （因为 old_val != "" 时虽然不等，但写入后 _set_by_path 的路径校验会阻止空值）。[br]
## [br]此方法直接操作 GSM.player.identity_id + buffer_change 绕过去重。[br]
## [br]来源: ADR-0022 §apply_identity 回滚策略。
func _rollback_identity(gsm: Node) -> void:
	var old_val: String = str(gsm.player.identity_id)
	if old_val.is_empty():
		return  # 本来就空，无需回滚
	gsm.player.identity_id = ""
	gsm._buffer_change("player.identity_id", old_val, "")
