class_name NodeInteractionRules
extends RefCounted
## NodeInteractionRules —— 节点交互弹窗的 Logic 内核（exploration-ui Story 006）。
##
## [b]零状态纯函数[/b]（ADR-0031 §2）：分发表、文案、弹窗定位、回复量断言全部
## 无副作用、不读 Autoload——GUT 直调可测（BLOCKING 单测目标）。[br]
## [br][b]分发表[/b]（GDD §4c 2026-09-08 B5 裁决）：interaction_type → 弹窗种类
## 三元组（kind / 确认动作 / 文案组）。[b]事件节点显式排除[/b]（EventSystem 面板
## 接管，走 [code]event_node_reached[/code] 而非 [code]node_interaction_triggered[/code]
## ——防双面板）；[b]传送节点显式排除[/b]（机制未闭合，B5 裁决）。[br]
## [br][b]专属警示数值[/b]：渡劫台 80% 修为损失（朱砂红）为渡劫专属——
## 严禁与 Boss 战 50% 混用（GDD §4b + combat-ui-system.md §9）。[br]
## [br][b]UI 零数值计算[/b]（control-manifest Forbidden）：灵泉回复量与回复点
## 治疗量由探索系统 API 返回，本文件只提供[b]校验/展示包装[/b]（[method
## spring_restore_all] 仅用于断言「系统返回 == 上限-当前」，不产生写入）。[br]
## [br][b]文案本地化豁免[/b]：与 node_move_interactor REASON_TEXTS /
## deploy_panel_rules 同源口径（项目暂无本地化系统，DEBT-CUI-007-1 同源）。
##
## 来源: design/gdd/exploration-ui-system.md §4/§4b/§4c/§5、ADR-0014 §决策 3、
## exploration-ui Story 006（AC-1/AC-2/AC-6/AC-7/AC-9/AC-10）。

## 战斗预览内核（敌人摘要 / 正文行 / 推荐上场数——本文件保留转发入口）。
const CombatPreview := preload("res://src/ui/exploration/node_combat_preview_rules.gd")
## 回复点结算（[method rest_heal_amount] 的公式来源——Feature 层实现）。
## [br][b]UI → Feature 的只读依赖[/b]：本文件只调它的静态纯函数 [code]heal_for[/code]，
## 不碰 HP 读写——与 [method spring_restore_all] 的只读包装同源口径。
const RestScript := preload("res://src/feature/exploration/exploration_rest.gd")

## === 弹窗种类（kind）=======================================================

const KIND_NONE: StringName = &""
const KIND_COMBAT: StringName = &"combat"
const KIND_SHOP: StringName = &"shop"
const KIND_SPRING: StringName = &"action_spring"
const KIND_REST: StringName = &"rest"
const KIND_TRIBULATION: StringName = &"tribulation"

## === 确认动作（confirm_action——宿主据此派发）==============================

const ACTION_NONE: StringName = &""
const ACTION_ENTER_COMBAT: StringName = &"enter_combat"
const ACTION_OPEN_SHOP: StringName = &"open_shop"
const ACTION_USE_SPRING: StringName = &"use_spring"
const ACTION_REST: StringName = &"rest"
const ACTION_ENTER_TRIBULATION: StringName = &"enter_tribulation"

## === 分发表（GDD §4c——interaction_type → 三元组）==========================
## 未列出的类型（event / teleport / 空串）→ [constant KIND_NONE]（无弹窗）。
const DISPATCH_TABLE: Dictionary = {
	&"combat": KIND_COMBAT,
	&"elite": KIND_COMBAT,
	&"shop": KIND_SHOP,
	&"action_spring": KIND_SPRING,
	&"rest": KIND_REST,
	&"tribulation": KIND_TRIBULATION,
}

## kind → 确认动作（数据驱动，非 if-elif 链）。
const CONFIRM_ACTIONS: Dictionary = {
	KIND_COMBAT: ACTION_ENTER_COMBAT,
	KIND_SHOP: ACTION_OPEN_SHOP,
	KIND_SPRING: ACTION_USE_SPRING,
	KIND_REST: ACTION_REST,
	KIND_TRIBULATION: ACTION_ENTER_TRIBULATION,
}

## === 文案（数据驱动）=======================================================

## 弹窗标题（含 GDD §4 线框图标）。
const TITLES: Dictionary = {
	KIND_COMBAT: "⚔ 战斗",
	KIND_SHOP: "🏪 坊市",
	KIND_SPRING: "💧 灵泉",
	KIND_REST: "💚 歇脚处",
	KIND_TRIBULATION: "🌩 渡劫台",
}

## 确认按钮文案（GDD §4/§4b 线框原文）。
const CONFIRM_TEXTS: Dictionary = {
	KIND_COMBAT: "进入战斗",
	KIND_SHOP: "进入商店",
	KIND_SPRING: "使用灵泉",
	KIND_REST: "休息",
	KIND_TRIBULATION: "挑战渡劫",
}

## 取消按钮文案——点击等效「先等等」（AC-3：关闭弹窗、停留该节点、AP 不回退）。
const CANCEL_TEXTS: Dictionary = {
	KIND_COMBAT: "先等等",
	KIND_SHOP: "离开",
	KIND_SPRING: "离开",
	KIND_REST: "继续前进",
	KIND_TRIBULATION: "再等等",
}

## 固定正文（GDD §4/§4b 线框原文；战斗与渡劫的正文另有动态行）。
const BODY_LINES: Dictionary = {
	KIND_SHOP: ["「你走进一间修仙坊市」", "这里有各种丹药和法器"],
	KIND_SPRING: ["「一股灵气从泉眼中涌出」", "回复全部行动力"],
	KIND_REST: ["全队回复50%已损失HP"],
	KIND_TRIBULATION: ["「雷云在你头顶汇聚」", "修为已满，可尝试渡劫突破"],
}

## 渡劫专属警示行（GDD §4b）——80% 修为损失，朱砂红高亮。
const TRIBULATION_WARNING: String = "⚠ 渡劫战撤退将损失 80% 本局修为"
## 渡劫警示补注——与普通战败对照（强化「远严于 50%」的语义区分）。
const TRIBULATION_WARNING_NOTE: String = "——远严于普通战败（50%）"
## 普通战斗/精英提示（GDD §4 线框「推荐战力」行——B3 裁决采用角色数版本）。
## 转发到 [NodeCombatPreviewRules]——文案只在一处定义。
const TEXT_RECOMMENDED_PREFIX: String = CombatPreview.TEXT_RECOMMENDED_PREFIX

## === 颜色（美术圣经「墨骨丹青」——朱砂红 / 淡墨 / 暖白）====================
const COLOR_TITLE: Color = Color(0.94, 0.92, 0.86)
const COLOR_BODY: Color = Color(0.85, 0.82, 0.74)
## 朱砂红 #B3424A——渡劫 80% 警示（与 lingshi_deck_bar.COLOR_OVERLIMIT 同源）。
const COLOR_DANGER: Color = Color("#B3424A")

## === 背景模糊（GDD §4「背景模糊 40%」）===================================
## 模糊强度（0..1——pause_blur.gdshader 的 blur_amount 语义）。
const BLUR_AMOUNT: float = 0.4
## 遮罩暗度（保留背景可见性——弹窗期间节点图「可见但不可操作」）。
const DIM_ALPHA: float = 0.25

## === 布局（弹窗「在节点附近弹出」——GDD §4 不覆盖全屏）====================
const POPUP_SIZE: Vector2 = Vector2(360.0, 220.0)
## 弹窗相对节点中心的偏移（向右下——避开节点图标本体）。
const POPUP_OFFSET: Vector2 = Vector2(40.0, 24.0)
## 弹窗距视口边缘的安全边距（px）。
const EDGE_MARGIN: float = 16.0

## === 动画（GDD Engine Notes：放大淡入 0.2s / 缩小淡出 0.15s）================
const OPEN_SEC: float = 0.2
const CLOSE_SEC: float = 0.15
## 弹窗缩放起点/终点（放大淡入）。
const SCALE_FROM: float = 0.9


## 分发表查询——interaction_type → 弹窗种类。[br]
## [b]返回[/b]: [constant KIND_NONE] 表示无弹窗（事件/传送/未知类型）。
static func popup_kind_for(interaction_type: StringName) -> StringName:
	return DISPATCH_TABLE.get(interaction_type, KIND_NONE)


## 分发表查询——kind → 确认动作。
static func confirm_action_for(kind: StringName) -> StringName:
	return CONFIRM_ACTIONS.get(kind, ACTION_NONE)


## 该类型是否应当弹出探索 UI 弹窗（事件/传送节点为 false——AC-9/AC-10）。
static func has_popup(interaction_type: StringName) -> bool:
	return popup_kind_for(interaction_type) != KIND_NONE


## 弹窗标题（未知 kind → 空串——宿主据此拒绝打开）。
static func title_for(kind: StringName) -> String:
	return str(TITLES.get(kind, ""))


## 按钮文案——返回 [code]{confirm, cancel}[/code]（GDD 线框原文）。
static func button_texts(kind: StringName) -> Dictionary:
	return {
		"confirm": str(CONFIRM_TEXTS.get(kind, "确认")),
		"cancel": str(CANCEL_TEXTS.get(kind, "关闭")),
	}


## 固定正文行（不含战斗/渡劫的动态行；未知 kind → 空数组）。
static func body_lines(kind: StringName) -> Array:
	return (BODY_LINES.get(kind, []) as Array).duplicate()


## 渡劫台是否可挑战——[param detail] 为节点详情（字段 [code]tribulation_ready[/code]）。[br]
## [b]默认宽松[/b]：字段缺失视为已圆满（stub 载荷未提供该字段时不误拦），
## 显式 [code]false[/code] 才判不可触发（AC-7）。
static func tribulation_ready(detail: Dictionary) -> bool:
	return bool(detail.get("tribulation_ready", true))


## 战斗敌人摘要——敌人名称 + 数量 + 境界（AC-2 三要素）。[br]
## [b]转发[/b]到 [NodeCombatPreviewRules.enemy_summary]（实现只在一处）。
static func combat_enemy_summary(enemy_roster: Array) -> Dictionary:
	return CombatPreview.enemy_summary(enemy_roster)


## 战斗弹窗动态正文行（名称 ×数量 / 境界 / 推荐上场角色）。[br]
## [param max_deploy]: 当前境界上场上限（RealmSystem 查询值，UI 不推算）。[br]
## [param recommended_override]: 地图配置显式推荐值（≤0 表示未配置 → 推定）。
static func combat_lines(enemy_roster: Array, max_deploy: int,
		recommended_override: int = 0) -> Array:
	return CombatPreview.lines(enemy_roster, max_deploy, recommended_override)


## 战斗弹窗动态正文行——[b]与开战上下文读同一份节点遭遇数据[/b]。[br]
## [br][b]为什么要带 encounter[/b]：弹窗若只读到达名册，展示的等级/数量与
## 开战时用的会是两套推导（名册可能为空、或只含预览字段）。这里先吃节点的
## 遭遇配置，再回退到名册——文案与 [code]CombatLaunchContext[/code] 同源。[br]
## [br][param p_encounter] 规范化遭遇配置（[code]EncounterFields.make/of_detail[/code]）。[br]
## [param p_roster] 到达名册（可为空——数量退化为模板 ID 数）。[br]
## [param p_max_deploy] 当前境界上场上限。[br]
## [param p_recommended_override] 地图配置显式推荐值（≤0 = 未配置）。
static func combat_lines_for_encounter(p_encounter: Dictionary, p_roster: Array,
		p_max_deploy: int, p_recommended_override: int = 0) -> Array:
	return CombatPreview.lines_for_encounter(p_encounter, p_roster, p_max_deploy,
			p_recommended_override)


## 推荐上场角色数——配置值优先，缺失时按敌人数对等推定（实现见
## [NodeCombatPreviewRules.recommended_deploy]）。
static func recommended_deploy(enemy_count: int, max_deploy: int,
		recommended_override: int = 0) -> int:
	return CombatPreview.recommended_deploy(enemy_count, max_deploy,
			recommended_override)


## 境界等级 → 中文名（1 炼气 … 5 化神）；未知等级返回空串不臆造。
static func realm_name(realm: int) -> String:
	return CombatPreview.realm_name(realm)


## 渡劫警示行（朱砂红渲染的独立行——AC-6「不与 Boss 50% 混用」）。
static func tribulation_warning_lines() -> Array:
	return [TRIBULATION_WARNING, TRIBULATION_WARNING_NOTE]


## 灵泉回复量校验——[b]期望值[/b]（上限 - 当前）；仅供测试断言系统返回值，
## UI 不使用本函数写状态（control-manifest：UI 不算回复量）。
static func spring_restore_all(current_ap: int, max_ap: int) -> int:
	return maxi(max_ap - current_ap, 0)


## 回复点治疗量——GDD 公式 7（floor(lost_hp_total × 0.5)，仅存活角色计入）。[br]
## [b]用途[/b]：交叉校验系统 API 返回值（UI 不自行应用）。[br]
## [b]公式单一来源[/b]：转发到 [code]ExplorationRest.heal_for[/code]（Feature 层
## 的实际结算实现）——两侧各写一遍必然漂移（同为「UI 零数值计算」，
## 参见 [method spring_restore_all] 的只读包装口径）。
static func rest_heal_amount(lost_hp_total: int) -> int:
	return RestScript.heal_for(lost_hp_total)


## 弹窗位置——节点附近弹出并夹入视口（GDD §4「不覆盖全屏」）。[br]
## [param anchor]: 节点中心的宿主局部坐标。[param popup_size]: 弹窗尺寸。
## [param host_size]: 宿主（视口）尺寸。[br]
## [b]返回[/b]: 弹窗左上角坐标（已 clamp 到边距内）。
static func popup_position(anchor: Vector2, popup_size: Vector2,
		host_size: Vector2) -> Vector2:
	var target: Vector2 = anchor + POPUP_OFFSET
	var max_x: float = maxf(host_size.x - popup_size.x - EDGE_MARGIN, EDGE_MARGIN)
	var max_y: float = maxf(host_size.y - popup_size.y - EDGE_MARGIN, EDGE_MARGIN)
	# 右/下越界时翻转到节点左侧/上方（避免弹窗盖住节点本体）
	if target.x > max_x:
		target.x = anchor.x - popup_size.x - POPUP_OFFSET.x
	if target.y > max_y:
		target.y = anchor.y - popup_size.y - POPUP_OFFSET.y
	target.x = clampf(target.x, EDGE_MARGIN, max_x)
	target.y = clampf(target.y, EDGE_MARGIN, max_y)
	return target


## === 内部 ================================================================
## 名册条目的双形态读取已随战斗预览内核移到 [NodeCombatPreviewRules]。
