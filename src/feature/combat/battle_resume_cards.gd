extends RefCounted
## BattleResumeCards —— 续战存档里[b]三堆牌[/b]的形状与解析（纯函数）。[br]
## [br][b]补的断链[/b]：上一轮的续战段只记「谁、多少血、第几回合、什么阶段、还有多少费」
## ——手牌 / 抽牌堆 / 弃牌堆一概不记。于是读档回到的那场仗[b]牌面全部重来[/b]：
## 开了局手牌重抽一遍、牌堆重洗一遍，玩家存档那一刻手里攥着的两张关键牌连同
## 已经打出去、已经垫进弃牌堆的牌，全被洗没了。[br]
## [br][b]为什么是「三堆原样存」而不是「存种子重放」[/b]：洗牌消耗的随机数次数随
## 对局走向变化（抽空返还、阵亡洗回都各消耗一次），存种子重放要么得把整条消耗序列
## 也存下来，要么重放出来的牌序一定与存档那一刻不同。存牌面本身是最短的一条路。[br]
## [br][b]存什么[/b]：三堆各按[b]原顺序[/b]存条目
## （[code]card_instance_id[/code] / [code]template_id[/code] / [code]level[/code]）——
## 顺序就是抽牌顺序（[code]_draw_cards[/code] 取 [code]_deck[0][/code]），
## 顺序错了等于换了牌序。[br]
## [br][b]「是否升级」记的是 [code]level[/code][/b]：GDD card-system.md §升级
## 「1 级起，上限由稀有度决定」，升级作用于单张实例——[code]level > 1[/code] 即已升级。
## 存 [code]level[/code] 而不是存一个布尔：布尔是 [code]level[/code] 的派生视图，
## 存派生值等于把同一事实写两遍（升级到 3 级与升级到 2 级在布尔上分不开，而
## 帧面上它们的天差地别）。派生读取见 [method is_upgraded]。[br]
## [br][b]为什么 JSON 安全要自己折一遍[/b]：堆里的条目在内存里有三种形态
## （[code]int[/code] / [code]Dictionary[/code] / [code]CardInstance[/code] 对象）——
## 对象过不了存档的 JSON 兼容校验（[code]SaveLoadSystem._is_json_compatible[/code]），
## 整份存档会被判 [code]VALIDATION_ERROR[/code]。故这里统一折成
## 「int + String + int」的条目，[b]不存对象、不存 StringName[/b]（同
## [code]battle_resume_sanitize.gd[/code] 的口径）。[br]
## [br][b]读侧为什么还原成 id 序列[/b]：牌堆的真理是[b]实例 ID[/b]——
## [code]CombatSystem._get_card_instance[/code] 按 ID 找模板，UI 建卡也按 ID；
## 存档里的 [code]template_id[/code] / [code]level[/code] 是给展示与排查用的
## （「这张是哪张卡、升过几级」），重建牌堆只吃 ID。[br]
##
## 来源: ADR-0002 §JSON 容器、ADR-0006 §模板/实例分离、ADR-0008 §GSM 边界、
## design/gdd/card-system.md §升级、[code]battle_resume_payload.gd[/code] §最小闭环。

## 载荷里的段名（本模块是三堆形状的真理来源）。
const KEY_CARDS: String = "cards"
## 三堆各自的段名——顺序就是抽牌顺序，别改键名去换语义。
const KEY_HAND: String = "hand"
const KEY_DRAW_PILE: String = "draw_pile"
const KEY_DISCARD_PILE: String = "discard_pile"

## 条目字段（与 [code]CardInstance[/code] / GSM 收藏同名——跨层不另起名）。
const KEY_CARD_INSTANCE_ID: String = "card_instance_id"
const KEY_TEMPLATE_ID: String = "template_id"
const KEY_LEVEL: String = "level"

## 取「实例 → 模板/等级」的查表来源键（取数包里的 GSM 收藏快照）。
const KEY_OWNED_CARDS: String = "owned_cards"

## 实例 ID 认不出时的哨兵（与既有取数口径一致）。
const NO_ID: int = -1

## 等级未知时的取值——[b]不等于「1 级」[/b]（见 [method is_upgraded]）。
const LEVEL_UNKNOWN: int = 0

## 三堆在取数包里的键名（写侧遍历用；顺序固定让载荷形状确定）。
const PILE_KEYS: PackedStringArray = [KEY_HAND, KEY_DRAW_PILE, KEY_DISCARD_PILE]

const Seeding := preload("res://src/feature/combat/combat_roster_seeding.gd")


## 把战斗侧的取数包折成存档段——[code]{hand, draw_pile, discard_pile}[/code]。[br]
## [br][param p_state] 取数包（[code]hand[/code] / [code]draw_pile[/code] /
## [code]discard_pile[/code] 三个数组；[code]owned_cards[/code] 为 GSM 收藏快照，
## 用于给裸 ID 条目补出模板与等级）。[br]
## [br][b]三堆一律给全[/b]（缺席按空数组）：形状确定，读侧不必逐处判有没有这个键。[br]
static func fold(p_state: Dictionary) -> Dictionary:
	var owned: Variant = p_state.get(KEY_OWNED_CARDS, [])
	var out: Dictionary = {}
	for pile_key: String in PILE_KEYS:
		out[pile_key] = card_entries(p_state.get(pile_key, []), owned)
	return out


## 一「堆」的条目折叠——按原顺序逐条折成 JSON 安全形态。[br]
## [br][param p_pile] 牌堆数组（条目三种形态都认）。[br]
## [param p_owned] GSM 收藏快照（[code]owned_cards[/code]；用于补模板与等级）。[br]
## [br][b]认不出 ID 的条目整个丢掉[/b]：留一条 ID 为 -1 的占位会变成一张
## 「点不动的牌」，而那张牌在玩家眼里是「游戏坏了」。[br]
static func card_entries(p_pile: Variant, p_owned: Variant = []) -> Array:
	var out: Array = []
	if not (p_pile is Array):
		return out
	var owned_index: Dictionary = _owned_index(p_owned)
	for raw: Variant in (p_pile as Array):
		var cid: int = card_id_of(raw)
		if cid < 0:
			continue
		var known: Dictionary = owned_index.get(cid, {})
		out.append({
			KEY_CARD_INSTANCE_ID: cid,
			KEY_TEMPLATE_ID: _template_of(raw, known),
			KEY_LEVEL: _level_of(raw, known),
		})
	return out


## 条目里的卡牌实例 ID——[b]三种形态都认[/b]（[code]int[/code] /
## [code]Dictionary[/code] / [code]CardInstance[/code] 对象）。[br]
## [br][b]为什么字典读两个键[/b]：[code]card_instance_id[/code] 是规范键，
## [code]instance_id[/code] 是牌库侧的历史别名——它出现在生产牌库里过（见
## [code]CombatSystem.discard_card[/code] 的兼容读取），漏读会让那批条目整堆丢掉。[br]
static func card_id_of(p_entry: Variant) -> int:
	if p_entry is int:
		return p_entry
	if p_entry is float:
		return int(p_entry)  # JSON 往返后数字一律是 float
	var explicit: int = Seeding.entry_int(p_entry, KEY_CARD_INSTANCE_ID, NO_ID)
	if explicit >= 0:
		return explicit
	return Seeding.entry_int(p_entry, "instance_id", NO_ID)


## 条目是否表示一张[b]已升级[/b]的卡（[code]level > 1[/code]，见类文档）。[br]
## [br][b]等级未知时返回 false[/b]：手改档 / 图鉴缺记录只能诚实地按「不知道」处理——
## 报成「已升级」会让玩家以为自己的卡被改了。[br]
static func is_upgraded(p_entry: Variant) -> bool:
	return Seeding.entry_int(p_entry, KEY_LEVEL, LEVEL_UNKNOWN) > 1


## 存档段（非字典一律空——不臆造）。
static func section(p_payload: Variant) -> Dictionary:
	if not (p_payload is Dictionary):
		return {}
	var raw: Variant = (p_payload as Dictionary).get(KEY_CARDS, {})
	return raw if raw is Dictionary else {}


## 存档里某一堆的[b]条目[/b]（原样返回，供往返等价断言）。[br]
## 存档里某一堆的[b]条目[/b]（按本模块的规范形态返回——与 [method card_entries]
## 同一口径）。[br]
## [br][b]为什么要过一遍规范化[/b]：存档往返把 int 变成 float，直接拿读回的原样条目
## 与写侧的 int 条目逐项比会全是类型差（而那不是缺陷，读侧本来就按 [code]int()[/code] 消费）。
## 两处都过同一个解析口径，比的才是「同一副牌」。[br]
## [param p_pile_key] 三堆之一（[constant KEY_HAND] / [constant KEY_DRAW_PILE] /
## [constant KEY_DISCARD_PILE]）。[br]
static func entries_of(p_payload: Variant, p_pile_key: String) -> Array:
	var raw: Variant = section(p_payload).get(p_pile_key, [])
	return card_entries(raw)


## 存档里某一堆的[b]实例 ID 序列[/b]（重建牌堆吃它——顺序即抽牌顺序）。
static func ids_of(p_payload: Variant, p_pile_key: String) -> Array:
	var out: Array = []
	for raw: Variant in entries_of(p_payload, p_pile_key):
		var cid: int = card_id_of(raw)
		if cid >= 0:
			out.append(cid)
	return out


## 这一份档是否带着牌面快照——读档侧「要不要接管牌堆」的唯一判据。[br]
## [br][b]判据是「三堆有没有内容」而不是「有没有这个键」[/b]：v3 老档经迁移补出的
## 是三个空数组（形状归一，不代表存过牌面），照它去接管只会把 [code]battle_start[/code]
## 刚发的开局手牌清成空手。空 = 没有快照 → 走自然发牌那条老路。[br]
static func has_state(p_payload: Variant) -> bool:
	for pile_key: String in PILE_KEYS:
		if not entries_of(p_payload, pile_key).is_empty():
			return true
	return false


# === 内部 ====================================================================

## 收藏快照 → [code]{card_instance_id: {template_id, level}}[/code]。[br]
## [br][b]模板落 String[/b]：内存里是 StringName，往返会变 String——写侧就统一，
## 免得「存前与读后逐项相等」这条断言永远不成立。[br]
static func _owned_index(p_owned: Variant) -> Dictionary:
	var out: Dictionary = {}
	if not (p_owned is Array):
		return out
	for raw: Variant in (p_owned as Array):
		var cid: int = Seeding.entry_int(raw, KEY_CARD_INSTANCE_ID, NO_ID)
		if cid < 0:
			continue
		out[cid] = {
			KEY_TEMPLATE_ID: str(Seeding.entry_raw(raw, KEY_TEMPLATE_ID)),
			KEY_LEVEL: Seeding.entry_int(raw, KEY_LEVEL, LEVEL_UNKNOWN),
		}
	return out


## 条目的模板 ID——条目自带优先，其次收藏快照，都没有时空串（不猜）。[br]
## [br][b]为什么条目自带优先[/b]：条目上的模板 ID 是[b]这张牌自己说的[/b]；
## 收藏快照可能在两处不一致（手改档 / 收藏表未同步），以牌面为准更接近真值。[br]
## [br][b]「没有」与「值是 null」要分开判[/b]：裸 ID 条目取 [code]template_id[/code]
## 得到的是 null，而 [code]str(null)[/code] 是字符串 [code]"<null>"[/code]（非空！
## ）——不显式判空的话，每一条裸 ID 都会被写上 [code]"<null>"[/code] 这个假模板名，
## 而它看起来「有值」，排查时极难回头怀疑到这里。
static func _template_of(p_entry: Variant, p_known: Dictionary) -> String:
	var raw: Variant = Seeding.entry_raw(p_entry, KEY_TEMPLATE_ID)
	if raw != null:
		var own: String = str(raw)
		if not own.is_empty():
			return own
	return str(p_known.get(KEY_TEMPLATE_ID, ""))


## 条目的等级——条目自带优先（0 = 未标注，落到收藏快照），见 [method _template_of]。
static func _level_of(p_entry: Variant, p_known: Dictionary) -> int:
	var own: int = Seeding.entry_int(p_entry, KEY_LEVEL, LEVEL_UNKNOWN)
	if own > 0:
		return own
	return int(p_known.get(KEY_LEVEL, LEVEL_UNKNOWN))
