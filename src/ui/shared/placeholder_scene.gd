class_name PlaceholderScene
extends Control
## PlaceholderScene —— SCENE_PATHS 占位场景共用实现（Sprint 18 场景补链）。
##
## [b]职责[/b]：闭合 [constant SceneManager.SCENE_PATHS] 中尚无对应 story 交付的
## 场景路径——深色底 + 场景标题 + 「尚未开放」状态 + 「返回」按钮。核心循环
## 转场（探索→商店、战斗→结算/战败、HUD→卡组编辑/修为养成）不再落到
## [code]scene_transition.gd[/code] 的「目标场景缺失 → 回退 MAIN_MENU」失败路径。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：不读不写任何游戏状态——只承载标题文案与
## 一次导航请求。[br]
## [br][b]零轮询[/b]（ADR-0031 §3）：无 [code]_process()[/code]——按钮信号驱动。[br]
## [br][b]导航[/b]：唯一出口经 [code]SceneManager.request_scene_change[/code]
## （ADR-0005——禁止直调 [code]change_scene_to_file[/code]）；[code]from[/code] 取
## [code]get_current_scene_id()[/code]（同 MainMenu/PauseMenu 先例，不写魔数）。[br]
## [br][b]出口按屏而异[/b]（2026-11-17）：战败屏「返回」回[b]主菜单[/b]，其余屏回
## [b]探索[/b]——目的地 / 转场类型 / 按钮文案三件事同进同退，判据收在
## [code]battle_record_exit.gd[/code]（见 [method _on_return_pressed]）。[br]
## [br][b]文案本地化豁免[/b]：项目暂无本地化系统——全部文案集中在本文件
## [constant TITLES] / [constant HINTS] 与
## [code]BattleRecordExit[/code] 的两个按钮词条，本地化 epic 入库后替换为 key
## （同 S16/S17 TEXT_* 口径）。[br]
## [br][b]战斗节点胜利标记[/b]：从战斗[b]胜利结算[/b]返回探索时，若结果为胜利，
## 标记战斗开始的节点为已清（GSM visited_nodes）。战败屏回主菜单那条路不跑这段
## 收尾（见 [method BattleRecordExit.returns_to_exploration]）。[br]
## [br][b]Boss 战胜利 = 本图通关[/b]：开战上下文里记的 [code]combat_type[/code]
## 为 [code]boss[/code] 时不走「标一格已清」，而是经
## [code]ExplorationSystem.end_exploration(BOSS_DEFEATED)[/code] 走完整通关结算
## （通关次数 / 首通标记 / 通关奖励 / 结算面板视图）——见 [method _settle_boss_victory]。[br]
## 来源: ADR-0005（场景切换唯一仲裁）、ADR-0031（表现层基线）、
## gate-check-presentation-layer-complete-2026-11-08 §B1（四占位场景）、
## ADR-0014 §决策 1 状态分层模型、GDD exploration-system.md §5、
## GDD exploration-ui-system.md §7。

## 结算屏出口裁决（战败回主菜单 / 其余回探索——见 [BattleRecordExit]）。[br]
## [br][b]SceneID / TransitionType 的引用收在它那里[/b]：本文件只传 [member screen_id]，
## 不再自己比较枚举——三块屏共用一份判定，出口口径才只有一个地方可改。
const ExitScript := preload("res://src/ui/shared/battle_record_exit.gd")
## 开战上下文（跨场景读回「这场是不是 Boss 战」——见
## [method _mark_battle_node_cleared_if_victory]）。
const LaunchScript := preload("res://src/feature/combat/combat_launch_context.gd")
## 探索系统脚本——[code]EndReason[/code] 枚举的真理来源（preload 避免 headless 下
## 的全局名解析问题；同 exploration_scene.gd 口径，不在这里另写一份字面值）。
const ExplorationSystemScript := preload("res://src/feature/exploration_system.gd")

## 底色（深墨基底——与 identity_select / loading 同源 BG-0 口径）。
const BG_COLOR: Color = Color(0.071, 0.071, 0.086)
## 标题字号（px——1920×1080 基准）。
const TITLE_FONT_SIZE: int = 32
## 提示正文字号（px）。
const HINT_FONT_SIZE: int = 16
## 内容块纵向间距（px）。
const CONTENT_SEPARATION: int = 16

## 固定 UI 词条（项目暂无本地化系统——S16/S17 TEXT_* 同源豁免注记）。[br]
## [br][b]返回按钮文案不在这里[/b]：它是[b]随屏而异[/b]的（战败屏回主菜单、其余回
## 探索），单一真理来源是 [code]BattleRecordExit.button_text[/code]——见
## [method return_button_text]。
const TEXT_NOT_AVAILABLE: String = "该界面尚未开放"
const TEXT_FALLBACK_TITLE: String = "占位场景"

## 本屏「返回」按钮的文案（转发 [code]BattleRecordExit[/code]——两屏目的地不同、
## 措辞随之不同）。[br]
## [br]做成函数而不是常量：占位期这一条文案随 [member screen_id] 变，写成常量就
## 必须在这里再抄一份「哪个 ID 对应哪句话」的判定——那正是要消灭的第二份真理。[br]
## [br][b]恒非含糊的「返回」二字[/b]：每块屏都写明回的是哪一层
## （「返回探索」/「返回主菜单」）。
static func return_button_text(p_screen_id: int) -> String:
	return ExitScript.button_text(p_screen_id)

## SceneID → 标题（键为 SceneManager.SceneID 字面值——const Dictionary 不可引用
## 脚本常量，镜像口径同 hud.gd SCENE_VISIBILITY / state_transition_matrix.gd）。
## 事件面板（7）已不在表中——Sprint 18 起事件走探索层 overlay
## （event_panel.tscn 挂真实 EventPanelScreen 脚本）；坊市（6）与修炼室（10）同样
## 已换挂真实界面（[code]ShopScreen[/code] / [code]CultivationScreen[/code]），
## 它们不再是占位场景，条目留着只会变成一份指向不存在的占位契约的旧账。
const TITLES: Dictionary = {
	2: "卡组编辑",    # SceneID.DECK_EDITING
	8: "战斗结算",    # SceneID.RESULT_SCREEN
	9: "战败",        # SceneID.DEFEAT_SCREEN
}

## SceneID → 归属说明（玩家可见的下一跳提示——不含开发排期术语）。
const HINTS: Dictionary = {
	2: "卡组编辑功能正在打造中，当前对局使用初始卡组。",
	8: "战斗胜利！奖励已计入修为与灵石，节点已标记为已清。",
	9: "战斗失败/撤退。节点未标记为已清，请重整旗鼓后再试。",
}

## 目标场景 ID（[code]SceneManager.SceneID[/code]——由 .tscn 逐个配置）。
@export var screen_id: int = 0

## [b]测试注入[/b]：可选——为 null 时按 /root/SceneManager 查找 Autoload。
var scene_manager: Node = null

## 返回按钮（测试与键盘焦点断言用）。
var return_button: Button = null
## 标题标签（测试断言用）。
var title_label: Label = null
## 状态标签（「尚未开放」——子类拿到真实数据后可覆写文案）。
var status_label: Label = null
## 提示标签（占位说明——子类可覆写为真实摘要）。
var hint_label: Label = null


func _ready() -> void:
	_build()
	# [b]落地即给键盘/手柄玩家一个可操作点[/b]：[method _build] 里没有一处
	# [code]grab_focus[/code]，整屏的焦点停在 [code]none[/code]——键盘玩家进到结算 /
	# 战败屏后 Tab 之前按回车什么都不发生，唯一的出路是用鼠标点「返回」。
	# 这跟「点不动」是一回事，只是发生在键盘上。[br]
	# [br][b]为什么在 [method _ready] 而不是 [_build][/b]：[code]_build[/code] 被
	# [code]battle_record_scene.gd[/code] 覆写并追加摘要/战报，若在基类 [_build] 里抓焦点，
	# 那时子树还没长全；等在 [code]_ready[/code] 末尾抓，无论子类追加了什么都已经在树上。[br]
	# [br][b]已经有焦点的场景不抢[/b]：视口当前焦点非空说明别处（如弹窗）正在接管，
	# 本屏不越权。
	if return_button != null and get_viewport() != null \
			and get_viewport().gui_get_focus_owner() == null:
		return_button.grab_focus()


## 构建静态界面（一次——`_ready` 时调用；[member screen_id] 已由 .tscn 赋值）。
func _build() -> void:
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = BG_COLOR
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.name = "Content"
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", CONTENT_SEPARATION)
	center.add_child(box)

	title_label = _make_label(TITLES.get(screen_id, TEXT_FALLBACK_TITLE),
			TITLE_FONT_SIZE, "Title")
	box.add_child(title_label)
	status_label = _make_label(TEXT_NOT_AVAILABLE, HINT_FONT_SIZE, "Status")
	box.add_child(status_label)
	hint_label = _make_label(str(HINTS.get(screen_id, "")), HINT_FONT_SIZE, "Hint")
	box.add_child(hint_label)

	return_button = Button.new()
	return_button.name = "ReturnButton"
	return_button.text = return_button_text(screen_id)
	return_button.custom_minimum_size = Vector2(160, 44)
	return_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return_button.pressed.connect(_on_return_pressed)
	box.add_child(return_button)


## 离开本屏——[b]唯一[/b]导航出口（ADR-0005 单一仲裁）。[br]
## [br][b]目的地与转场类型由 [BattleRecordExit] 裁决[/b]：战败屏回[b]主菜单[/b]
## （GAME_TO_MENU——本局已结束），其余（胜利结算 / 卡组编辑 / 坊市 / 养成）回
## [b]探索[/b]（COMBAT_TO_EXPLORE）。两屏此前共用「一律回探索」一个出口，而规格上
## 战败必须回主菜单（见 [BattleRecordExit] 类文档的规格引用）。[br]
## [br][b]from 动态取当前场景[/b]：不写魔数（PauseMenu M-2 先例）。[br]
## [br][b]结算必须先于转场[/b]：通关结算会 publish 面板视图（跨场景缓存），
## 面板挂在转场[b]之后[/b]的探索场景里——顺序反了面板就是空的。战败回主菜单那条路
## 不需要探索侧收尾（[method BattleRecordExit.returns_to_exploration] 判据），
## 跳过它也就免了「在主菜单里标一格已清」这种说不通的写入。[br]
## [br]来源: ADR-0005、ADR-0014 §决策 1 状态分层模型、design/ux/pause-menu.md
## （§Events Fired 战斗投降链）、design/gdd/audio-system.md（§9 N/A 转换）。
func _on_return_pressed() -> void:
	var sm: Node = _scene_manager()
	if sm == null or not sm.has_method(&"request_scene_change"):
		push_error("PlaceholderScene: SceneManager 不可用——返回中止")
		return
	var from_id: int = screen_id
	if sm.has_method(&"get_current_scene_id"):
		from_id = int(sm.call(&"get_current_scene_id"))
	if ExitScript.returns_to_exploration(screen_id):
		_mark_battle_node_cleared_if_victory()
	sm.call(&"request_scene_change", from_id,
		ExitScript.target_scene(screen_id),
		ExitScript.transition_type(screen_id))


## 战斗胜利的收尾（既有调用点与本方法名保持不变——它就是入口）。[br]
## [br][b]两分支[/b]：开战上下文记的 [code]combat_type[/code] 是 [code]boss[/code]
## 时走本图[b]通关结算[/b]（[method _settle_boss_victory]）；其余（普通/精英，
## 以及无上下文的旧调用方）仍只把这一格标为已清。[br]
## [br][b]判据是开战上下文而不是节点类型[/b]：跨场景之后节点图已释放，只剩这一份
## 上下文能回答「刚打完的是不是 Boss」——见
## [method CombatLaunchContext.get_origin_combat_type]。[br]
## [br]来源: ADR-0014 §决策 1 状态分层模型、GDD exploration-system.md §5。
func _mark_battle_node_cleared_if_victory() -> void:
	var node_id: int = _victory_origin_node()
	if node_id < 0:
		return
	if _is_boss_battle() and _settle_boss_victory():
		return
	_mark_node_cleared(node_id)


## 刚打完的是不是 Boss 战（开战上下文的 [code]combat_type[/code] 判据）。[br]
## [br]无探索侧上下文的旧调用方得到 [code]&""[/code] → false，走普通标记路径。
func _is_boss_battle() -> bool:
	return LaunchScript.get_origin_combat_type() == LaunchScript.COMBAT_TYPE_BOSS


## Boss 战胜利 → 本图通关结算（通关次数 / 首通标记 / 奖励 / 结算面板视图）。[br]
## [br][b]返回[/b]：结算是否真的跑起来了。[code]summary[/code] 带
## [code]is_first_clear[/code] 即表示走通了 [code]_settle_boss_defeated[/code]；
## GSM 不可用或无活跃地图时结算提前返回，摘要里没有这个键——此时调用方回退到
## 「只标一格已清」，免得玩家打完 Boss 连节点都没清。[br]
## [br][b]为什么经 Autoload 调用而非本地实现[/b]：通关结算属 Feature 层
## （ADR-0014 §决策 5），本场景只负责「胜利之后该请求哪种结算」。[br]
## [br]来源: GDD exploration-system.md §5、GDD exploration-ui-system.md §7。
func _settle_boss_victory() -> bool:
	var exploration: Node = get_node_or_null("/root/ExplorationSystem")
	if exploration == null or not exploration.has_method(&"end_exploration"):
		push_warning("PlaceholderScene: ExplorationSystem 不可用——Boss 通关结算跳过")
		return false
	var summary: Dictionary = exploration.call(&"end_exploration",
			ExplorationSystemScript.EndReason.BOSS_DEFEATED)
	return summary.has("is_first_clear")


## 标记战斗开始的节点为已清——统一走 [code]ExplorationSystem.mark_node_visited[/code]
## （与到达标记同一口径）；系统不可用时回退 GSM 的 [code]add_visited_node[/code]。
func _mark_node_cleared(node_id: int) -> void:
	var exploration: Node = get_node_or_null("/root/ExplorationSystem")
	if exploration != null and exploration.has_method(&"mark_node_visited"):
		exploration.call(&"mark_node_visited", node_id)
		return
	var gsm: Node = get_node_or_null("/root/GameStateManager")
	if gsm == null or not gsm.has_method(&"add_visited_node"):
		return
	gsm.call(&"add_visited_node", node_id)


## 本次返回是否为「一场胜利的战斗」，是则给出其起始节点 ID（否则 -1）。[br]
## [br][b]条件[/b]：当前场景是 RESULT_SCREEN (8) / DEFEAT_SCREEN (9)、战斗结果为
## 胜利、且探索侧留下了战斗节点上下文。失败/撤退不标记也不结算——主动逃跑
## 或战败不算通关。
## [br]来源: ADR-0014 §决策 1 状态分层模型。
func _victory_origin_node() -> int:
	if screen_id != 8 and screen_id != 9:
		return -1
	var view: RefCounted = _get_combat_result_view()
	if view == null or not view.has_method(&"is_victory"):
		return -1
	if not bool(view.call(&"is_victory")):
		return -1
	return LaunchScript.get_origin_node_id()


## 获取战斗结算对象（胜利判定用）。
func _get_combat_result_view() -> RefCounted:
	var view_script := preload("res://src/feature/combat/combat_result_view.gd")
	return view_script.last()


## SceneManager——注入优先，否则 /root/SceneManager（测试可替换为 mock）。
func _scene_manager() -> Node:
	if scene_manager != null:
		return scene_manager
	return get_node_or_null("/root/SceneManager")


## 标签工厂（字号统一在此下发——不在各 .tscn 重复写主题覆盖）。
func _make_label(text: String, font_size: int, label_name: String) -> Label:
	var label := Label.new()
	label.name = label_name
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	return label
