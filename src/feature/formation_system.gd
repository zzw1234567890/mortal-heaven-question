## FormationSystem —— 阵法系统 Autoload（#23）。[b]链尾：委托出口面 + 战斗结束清理[/b]。
##
## Feature 层 Autoload。采用内部条件状态机管理阵法位数据——
## 阵法位状态、激活/未激活判定、角色归属关系均在内部 Dictionary 中管理，
## 战斗期间不经过 GSM（ADR-0024 GSM 例外先例，同 ADR-0011/0013/0016）。
##
## [b]本 Story 范围[/b]（4-14）：SlotState/AuraScope 枚举 + 阵位数据模型 +
## deploy_formation / overwrite_formation / set_character_affilation /
## clear_character_affilation + 查询 API + 5 个 Cat 2b 信号。[br]
## [b]已注册进 project.godot[/b]——Autoload #23（FormationSystem）。[br]
## [b]后续 story[/b]：recheck_all_conditions 实时重判（4-15）、
## get_aura_bonus O(1) 查询（4-16）、serialize_all 快照（4-17）。
## [b]存根接口[/b]：条件判定走 FactionSystem.check_condition 或可注入
## condition_check_cb；效果引擎 register/remove 通过 Callable 承载——默认空操作。
##
## [b]本层职责[/b]：四个委托出口面与战斗结束清理。[br]
##   · 条件实时重判——[method recheck_all_conditions] 与 DeploymentSystem 信号处理器
##     [method _on_field_changed]（实现体在 [code]formation_slot_ops.gd[/code]）；[br]
##   · 光环查询——[method get_aura_bonus]（实现体在 [code]formation_aura.gd[/code]）；[br]
##   · 序列化三出口——[method serialize_all] / [method deserialize_all] /
##     [method write_snapshot_to_gsm]（实现体在 [code]formation_serializer.gd[/code]）；[br]
##   · 清理——[method clear_all_formations]（战斗结束，按 ADR-0024 §验证标准保留
##     [member _next_formation_id]）与测试辅助 [method _clear_all]（重置 ID，便于断言）。
##
## [b]继承链[/b]（各段守 300 行内，成员名与访问路径逐字不变）：[br]
## [code]  formation_system_contract.gd [/code] ← 声明面：2 枚举 / 6 信号 / 1 标量常量 / 15 实例字段[br]
## [code]  formation_system_access.gd   [/code] ← 接缝与访问面：默认状态构造 / 三个惰性子模块获取器 / 信号发射包装 / 两个 Autoload 获取器[br]
## [code]  formation_system_flow.gd     [/code] ← 流程面：部署与覆盖 / 归属管理 / 查询 API / 内部原语[br]
## [code]  formation_system.gd          [/code] ← 链尾：条件重判与光环委托 / 序列化三出口 / 战斗结束清理[br]
##
## [b]链序不是自由选择[/b]：GDScript 解析期要求被调方在[b]本段或祖先段[/b]——祖先段用裸
## 标识符引用后代段成员会直接报 [code]Function "xxx()" not found in base self[/code]。
## 故本层四个出口都要排在接缝段（惰性获取器与 [method _get_gsm]）与流程段（内部原语）之后；
## 而两个枚举因为要供给 [method _make_empty_slot]（[code]SlotState.EMPTY[/code] /
## [code]AuraScope.AFFILIATED_CHARACTERS[/code]）与 [method deploy_formation] 的默认参数值，
## 只能随声明整体落链首。[br]
## [b]路径即契约[/b]：[code]project.godot[/code] 的 [code][autoload][/code] 把
## [code]FormationSystem[/code] 绑在 [code]res://src/feature/formation_system.gd[/code]
## 这一串字符上，四个既有测试文件按同一路径 [code]preload[/code] 取类（读枚举、建实例），
## 故本文件名逐字不动。[b]本类不声明[/b] [code]class_name[/code]——Autoload 全局单例，
## 声明 class_name 会与全局名冲突，导致 [code]FS_SCRIPT.new()[/code] 测试实例无法解析；
## 测试以 [code]var fs: Node[/code] 持有 + 动态分派访问（同 DeploymentSystem/BindingManager 先例）。
## 守卫用例：[code]tests/unit/formation_system/test_formation_public_face_lock.gd[/code]。
##
## 来源: ADR-0024 §决策 §对象模型 §阵法状态机 §关键接口 / GDD formation-system.md。

extends "res://src/feature/formation/formation_system_flow.gd"


## 清空全部阵位和归属（测试辅助 + Story 004 clear_all_formations 基础）。[br]
## [b]注意[/b]：本方法重置 [member _next_formation_id] 为 1——便于测试断言。[br]
## Story 004 公共 [code]clear_all_formations()[/code] 须按 ADR-0024 §验证标准保留 [member _next_formation_id]。
func _clear_all() -> void:
	_reset_slots()
	_affiliations.clear()
	_next_formation_id = 1
	_deploy_turn = 0


# === 条件实时重判（Story 002）=================================================

## 条件重判——委托给部署子模块（Sprint 12 Story 019 拆分）。[br]
## [br][b]返回[/b]: [code]Array[/code]——元素 [code]{formation_id, slot_index, old_state, new_state, reason}[/code]。
func recheck_all_conditions() -> Array:
	return _get_slot_ops().recheck_all_conditions()


## DeploymentSystem 信号处理器——委托给部署子模块（Sprint 12 Story 019 拆分）。
func _on_field_changed(_character_id: int = -1, _slot_index: int = -1, _extra: Variant = null) -> void:
	_get_slot_ops().on_field_changed(_character_id, _slot_index, _extra)


# === 光环查询（Story 003）====================================================

## 战斗热路径 O(1) 查询——计算角色从归属阵法获得的总光环加成（AC-001/002）。[br]
## 委托给 formation_aura.gd 子模块（Sprint 9 Story 3 拆分）。
func get_aura_bonus(character_id: int, stat_name: String) -> Dictionary:
	return _get_aura().get_aura_bonus(character_id, stat_name)


# === 序列化 / 反序列化 / 快照导出（Story 004）=================================

## 序列化全部阵位数据 + 归属关系——委托给 formation_serializer.gd 子模块（Sprint 9 Story 3 拆分）。
func serialize_all() -> Dictionary:
	return _get_serializer().serialize_all()


## 从快照恢复阵位状态 + 归属关系——委托给 formation_serializer.gd 子模块。
func deserialize_all(data: Dictionary) -> void:
	_get_serializer().deserialize_all(data)


## 写阵法快照至 GSM battle.formation_snapshot——委托给 formation_serializer.gd 子模块。
func write_snapshot_to_gsm() -> void:
	_get_serializer().write_snapshot_to_gsm()


## 清空全部阵位和归属——战斗结束清理（AC-005）。[br]
## [b]注意[/b]：[member _next_formation_id] 保留（ADR-0024 §验证标准——不重置，避免 ID 冲突）。[br]
## 同时清理 [member _pending_affiliations] 延迟队列（lead-programmer C2——跨战斗遗留防护）。
func clear_all_formations() -> void:
	_reset_slots()
	_affiliations.clear()
	_pending_affiliations.clear()
	_deploy_turn = 0
