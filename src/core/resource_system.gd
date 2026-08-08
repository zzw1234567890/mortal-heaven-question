extends Node
# class_name ResourceSystem —— 不声明：Autoload 全局单例
# （控制清单 2026-08-05 规则，同 GSM/EventSystem/RealmSystem/CardSystem 先例）。

## ResourceSystem —— 资源读写 API Autoload。[br]
## Core 层 Autoload。持有 LingCaiQuality 枚举 + 类型安全读写 API，[br]
## 不持有资源数据——所有数据存储在 GSM player.resources 域。[br]
## [br][b]Autoload 顺序[/b]：GSM #1 → ... → EventSystem → ResourceSystem（监听 EventSystem.resource_add_requested）[br]
## [br]来源: ADR-0019。

## 灵材品质枚举（ADR-0019 §关键接口）。
enum LingCaiQuality { LOW = 1, MEDIUM = 2, HIGH = 3, TOP = 4 }


# === 资源公式调参旋钮（GDD §调优旋钮）=======================================
## 所有资源公式的调参旋钮集中为 const——数据驱动，绝不硬编码（ADR-0019）。

## 拆解基础价值表——白/蓝/紫/金/暗金（索引 0-4 对应 rarity 1-5）。
const DISMANTLE_BASE: PackedInt32Array = [10, 30, 100, 400, 2000]
## 炼制物拆解折价系数（50%）。
const CRAFTED_DISCOUNT: float = 0.5
## 删卡基础费用（首次）。
const DELETE_BASE: int = 50
## 删卡费用递增量（每次 +25）。
const DELETE_INCREMENT: int = 25
## 灵材出售单价表——低/中/高/顶（索引 0-3 对应 quality 1-4）。
const LING_CAI_SELL_PRICE: PackedInt32Array = [10, 30, 80, 200]
## 境界差额每级惩罚系数（-30%/级）。
const REALM_PENALTY_PER_GAP: float = 0.3
## 境界惩罚保底值（最低 0.1）。
const REALM_PENALTY_FLOOR: float = 0.1
## 青云剑宗灵石加成倍率（+15%）。
const LING_SHI_BOOST_MULTIPLIER: float = 1.15


func _ready() -> void:
	# 监听 EventSystem 资源增加请求（Foundation→Core 信号委托，ADR-0007 Cat 2c）
	EventSystem.resource_add_requested.connect(_on_resource_add_requested)


## EventSystem 资源增加请求处理——委托 add_resource。[br]
## [br][param type] 资源类型。[br]
## [br][param amount] 增加数量。
func _on_resource_add_requested(type: StringName, amount: int) -> void:
	add_resource(type, amount)


## 增加资源——类型安全包装，内部委托 GSM 第二层原子写入。[br]
## [br][b]非负 amount 守卫[/b]：[param amount] < 0 返回 false（防变相增加资源）。[br]
## [br][param type] 资源类型（&"ling_shi" / &"ling_cai"）。[br]
## [br][param amount] 增加数量（必须 ≥ 0）。[br]
## [br][param quality] 灵材品质（1-4），ling_shi 忽略。[br]
## [br][b]返回[/b]: 成功 true；负 amount / 无效 type / 无效品质返回 false。
func add_resource(type: StringName, amount: int, quality: int = -1) -> bool:
	if amount < 0:
		push_error("ResourceSystem.add_resource: amount 不能为负数（%d）" % amount)
		return false
	match type:
		&"ling_shi":
			var new_val: int = GameStateManager.player.resources.ling_shi + amount
			GameStateManager._set_resource_ling_shi(new_val)
			return true
		&"ling_cai":
			if quality < 1 or quality > 4:
				push_error("ResourceSystem.add_resource: 无效品质 %d（有效 1-4）" % quality)
				return false
			var key: String = _quality_key(quality)
			var current: int = GameStateManager.player.resources.ling_cai[key]
			GameStateManager._set_resource_ling_cai(quality, current + amount)
			return true
		&"dan_yao_sui_pian":
			push_warning("ResourceSystem.add_resource: dan_yao_sui_pian 暂未通过 ResourceSystem 管理（待后续 Epic）")
			return false
	push_error("ResourceSystem.add_resource: 未知资源类型 '%s'" % type)
	return false


## 消费资源——先 can_spend 校验余额，再原子扣减。[br]
## [br][b]非负 amount 守卫[/b]：[param amount] < 0 返回 false。[br]
## [br][b]余额不足不扣减[/b]：返回 false 且 GSM 状态不变。[br]
## [br][param type] 资源类型。[br]
## [br][param amount] 消费数量。[br]
## [br][param quality] 灵材品质。[br]
## [br][b]返回[/b]: 成功 true；余额不足 / 负 amount / 无效类型返回 false。
func spend_resource(type: StringName, amount: int, quality: int = -1) -> bool:
	if amount < 0:
		push_error("ResourceSystem.spend_resource: amount 不能为负数（%d）" % amount)
		return false
	if not can_spend(type, amount, quality):
		return false
	match type:
		&"ling_shi":
			GameStateManager._set_resource_ling_shi(GameStateManager.player.resources.ling_shi - amount)
			return true
		&"ling_cai":
			if quality < 1 or quality > 4:
				push_error("ResourceSystem.spend_resource: 无效品质 %d（有效 1-4）" % quality)
				return false
			var current: int = _get_ling_cai_by_quality(quality)
			GameStateManager._set_resource_ling_cai(quality, current - amount)
			return true
	push_error("ResourceSystem.spend_resource: 未知资源类型 '%s'" % type)
	return false


## 余额校验——所有消费操作前置入口（GDD §4 契约）。[br]
## [br][param type] 资源类型。[br]
## [br][param amount] 待消费数量。[br]
## [br][param quality] 灵材品质。[br]
## [br][b]返回[/b]: 余额充足 true。
func can_spend(type: StringName, amount: int, quality: int = -1) -> bool:
	return get_resource(type, quality) >= amount


## 查询资源余额。[br]
## [br][param type] 资源类型。[br]
## [br][param quality] 灵材品质；ling_cai 不传 quality 时返回四品质总和。[br]
## [br][b]返回[/b]: 余额 int；无效类型返回 0 + push_error。
func get_resource(type: StringName, quality: int = -1) -> int:
	match type:
		&"ling_shi":
			return GameStateManager.player.resources.ling_shi
		&"ling_cai":
			if quality >= 1:
				return _get_ling_cai_by_quality(quality)
			var lc: Dictionary = GameStateManager.player.resources.ling_cai
			return lc.low + lc.medium + lc.high + lc.top
	push_error("ResourceSystem.get_resource: 未知资源类型 '%s'" % type)
	return 0


## 品质 int → 字典 key 字符串。[br]
## [br][param quality] 品质（1-4）。[br]
## [br][b]返回[/b]: 对应 key 字符串；无效品质返回 "low" + push_error。
func _quality_key(quality: int) -> String:
	match quality:
		1: return "low"
		2: return "medium"
		3: return "high"
		4: return "top"
	push_error("ResourceSystem._quality_key: 无效品质 %d" % quality)
	return "low"


## 按品质查询灵材数量。[br]
## [br][param quality] 品质（1-4）。[br]
## [br][b]返回[/b]: 该品质数量；无效品质返回 0 + push_error。
func _get_ling_cai_by_quality(quality: int) -> int:
	if quality < 1 or quality > 4:
		push_error("ResourceSystem._get_ling_cai_by_quality: 无效品质 %d" % quality)
		return 0
	return GameStateManager.player.resources.ling_cai[_quality_key(quality)]


# === 资源公式 API（纯函数，无副作用，不读写 GSM 状态）=========================
## 6 个资源公式纯函数——GDD §公式 1/1b/2/3/6/7 的真理来源。[br]
## [br][b]纯函数契约[/b]（ADR-0019 §纯公式服务层）：[br]
##   - 接受原始类型参数（int/float/bool），不接收领域对象[br]
##   - 不读写 GSM.player.resources——调用方负责通过 add_resource/spend_resource 应用结果[br]
##   - 无副作用，可独立单元测试

## 拆解卡牌价值——base + floor(base × (level-1) × 0.05)。[br]
## [br][param rarity] 稀有度（1=白 ~ 5=暗金）。[br]
## [br][param level] 卡牌等级（≥1）。[br]
## [br][b]返回[/b]: 拆解所得灵石；无效 rarity 返回 0 + push_error。[br]
## [br][b]来源[/b]: GDD §公式 1 + ADR-0019 §关键接口。
func dismantle_value(rarity: int, level: int) -> int:
	if rarity < 1 or rarity > 5:
		push_error("ResourceSystem.dismantle_value: 无效稀有度 %d（有效 1-5）" % rarity)
		return 0
	var base: int = DISMANTLE_BASE[rarity - 1]
	var bonus: int = floori(base * maxi(0, level - 1) * 0.05)
	return base + bonus


## 拆解炼制物价值——炼制物折价 50%，非炼制物等同 dismantle_value。[br]
## [br][param rarity] 稀有度（1-5）。[br]
## [br][param level] 卡牌等级。[br]
## [br][param is_crafted] 是否炼制产出。[br]
## [br][b]返回[/b]: 拆解所得灵石。[br]
## [br][b]来源[/b]: GDD §公式 1b + ADR-0019 §关键接口。
func dismantle_crafted_value(rarity: int, level: int, is_crafted: bool) -> int:
	var standard: int = dismantle_value(rarity, level)
	if is_crafted:
		return floori(standard * CRAFTED_DISCOUNT)
	return standard


## 出售灵材价值——单价 × 数量。[br]
## [br][param quality] 品质（1=低 ~ 4=顶）。[br]
## [br][param quantity] 出售数量（≥0）。[br]
## [br][b]返回[/b]: 所得灵石；无效 quality 返回 0 + push_error，负 quantity 返回 0 + push_error。[br]
## [br][b]来源[/b]: GDD §公式 2 + ADR-0019 §关键接口。
func sell_ling_cai_value(quality: int, quantity: int) -> int:
	if quality < 1 or quality > 4:
		push_error("ResourceSystem.sell_ling_cai_value: 无效品质 %d（有效 1-4）" % quality)
		return 0
	if quantity < 0:
		push_error("ResourceSystem.sell_ling_cai_value: 负数量 %d" % quantity)
		return 0
	var unit_price: int = LING_CAI_SELL_PRICE[quality - 1]
	return unit_price * quantity


## 删卡费用——base + increment × (count-1)。[br]
## [br][param delete_count] 删卡次数（≥1）。[br]
## [br][b]返回[/b]: 费用灵石；delete_count < 1 返回 [constant DELETE_BASE] + push_error（保守默认费用，避免低估扣减）。[br]
## [br][b]来源[/b]: GDD §公式 3 + ADR-0019 §关键接口。
func delete_card_cost(delete_count: int) -> int:
	if delete_count < 1:
		push_error("ResourceSystem.delete_card_cost: 无效删卡次数 %d（≥1）" % delete_count)
		return DELETE_BASE
	return DELETE_BASE + DELETE_INCREMENT * (delete_count - 1)


## 境界差额灵石惩罚——玩家高于地图上限时按级衰减，保底 0.1。[br]
## [br][param player_level] 玩家境界等级。[br]
## [br][param map_max_level] 地图允许的最高境界等级。[br]
## [br][b]返回[/b]: 惩罚系数 [code]float[/code]（范围 [0.1, 1.0]）；gap ≤ 0 返回 1.0（无惩罚）。[br]
## [br][b]来源[/b]: GDD §公式 7 + ADR-0019 §关键接口。
func realm_gap_penalty(player_level: int, map_max_level: int) -> float:
	var gap: int = player_level - map_max_level
	if gap <= 0:
		return 1.0
	return maxf(REALM_PENALTY_FLOOR, 1.0 - gap * REALM_PENALTY_PER_GAP)


## 灵石天赋加成——青云剑宗 +15%，无天赋原值返回。[br]
## [br][param base_amount] 基础灵石数量。[br]
## [br][param has_ling_shi_boost] 是否拥有灵石加成天赋。[br]
## [br][b]返回[/b]: 加成后灵石。[br]
## [br][b]来源[/b]: GDD §公式 6 + ADR-0019 §关键接口。
func apply_ling_shi_bonus(base_amount: int, has_ling_shi_boost: bool) -> int:
	if has_ling_shi_boost:
		return floori(base_amount * LING_SHI_BOOST_MULTIPLIER)
	return base_amount
