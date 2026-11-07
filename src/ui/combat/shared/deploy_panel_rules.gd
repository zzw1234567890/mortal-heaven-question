class_name DeployPanelRules
extends RefCounted
## DeployPanelRules —— 备战面板 Logic 内核纯函数（combat-ui-layout Story 007）。
##
## [b]职责[/b]：备战面板的全部判定逻辑——角色 4 态判定
## [method deploy_selection_state]、境界→前后排位数映射
## [method formation_slot_layout]、确认按钮启用判定
## [method confirm_button_enabled]、协同信息共享阵营计算
## [method shared_faction_tags]。面板组件（DeployPanel / DeployCharacterCard /
## DeployFormationPreview）只消费不复制（story 001 共享纯函数模块条款）。[br]
## [br][b]纯函数[/b]（ADR-0031 Logic 内核模式）：无状态、无副作用、确定映射——
## 单元测试零依赖。[br]
## [br][b]数据驱动[/b]（control-manifest 禁止硬编码境界→阵位映射）：
## [constant FORMATION_SLOT_TABLE] 是唯一映射表，新增境界只改表不改函数体。[br]
## [br][b]不变量[/b]：每个境界 [code]front + back ≥ max_deploy[/code]
## （炼气 3 ≥ 2 … 化神 6 ≥ 6），由单元测试全枚举锁定。[br]
## [br][b]与 DeploymentSystem 的一致性[/b]：前排位数与
## [code]FRONT_CAPACITY_BY_MAX_DEPLOY[/code]（{2:2, 3:2, 4:2, 5:3, 6:3}）同口径，
## 两表由各自单元测试锁定。
##
## @experimental
## 来源: ADR-0031、design/gdd/combat-ui-system.md §8 备战阶段UI、
## combat-ui-layout Story 007（AC-2/AC-3/AC-4/AC-5/AC-7）。

## === 4 态字符串常量（GDD §8 角色选择状态表）=================================

## 已选——✓ + 金色高亮边框。
const STATE_SELECTED: String = "selected"
## 可选未选——☐ + 正常颜色。
const STATE_SELECTABLE: String = "selectable"
## 可替换——⊕（名额已满且未阵亡）。
const STATE_REPLACEABLE: String = "replaceable"
## 不可用——💀 灰色（阵亡）。
const STATE_UNAVAILABLE: String = "unavailable"

## === 境界 → 阵位分布表（GDD §8：炼气前2后1 / 筑基前2后2 / 金丹前2后2 /
## 元婴前3后2 / 化神前3后3）=====================================================

## 编译时常量——唯一映射来源。键为境界 ID（1-5，与 RealmSystem.realm_table 同口径）。
const FORMATION_SLOT_TABLE: Dictionary = {
	1: {"front": 2, "back": 1},
	2: {"front": 2, "back": 2},
	3: {"front": 2, "back": 2},
	4: {"front": 3, "back": 2},
	5: {"front": 3, "back": 3},
}


## 角色选择 4 态判定——[b]阵亡优先[/b]于其余一切状态（GDD §8 表格）。[br]
## [br][b]判定顺序[/b]（顺序即优先级，单元测试逐分支锁定）：[br]
##   1. 阵亡 → [constant STATE_UNAVAILABLE]（名额是否已满不影响）[br]
##   2. 已选 → [constant STATE_SELECTED][br]
##   3. 未选且 [code]selected_count >= max_deploy[/code] → [constant STATE_REPLACEABLE][br]
##   4. 其余 → [constant STATE_SELECTABLE][br]
## [br][param is_dead]: 角色是否阵亡（不可用）。[br]
## [param is_selected]: 角色当前是否已选。[br]
## [param selected_count]: 当前已选人数。[br]
## [param max_deploy]: 当前境界上场人数上限。
static func deploy_selection_state(is_dead: bool, is_selected: bool,
		selected_count: int, max_deploy: int) -> String:
	if is_dead:
		return STATE_UNAVAILABLE
	if is_selected:
		return STATE_SELECTED
	if selected_count >= max_deploy:
		return STATE_REPLACEABLE
	return STATE_SELECTABLE


## 境界 → 阵位布局（前排位数 / 后排位数 / 总数）。[br]
## [br][b]未知境界显式报错[/b]（QA 规格 AC-2 边缘：非静默默认）——
## push_error 并返回空字典，调用侧必须守卫 [code]is_empty()[/code]。[br]
## [br][param realm_id]: 境界 ID（1-5）。[br]
## [br][b]返回[/b]: [code]{front, back, total, realm_id}[/code]；未知境界返回 [code]{}[/code]。
static func formation_slot_layout(realm_id: int) -> Dictionary:
	if not FORMATION_SLOT_TABLE.has(realm_id):
		push_error("DeployPanelRules.formation_slot_layout: 未知境界 ID %d（有效范围 1-5）" % realm_id)
		return {}
	var row: Dictionary = FORMATION_SLOT_TABLE[realm_id]
	var front: int = int(row["front"])
	var back: int = int(row["back"])
	return {"front": front, "back": back, "total": front + back, "realm_id": realm_id}


## 确认出战按钮启用判定——至少选中 1 名可用角色（GDD §8 末条）。[br]
## [param selected_count]: 当前已选人数（阵亡角色不计入——由面板侧过滤）。
static func confirm_button_enabled(selected_count: int) -> bool:
	return selected_count >= 1


## 已选人数未满上限时的提示文案（GDD §8「还可以选择X人」）。[br]
## [br][b]满员口径[/b]：达到上限时返回已选满提示，不再提示剩余人数。[br]
## [param selected_count]: 当前已选人数。[br]
## [param max_deploy]: 当前境界上场人数上限。
static func remaining_hint(selected_count: int, max_deploy: int) -> String:
	if max_deploy <= 0:
		return "上场人数上限未初始化"
	var remaining: int = max_deploy - selected_count
	if remaining > 0:
		return "还可以选择%d人" % remaining
	return "已选满 %d/%d" % [selected_count, max_deploy]


## 协同信息——悬停角色与已选阵容共享的阵营标签（GDD §8「悬停协同信息」）。[br]
## [br][b]语义[/b]：只统计两边都存在的标签，去重且保持悬停角色的标签顺序。[br]
## [param hovered_tags]: 悬停角色的阵营标签列表。[br]
## [param selected_tags]: 已选角色阵营标签的并集。
static func shared_faction_tags(hovered_tags: Array, selected_tags: Array) -> Array:
	var shared: Array = []
	for tag: Variant in hovered_tags:
		if selected_tags.has(tag) and not shared.has(tag):
			shared.append(tag)
	return shared


## 悬停协同信息文案（GDD §8「此角色与已选阵容的协同信息」）。[br]
## [param display_name]: 悬停角色显示名。[br]
## [param shared_tags]: [method shared_faction_tags] 的结果。
static func synergy_text(display_name: String, shared_tags: Array) -> String:
	if shared_tags.is_empty():
		return "%s：暂无协同" % display_name
	var parts: Array = []
	for tag: Variant in shared_tags:
		parts.append(str(tag))
	return "%s：协同 %s" % [display_name, "、".join(PackedStringArray(parts))]


## 替换确认文案（GDD §8「用[角色名]替换[已选角色名]？」）。[br]
## [param new_name]: 新选角色名。[br]
## [param replaced_name]: 被替换的已选角色名。
static func replace_prompt(new_name: String, replaced_name: String) -> String:
	return "用%s替换%s？" % [new_name, replaced_name]
