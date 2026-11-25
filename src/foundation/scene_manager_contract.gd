## SceneManager 声明面（继承链首段）——[b]2 枚举 / 2 信号 / 2 常量表 / 11 实例字段[/b]。
##
## [b]本层职责[/b]：整条链的[b]共享声明[/b]。[br]
##   · 枚举 [enum SceneID] / [enum TransitionType]——全工程按路径 [code]preload[/code]
##     取类后以 [code]SceneManagerScript.SceneID.COMBAT[/code] 这种[b]静态形式[/b]访问——
##     实测：经链尾脚本静态解析祖先段枚举 / 常量 / static 方法均成立（守卫用例
##     [method test_static_enum_and_const_access_from_path_script] 守着这条）；[br]
##   · 信号 [signal pre_transition] / [signal post_transition]——audio_manager 按名 connect，
##     由管线段发射（基段声明的信号可在派生段 [code]emit[/code]）；[br]
##   · 常量 [constant SCENE_PATHS]——[b]12 条注册路径的单一真理来源[/b]，同时是
##     [method verify_scene_paths] 的默认参数值（默认值表达式只能引用本段或祖先段的常量，
##     故它必须随声明落在链首；探针 L 段实测确认）；[constant TRANSITION_AUDIO_PARAMS]
##     ——BGM 过渡参数表；[br]
##   · 实例字段——转场状态（[member _transitioning] / [member _transition_type] /
##     [member _current_scene_id] / [member _test_mode] / [member _phase3_in_progress]）、
##     三个惰性子模块引用与三个注入依赖。
## [b]本层不含任何方法[/b]：装配在链尾——[method _ready] 要调
## [method _get_persistent_layer] / [method _get_audio_manager] / [method verify_scene_paths]，
## 属「后代调祖先」；反过来把 [method _ready] 放本段会构成「祖先调后代」，解析期即失败
## （链序说明见链尾段文档）。
##
## [b]为什么拆出这一层[/b]：[code]scene_manager.gd[/code] 430 行，超 300 行软上限
## （.claude/docs/coding-standards.md）。声明面独立成段是既有先例
## （[code]gsm_atomic_writes_contract.gd[/code] / [code]combat_system_contract.gd[/code]）。
##
## [b]继承链[/b]（各段守 300 行内，成员名与访问路径逐字不变）：[br]
## [code]  scene_manager_contract.gd [/code] ← 声明面：2 枚举 / 2 信号 / 2 常量表 / 11 实例字段[br]
## [code]  scene_manager_access.gd   [/code] ← 依赖与访问面：注入 / 惰性获取 / 音频门面 / 持久层注册[br]
## [code]  scene_manager_pipeline.gd [/code] ← 转场管线面：请求入口 / 信号发射包装 / 异步管线[br]
## [code]  scene_manager.gd          [/code] ← 本层：装配与出口面（_ready / 查询 / 自检 / 静态工具）[br]
##
## 来源: ADR-0005 §5 阶段异步转换管线、ADR-0031 §1.2（PersistentLayer 挂载）、
## .claude/docs/coding-standards.md §文件行数限制（300 行软上限）。

extends Node

## === SceneID 枚举 ==============================================================

## 游戏内全部场景标识符——新增场景需同步更新 [constant SCENE_PATHS]。
enum SceneID {
	MAIN_MENU = 0,            ## 主菜单
	IDENTITY_SELECT = 1,      ## 开局身份选择
	DECK_EDITING = 2,         ## 卡组编辑
	EXPLORATION = 3,          ## 探索地图
	COMBAT = 4,               ## 战斗场景
	TRIBULATION = 5,          ## 渡劫场景
	SHOP = 6,                 ## 商店
	EVENT_PANEL = 7,          ## 事件面板
	RESULT_SCREEN = 8,        ## 战斗结算
	DEFEAT_SCREEN = 9,        ## 战败画面
	CULTIVATION = 10,         ## 修炼室
	LOADING = 99,             ## 加载画面（内部使用）
}

## === TransitionType 枚举 =======================================================

## 场景转换类型——驱动音频系统的 BGM 过渡矩阵（见 audio-system.md）。
enum TransitionType {
	NONE = 0,              ## 无转换（初始状态）
	MENU_TO_GAME = 1,      ## 主菜单→游戏（长淡入，1.5s BGM 过渡）
	GAME_TO_MENU = 2,      ## 游戏→主菜单（长淡出，1.5s BGM 过渡）
	EXPLORE_TO_COMBAT = 3, ## 探索→战斗（快速切入，0.5s BGM 过渡）
	COMBAT_TO_EXPLORE = 4, ## 战斗→探索（正常切回，1.0s BGM 过渡）
	TRIBULATION = 5,       ## 渡劫战斗（特殊 BGM，0.3s 过渡）
}

## === 信号 ======================================================================

## Cat 2a：转场前通知。Phase 2 发射——音频/HUD 做转场前准备。
## [param from] 源场景 ID，[param to] 目标场景 ID，[param type] 转换类型。
signal pre_transition(from: int, to: int, type: int)

## Cat 2a：转场后通知。Phase 4 发射——音频/HUD/探索初始化新场景。
## [param from] 源场景 ID，[param to] 目标场景 ID。
signal post_transition(from: int, to: int)

## === 场景路径注册表 ============================================================

## 编译时常量字典——所有场景文件路径的单一真理来源。O(1) 查询，无文件 I/O。
const SCENE_PATHS: Dictionary = {
	SceneID.MAIN_MENU:       "res://src/ui/main_menu/MainMenu.tscn",
	SceneID.IDENTITY_SELECT: "res://src/ui/identity_select/identity_select.tscn",
	SceneID.DECK_EDITING:    "res://src/ui/deck_editing/deck_editing.tscn",
	SceneID.EXPLORATION:     "res://src/feature/exploration/exploration_scene.tscn",
	SceneID.COMBAT:          "res://src/feature/combat/combat_scene.tscn",
	SceneID.TRIBULATION:     "res://src/feature/tribulation/tribulation_scene.tscn",
	SceneID.SHOP:            "res://src/feature/shop/shop_scene.tscn",
	SceneID.EVENT_PANEL:     "res://src/ui/event_panel/event_panel.tscn",
	SceneID.RESULT_SCREEN:   "res://src/ui/result_screen/result_screen.tscn",
	SceneID.DEFEAT_SCREEN:   "res://src/ui/defeat_screen/defeat_screen.tscn",
	SceneID.CULTIVATION:     "res://src/feature/cultivation/cultivation_scene.tscn",
	SceneID.LOADING:         "res://src/ui/loading/loading_screen.tscn",
}

## === 音频过渡参数表 ==========================================================

## 编译时常量——TransitionType → BGM 过渡参数的映射表。[br]
## 音频系统通过 [signal pre_transition] 的 [code]type[/code] 参数索引本表。[br]
## [br][b]角色[/b]: SceneManager 提供数据契约——音频系统执行实际的 BGM 淡入/淡出。[br]
## [b]维护[/b]: 新增 TransitionType 值时必须同步向本表添加条目——否则音频系统
## 的 [code]match[/code] 语句将报 missing-branch 编译警告。[br]
## [br][b]真源裁定[/b]（ADR-0031 + GDD 边界澄清 2026-09-07）：音频行为唯一真源是
## GDD §9 过渡矩阵（audio-manager story 004 [code]state_transition_matrix.gd[/code]）；
## 本表降级为场景级引用层。数值已与矩阵对齐：探索→战斗 0.5s 淡出（非硬切）、
## 渡劫 0.3s 顺序式（先淡出完成再淡入，[code]sequential[/code] 标记）。
const TRANSITION_AUDIO_PARAMS: Dictionary = {
	TransitionType.MENU_TO_GAME: {
		duration_seconds = 1.5,
		from_behavior = &"fade_out",
		to_behavior = &"fade_in",
	},
	TransitionType.GAME_TO_MENU: {
		duration_seconds = 1.5,
		from_behavior = &"fade_out",
		to_behavior = &"fade_in",
	},
	TransitionType.EXPLORE_TO_COMBAT: {
		duration_seconds = 0.5,
		from_behavior = &"fade_out",
		to_behavior = &"fade_in",
	},
	TransitionType.COMBAT_TO_EXPLORE: {
		duration_seconds = 1.0,
		from_behavior = &"fade_out",
		to_behavior = &"fade_in",
	},
	TransitionType.TRIBULATION: {
		duration_seconds = 0.3,
		from_behavior = &"fade_out",
		to_behavior = &"fade_in",
		sequential = true,
	},
}

## === 内部状态 ==================================================================

## 转场进行中标志——true 时拒绝所有新的转换请求。
var _transitioning: bool = false

## 当前转换类型——Phase 2 设置，Phase 5 重置为 NONE。
var _transition_type: TransitionType = TransitionType.NONE

## 当前活跃场景 ID——成功完成转场后更新。
var _current_scene_id: int = SceneID.MAIN_MENU

## 测试模式标志——为 true 时跳过 [method _execute_transition] 中的异步场景加载。
## [br][b]仅测试使用[/b]——GUT 单元测试无有效 .tscn 文件，await 会永久挂起。
var _test_mode: bool = false

## Phase 3 进行中标志位——await 中断双重保底。
## Phase 3 开始时设为 true，Phase 4 正常到达时设为 false。
## tree_changed 信号可能在非场景切换场景下触发——此标志位作为语义校验。
var _phase3_in_progress: bool = false

## 转换管线子模块（惰性初始化，Sprint 10 Story 7 拆分）。
var _transition: RefCounted = null

## 持久层子模块（惰性初始化，hud Story 001 / GAP-2 裁决）。
var _persistent_layer: ScenePersistentLayer = null

## AudioManager 实例（audio Story 001——RefCounted 控制类，非 Autoload）。[br]
## 启动时惰性创建并持有引用（防 RefCounted 提前释放）——节点池经
## [method register_persistent] 挂入 PersistentLayer（ADR-0031 §1.2）。[br]
## [br]类型注记：AudioManager 虽定义于表现层，但 [code]class_name[/code]
## 为全局注册类型，Foundation 层直接静态引用无循环依赖（audio_manager.gd
## 只引用 AudioEnums/AudioServerAdapter，不反向引用 SceneManager 类型——
## 同文件 [member _persistent_layer]: ScenePersistentLayer 先例）。静态类型
## 使消费方免于运行时强转。
var _audio_manager: AudioManager = null

## === 依赖注入 ==================================================================

## 注入的 GSM 引用。null 时使用 GameStateManager Autoload。
## 测试中可替换为轻量 mock（需实现 session Dictionary + set_session_scene 方法）。
var _gsm: Node = null

## 注入的 InputManager 引用。null 时使用 InputManager Autoload。
## 测试中可替换为 mock（需实现 push_lock / pop_lock 方法）。
var _im: Node = null

## 注入的 SaveLoad 引用。null 时使用 SaveLoadSystem Autoload。
## 测试中可替换为 mock（需实现 auto_save 方法）。
var _save_load: Node = null
