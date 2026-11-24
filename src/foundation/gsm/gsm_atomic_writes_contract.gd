## GSMAtomicWrites 接缝层（继承链首段）——[b]GSM 引用 + 三个子域委托 + 装配口[/b]。
##
## [b]本层职责[/b]：整条链的共享状态与装配口。[br]
##   · [member _gsm]——GSM 父节点引用，全部 52 个方法都靠它读写数据域；[br]
##   · 三个子域委托（[member _battle_writes] / [member _exploration_writes] /
##     [member _narrative_writes]）——战斗 / 探索 / 叙事三域的写入实现体；[br]
##   · [method init]——装配口。GSM 在 [code]_init()[/code] 里按名直呼
##     [code]_atomic_writes.init(self)[/code]（52 个方法里唯一不经同名 wrapper 的那个）。
##
## [b]为什么用继承链而非组合式转发器[/b]：GSM 按[路径]取这个类
## （[code]load("res://src/foundation/gsm/gsm_atomic_writes.gd").new()[/code]），把实例存在
## [code]_atomic_writes[/code]（静态类型 [code]RefCounted[/code]）上，逐条
## [code]_atomic_writes.方法名(...)[/code] 转发全部 52 个方法——[b]按名动态分派[/b]，
## 编译器只认得出 [code]RefCounted[/code] 自带的那些方法。名字打错、漏拆、默认值走样
## 都只是运行时 [code]push_error[/code]，不报语法错。继承链让「逐字搬家」等价于「逐位不变」；
## 组合式要给每个成员补一层转发器，而转发器与实体漂移正是静默失效。
## 守卫用例：[code]tests/unit/gsm/test_atomic_writes_public_face_lock.gd[/code]。
##
## [b]继承链[/b]（各段守 300 行内，成员名与访问路径逐字不变）：[br]
## [code]  gsm_atomic_writes_contract.gd  [/code] ← 本层：接缝（4 字段 + init）[br]
## [code]  gsm_atomic_writes_player.gd    [/code] ← 玩家域：修为 / 资源 / 身份 / 境界 / 轮回 / 天赋 / 渡劫[br]
## [code]  gsm_atomic_writes_collection.gd[/code] ← 收藏域：实例 ID / 收藏增删 / 模板校验[br]
## [code]  gsm_atomic_writes_deck.gd      [/code] ← 卡组域：卡组 / 阵位 / 变更日志 / 上限修正 / 散功计数[br]
## [code]  gsm_atomic_writes.gd           [/code] ← 链尾：会话域 + 三域子模块委托转发（GSM 按此路径 load）[br]
##
## 来源: ADR-0001 §第二层原子写入 / .claude/docs/coding-standards.md §文件行数限制。

extends RefCounted



## 指向 GSM 父节点的引用。
var _gsm: Node = null

## 战斗域写入子模块（Sprint 8 Story 8-11 拆分）。
var _battle_writes: RefCounted = null

## 探索域写入子模块（Sprint 8 Story 8-11 拆分）。
var _exploration_writes: RefCounted = null

## 叙事域写入子模块（Sprint 12 Story 012 拆分）。
var _narrative_writes: RefCounted = null


## 绑定 GSM 父节点引用。
func init(gsm: Node) -> void:
	_gsm = gsm
	_battle_writes = load("res://src/foundation/gsm/gsm_battle_writes.gd").new(gsm)
	_exploration_writes = load("res://src/foundation/gsm/gsm_exploration_writes.gd").new(gsm)
	_narrative_writes = load("res://src/foundation/gsm/gsm_narrative_writes.gd").new(gsm)
