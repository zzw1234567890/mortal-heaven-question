extends RefCounted
## NodeIconArt —— 节点[b]类型图标[/b]的贴图来源：14 张水墨线稿（每类一张）。[br]
##
## [b]为什么与 [NodeIconAtlas] 并存而不是替换它[/b]：图集是 Story 001 的程序化占位
## （32px 格子里现画的几何 glyph），它同时供着类型主色、类型短标签两件事，且既有断言
## 逐格钉死了它的尺寸/位置/色值。本轮要的是「线稿图标」，与「类型色/短标签」是两件事
## ——于是新开一条[b]并行[/b]通路：图标走这里，色与标签仍走图集。任一缺失都不崩。[br]
##
## [br][b]缺图不留白[/b]：某类型没有对应 PNG 时返回 [code]null[/code]，调用方回退到
## 图集 glyph——「某个类型永远没图标」在运行时不报错（只是画成旧样子），所以有一条
## 单测按本模块的映射表逐类断言文件在盘上（见
## [code]tests/unit/exploration_ui/test_node_icon_files.gd[/code]）。[br]
##
## [br][b]零状态所有权[/b]（ADR-0031 §2）：只读资源，不读 GSM、不写任何玩法状态。[br]
##
## [br]来源: 本轮任务书任务二（节点配图标）、design/gdd/exploration-ui-system.md §2、
## ADR-0031 §2/§5。

## 图标目录。
const ICON_DIR: String = "res://assets/environments/node_icons/"
## 文件名前缀（[code]node_<名字>.png[/code]）。
const ICON_PREFIX: String = "node_"
## ★ 类型映射表——[code]ExplorationSystem.NodeType[/code] 枚举值 → 文件名主干 ★。[br]
## [br][b]为什么是模块级常量[/b]：这是「哪个类型该有哪张图」的唯一出处，单测直接读它
## 逐类查盘（任务书的硬要求：缺失的图标在运行时不报错，只能靠一条断言兜住）。[br]
## [br][b]为什么是字符串而不是枚举引用[/b]：本模块不认识探索系统（UI 不该依赖玩法枚举，
## 见 .claude/rules/ui-code.md）；数字键与 [code]NodeType[/code] 的对应由单测交叉断言，
## 两边分叉时那条断言会红。
const TYPE_ICON_NAMES: Dictionary = {
	0: "entry",          # ENTRY 入口
	1: "combat",         # COMBAT 战斗
	2: "elite",          # ELITE 精英
	3: "boss",           # BOSS
	4: "event",          # EVENT 事件
	5: "shop",           # SHOP 商店
	6: "teleport",       # TELEPORT 传送
	7: "action_spring",  # ACTION_SPRING 行动力泉
	8: "rest",           # REST 回复点
	9: "tribulation",    # TRIBULATION 渡劫台
	10: "harvest",       # HARVEST 采集点
	11: "alchemy",       # ALCHEMY 炼丹台
	12: "forge",         # FORGE 炼器台
	13: "meditation",    # MEDITATION 洞府
}

## 已解析过的纹理（同一张图会被每个节点反复取，加载一次即可；含「没有」的负结果）。
static var _cache: Dictionary = {}
## 已烘好的「印章」贴图（圆形裁切 + 压色后的 128×128 小图——见 [method stamp_of]）。
static var _stamps: Dictionary = {}

## 印章贴图边长（px）。[br]
## [br][b]为什么要烘一张小图而不是直接用 1536×1536 原图[/b]：图标在屏幕上最大也只有
## 约 56×1.5 ≈ 84px（[constant NodeGraphStyle.NODE_SIZE] × 悬停 1.1 × 视口上限 1.5），
## 一张 1536² 的图持有 9.4MB 显存而只用得上 84px；烘到 128 后 14 类合计约 0.9MB，
## 且「圆形裁切」这件事只需做一次（原图裁切要靠逐帧的 shader 或 discard）。[br]
## [br]128 在 84px 下有 1.5 倍余量（缩放采样不会糊）。
const STAMP_SIZE: int = 128
## 印章裁切的圆半径（相对边长的一半——0.5 = 内切圆）。
const STAMP_RADIUS: float = 0.5
## 印章纸张的压暗量（0..1 的亮度减法）。[br]
## [br][b]为什么压而不是留原色[/b]：原图是[b]米白宣纸[/b]（实测均值 RGB 227/215/197、
## 亮度中位 223），直接贴到本作的深色地图上是一块发光的白斑——反馈里「跟深色 UI 打架」
## 指的正是这个。压 0.38 之后纸张落到亮度 ≈ 130 的暖灰，仍然明显亮于迷雾区（亮度 20
## 上下），节点照样跳得出来，但它不再刺眼。[br]
## [br][b]为什么用减法而不是乘法[/b]：减法把墨线（亮度约 30）一并压到近黑、纸张压到
## 中灰，[b]墨与纸的落差还变大了一点[/b]；乘法是等比缩小，浅色线稿的中间调会被压平。
const STAMP_DARKEN: float = 0.38


## 类型图标路径；该类型未登记或无文件时返回空串（调用方据此回退图集）。
static func path_of(p_type_id: int) -> String:
	var stem: String = str(TYPE_ICON_NAMES.get(p_type_id, ""))
	if stem.is_empty():
		return ""
	var path: String = ICON_DIR + ICON_PREFIX + stem + ".png"
	return path if ResourceLoader.exists(path) else ""


## 类型图标纹理（原图 1536×1536）；缺失时返回 null（调用方回退图集 glyph）。
static func texture_of(p_type_id: int) -> Texture2D:
	if _cache.has(p_type_id):
		return _cache[p_type_id] as Texture2D
	var path: String = path_of(p_type_id)
	var texture: Texture2D = null
	if not path.is_empty():
		texture = load(path) as Texture2D
	_cache[p_type_id] = texture
	return texture


## 类型图标[b]印章[/b]——原图缩小 + 圆形裁切（带 1.5px 抗锯齿）+ 压色；缺失时 null。[br]
## [br][b]为什么「裁成圆」而不是留方[/b]：原图是方形纸片，方形的浅色纸直接压在地图上
## 会读成一个「贴上去的方块」——反馈原话正是「不能是方块」。裁成圆之后它是一枚印章：
## 圆形边缘天然地把纸张收进一个边界里，且与地盘石台的八边形形成内外两重形状。[br]
## [br][b]成本[/b]：每类一次性 128² 次取像素 + 写像素（14 类合计约 23 万次），首次
## 绘制时发生，之后走 [member _stamps] 缓存。代价是首帧多几毫秒；换来的是不用引入
## shader 资源（[code]discard[/code] 方案则要每次绘制带一次材质状态切换）。[br]
## [br][b]返回[/b]：128×128 的 [ImageTexture]（已预乘无关——普通混合即可）。
static func stamp_of(p_type_id: int) -> Texture2D:
	if _stamps.has(p_type_id):
		return _stamps[p_type_id] as Texture2D
	var texture: Texture2D = texture_of(p_type_id)
	var stamp: Texture2D = null
	if texture != null:
		stamp = _bake_stamp(texture)
	_stamps[p_type_id] = stamp
	return stamp


## 由原图烘出印章（见 [method stamp_of] 的成本说明）。[br]
## [br][b]为什么不用 [code]Image.adjust_brightness[/code][/b]：Godot 4.6 的
## [code]Image[/code] 没有这个方法（实测 [code]has_method[/code] 为 false，调用会
## 「Invalid call」并把烘图整段打断——印章返回 null，图标静默退回旧 glyph）。压色与
## 圆形掩膜本来就都要逐像素走一遍，合成一个循环省一趟 16k 像素的遍历。
static func _bake_stamp(p_texture: Texture2D) -> Texture2D:
	var image: Image = p_texture.get_image()
	if image == null:
		return null
	if image.is_compressed():
		image.decompress()  # detect_3d 若把它转成了 VRAM 压缩格式，先解回像素
	image.convert(Image.FORMAT_RGBA8)
	image.resize(STAMP_SIZE, STAMP_SIZE, Image.INTERPOLATE_LANCZOS)
	_apply_stamp_face(image)
	return ImageTexture.create_from_image(image)


## 就地压色 + 打圆形 alpha 掩膜（[param p_image] 必须已是 RGBA8）。[br]
## [br][b]压色用减法[/b]（[constant STAMP_DARKEN]），不用 [method Color.darkened]：
## 乘法是等比缩小，浅色线稿的中间调会被压平；减法把墨线与纸张一起拉下来，墨/纸的
## 落差反而保住了。[br]
## [br][b]1.5px 羽化[/b]：硬切的圆边在缩到 50% 时会出锯齿；1.5px 的过渡在 128px 图上
## 看不出「糊」，缩下去却正好当作超采样用。[br]
## [br][b]为什么用平方距离比较[/b]：省掉 16k 次开方（同样的判定，纯算术）。
static func _apply_stamp_face(p_image: Image) -> void:
	var edge: float = float(STAMP_SIZE) * STAMP_RADIUS
	var center: float = float(STAMP_SIZE) * 0.5
	var feather: float = 1.5
	var outer_sq: float = edge * edge
	var inner: float = edge - feather
	var inner_sq: float = inner * inner
	for y: int in STAMP_SIZE:
		var dy: float = float(y) + 0.5 - center
		for x: int in STAMP_SIZE:
			var dx: float = float(x) + 0.5 - center
			var dist_sq: float = dx * dx + dy * dy
			if dist_sq >= outer_sq:
				p_image.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
				continue
			var pixel: Color = p_image.get_pixel(x, y)
			pixel.r = maxf(pixel.r - STAMP_DARKEN, 0.0)
			pixel.g = maxf(pixel.g - STAMP_DARKEN, 0.0)
			pixel.b = maxf(pixel.b - STAMP_DARKEN, 0.0)
			if dist_sq > inner_sq:
				var t: float = (edge - sqrt(dist_sq)) / feather
				pixel.a *= clampf(t, 0.0, 1.0)
			p_image.set_pixel(x, y, pixel)


## 清空缓存（测试用：换资源后免得起新进程）。
static func clear_cache() -> void:
	_cache.clear()
	_stamps.clear()
