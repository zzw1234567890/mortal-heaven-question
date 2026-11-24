## DeploymentSystem —— 上场阵位系统 Autoload（#17）。[b]链尾：战斗结束快照导出 / 读档恢复[/b]。
##
## Feature 层 Autoload。采用内部状态机管理阵位数据——阵位分布、角色在场状态、
## 待命/已就绪标记均在内部 [member _field] Dictionary 中管理，战斗期间阵位数据不经过 GSM。
## 采用与 ADR-0011 StatusEffectSystem / ADR-0013 BindingManager 相同的 GSM 边界先例。[br]
##
## [b]Autoload 路径不变[/b]：[code]project.godot[/code] 仍指
## [code]res://src/feature/deployment_system.gd[/code]——本文件是链尾，注册名与既有测试的
## [code]DS_SCRIPT[/code] 常量逐字不动。[br]
##
## [b]本层职责[/b]：[b]GSM 边界的薄转发层[/b]——6 个方法全部转发
## [code]deployment_serializer.gd[/code]：战斗结束的 [method serialize_field] /
## [method write_snapshot_to_gsm] / [method sync_unavailable_to_gsm]，以及读档侧的
## [method deserialize_field] / [method restore_unavailable_from_storage] /
## [method load_unavailable_from_gsm]。拆分前本层的转发就不含逻辑，故链尾最薄
## （本文件 53 行）。[br]
##
## 来源: ADR-0016 §决策 §GSM 边界 §快照导出 / GDD deployment-system.md。[br]
## [b]Autoload 注册[/b]：[code]project.godot[/code] 的
## [code]DeploymentSystem="*res://src/feature/deployment_system.gd"[/code] 逐字不动（#17）。

extends "res://src/feature/deployment/deployment_system_unavailable.gd"

# === 战斗结束快照导出 / 读档恢复（ADR-0016 §GSM 边界）=============================

## 战斗结束时序列化阵位——委托给 _serializer 子模块。
func serialize_field() -> Dictionary:
	return _get_serializer().serialize_field()


## 从快照恢复阵位——委托给 _serializer 子模块。
func deserialize_field(data: Dictionary) -> void:
	_get_serializer().deserialize_field(data)


## 战斗结束时同步不可用角色列表至 GSM——委托给 _serializer 子模块。
func sync_unavailable_to_gsm() -> void:
	_get_serializer().sync_unavailable_to_gsm()


## 从 GSM 现读不可用角色列表并拉回本地——委托给 _serializer 子模块。
func restore_unavailable_from_storage() -> void:
	_get_serializer().restore_unavailable_from_storage()


## 从 GSM 存档数据恢复不可用角色列表——委托给 _serializer 子模块。
func load_unavailable_from_gsm(data: Dictionary) -> void:
	_get_serializer().load_unavailable_from_gsm(data)


## 写阵位快照至 GSM——委托给 _serializer 子模块。
func write_snapshot_to_gsm() -> void:
	_get_serializer().write_snapshot_to_gsm()
