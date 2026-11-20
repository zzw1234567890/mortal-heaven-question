extends RefCounted
## HandAreaKeyboard —— 手牌区的键盘确认出口（DEBT-CUI-007-2 拆分·键盘组）。
##
## [b]职责[/b]：把每张 [HandCard] 的 [signal HandCard.activated]（回车/空格）收到
## 一处，再经 [member activated] 原样转给交互接线。[br]
## [br][b]为什么单独成文件[/b]：[code]hand_area.gd[/code] 贴上 300 行软上限，
## 而「哪张卡被键盘确认了」与「手牌长什么样」是两件事（同 [code]hand_area_cards.gd[/code]
## 拆节点池、[code]hand_area_layout.gd[/code] 拆排位的先例）。[br]
## [br][b]为什么不在卡里冒泡[/b]：Godot 的信号不冒泡——卡的 [signal HandCard.activated]
## 必须由持有者（本模块代手牌区）显式转出去。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：不持手牌快照（每次由宿主传入），
## 不判「这张卡能不能出」——那是出牌流程的事。[br][b]零轮询[/b]：全部由宿主显式驱动。
##
## 来源: ADR-0031 §2、.claude/rules/ui-code.md（交互元素须支持键盘/手柄）、
## combat-ui-interaction Story 001、DEBT-CUI-007-2。

## 键盘确认的卡（[signal HandCard.activated] 的转发口——未接线时为空 Callable）。[br]
## [br][b]载荷是卡实例 ID[/b]：手牌区是渲染层（零状态所有权，ADR-0031 §2）——
## 「这张卡能不能出、打谁」全部归交互层的出牌流程；本模块只把「哪张被确认了」交上去。
var activated: Callable = Callable()


## 接上每张卡的键盘确认出口。[br]
## [br][b]每轮快照都要重接[/b]：卡节点会被复用（[code]hand_area_cards.sync[/code] 池化），
## 信号连接跟着节点走，新节点没接就按不出东西；重复连接由
## [method Signal.is_connected] 挡掉。
func connect_cards(p_cards: Array) -> void:
	for entry: Variant in p_cards:
		if not (entry is Dictionary):
			continue
		var node: Variant = (entry as Dictionary).get("node")
		if not (node is HandCard) or not is_instance_valid(node):
			continue
		if not (node as HandCard).activated.is_connected(_on_card_activated):
			(node as HandCard).activated.connect(_on_card_activated)


## 卡的键盘确认 → 转发给交互接线（未接线时静默——纯渲染用例不该因此报错）。
func _on_card_activated(p_card_instance_id: int) -> void:
	if activated.is_valid():
		activated.call(p_card_instance_id)
