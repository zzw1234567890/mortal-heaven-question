extends RefCounted
## CombatLayoutDeployMount —— 备战面板的装配与开合（combat_layout 拆分模块·备战组）。
##
## [b]职责[/b]：实例化 [code]DeployPanel[/code]（全屏覆盖层、默认隐藏）、按需下发名册
## 并打开 / 关闭。[b]不持有游戏状态[/b]——上限、境界、名册全部由调用方（场景挂载侧）
## 经参数传入；面板自身的依赖（gsm / card_system）由挂载侧在调用前经
## [code]DeployPanel.setup()[/code] 注入。
##
## [b]为什么单独成文件[/b]：[code]combat_layout.gd[/code] 是场景挂载侧唯一持有的节点，
## 备战 / 结算 / 反馈 / 装配四组接线此前全堆在同一个类里（465 行，超 300 行软上限）。
## 本模块只负责「备战面板这一组」，主类保留薄转发，对外 API 与节点树不变。
##
## 来源: combat-ui-layout Story 007、DEBT-CUI-007-2（combat_layout 拆分）。

## 备战面板脚本（全屏覆盖层，默认隐藏）。
const PanelScript: GDScript = preload("res://src/ui/combat/deploy/deploy_panel.gd")

## 面板左/上内边距（px——1920×1080 基准）。
const OFFSET_LEFT: float = 120.0
const OFFSET_TOP: float = 80.0

## 宿主布局根（面板挂在这里——顺序即绘制层级，须排在战场内容之后）。
var _layout: Control = null
## 面板实例（[method build] 创建）。
var panel: Variant = null


## 构造——传入宿主布局根。
func _init(p_layout: Control) -> void:
	_layout = p_layout


## 构建面板（全屏覆盖层，默认隐藏；不依赖场景树时序——可在 [code]_init()[/code] 中调用）。
func build() -> void:
	panel = PanelScript.new()
	panel.name = "DeployPanel"
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = OFFSET_LEFT
	panel.offset_top = OFFSET_TOP
	panel.visible = false
	_layout.add_child(panel)


## 打开面板——单次取数下发（上限 / 境界与名册同一次 [code]load_roster[/code]，
## 避免「先按默认上限 0 刷新一遍」导致首轮全部误判为可替换 + 双重建卡）。[br]
## [br][b]未注入依赖时[/b]：[code]DeployPanel.has_sources()[/code] 为假 → 显式告警，
## 避免「生产路径静默空面板」。
## [br][param p_max_deploy] 当前境界上场人数上限。[param p_realm_id] 境界 ID。
## [param p_battle_title] 战斗名称标题。
func show_panel(p_max_deploy: int, p_realm_id: int, p_battle_title: String) -> void:
	if panel == null:
		return
	if not bool(panel.call(&"has_sources")):
		push_warning("CombatLayout.show_deploy_panel: 未注入 gsm/card_system——"
				+ "面板将显示空名册（由场景挂载侧调用 DeployPanel.setup() 修复）")
	panel.call(&"set_battle_title", p_battle_title)
	panel.call(&"load_roster", p_max_deploy, p_realm_id)
	panel.visible = true


## 关闭面板（确认出战 / 返回探索后由上层调用）。
func hide_panel() -> void:
	if panel != null:
		panel.visible = false
