extends RefCounted
## CharacterStatusRows —— 角色状态各小节的行文案组装（从 [CharacterStatusScreen] 拆出）。[br]
## [br][b]为什么单独一处[/b]：面板本轮的三节文案（境界/属性/角色）加起来会越过 300 行
## 软上限；而「这些数值该写成哪句话」与「面板怎么搭、键盘怎么走」是两件事（同
## [code]shop_panel_layout.gd[/code] 的拆分先例）。[br]
## [br][b]纯函数、只读传入的模型[/b]：本模块不 new 任何节点、不访问 Autoload——模型由
## 面板注入（模型缺失那条分支在面板里，不在这里）。[br]
## [br][b]只做文案，不做数值[/b]：[method rows_for] 拿到的数字逐字来自
## [code]CharacterStatusModel[/code]（它自己又是现实读 GSM / 境界表 / HP 账本），
## 本模块一次加减乘除都没有——唯一例外是「未记过账加注『模板基准』」这类纯措辞。[br]
## [br][b]文案本地化豁免[/b]：与 character_status_screen / shop_panel_screen 同源口径
## （项目暂无本地化系统）。
##
## 来源: GDD realm-system.md §2 境界属性表、GDD combat-system.md §7（跨场残血）、
## GDD deployment-system.md §10（不可用角色）、.claude/rules/ui-code.md（色盲可读——
## 状态写进文本）、先例 [code]inventory_catalog.gd[/code]（文案单点）。

## 小节标识（与 [code]CharacterStatusScreen.SECTIONS[/code] 的 id 一致）。
const SECTION_REALM: StringName = &"realm"
const SECTION_ATTRIBUTES: StringName = &"attributes"
const SECTION_CHARACTERS: StringName = &"characters"

## 角色行里「生命未记过账」的加注——让「满血」与「没数据」可区分。
const TEXT_HP_BASELINE: String = "（生命为模板基准）"
## 详情区里「模板查不到」的加注（字段值无从谈起——不拿 0 冒充攻击力）。
const TEXT_TEMPLATE_UNKNOWN: String = "卡牌模板暂不可查——只能看到角色位上的记录。"
## 详情区各字段的标签（与模板字段一一对应，顺序即显示顺序）。
const DETAIL_LABELS: Array = [
	["name", "名称"],
	["type_name", "类型"],
	["rarity_name", "稀有度"],
	["cost", "灵能消耗"],
	["base_attack", "攻击"],
	["base_defense", "防御"],
	["base_hp", "基础生命"],
	["hp_text", "当前生命"],
	["status_text", "出战状态"],
]


## 按小节取行——[b]返回 Array[Dictionary][/b]，每项
## [code]{text: String, payload: Dictionary}[/code]。[br]
## [br][b]为什么要连载荷一起给[/b]：角色行是可确认的（确认后看这条角色的详情），
## 面板要能拿回「这一行是哪个角色」——载荷随行一起产出，面板就不必维护
## 「下标 → 角色 ID」的第二份副本（刷新会换一批控件，副本必然与控件错位）。[br]
## [br][b]载荷为空 = 这一行不可确认[/b]：境界与属性行只是信息（点了没有下一步动作），
## 空载荷让面板把它们渲染成不可聚焦的文本行——不做一个点了没反应的按钮。[br]
## [br]未知小节 id 返回空数组（面板走空态分支，不臆造一行）。
static func rows_for(p_section_id: String, p_model: RefCounted) -> Array:
	if p_model == null:
		return []
	match p_section_id:
		"realm":
			return _texts_to_rows(realm_rows(p_model))
		"attributes":
			return _texts_to_rows(attribute_rows(p_model))
		"characters":
			return character_rows(p_model)
	return []


## 纯文本行 → 无载荷行（见 [method rows_for] 注记）。
static func _texts_to_rows(p_texts: Array) -> Array:
	var rows: Array = []
	for text: Variant in p_texts:
		rows.append({"text": str(text), "payload": {}})
	return rows


## 境界节：境界名 / 修为与上限 / 是否已至最高 / 是否陨落。[br]
## [br][b]修为与上限同显[/b]（[code]100 / 1000[/code]）：只给当前修为看不出离突破还有
## 多远；上限取自 [code]player.max_cultivation[/code]（GSM 的既有权）。[br]
## [br]后两行按条件出现——「已至最高境界」与「已陨落」都是[b]例外态[/b]，
## 常态下不占屏幕。
static func realm_rows(p_model: RefCounted) -> Array:
	var status: Dictionary = p_model.call(&"realm_status")
	var rows: Array = [
		"当前境界 · %s" % str(status.get("realm_name", "")),
		"修为 · %s" % str(status.get("cultivation_text", "")),
	]
	if bool(status.get("at_max_realm", false)):
		rows.append("已至最高境界 · 无需再突破")
	if bool(status.get("is_fallen", false)):
		rows.append("状态 · 已陨落")
	return rows


## 属性节：境界配置表那一档的每个键一行（[code]标签 · 值[/code]）。[br]
## [br][b]值逐字透传[/b]：本模块不做单位换算、不做区间夹取——测试直接拿这些行与
## [code]RealmSystem.realm_table[/code] 对照，任何加工都会破坏那条对照。[br]
## [br][b]行数由表决定[/b]：表里多一个键，这里就多一行——界面不需要跟着改。
static func attribute_rows(p_model: RefCounted) -> Array:
	var rows: Array = []
	for raw: Variant in p_model.call(&"attributes"):
		if raw is Dictionary:
			var entry: Dictionary = raw
			rows.append("%s · %s" % [str(entry.get("label", "")),
					str(entry.get("value_text", ""))])
	return rows


## 角色节：每个角色一行（名字 · 生命 · 攻击 · 出战态），载荷为该角色的 ID。[br]
## [br][b]阵亡标记写进文本[/b]（模型给的「已阵亡（不可出战）」）：不靠颜色单独承载
## 信息（.claude/rules/ui-code.md 色盲可读），且阵亡角色[b]照实列出而非隐藏[/b]——
## 玩家必须看得到谁倒了（GDD combat-system.md §7 的死亡跨场持久）。[br]
## [br][b]生命的来源由模型保证[/b]：[code]hp_text[/code] 已是「账本值或模板基准」的
## 最终结果，本模块只在未记账时加注「模板基准」——数值口径不在这里重算。
static func character_rows(p_model: RefCounted) -> Array:
	var rows: Array = []
	for raw: Variant in p_model.call(&"characters"):
		if not (raw is Dictionary):
			continue
		var entry: Dictionary = raw
		var line: String = "%s · 生命 %s · 攻击 %d · %s" % [
			str(entry.get("name", "")),
			str(entry.get("hp_text", "")),
			int(entry.get("attack", 0)),
			str(entry.get("status_text", "")),
		]
		if not bool(entry.get("hp_known", false)):
			line += TEXT_HP_BASELINE
		rows.append({
			"text": line,
			"payload": {"character_id": int(entry.get("character_id", -1))},
		})
	return rows


## 角色详情区的行（选中某角色后显示）——标签与值逐字来自模型给的投影。[br]
## [br][b]只列模板确实有的字段[/b]：值为空串的字段跳过（如稀有度未登记），
## 界面因此不会出现「类型 · 」这种半行。[br]
## [br][b]模板查不到时只给一行提示[/b]：此时 [code]type_name[/code] 等键根本不存在，
## 逐字段列会变成一片空白——不如直接说清楚为什么看不到。[br]
## [br][b]返回[/b]：Array[String]（空数组 = 没有可展示的详情，面板收起详情区）。
static func detail_rows(p_model: RefCounted, p_character_id: int) -> Array:
	if p_model == null:
		return []
	var detail: Dictionary = p_model.call(&"character_detail", p_character_id)
	if detail.is_empty():
		return []
	if not bool(detail.get("template_known", false)):
		return [TEXT_TEMPLATE_UNKNOWN]
	var rows: Array = []
	for pair: Variant in DETAIL_LABELS:
		var field: String = str((pair as Array)[0])
		var label: String = str((pair as Array)[1])
		var value: String = str(detail.get(field, ""))
		if value.strip_edges().is_empty():
			continue
		rows.append("%s · %s" % [label, value])
	if not str(detail.get("description", "")).strip_edges().is_empty():
		rows.append("描述 · %s" % str(detail.get("description")))
	if not bool(detail.get("hp_known", false)):
		rows.append("生命说明 · 尚无战斗记录，显示的是模板基准值")
	return rows

