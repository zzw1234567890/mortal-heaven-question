## FormationSystem 声明面（继承链首段）——[b]2 枚举 / 6 信号 / 1 标量常量 / 15 实例字段[/b]。
##
## [b]本层职责[/b]：整条链的[b]共享声明[/b]。[br]
##   · 枚举 [enum SlotState] / [enum AuraScope]——阵位状态与光环作用域。存档
##     [code]battle.formation_snapshot[/code] 与两个子模块里那两份[b]私有整数副本[/b]
##     （[code]formation_slot_ops.gd[/code] 的 [code]_STATE_ACTIVE[/code] /
##     [code]formation_aura.gd[/code] 的 [code]_SCOPE_AFFILIATED[/code]）都按这组值对齐；
##     四个既有测试文件还按路径 [code]preload[/code] 取类后以
##     [code]FS_SCRIPT.SlotState.ACTIVE[/code] 这种[b]静态形式[/b]访问
##     ——实测：经链尾脚本静态解析祖先段枚举成立（守卫用例守着这条）；[br]
##   · 6 条 Cat 2b 信号——[b]全部落链首[/b]：基段声明的信号可在派生段 [code]emit[/code]，
##     反向解析期即失败，而本链有[b]三个发射方[/b]（流程段的归属写入、子模块经
##     [code]_parent.call("_emit_safe", …)[/code] 回取的部署/覆盖/重判、链尾的批量重判），故整体落链首；[br]
##   · 标量常量 [constant MAX_SLOTS]——阵位数的单一真理来源，也是子模块经
##     [code]_parent.get("MAX_SLOTS")[/code] 回取的入口；[br]
##   · 15 个实例字段——4 个阵位数据字段（含 lead-programmer C2 的延迟归属队列）
##     + 7 个可注入存根 [Callable] + 3 个子模块引用（惰性创建，获取器在接缝段）。
##     字段初始化器[b]不引用[/b]本段枚举（空位默认值走接缝段的 [method _make_empty_slot]），
##     故字段与枚举同段只为「值定义集中一处」，并无解析期先后约束。
## [b]本层不含任何方法[/b]：默认状态构造在接缝段——[method _init] 要调
## [method _reset_slots]、后者要调 [method _make_empty_slot]，属「后代调祖先」；
## 反过来把 [method _init] 放本段会构成「祖先调后代」，解析期即失败（链序说明见链尾段文档）。
##
## [b]为什么拆出这一层[/b]：[code]formation_system.gd[/code] 435 行，超 300 行软上限
## （.claude/docs/coding-standards.md）。声明面独立成段是既有先例
## （[code]tribulation_system_contract.gd[/code] / [code]combat_system_contract.gd[/code] /
## [code]deployment_system_contract.gd[/code] / [code]scene_manager_contract.gd[/code]）。
##
## [b]继承链[/b]（各段守 300 行内，成员名与访问路径逐字不变）：[br]
## [code]  formation_system_contract.gd [/code] ← 声明面：2 枚举 / 6 信号 / 1 标量常量 / 15 实例字段[br]
## [code]  formation_system_access.gd   [/code] ← 接缝与访问面：默认状态构造 / 三个惰性子模块获取器 / 信号发射包装 / 两个 Autoload 获取器[br]
## [code]  formation_system_flow.gd     [/code] ← 流程面：部署与覆盖 / 归属管理 / 查询 API / 内部原语[br]
## [code]  formation_system.gd          [/code] ← 链尾：条件重判与光环委托 / 序列化三出口 / 战斗结束清理[br]
##
## 来源: ADR-0024 §决策 §对象模型 §阵法状态机 §关键接口 / GDD formation-system.md。

extends Node


# class_name FormationSystem —— 不声明：Autoload 全局单例，
# 声明 class_name 会与全局名冲突，导致 FS_SCRIPT.new() 测试实例无法解析。
# 测试以 var fs: Node 持有 + 动态分派访问（同 DeploymentSystem/BindingManager 先例）。


# === 枚举 ======================================================================

enum SlotState { EMPTY, DEPLOYED_UNACTIVE, ACTIVE, DISCARDED }
enum AuraScope { GLOBAL, AFFILIATED_CHARACTERS, SAME_FACTION, FORMATION_TRIGGER }


# === Cat 2b 信号（ADR-0024 §Cat 2b 信号，经 _emit_signal_safe 路由）===============

## 阵法部署到阵法位（无论是否激活）。
signal formation_deployed(formation_id: int, slot_index: int, template_id: StringName, deployed_turn: int)
## 阵法条件满足→激活。
signal formation_activated(formation_id: int, slot_index: int, template_id: StringName, trigger_reason: String)
## 阵法条件不满足→失效。
signal formation_deactivated(formation_id: int, slot_index: int, reason: String)
## 覆盖完成（携带 old/new formation_id，UI 据此替换图标 + 过渡动画）。
signal formation_overwritten(old_formation_id: int, new_formation_id: int, slot_index: int)
## 玩家手动指定角色归属。
signal character_affiliated(character_id: int, formation_id: int)
## 条件重判完成批量通知（携带变更列表）。
signal formation_condition_reevaluated(changes: Array)


# === 常量 ======================================================================

const MAX_SLOTS: int = 3


# === 内部数据 ==================================================================

## 阵法位——slot_index(0-2) → 阵法 Dictionary。[br]
## [b]声明为无类型 Dictionary[/b]——Dictionary[int, Dictionary] 是嵌套类型化集合，
## Godot 4.6 GDScript 不支持。值仍为 Dictionary，类型保证由构造路径维护。
var _slots: Dictionary = {}

## 角色归属——character_id → formation_id（每角色最多 1 个）。
var _affiliations: Dictionary[int, int] = {}

## 下一阵法 ID（单调递增）。
var _next_formation_id: int = 1

## 当前回合（由调用方设置，默认 0）。
var _deploy_turn: int = 0

## 延迟归属队列（ADR-0024 §风险——敌方回合时序安全）。[br]
## 敌方回合条件重判中新阵法激活需归属选择时压入此队列，[br]
## 己方回合 Phase 1 DRAW 由 CombatSystem 弹出（本 Story 仅实现数据结构 + 压入存根）。
var _pending_affiliations: Array[Dictionary] = []


# === 可注入存根（同 BindingManager 先例——默认空操作/安全回退）===================

## 阵法激活条件判定存根——(requirement: Dictionary) -> bool。默认走 FactionSystem.check_condition。
var condition_check_cb: Callable = Callable()

## 效果引擎 register_persistent_effect 存根——(card_instance_id, template_id, scope_context)。默认空操作。
var effect_register_cb: Callable = Callable()

## 效果引擎 remove_effects_by_source 存根——(card_instance_id)。默认空操作。
var effect_remove_cb: Callable = Callable()

## 阵法覆盖时旧卡进弃牌堆存根——(card_instance_id)。默认空操作。
var card_discard_cb: Callable = Callable()

## 阵营人数查询存根——(tag_id: StringName) -> int。默认走 FactionSystem.count_on_field。
var count_on_field_cb: Callable = Callable()

## 固定属性加成查询存根——(formation_id: int, stat_name: String) -> float。[br]
## 用于固定阵法（非梯度）的属性增益查询——默认从 slot.effect_config 读取。
var fixed_bonus_cb: Callable = Callable()

## 角色存在性验证存根——(character_id: int) -> bool。默认返回 true（假设存在）。
var character_exists_cb: Callable = Callable()


# === 子模块（Sprint 9 Story 3 拆分）=================================================

## 序列化子模块——惰性初始化。
var _serializer: RefCounted = null

## 光环查询子模块——惰性初始化。
var _aura: RefCounted = null

## 部署/覆盖/条件重判子模块——惰性初始化（Sprint 12 Story 019 拆分）。
var _slot_ops: RefCounted = null
