extends RefCounted
## MapSelectNotice —— 地图选择界面的[b]面向玩家提示出口[/b]（从 [MapSelectScreen] 拆出）。[br]
## [br][b]为什么单独一处[/b]：屏幕脚本已贴 300 行软上限
## （.claude/docs/coding-standards.md），而「未解锁卡片的条件文案怎么念、念到哪去」
## 与「列表怎么取、点击怎么分流」是两件事（同 [code]map_select_data.gd[/code] /
## [code]map_select_animator.gd[/code] 拆分先例）。[br]
## [br][b]本模块补的断链[/b]：未解锁卡此前点击是 [code]pass[/code]——既不进图
## 也不给任何反馈，玩家只能逐张试出「为什么点不动」（卡片上只有 🔒 与悬停
## tooltip，触屏/手柄路径连悬停都没有）。本轮把「点击未解锁卡」改成弹一条中文
## 条件提示（「需筑基期」/「需通关苍玄古战场」），提示文案与灰显判据同源。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本模块不写 GSM、不改卡片、不发进入
## 意图——只把条目里已有的字段念成一句中文并交给通知区域。[br]
## [br][b]判定同源[/b]：[method is_locked] 与 [code]MapSelectScreen.should_show_lock[/code]
## 是同一字段 [code]is_unlocked[/code] 的取反镜像（与
## [code]MapCard.is_unlocked_card[/code] 同一份豁免注记：字段是单一真理来源，
## 两侧互为取反，不互相引用以免 preload 循环）。[br]
## [br][b]文案本地化豁免[/b]：与各 [code]TEXT_*[/code] 同源口径（项目暂无本地化系统）。[br]
##
## 来源: design/gdd/exploration-ui-system.md §1（未解锁灰显 + 标明所需境界）、
## design/gdd/exploration-system.md §8 地图初始解锁顺序、ADR-0031 §2、
## hud Story 004 通知接口。

## HUD 挂载入口（通知区域在常驻 HUD 上，见 [HudBootstrap]）。
const HudBootstrapScript := preload("res://src/ui/hud/hud_bootstrap.gd")

## SceneManager 绝对路径（HUD 挂在它的 PersistentLayer 下）。
const SCENE_MANAGER_PATH: StringName = &"/root/SceneManager"

## 宿主注入字段名——测试用通知入口 [code]func(type, text) -> int[/code]。
const FIELD_NOTIFY_CB: StringName = &"notify_cb"

## 提示类型（HUD 通知区域色档）。[br]
## [br][b]为什么是 system[/b]：这条提示回答的是「我为什么点不动」——普通通知会在
## 连点多张锁定卡时按容量规则互相挤出（G2 裁决），玩家刚好错过就还是不知道为什么；
## system 为重要通知（白字 5s、不被挤出），与该提示的「解释性」定位相符。
const NOTIFY_TYPE: String = "system"

## 条件文案的数字形式——条目缺 [code]locked_hint[/code] 时的回退
## （旧载荷兼容；Feature 层给的是「需筑基期」这类中文境界名）。
const TEXT_REALM_DIGIT: String = "需%d境界"


## 卡片是否处于未解锁态——[code]is_unlocked[/code] 字段的取反镜像
## （缺字段按已解锁处理，与 [code]MapSelectScreen.should_show_lock[/code] 同口径）。
static func is_locked(p_entry: Dictionary) -> bool:
	return not bool(p_entry.get(&"is_unlocked", true))


## 未解锁卡片的中文条件文案。[br]
## [br][param p_entry] 地图条目（[code]get_map_list()[/code] 的单条）。[br]
## [br][b]返回[/b]：条目自带的 [code]locked_hint[/code]（Feature 层按探明表算好的
## 「需筑基期」/「需通关苍玄古战场」/两者并排）；已解锁或字段缺失时——
## 已解锁返回空串，字段缺失回退数字形式（旧载荷兼容）。[br]
static func locked_hint_text(p_entry: Dictionary) -> String:
	if not is_locked(p_entry):
		return ""
	var hint: String = str(p_entry.get(&"locked_hint", ""))
	if not hint.is_empty():
		return hint
	return TEXT_REALM_DIGIT % int(p_entry.get(&"realm_requirement", 0))


## 点击未解锁卡的中文提示——发出提示并返回实际展示的文案。[br]
## [br][param p_host] 宿主屏幕（读它的注入字段 + 作通知入口查找锚点）。[br]
## [param p_entry] 被点击的条目（[b]已解锁条目静默返回空串[/b]——已通关不可重入
## 也走这条路，它不是缺陷而是设计，不该弹「条件不足」）。[br]
## [br][b]返回[/b]：展示的文案（空串 = 本条不该提示 / 无提示出口）；测试断言用。[br]
## [br][b]无出口时的降级[/b]：只留 [method @GlobalScope.push_warning]，不把缺 UI
## 变成崩溃（[code]shop_node_presenter.gd[/code] 同源口径）。
static func notify_locked(p_host: Node, p_entry: Dictionary) -> String:
	var text: String = locked_hint_text(p_entry)
	if text.is_empty():
		return ""
	var sink: Callable = notification_sink(p_host)
	if sink.is_valid():
		sink.call(NOTIFY_TYPE, text)
		return text
	push_warning("MapSelectNotice: 无通知出口，解锁条件提示未展示（%s）" % text)
	return ""


## 通知入口——宿主注入字段优先，否则取常驻 HUD 的
## [method Hud.request_notification]；都没有时返回无效 Callable（调用方降级）。[br]
## [br][b]不注入也能工作的理由[/b]：生产路径由 HUD 兜底（玩家真的看得到提示），
## 注入只服务 headless 测试——不必为了测试在生产接线里多插一根线。[br]
static func notification_sink(p_host: Node) -> Callable:
	var injected: Variant = p_host.get(FIELD_NOTIFY_CB) if p_host != null else null
	if injected is Callable and (injected as Callable).is_valid():
		return injected
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return Callable()
	var sm: Node = tree.root.get_node_or_null(NodePath(String(SCENE_MANAGER_PATH)))
	var hud: Node = HudBootstrapScript.mounted(sm)
	if hud == null or not hud.has_method(&"request_notification"):
		return Callable()
	return Callable(hud, &"request_notification")
