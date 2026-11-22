extends RefCounted
## MainMenuSaveState —— 主菜单的存档存在性判定与「继续 / 读档」按钮态（从 main_menu.gd 拆出）。[br]
## [br][b]职责[/b]：把 [code]SaveLoadSystem.list_slots()[/code] 的原始列表翻成界面状态——
## 「继续游戏」亮不亮、摘要行写什么、「读档」亮不亮、下方提示说什么；以及两张
## 存档信号的接线（读档完成 → 重刷；存档损坏 → 弹提示）。[br]
## [b]不管什么[/b]：不建对话框、不导航、不读档——它只回答「此刻界面上这两个按钮该是什么样」。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：[b]什么都不缓存[/b]——每次刷新重新
## [code]list_slots()[/code]，面板正开着时顺手把槽位列表重灌一遍。存档状态可能在主菜单
## 停留期间变了（另一个进程、刚从暂停菜单退出来），缓存一份就是留一处会过期的副本。[br]
## [br][b]两个按钮一起刷[/b]：「继续游戏」（读最新档）与「读档」（挑槽位）读的是同一份
## 列表，只是判定宽严不同——前者只要有档，后者要有非空槽位。分两次读会出现
## 「继续游戏亮着、读档灰着」这种自相矛盾的界面。[br]
## [br][b]为什么单独成文件[/b]：[code]main_menu.gd[/code] 超 300 行软上限
## （.claude/docs/coding-standards.md），而「存档读出来的东西怎么落到控件上」与
## 「按钮怎么摆、点下去走哪条导航链」是不同的事。[br]
## [br][b]不直引 Autoload[/b]（ADR-0031 §2）：[code]save_load[/code] 由宿主注入，
## 测试换掉它即可脱离真实文件系统。[br]
## [br][b]零轮询[/b]：无 [code]_process()[/code]——刷新由 [code]_ready[/code] 与两张
## 存档信号显式驱动。
##
## 来源: ADR-0031 §2、design/gdd/main-menu-system.md（三条路径 / 无档边界）、
## story-001-main-menu-scene.md（AC-1 / AC-2 / AC-3）。

## 存档判定内核（纯函数——「存档存在性判定提取纯函数」，control-manifest
## Presentation 必需模式）。类名在测试动态加载下不可靠，故走 preload。
const Logic := preload("res://src/ui/main_menu/main_menu_logic.gd")

## 固定词条（无档提示的出处——文案归 [MainMenuTexts]，本件只取）。
const Texts := preload("res://src/ui/main_menu/main_menu_texts.gd")


## 刷新存档存在性 + 摘要（宿主 [code]_ready] + 读档完成信号驱动）。[br]
## [br][param p_host] 宿主（读它的注入引用、写它的控件与面板句柄）。[br]
## [br][b]为什么回调也传进来[/b]：损坏对话框的确认回调归宿主（它还要接线），
## 本件只负责把「确认后重刷」挂到信号上——[method Object.set] 之外不再有别的宿主写侧。[br]
## [br][b]面板正开着时同步灌列表[/b]：读档失败退回主菜单的场景里槽位可能已变，
## 面板自己在打开时才 populate，不跟着重灌就会停在旧列表上。
static func refresh(p_host: Node) -> void:
	if p_host == null:
		return
	var slots: Array = list_slots_safe(p_host)
	var has_save: bool = Logic.has_continuable_save(slots)
	var continue_button: Button = p_host.get(&"continue_button") as Button
	var save_summary_label: Label = p_host.get(&"save_summary_label") as Label
	if continue_button != null:
		continue_button.disabled = not has_save
	if save_summary_label != null:
		if has_save:
			save_summary_label.text = Logic.build_save_summary(
					Logic.select_latest_save(slots))
		else:
			save_summary_label.text = ""
		# 摘要行 visible 控制（story AC：无存档时隐藏，布局占位保留——
		# visible 而非从树移除）
		save_summary_label.visible = has_save
	# 「读档」按槽位判定——自动槽空但有手动档时它仍该亮着（两者不等价）
	var entries: Array[Dictionary] = Logic.loadable_slots(slots)
	var load_button: Button = p_host.get(&"load_button") as Button
	if load_button != null:
		load_button.disabled = not has_any_slot(entries)
	var hint: Label = p_host.get(&"no_save_hint_label") as Label
	if hint != null:
		hint.text = "" if has_save else Texts.TEXT_NO_SAVE_CONTINUE
	var panel: Object = p_host.get(&"_load_slot_panel") as Object
	if panel != null and is_instance_valid(panel) \
			and bool(panel.call(&"is_open")):
		# 面板正开着（读档失败退回的场景）：列表可能已变，跟着 re-populate 一次
		panel.call(&"populate", entries)


## 槽位条目里是否有至少一个非空（「读档」按钮的启用判据）。[br]
## [br][b]与 [method MainMenuLogic.has_continuable_save] 的差别[/b]：那个判的是
## [code]list_slots()[/code] 的原始列表（含战前快照槽），本判据只看玩家可在读档
## 界面里选到的那几格——快照槽非空不该让「读档」亮起来（点进去列表里没有它）。
static func has_any_slot(p_entries: Array) -> bool:
	for entry: Dictionary in p_entries:
		if bool(entry.get("exists", false)):
			return true
	return false


## [code]list_slots[/code] 防御读取——SaveLoadSystem 不可用时返回空数组（安全默认：
## 按无存档处理，按钮禁用——Logic 内核空状态防御对齐）。
static func list_slots_safe(p_host: Node) -> Array:
	var sl: Node = get_save_load(p_host)
	if sl != null and sl.has_method(&"list_slots"):
		return sl.list_slots()
	push_warning("MainMenu: SaveLoadSystem 不可用——按无存档处理")
	return []


## 连接两张存档信号——返回主菜单（暂停菜单退出路径）后刷新存档状态。[br]
## 已连接时跳过（宿主可能多次 [code]_ready[/code]——幂等）。[br]
## [br][param p_on_completed] 宿主 [code]_on_save_load_completed[/code] 的 Callable；
## [param p_on_corrupted] 宿主 [code]_on_save_corrupted[/code] 的 Callable。
static func connect_signals(p_host: Node, p_on_completed: Callable,
		p_on_corrupted: Callable) -> void:
	var sl: Node = get_save_load(p_host)
	if sl == null:
		return
	if sl.has_signal(&"load_completed") \
			and not sl.is_connected(&"load_completed", p_on_completed):
		sl.connect(&"load_completed", p_on_completed)
	if sl.has_signal(&"save_corrupted") \
			and not sl.is_connected(&"save_corrupted", p_on_corrupted):
		sl.connect(&"save_corrupted", p_on_corrupted)


## [code]SaveLoadSystem[/code]——注入优先，否则回退 Autoload（[code]get_node_or_null[/code]
## 保持脚本可脱离 Autoload 环境解析——先例 [code]RealmBar._get_gsm[/code]）。
static func get_save_load(p_host: Node) -> Node:
	var injected: Node = p_host.get(&"save_load") as Node
	if injected != null:
		return injected
	return p_host.get_node_or_null("/root/SaveLoadSystem")
