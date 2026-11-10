extends "res://src/ui/shared/placeholder_scene.gd"
## BattleRecordScene —— 结算回流占位场景基类（Sprint 18）。[br]
## [br][b]职责[/b]：在占位契约（标题 / 状态 / 返回按钮 / 返回探索经 SceneManager）
## 之上，把本场战绩（[code]CombatResultView[/code]）读出来并展示——
## 「能拿到数据」是本轮要求，「做正式 UI」不是。[br]
## [br][b]数据来源[/b]：[method CombatResultView.last]（战斗场景在
## [signal CombatSystem.battle_ended] 时经 [code]combat_result_bridge.gd[/code] 发布）。
## [b]不读 GSM / 战斗系统[/b]——战斗场景此时已释放，跨场景只剩这份只读快照
## （ADR-0031 §2）。[br]
## [br][b]为什么两个场景共用[/b]：胜利走 RESULT_SCREEN、失败/撤退走 DEFEAT_SCREEN
## （[method CombatSystem._request_scene_change]），两个方向的战绩取数、降级与
## 打印口径完全一致——各写一份必然漂移。[br]
## [br][b]没有数据时[/b]：沿用占位文案，把状态行改为「本场无战绩数据」——
## 不臆造数字，也不把「读不到」变成崩溃。[br]
## [br][b]占位契约不变[/b]：标题非空、返回按钮文案与导航路径（EXPLORATION /
## COMBAT_TO_EXPLORE）全部继承自 [code]PlaceholderScene[/code]，本文件只覆写
## 构建期文案并追加一段摘要。[br]
## [br]来源: production/session-state/active.md（Sprint 18 结算回流）、ADR-0031。

## 结算对象类型——载荷折叠与跨场景缓存的单一实现。
const ViewScript := preload("res://src/feature/combat/combat_result_view.gd")

## 日志前缀（便于在完整日志里 grep 本类输出）。
const LOG_PREFIX: String = "[CombatRecord]"
## 无战绩数据的提示（旧载荷 / 直接跳进本场景）。
const TEXT_NO_RECORD: String = "本场无战绩数据"
## 有战绩数据时的状态行（占位期文案，本地化 epic 后替换为 key）。
const TEXT_RECORDED: String = "战绩已记录"
## 摘要标签字号（px）。
const BRIEF_FONT_SIZE: int = 14

## 本场结算对象（null = 没有战绩数据）。
var result_view: RefCounted = null
## 摘要标签（测试断言用）。
var brief_label: Label = null


## 在占位界面之上追加战绩摘要（[code]super()[/code] 先建标题/状态/提示/按钮）。
func _build() -> void:
	super()
	result_view = ViewScript.last()
	if result_view == null:
		if status_label != null:
			status_label.text = TEXT_NO_RECORD
		print("%s %s" % [LOG_PREFIX, TEXT_NO_RECORD])
		return
	if title_label != null:
		title_label.text = str(result_view.call(&"title"))
	if status_label != null:
		status_label.text = TEXT_RECORDED
	var lines: PackedStringArray = result_view.call(&"summary_lines")
	brief_label = _make_label("\n".join(lines), BRIEF_FONT_SIZE, "Brief")
	var box: VBoxContainer = _content_box()
	if box == null:
		return
	box.add_child(brief_label)
	# 摘要插在返回按钮之前——键盘/手柄焦点顺序保持「先读数据、再离开」
	if return_button != null:
		box.move_child(brief_label, return_button.get_index())
	for line: String in lines:
		print("%s %s" % [LOG_PREFIX, line])


## 取占位场景的内容容器（[method PlaceholderScene._build] 里名为 "Content" 的 VBox）。
func _content_box() -> VBoxContainer:
	var center: Node = get_node_or_null("Center")
	if center == null:
		return null
	return center.get_node_or_null("Content") as VBoxContainer
