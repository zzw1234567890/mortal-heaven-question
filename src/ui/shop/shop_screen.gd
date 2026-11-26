## ShopScreen —— 主菜单坊市界面（纯代码构建 UI）。[br]
## [br][b]为什么需要它[/b]：[code]SceneManager.SCENE_PATHS[/code] 里
## [code]SHOP[/code] 一直指向一个占位场景（深色底 + 「坊市交易功能正在打造中」），
## 玩家从主菜单点进去只能看到一个返回按钮。而坊市的[b]结算链路早已存在[/b]
## ——[code]ExplorationShop[/code] 的「校验 → 建实例 → 扣灵石 → 入收藏」四步与
## 面板控件树（[code]shop_panel_layout.gd[/code]）都是现成的，缺的只是
## 「一块不依赖节点载荷的常驻货架 + 一个挂得上去的场景」。[br]
## [br][b]与探索侧商店的分工[/b]：控件树（怎么摆、焦点环长什么样）与游标
## （方向键怎么动）[b]完全复用[/b]探索侧那两份模块；本文件只管「场景级」的三件事
## ——货源（[ShopLogic] 从 [ShopGoodsCatalog] 取常驻货架）、进出（经
## [code]SceneManager[/code] 回主菜单）、以及把购买结果回填到提示行。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本界面不持有灵石、不写收藏——购买全部
## 经 [ShopLogic]（它再经 [code]ResourceSystem[/code] / [code]CardSystem[/code] /
## [code]GSM[/code]），界面的每一行都在 [method refresh] 时[b]现读[/b]（刚买完那行
## 的可负担态必须立刻刷新）。[br]
## [br][b]为什么买不起的行点下去仍给中文原因[/b]：[code]ShopPanelLayout.add_item_row[/code]
## 把买不起的行设成 [code]disabled[/code]（禁用的 [Button] 不发 [signal Button.pressed]），
## 于是「点了没反应」——玩家无从知道自己差多少灵石。本界面给每行另外接上
## [signal Control.gui_input]：点到禁用行时调一次 [method ShopLogic.purchase]，
## 把它的[b]拒绝原因[/b]（「灵石不足：需要 25，当前 10」）写进提示行。这条路径
## 一分钱都不会动——[method ShopLogic.purchase] 的校验全在动手之前。[br]
## [br][b]模板是异步来的[/b]：卡牌模板由 [code]CardSystem._ready[/code] 用
## [code]load_threaded_request[/code] 分批装载（每帧 10 个），而本界面
## [code]_ready[/code] 只刷一次。[method ShopLogic.rows] 对查不到模板的条目
## [b]直接剔除[/b]（不上架一条没有名字与稀有度的货）——故装载完成前进来的一次
## 刷新会让货架空掉，且此后没有任何东西会再刷第二次。本界面因此接上
## [code]templates_loaded[/code]，在装载收尾时自己再刷一次（见
## [method _connect_templates_loaded]）。[br]
## [br][b]事件层级 = _input[/b]：与商店面板 / 卡组编辑同源理由——焦点落在
## [Button] 上时引擎的内置焦点导航会在 GUI 阶段先吃掉方向键；[code]_input[/code]
## 排在 GUI 派发之前，是唯一能拦住的层。消费走
## [method Viewport.set_input_as_handled]（顺带挡住 [code]InputManager[/code] 的
## Esc → 暂停菜单）。[br]
## [br][b]文案本地化豁免[/b]：项目暂无本地化系统——本文件的面向玩家句子集中在
## [constant TEXT_*]，本地化 epic 入库后替换为 key（同 S16/S17 口径）。
##
## [b]继承链[/b]（各段守 300 行内，成员名与访问路径逐字不变）：[br]
## [code]  shop_screen_contract.gd [/code] ← 声明面：1 信号 / 12 常量 / 15 实例字段[br]
## [code]  shop_screen_access.gd   [/code] ← 接缝与访问面：读数口 / 测试用按下 /
##  控件取值原语 / 环境拆除[br]
## [code]  shop_screen_flow.gd     [/code] ← 流程面：刷新 / 键盘导航 / 购买 / 进出 / 上架[br]
## [code]  shop_screen.gd          [/code] ← 链尾（本文件）：构造与生命周期 / 控件树[br]
##
## [b]链序不是自由选择[/b]：GDScript 解析期要求被调方在[b]本段或祖先段[/b]——祖先段
## 用裸标识符引用后代段成员会直接报
## [code]Function "xxx()" not found in base self[/code]。本轮实测推出的三段次序：[br]
##   ① [method refresh] 与 [method _present] / [method _purchase] 互引成环，且
##      [method press_item] 要调 [method _refusal_for] / [method _show_message]
##      ——这一大组落流程段与访问段；[br]
##   ② [method _init] 要调 [method _build_layout]（本段）/ [method _rows_of] 与
##      [method _activate_row]（访问段）/ [method _request_leave] 与
##      [method _on_focus_changed]（流程段），全部在祖先段，故[b]构造留在链尾[/b]；[br]
##   ③ [method _ready] 要调 [method refresh]（流程段），同理留链尾。[br]
## [b]已知坑[/b]：把 [method _init] 留在祖先段、而它调的方法在派生段，会报
## [code]extends can only be used once.[/code]（错误指向基段文件，极具误导）——
## 构造三件套要整体进同一段，或将构造整体下沉到链尾。
##
## [b]路径即契约[/b]：[code]src/feature/shop/shop_scene.tscn[/code] 的
## [code]ext_resource[/code] 把脚本绑在 [code]res://src/ui/shop/shop_screen.gd[/code]
## 这一串字符上，故[b]本文件名与路径逐字不动[/b]。守卫用例：
## [code]tests/unit/shop/test_shop_screen_public_face_lock.gd[/code]。
##
## 来源: design/gdd/deck-editing-system.md §3 坊市买卖、
## design/ux/deck-editing-ui.md §坊市-买卡、ADR-0005（导航唯一入口）、
## ADR-0031 §1/§2、.claude/rules/ui-code.md（双输入 + 色盲可读）、先例
## [code]deck_editing_screen.gd[/code]（同形态的独立场景 + 复用布局模块）、
## [code]shop_panel_screen.gd[/code]（同一套控件树与游标）。

extends "res://src/ui/shop/shop_screen_flow.gd"

# ═══════════════════════════════════════════════════════════════════════════════
# 构造与生命周期
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	name = "ShopScreen"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_layout()
	_navigator = NavScript.new()
	_navigator.call(&"bind", _rows_of, _activate_row, _request_leave)
	_navigator.connect(&"focus_changed", _on_focus_changed)


func _ready() -> void:
	if shop_logic == null:
		shop_logic = LogicScript.new(
				SourcesScript.resolve(resource_system, &"ResourceSystem"),
				SourcesScript.resolve(card_system, &"CardSystem"),
				SourcesScript.resolve(gsm, &"GameStateManager"))
	_logic_ = shop_logic
	refresh()


# ═══════════════════════════════════════════════════════════════════════════════
# 控件树
# ═══════════════════════════════════════════════════════════════════════════════

## 建控件树并接线（骨架来自 [ShopPanelLayout]——本界面只管往列表里填行）。[br]
## [br][b]「离开」只接一个出口[/b]：[code]ShopPanelLayout.build[/code] 已把按钮的
## [signal Button.pressed] 转发到本屏的 [signal leave_requested]，故这里只接那一个
## ——再接一次按钮的 [signal Button.pressed] 会让同一次点击发出两次转场请求。[br]
## [br][b]为什么先传本屏的名字进 build[/b]：[method Object.emit_signal] 对未声明的
## 信号名只在运行时静默失败（[code]ERR_UNAVAILABLE[/code]），故签名必须对上本屏
## 真正声明过的那个（见 [signal leave_requested]）。
func _build_layout() -> void:
	var parts: Dictionary = LayoutScript.build(self, TEXT_TITLE)
	_title_label = parts.get("title_label")
	_balance_label = parts.get("balance_label")
	_item_box = parts.get("item_box")
	_message_label = parts.get("message_label")
	_leave_button = parts.get("leave_button")
	leave_requested.connect(_request_leave)
