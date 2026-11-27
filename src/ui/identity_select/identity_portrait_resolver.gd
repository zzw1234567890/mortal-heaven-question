extends RefCounted
## IdentityPortraitResolver —— 身份卡立绘/占位配色的解析（静态纯函数 + 纹理缓存）。
##
## [b]职责[/b]：回答两个问题——「这个身份的两名角色分别是谁、谁有立绘」以及
## 「没有立绘时用哪套配色」。[br]
## [br][b]立绘来源[/b]：`assets/characters/portraits/char_<骨架名>_portrait_full.png`。
## 资产名与 card_id 并不逐字相等（[code]su_jian_ming[/code] 的立绘实名
## [code]char_su_jianming_portrait_full.png[/code]——只少一道下划线），
## 故扫目录建「骨架名」索引再查，不猜文件名。[br]
## [br][b]角色配对来源[/b]：读 [code]identity_templates.gd[/code] 的
## [code]character_details[/code]（ADR-0022 单一事实来源）取 [code]card_id[/code]
## 与 [code]display_name[/code] 的配对——UI 侧只消费这张表，不另立一张。
## 身份 id 查无（测试手搓条目 / 数据缺失）时回退到条目自带的显示名，
## 那一路没有 card_id，因此恒走程序化占位，不会误配到别人的立绘。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：只读数据表与资产路径，不写任何游戏状态。[br]
## [br][b]不新增贴图[/b]：没有立绘时不给新 png——配色 + 印章纹样由
## [code]identity_portrait_tile.gd[/code] 用 [method CanvasItem._draw] 现画。[br]
## [br]来源: ADR-0022、ADR-0031 §2/§5、design/gdd/identity-selection-system.md
## §用户界面需求、story-004-identity-select-ui.md。

## 身份模板表（角色配对唯一来源）。
const Templates := preload("res://src/feature/identity/identity_templates.gd")

## 立绘目录与文件名模板。[br]
## [br][b]为什么按「骨架名」而不是文件名猜[/b]：资产名与 card_id 不逐字相等
## （[code]su_jian_ming[/code] 的立绘少一道下划线），猜候选名是在赌变体规则。
## 改为扫目录把每个 png 归一成骨架名（去掉前缀/后缀/全部下划线）建索引，
## card_id 也归一后查表——任何下划线写法都能命中。
const PORTRAIT_DIR: String = "res://assets/characters/portraits/"
const PORTRAIT_PREFIX: String = "char_"
const PORTRAIT_SUFFIX: String = "_portrait_full.png"
const PORTRAIT_PATTERN: String = PORTRAIT_PREFIX + "%s" + PORTRAIT_SUFFIX

## 没有立绘的身份按 [code]style_tag[/code] 回退的固定色板（五行/派系观感）。
## 每个值 = {top 渐变上沿, bottom 渐变下沿, accent 印章纹样色}。[br]
## [br][b]为什么取这么亮[/b]：占位的硬性要求是「不能是空白色块」——早先的
## 暗色取值（如 #8A2E33→#3A1013）在 104×72 的格子里读起来就是一块黑。
## 现在上沿取中高明度、下沿只压到中暗，印章环用近白色，缩到最小也认得出。
const STYLE_PALETTES: Dictionary = {
	"续航": {"top": Color("#3FB8A8"), "bottom": Color("#1E6B66"), "accent": Color("#E8FFF8")},
	"快攻": {"top": Color("#D9534F"), "bottom": Color("#8C2320"), "accent": Color("#FFF0EC")},
	"灵活": {"top": Color("#9B6BD6"), "bottom": Color("#552A80"), "accent": Color("#F6EEFF")},
	"控制": {"top": Color("#4A8FD9"), "bottom": Color("#22497E"), "accent": Color("#EAF4FF")},
	"辅助": {"top": Color("#E08A3C"), "bottom": Color("#8A4A15"), "accent": Color("#FFF3E4")},
	"运营": {"top": Color("#5FB87E"), "bottom": Color("#256B41"), "accent": Color("#EFFFF3")},
}

## 兜底色板——style_tag 不在表内时用（中性玄色，仍非空白块）。
const FALLBACK_PALETTE: Dictionary = {
	"top": Color("#6E6E7A"), "bottom": Color("#33333C"), "accent": Color("#F0F0F5"),
}

## 立绘纹理缓存 {path: Texture2D}——同资产多卡复用，不重复 load。
static var _cache: Dictionary = {}
## 骨架名索引 {骨架名: 路径}——首次查不到时懒建（见 [method _ensure_index]）。
static var _index: Dictionary = {}
static var _index_built: bool = false


## 身份的两名角色配对——[code][{card_id, display_name}][/code]。[br]
## [br][b]参数[/b] [param p_identity_id]: 身份 id（条目里的 [code]identity_id[/code]）。[br]
## [param p_display_names]: 条目自带的显示名（模板查无时的回退源——那一路 card_id
## 为空字符串，因此只会拿到程序化占位）。[br]
static func character_cards(p_identity_id: StringName,
		p_display_names: Array) -> Array[Dictionary]:
	var details: Array = _template_details(p_identity_id)
	var out: Array[Dictionary] = []
	for raw: Variant in details:
		if raw is Dictionary:
			out.append({
				"card_id": str((raw as Dictionary).get(&"card_id", "")),
				"display_name": str((raw as Dictionary).get(&"display_name", "")),
			})
	if not out.is_empty():
		return out
	for raw_name: Variant in p_display_names:
		out.append({"card_id": "", "display_name": str(raw_name)})
	return out


## 角色立绘纹理——没有资产返回 null（调用方据此走程序化占位）。[br]
## [br][b]返回[/b]: [Texture2D] 或 null。
static func portrait_for(card_id: String) -> Texture2D:
	if card_id.is_empty():
		return null
	var path: String = resolve_path(card_id)
	if path.is_empty():
		return null
	if _cache.has(path):
		return _cache[path]
	var tex: Texture2D = load(path) as Texture2D
	_cache[path] = tex
	return tex


## 立绘资产路径——把 card_id 归一成骨架名后查目录索引，查无返回空串。[br]
## [br][b]归一规则[/b]：去掉全部下划线再比（[code]su_jian_ming[/code] 与
## 资产名里的 [code]su_jianming[/code] 归一后同为 [code]sujianming[/code]）。
static func resolve_path(card_id: String) -> String:
	if card_id.is_empty():
		return ""
	_ensure_index()
	return str(_index.get(_skeleton(card_id), ""))


## 懒建骨架名索引——首次查询时才扫目录（无立绘的身份不付这次扫描）。[br]
## [br][b]只在目录空时重扫[/b]：索引非空后直接返回，避免每张卡都开一次目录。
static func _ensure_index() -> void:
	if _index_built:
		return
	_index_built = true
	var dir: DirAccess = DirAccess.open(PORTRAIT_DIR)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		var file: String = file_name.strip_edges()
		if not file.begins_with(PORTRAIT_PREFIX) or not file.ends_with(PORTRAIT_SUFFIX):
			continue
		if not ResourceLoader.exists(PORTRAIT_DIR + file):
			continue
		var core: String = file.substr(PORTRAIT_PREFIX.length(),
				file.length() - PORTRAIT_PREFIX.length() - PORTRAIT_SUFFIX.length())
		var key: String = _skeleton(core)
		if not _index.has(key):
			_index[key] = PORTRAIT_DIR + file


## 骨架名——去掉全部下划线（大小写无关的比对基准）。
static func _skeleton(p_name: String) -> String:
	return p_name.replace("_", "").to_lower()


## 该身份是否至少有一张立绘（测试与视觉分支判定用）。
static func has_any_portrait(p_identity_id: StringName, p_display_names: Array) -> bool:
	for card: Dictionary in character_cards(p_identity_id, p_display_names):
		if portrait_for(str(card["card_id"])) != null:
			return true
	return false


## 占位色板——按身份 id 取风格标签，再按 [code]style_tag[/code] 查固定色板。[br]
## [br][b]返回[/b]: [code]{top, bottom, accent}[/code]（恒非空——查无走
## [constant FALLBACK_PALETTE]）。
static func palette_for(p_identity_id: StringName, p_style_tag: String) -> Dictionary:
	var tag: String = _template_style_tag(p_identity_id)
	if tag.is_empty():
		tag = p_style_tag
	if STYLE_PALETTES.has(tag):
		return STYLE_PALETTES[tag]
	return FALLBACK_PALETTE


## 取身份模板的 [code]character_details[/code]（查无返回空数组）。
static func _template_details(p_identity_id: StringName) -> Array:
	var table: Dictionary = Templates.IDENTITY_TEMPLATES
	if not p_identity_id.is_empty() and table.has(p_identity_id):
		var tmpl: Dictionary = table[p_identity_id]
		var details: Variant = tmpl.get(&"character_details", [])
		if details is Array:
			return details
	return []


## 取身份模板的 [code]style_tag[/code]（查无返回空串）。
static func _template_style_tag(p_identity_id: StringName) -> String:
	var table: Dictionary = Templates.IDENTITY_TEMPLATES
	if not p_identity_id.is_empty() and table.has(p_identity_id):
		return str((table[p_identity_id] as Dictionary).get(&"style_tag", ""))
	return ""
