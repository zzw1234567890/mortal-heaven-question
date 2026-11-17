extends RefCounted
## DeckViewSources —— 卡组查看面板的[b]取数与依赖解析[/b]（纯逻辑，不碰控件树）。[br]
## [br][b]为什么单独一处[/b]：面板要守 300 行软上限（.claude/docs/coding-standards.md），
## 而「卡组从哪来、链路没接上时怎么降级、提示行该说什么」与「控件怎么搭、按键意味着
## 什么」是两件事（同 [code]deck_view_rows.gd[/code] / [code]combat_bag_readout.gd[/code]
## 的拆因）。[br]
## [br][b]依赖解析三十行只写一遍[/b]：[code]/root[/code] 回落是项目里反复出现的动作，
## 本模块把「注入优先、否则按 Autoload 名找」收成一个方法——面板只传字段名与
## Autoload 名，不自己拼 [code]NodePath[/code]。[br]
## [br][b]返回值可能是 null[/b]：两个来源都没有时如实返回——取数侧各自降级
## （[code]DeckViewRows[/code] 判空后不出行），本模块不臆造替身。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：全是 static 纯函数，不缓存、不持节点。[br]
## [br][b]文案本地化豁免[/b]：提示行句子集中在此（项目暂无本地化系统——与
## [code]deck_view_rows.gd[/code] 同源标注）。[br]
##
## 来源: ADR-0031 §2、.claude/rules/ui-code.md、先例
## [code]inventory_model.gd[/code]（注入优先 + Autoload 回落的读侧口径）。

## 只读声明（规格明写「所有编辑按钮禁用」，说清楚比让玩家找按钮强）。
const TEXT_READONLY: String = "只读查看——战斗中不可编辑卡组。"
## 键盘操作提示（与背包面板同源——不靠玩家自己猜）。
const TEXT_HINT: String = "↑  ↓ 选牌，回车看详情，Esc 返回。"
## 提示行各段之间的分隔（两格——与面板其他提示行的呼吸感一致）。
const HINT_SEPARATOR: String = "  "


## 卡组实例 ID 列表（[code]DeckEditingSystem.get_deck_cards[/code]；不可用时空数组）。[br]
## [br][b]每次现取不缓存[/b]：面板停留期间可能刚好打出一张牌——缓存会让标注停在
## 打开那一刻的旧状态（零状态所有权，见面板类文档）。[br]
## [br][b]复制一份再交出去[/b]：直接返回系统持有的那份数组，调用方一个不经意的
## 修改就写进了系统内部状态（[code]get_deck_cards[/code] 的契约本就是给副本）。[br]
## [br][param p_injected] 面板上注入的卡组引用（可为 null）。[br]
## [param p_autoload] 回落查找的 Autoload 节点名。
static func deck_ids(p_injected: Variant, p_autoload: StringName) -> Array:
	var deck: Node = resolve(p_injected, p_autoload)
	if deck == null or not deck.has_method(&"get_deck_cards"):
		return []
	var raw: Variant = deck.call(&"get_deck_cards")
	return (raw as Array).duplicate() if raw is Array else []


## 依赖解析——注入优先，否则按 [code]/root[/code] 找 Autoload。[br]
## [br][param p_injected] 面板上的注入引用（任何类型；非 Node / 已失效一律当作没注入）。[br]
## [br][b]返回[/b]：可用节点或 null（见类文档——不臆造替身）。
static func resolve(p_injected: Variant, p_autoload: StringName) -> Node:
	if p_injected != null and p_injected is Node and is_instance_valid(p_injected):
		return p_injected
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath(String(p_autoload)))


## 提示行文案——只读声明 + 操作提示 +（模板未加载时）缺失说明。[br]
## [br][param p_unresolved_hint] [code]DeckViewRows.resolution_hint[/code] 的产出
## （无缺失时为空串，此处跳过该段）。[br]
## [br][b]三件事挤一行[/b]：只读状态、怎么按键、少了几张——玩家扫一眼就够；
## 分成三行会把这行提示顶成面板的主要视觉（它是脚注）。
static func message_for(p_unresolved_hint: String) -> String:
	var parts: Array = [TEXT_READONLY, TEXT_HINT]
	if not p_unresolved_hint.strip_edges().is_empty():
		parts.append(p_unresolved_hint)
	return HINT_SEPARATOR.join(parts)
