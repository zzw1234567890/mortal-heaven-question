## DeploymentSystem 定义层（继承链首段）——[b]枚举、Cat 2b 信号、脚本常量[/b]住在这一层。
##
## [b]为什么拆出这一层[/b]：[code]deployment_system.gd[/code] 596 行，超 300 行软上限
## （.claude/docs/coding-standards.md）。拆法用[b]继承链[/b]而非组合——产品代码（战斗域
## 24 个文件 + UI/存档域）、约 20 个既有测试文件，以及 3 个 RefCounted 子模块
## （[code]deployment_serializer.gd[/code] / [code]deployment_slot_allocator.gd[/code] /
## [code]deployment_emitter.gd[/code]）全都直取这个面：前者写
## [code]ds.call("setup_field", ...)[/code] / [code]ds.get("_field")[/code] /
## [code]DS_SCRIPT.FieldState.EMPTY[/code]，后者经 [code]_parent.get("SLOT_COUNT")[/code] /
## [code]_parent.call("_state_to_string", ...)[/code] 这类动态分派回取。组合式拆分要给每个成员
## 补一层转发器，而转发器与实体漂移是[b]静默失效[/b]——[code]call / get / set[/code]
## 传错名字不报语法错，只 push_error 或静默返回 null。
## 守卫用例（[code]tests/unit/deployment_system/test_deployment_public_face_lock.gd[/code]）实测：
## 常量 / 信号 / 枚举 / 实例字段 / 方法与 [method Object.get] / [method Object.set] /
## [method Object.call] [b]都沿继承链解析[/b]，故逐字搬家即逐位等价，无需转发器。
##
## [b]继承链[/b]（各段守 300 行内，成员名与访问路径逐字不变）：[br]
## [code]  deployment_system_contract.gd       [/code] ← 本层：1 枚举 / 3 常量 / 6 信号[br]
## [code]  deployment_system_fields.gd         [/code] ← 状态层：6 个实例字段[br]
## [code]  deployment_system_access.gd         [/code] ← 接缝层：GSM 查找 + 3 惰性 getter + 6 信号出口[br]
## [code]  deployment_system_field_queries.gd  [/code] ← 数据层：阵位查询 API + 内部数据原语[br]
## [code]  deployment_system_battle_ops.gd     [/code] ← 战斗操作层：构造 / 备战 / 待命 / 补位 / 目标查询[br]
## [code]  deployment_system_unavailable.gd    [/code] ← 不可用生命周期层：阵亡标记 / 复活 / 判负[br]
## [code]  deployment_system.gd                [/code] ← 链尾：战斗结束快照导出 / 读档恢复（Autoload 入口）[br]
##
## [b]Autoload 路径不变[/b]：[code]project.godot[/code] 仍指
## [code]res://src/feature/deployment_system.gd[/code]——注册名与既有测试的
## [code]DS_SCRIPT[/code] 常量逐字不动。[br]
##
## [b]信号只声明一处[/b]：重复声明会被当成两个不同信号，发了外部连不上——故 6 个 Cat 2b 信号
## 全部落在本层，由链上各段发射（探针已验证基类信号可在派生段 emit）。[br]
##
## 来源: ADR-0016 §决策 §阵位数据模型 §关键接口 / GDD deployment-system.md、
## .claude/docs/coding-standards.md §文件行数限制。

extends Node
# class_name DeploymentSystem —— 不声明：Autoload 全局单例，
# 声明 class_name 会与全局名冲突，导致 DS_SCRIPT.new() 测试实例无法解析。
# 测试以 var ds: Node 持有 + 动态分派访问（同 GSM/RealmSystem/CostSystem 先例，
# 控制清单 2026-08-05 规则）。

# === 枚举 ========================================================================

## 角色在场状态机——STANDBY（待命）→ READY（已就绪）→ ACTED（已行动）→ 回合结束 → READY；DEAD → 空位。
## 状态转换由 CombatSystem 在回合编排中驱动（clear_standby_state / set_acted）。
enum FieldState {
	EMPTY = 0,    ## 空位——无角色
	STANDBY = 1,  ## 待命——上场回合不可攻击（GDD §5 待命规则）
	READY = 2,    ## 已就绪——可正常行动
	ACTED = 3,    ## 已行动——本回合已执行动作
	DEAD = 4,     ## 阵亡——阵位变为空位
}

# === 常量 ========================================================================

## 固定 6 格阵位（前 3 后 3）——ADR-0016 §阵位数据模型。
const SLOT_COUNT: int = 6

## 前排阵位数量（slot 0-2）。
const FRONT_SLOTS: int = 3

## 境界上场上限 → 前排配额映射（GDD §2 境界阵位分布表）。
## 炼气/筑基/金丹（max_deploy 2-4）→ 前 2；元婴/化神（5-6）→ 前 3。
## 阵位分布是境界属性——由 max_deploy 唯一决定（ADR-0016 境界→人数映射在 RealmSystem，
## 本表为 DeploymentSystem 的阵位分布规则）。
const FRONT_CAPACITY_BY_MAX_DEPLOY: Dictionary = {2: 2, 3: 2, 4: 2, 5: 3, 6: 3}

# === 信号声明（Cat 2b）=============================================================

## 角色上场时发射（备战/战中补位）。[br]
## [br][b]载荷[/b]: [code](character_id, slot_index, is_front, deploy_turn)[/code]。
signal character_deployed(character_id: int, slot_index: int, is_front: bool, deploy_turn: int)

## 角色阵亡离场时发射。[br]
## [br][b]载荷[/b]: [code](character_id, slot_index, reason)[/code]——reason 为离场原因字符串。
signal character_removed(character_id: int, slot_index: int, reason: String)

## 前排全灭→后排暴露时发射（仅一次，setup_field 重置标志）。[br]
## [br][b]载荷[/b]: 无参数。
signal front_line_breached()

## 回合结束时待命清除发射（Phase 6 END，CombatSystem 调用）。[br]
## [br][b]载荷[/b]: [code](character_ids: Array[int])[/code]——仅含 STANDBY→READY 的角色（不含 ACTED→READY）。
signal standby_cleared(character_ids: Array[int])

## 角色标记为不可用时发射（战斗结算）。[br]
## [br][b]载荷[/b]: [code](character_id: int)[/code]。
signal character_unavailable(character_id: int)

## 角色复活时发射。[br]
## [br][b]载荷[/b]: [code](character_id: int)[/code]。
signal character_revived(character_id: int)
