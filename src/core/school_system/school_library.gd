extends RefCounted
## SchoolLibrary —— 流派库纯数据子模块（从 school_system.gd 拆分）。
##
## 5 流派完整定义——编译时常量，零运行时加载开销。
## [b]只读约定[/b]（ADR-0025）：const Dictionary 并非真正冻结，团队约定运行时不写入。
##
## [br]来源: ADR-0025 + GDD school-system.md。
## [br]Sprint 12 Story 014：从 school_system.gd 拆分。

const SCHOOL_LIBRARY: Dictionary = {
	# =========================================================================
	# ① 归墟真灵流 —— priority 1（条件最苛刻，优先级最高）
	# =========================================================================
	&"spirit_realm_beast": {
		id = &"spirit_realm_beast",
		name = "归墟真灵流",
		tagline = "万灵臣服",
		description = "以归墟/真灵阵营的高阶角色为核心的后期流派，角色单体强度高但成型慢，一旦成型碾压一切。",
		priority = 1,
		detection = {
			conditions = [
				{type = "min_realm", value = 3},  # 金丹期(L≥3)
				{type = "faction_count", tags = [&"guixu_abyss", &"zhenling"], min = 2},  # 归墟/真灵标签 ≥2
				{type = "avg_card_cost", min = 3.0},  # 卡组总费用均值 ≥3.0
				{type = "min_rarity", value = "blue"},  # 场上无低于蓝色稀有度角色
			],
		},
		effects = [
			{type = "stat_boost", target = "spirit", hp = 3, atk = 1},
			{type = "immune_debuff", target = "spirit", debuffs = [&"fear", &"confusion"]},
			{type = "aura_hp", value = 1, per_unit = "spirit"},
		],
		weakness = "成型门槛极高——金丹期前无法激活；被快攻流派克制；卡组费用均值高意味着前期抽牌容易卡手。",
		visual_theme = "银白/星蓝——星辰流转的光效",
	},

	# =========================================================================
	# ② 正道发育流 —— priority 2
	# =========================================================================
	&"righteous_dev": {
		id = &"righteous_dev",
		name = "正道发育流",
		tagline = "稳扎稳打，步步为营",
		description = "以正道阵营角色为核心的防御续航流派，擅长拖长战斗回合数，通过持续回复和治疗耗死对手。",
		priority = 2,
		detection = {
			conditions = [
				{type = "faction_count", tags = [&"zhengdao"], min = 3},  # 正道 ≥3
				{type = "faction_ratio", tag = &"zhengdao", min = 0.6},  # 正道占比 ≥60%
				{type = "excluded_faction", tag = &"modao"},  # 不含魔道阵营限定卡
			],
		},
		effects = [
			{type = "regen", target = "zhengdao", value = 2, trigger = "turn_end"},
			{type = "damage_reduce", target = "zhengdao", value = 1, floor = 1},
			{type = "formation_ease", value = -1},
		],
		weakness = "被高爆发流派克制（回复跟不上爆发伤害）；清场类AOE对续航阵型打击大。",
		visual_theme = "青色/金色——温润的光效",
	},

	# =========================================================================
	# ③ 魔道快攻流 —— priority 3
	# =========================================================================
	&"demonic_aggro": {
		id = &"demonic_aggro",
		name = "魔道快攻流",
		tagline = "先下手为强",
		description = "以魔道阵营角色为核心的快攻流派，前3回合打出成吨伤害，争取在对手站稳前结束战斗。",
		priority = 3,
		detection = {
			conditions = [
				{type = "faction_count", tags = [&"modao"], min = 3},  # 魔道 ≥3
				{type = "faction_ratio", tag = &"modao", min = 0.6},  # 魔道占比 ≥60%
				{type = "card_type_ratio", card_type = "low_cost", min_pct = 0.5},  # 费用≤2的低费卡 ≥50%
			],
		},
		effects = [
			{type = "attack_boost", target = "modao", value = 2, trigger = "first_3_turns", turn_limit = 3},
			{type = "draw_on_kill", target = "modao", value = 1, trigger = "on_kill"},
			{type = "cost_boost", target = "player", value = 1, turn = 1},
		],
		weakness = "被高防御流派克制（单张高伤牌被格挡后节奏断档）；拖到第5回合后输出衰减明显。",
		visual_theme = "赤红/暗紫——凌厉锋锐的光效",
	},

	# =========================================================================
	# ④ 正邪混合流 —— priority 4
	# =========================================================================
	&"mixed_alignment": {
		id = &"mixed_alignment",
		name = "正邪混合流",
		tagline = "不拘一格，为我所用",
		description = "同时使用正道和魔道角色的均衡流派，放弃阵营极致加成换取更高的构筑灵活性和场面适应性。",
		priority = 4,
		detection = {
			conditions = [
				{type = "faction_count", tags = [&"zhengdao"], min = 2},  # 正道 ≥2
				{type = "faction_count", tags = [&"modao"], min = 2},  # 魔道 ≥2
				{type = "faction_ratio", tag = &"zhengdao", min = 0.3, max = 0.7},  # 正道占比 30%~70%
				{type = "faction_ratio", tag = &"modao", min = 0.3, max = 0.7},  # 魔道占比 30%~70%
				{type = "max_dark_gold_count", value = 1},  # 暗金卡不超过1张
			],
		},
		effects = [
			{type = "stat_boost", target = "mixed", atk = 1, def = 1},
			{type = "cost_discount", target = "player", chance = 0.3, value = 1},
			{type = "formation_ease", value = -1},
		],
		weakness = "核心增益依赖双方同时在场——任意一方减员后强度下降明显；被纯阵营流派克制。",
		visual_theme = "青紫交织——阴阳融合的光效",
	},

	# =========================================================================
	# ⑤ 百艺炼丹流 —— priority 5（需运营进度）
	# =========================================================================
	&"alchemy_mastery": {
		id = &"alchemy_mastery",
		name = "百艺炼丹流",
		tagline = "炼丹炼器，以物养战",
		description = "以炼丹炼器为核心的资源转化流派，不靠战斗正面碾压，而是通过制作丹药/法宝卡牌堆叠属性，用资源量压倒对手。",
		priority = 5,
		detection = {
			conditions = [
				{type = "card_type_ratio", card_type = "pill", min_pct = 0.2},  # 丹药卡 ≥20%
				{type = "required_characters", ids = [&"wanxiang_zhenren"]},  # 万象真人在场或已收藏
				{type = "min_alchemy_count", value = 3},  # 本局已进行 ≥3 次炼丹/炼器
			],
		},
		effects = [
			{type = "pill_boost", target = "all", value = 0.2, trigger = "on_pill_use"},
			{type = "cost_reduce", target = "alchemy_material", value = 1, floor = 1},
			{type = "action_recover", target = "player", per_pills = 3, value = 1, max_triggers = 3},
			{type = "pill_breakthrough", target = "player", chance = 0.1},
		],
		weakness = "依赖资源——如果没有足够的灵材/灵石，流派无法发挥作用；前期战力薄弱（卡组中大量丹药卡代替了战斗卡）。",
		visual_theme = "金色/药鼎——炼丹光效",
	},
}
