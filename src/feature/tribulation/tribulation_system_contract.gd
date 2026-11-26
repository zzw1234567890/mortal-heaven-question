## TribulationSystem 声明面（继承链首段）——[b]2 枚举 / 3 标量常量 / 1 转换白名单 / 5 信号 / 7 实例字段[/b]。
##
## [b]本层职责[/b]：整条链的[b]共享声明[/b]。[br]
##   · 枚举 [enum TribulationState] / [enum TribulationType]——GSM 的
##     [code]player.tribulation_state[/code] 与存档都按[b]整数[/b]落盘，且三处 UI / 剧情件按路径
##     [code]preload[/code] 取类后以 [code]TribulationScript.TribulationState.PREPARING[/code]
##     这种[b]静态形式[/b]访问（[code]tribulation_launch.gd[/code] /
##     [code]cultivation_actions.gd[/code] / [code]cultivation_tribulation_gate.gd[/code]）
##     ——实测：经链尾脚本静态解析祖先段枚举成立（守卫用例守着这条）；[br]
##   · 标量常量 [constant MAX_TRIBULATION_PILLS] / [constant FAILURE_PENALTY_RATIO] /
##     [constant CONSECUTIVE_FAILURE_THRESHOLD]——GDD 数值的单一真理来源；[br]
##   · [constant _VALID_TRANSITIONS]——状态机的行为契约就长在这张表上；[br]
##   · 5 条 Cat 2b 信号——[b]全部落链首[/b]：基段声明的信号可在派生段 [code]emit[/code]，
##     反向解析期即失败，而本链有两个发射方（流程段与结算转发各自走
##     [method _emit_safe]）；[br]
##   · 7 个实例字段——[member _trib_type] 的初始化器引用 [enum TribulationType]
##     （字段初始化器是解析期求值，只能引用本段或祖先段的声明），故字段必须随枚举落本段。
## [b]本层不含任何方法[/b]：装配在链尾——[method _ready] 要调
## [method _get_combat_system]，属「后代调祖先」；反过来把 [method _ready] 放本段会构成
## 「祖先调后代」，解析期即失败（链序说明见链尾段文档）。
##
## [b]为什么拆出这一层[/b]：[code]tribulation_system.gd[/code] 429 行，超 300 行软上限
## （.claude/docs/coding-standards.md）。声明面独立成段是既有先例
## （[code]combat_system_contract.gd[/code] / [code]deployment_system_contract.gd[/code] /
## [code]scene_manager_contract.gd[/code] / [code]progression_system_contract.gd[/code]）。
##
## [b]继承链[/b]（各段守 300 行内，成员名与访问路径逐字不变）：[br]
## [code]  tribulation_system_contract.gd [/code] ← 本层：声明面（2 枚举 / 3 标量常量 / 1 转换白名单 / 5 信号 / 7 字段）[br]
## [code]  tribulation_system_access.gd   [/code] ← 接缝与访问面：惰性获取器 / 信号发射包装 / GSM 与四个 Autoload 获取器[br]
## [code]  tribulation_system_flow.gd     [/code] ← 流程面：触发 / 取消 / 状态转换 / 查询 / 渡劫丹[br]
## [code]  tribulation_system.gd          [/code] ← 链尾：装配（_ready）+ 战斗委托 / 结算 / 雷伤 / Boss 查询出口[br]
##
## 来源: ADR-0021 §关键接口 / §信号分类 / §状态与转换、GDD tribulation-system.md §1-7。

extends Node


# === 枚举 ========================================================================

## 渡劫生命周期状态枚举——存入 GSM player.tribulation_state（ADR-0021）。
enum TribulationState {
	NOT_READY = 0,   ## 修为未满，不可渡劫
	READY = 1,        ## 修为已满，可触发渡劫（瞬态——check_tribulation_ready 返回 true 时隐含）
	PREPARING = 2,    ## 渡劫准备阶段（选择渡劫丹+调整角色）
	IN_COMBAT = 3,    ## 渡劫战中（委托 CombatSystem）
	SUCCESS = 4,      ## 突破成功（瞬时状态——结算后回到 NOT_READY）
	FAILED = 5,       ## 渡劫失败（瞬时状态——结算后回到 NOT_READY）
}

## 渡劫类型枚举——正常渡劫 vs 越阶渡劫（ADR-0021 §越阶渡劫）。
enum TribulationType {
	NORMAL = 0,       ## 正常渡劫——挑战同境界天劫 Boss
	CROSS_REALM = 1, ## 越阶渡劫——挑战高一级天劫 Boss
}


# === 常量 ========================================================================

## 渡劫丹使用总上限（GDD §边缘情况 + ADR-0021 §渡劫丹管理）。
const MAX_TRIBULATION_PILLS: int = 2

## 渡劫失败修为损失比例——max_cultivation × 0.15（GDD §公式 1）。
const FAILURE_PENALTY_RATIO: float = 0.15

## 连续失败保护阈值——3 次失败后解锁天劫试炼（GDD §公式 3 + §7）。
const CONSECUTIVE_FAILURE_THRESHOLD: int = 3


# === 信号（Cat 2b）=============================================================

## 渡劫触发——trigger_tribulation() 成功后发射。[br]
## [br][param realm_level] 当前境界等级。[br]
## [br]来源: ADR-0021 §信号分类。
signal tribulation_triggered(realm_level: int)

## 渡劫准备阶段开始——UI 就绪后发射。[br]
## [br]来源: ADR-0021 §信号分类。
signal tribulation_preparation_started()

## 渡劫成功——结算完毕后发射（realm_up + 金卡奖励 + 计数器重置之后）。[br]
## [br][param old_realm] 旧境界等级。[br]
## [br][param new_realm] 新境界等级。[br]
## [br][param is_cross_realm] 是否越阶渡劫。[br]
## [br]来源: ADR-0021 §信号分类。
signal tribulation_succeeded(old_realm: int, new_realm: int, is_cross_realm: bool)

## 渡劫失败——结算完毕后发射（修为扣除 + 失败计数更新后）。[br]
## [br][param penalty] 修为损失量。[br]
## [br][param realm_level] 当前境界等级。[br]
## [br]来源: ADR-0021 §信号分类。
signal tribulation_failed(penalty: int, realm_level: int)

## 天劫庇护解锁——连续失败计数达到阈值时发射。[br]
## [br]来源: ADR-0021 §信号分类 + GDD §7。
signal tribulation_protection_unlocked()


# === 内部状态 ====================================================================

## 当前渡劫类型——trigger_tribulation 时设置，结算后清除。
var _trib_type: int = TribulationType.NORMAL

## 激活的渡劫丹列表——准备阶段使用_tribulation_pill 添加（Story 5-12 实现）。
var _active_pills: Array = []

## 可注入 CombatSystem 引用——测试时设置，绕过 Autoload 查找（同 CombatSystem get_card_instance_cb 模式）。
var _combat_override: Node = null

## 可注入 RealmSystem 引用——测试时设置，绕过 Autoload 查找。
var _realm_override: Node = null

## 可注入 CardSystem 引用——测试时设置，绕过 Autoload 查找（同 _realm_override 模式）。[br]
## [br][b]为什么需要[/b]：金卡奖励要从模板注册表里挑「金档」模板，而真实 Autoload 的
## 模板是[b]异步[/b]加载的（[code]load_threaded_request[/code]）——测试注入一个已灌入
## 夹具模板的实例即可确定性地验「发的是不是金档」。
var _card_override: Node = null

## 结算子模块——惰性初始化（Sprint 9 Story 7 拆分）。
var _settlement: RefCounted = null

## 渡劫战斗委托子模块——惰性初始化（Sprint 12 Story 017 拆分）。
var _combat_delegation: RefCounted = null


## 合法状态转换白名单——_validate_state_transition 使用。
## [br]键=当前状态，值=可转换到的状态集合。
const _VALID_TRANSITIONS: Dictionary = {
	TribulationState.NOT_READY: [TribulationState.PREPARING],
	TribulationState.READY: [TribulationState.PREPARING],
	TribulationState.PREPARING: [TribulationState.IN_COMBAT, TribulationState.NOT_READY, TribulationState.READY],
	TribulationState.IN_COMBAT: [TribulationState.SUCCESS, TribulationState.FAILED],
	TribulationState.SUCCESS: [TribulationState.NOT_READY],
	TribulationState.FAILED: [TribulationState.NOT_READY, TribulationState.READY],
}
