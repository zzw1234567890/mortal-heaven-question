## DeploymentSystem 状态层（继承链第 2 段）——[b]全部 6 个实例字段[/b]住在这一层。
##
## [b]本层职责[/b]：阵位系统的全部可变态。[br]
##   · 阵位数据（[member _field]）与跨战斗阵亡名单（[member _unavailable_characters]）；[br]
##   · 前排破防信号的一次性标志（[member _front_line_breached_emitted]）；[br]
##   · 3 个子模块引用（惰性创建，getter 在 [code]deployment_system_access.gd[/code]）。[br]
##
## [b]为什么字段单独一段而非并入定义层[/b]：字段本身不引用本链的枚举，与定义层并无
## 解析期先后约束；拆开只为让「值定义」与「可变状态」各自可读，且两段合一的体量会挤占
## 后续各段的余量。[br]
##
## [b]哪些字段是有意留作公开接缝[/b]：[member _field] 与 [member _unavailable_characters]
## 是既有测试与 3 个 RefCounted 子模块用 [code]ds.get("_field")[/code] /
## [code]_parent.get("_unavailable_characters")[/code] 直取的入口，名字一律不动。[br]
##
## 来源: ADR-0016 §阵位数据模型 / .claude/docs/coding-standards.md §文件行数限制。

extends "res://src/feature/deployment/deployment_system_contract.gd"

# === 内部数据 =====================================================================

## 阵位数据——[code]{slot_index: {character_id, is_front, deploy_turn, state}}[/code]。
## slot_index 编码：0=前1, 1=前2, 2=前3, 3=后1, 4=后2, 5=后3。[br]
## 空位为 [code]{character_id: -1, is_front: bool, deploy_turn: -1, state: EMPTY}[/code]。
var _field: Dictionary = {}

## 不可用角色列表（跨战斗持久）——[code]{character_id: {death_turn, death_battle_id, revival_methods}}[/code]。
## 本 Story 仅初始化空字典——mark_unavailable/revive_character 生命周期属 Story 004。
var _unavailable_characters: Dictionary = {}

## 前排破防信号已发射标志——防止 [method is_targetable] 重复发射 front_line_breached。
## 在 [method setup_field] 中重置（ADR-0016 §风险缓解）。
var _front_line_breached_emitted: bool = false

## 序列化子模块——惰性初始化（Sprint 9 Story 1 拆分）。
var _serializer: RefCounted = null

## 阵位分配子模块——惰性初始化（Sprint 9 Story 1 拆分）。
var _slot_allocator: RefCounted = null

## 信号发射子模块——惰性初始化（Sprint 12 Story 018 拆分）。
var _emitter: RefCounted = null
