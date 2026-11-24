extends Node
## SaveLoadSystem 契约面（继承链首段）——[b]枚举、信号、依赖注入[/b]住在这一层。[br]
## [br][b]为什么拆出这一层[/b]：[code]save_load_system.gd[/code] 严重超 300 行软上限
## （.claude/docs/coding-standards.md）。拆法用[b]继承链[/b]而非组合——本库的用例与产品
## 代码大量直取 [code]SaveLoadSystem.SaveSlotType[/code] / [code]SaveLoadSystem.SaveResult[/code]
## 这类脚本类成员，也大量直调 [code]sls._atomic_write[/code] / [code]sls._get_save_root[/code]
## 这类私有面（Story 002/003/005 的验收就写在私有面上）。探针实测：常量 / 枚举 /
## [code]static var[/code] / 静态函数 / 信号 / 方法与 [method Object.get] / [method Object.call]
## [b]都沿继承链解析[/b]，故拆分后这些名字的解析结果与拆分前逐位一致。组合式拆分则要给
## 每个成员补一层转发器——那本身就是改面（转发器与实体漂移即静默失效）。[br]
## [br][b]继承链[/b]（各段守 300 行内，成员名与访问路径逐字不变）：[br]
## [code]  save_load/contract.gd[/code]        ← 本层：枚举 / 信号 / 依赖注入[br]
## [code]  save_load/atomic_io.gd[/code]       ← 写入控制 + JSON 引擎 + 路径 + 原子写盘[br]
## [code]  save_load/container.gd[/code]       ← 容器 schema / 完整性校验 / 版本校验 / 完整读取[br]
## [code]  save_load/migration.gd[/code]       ← 迁移注册表 + 逐级迁移链[br]
## [code]  save_load/slots.gd[/code]           ← meta.json 与槽位查询[br]
## [code]  save_load/snapshots.gd[/code]       ← 跨局进度 + 战斗快照[br]
## [code]  save_load_system.gd[/code]          ← 链尾：公共 API 编排（Autoload 入口不变）[br]
## [br][b]本层职责[/b]：三个枚举（存档格式的一部分，值即契约）+ 五个信号 + 依赖注入面
## （GSM / CardSystem / DeploymentSystem 的取用口径）。[br]
## [br][b]信号只声明一处[/b]：重复声明会被当成两个不同信号，发了外部连不上——故全部落在
## 本层，由链上各层发射（探针已验证基类信号可在派生层 emit）。[br]
## [br]来源: ADR-0002 §存档容器与迁移链、.claude/docs/coding-standards.md §文件行数限制。

## === 存档槽位类型 ==============================================================

## 存档槽位类型——驱动文件路径解析和 UI 展示。
enum SaveSlotType {
	AUTOSAVE = 0,  ## 自动存档——固定 autosave 槽位，每局唯一，自动覆盖
	MANUAL = 1,    ## 手动存档——3 个槽位（save_1/save_2/save_3），玩家可命名/覆盖/删除
	SNAPSHOT = 2,  ## 战斗前快照——固定 pre_battle 槽位，战斗胜利/撤退后自动清除
}

## === 保存结果 ==================================================================

## 保存操作的结果码。
enum SaveResult {
	SUCCESS = 0,          ## 保存成功
	DISK_FULL = 1,        ## 磁盘空间不足
	WRITE_ERROR = 2,      ## 写入错误（含 Windows rename 重试 3 次均失败）
	VALIDATION_ERROR = 3, ## 数据校验失败——data 不符合存档格式约束
}

## === 读取结果 ==================================================================

## 读取操作的结果码。
enum LoadResult {
	SUCCESS = 0,           ## 读取成功
	FILE_NOT_FOUND = 1,    ## 文件不存在——槽位为空或路径无效
	CORRUPTED = 2,         ## 存档损坏——JSON 解析失败、顶层非 Object、缺少必填字段
	VERSION_MISMATCH = 3,  ## 版本不兼容——存档的 schema_version 高于当前游戏版本
	DESERIALIZE_ERROR = 4, ## 反序列化错误——GSM.deserialize() 返回 false
}

## === 信号声明 =================================================================

## 存档完成信号——保存成功或失败后发射。
## [br][param slot_type] 槽位类型；[param slot_id] 槽位编号；
## [param success] true 表示保存成功。
signal save_completed(slot_type: SaveSlotType, slot_id: int, success: bool)

## 读档开始信号——在读档流程启动前发射，供 UI 显示加载提示。
signal load_started(slot_type: SaveSlotType, slot_id: int)

## 读档完成信号——成功或失败后发射。[br]
## [param success] true 表示读档成功。
signal load_completed(success: bool)

## 存档损坏信号——读档时检测到存档数据不可恢复时发射。
## [br][param reason] 损坏原因（DESERIALIZE_ERROR / CORRUPTED 等字符串）。
signal save_corrupted(slot_type: SaveSlotType, slot_id: int, reason: String)

## 跨局进度保存信号——[method load_progression] 因文件损坏重置默认值后发射。
## [br][param success] false 表示 progression.dat 损坏已重置为默认值。
signal progression_saved(success: bool)

## === 依赖注入 =================================================================

## 游戏状态管理器引用——通过 [method set_dependencies] 注入，或 Autoload #1 回退。
var _gsm: Node = null

## 卡牌系统引用——通过 [method set_dependencies] 注入，CardSystem 未实现时为 null。
var _card_system: Node = null


## 设置依赖引用——注入 GSM 和 CardSystem 以便测试 mock。
## [br]不传参数则保留已有引用（测试中可多次调用覆盖）。
func set_dependencies(gsm: Node = null, card_system: Node = null) -> void:
	if gsm != null:
		_gsm = gsm
	if card_system != null:
		_card_system = card_system


## 获取当前使用的 GSM 引用——注入对象优先，否则回退到 Autoload #1 GameStateManager。
func _get_gsm() -> Node:
	if _gsm != null:
		return _gsm
	return GameStateManager


## 获取当前使用的 CardSystem 引用——注入对象优先，未注入时返回 null（前向兼容）。
func _get_card_system() -> Node:
	if _card_system != null:
		return _card_system
	return null


## 获取当前使用的 DeploymentSystem 引用——未注册 Autoload 时返回 null（前向兼容）。[br]
## [br]用 SceneTree.root 查找而非硬引用全局名——避免测试环境无 Autoload 时崩溃。[br]
## [br][b]为什么住在契约面[/b]：与 [method _get_gsm] / [method _get_card_system] 同形
## （「注入优先、缺席回退」的三个取用口径），读档链路上的落地调用只是它的一个消费者。
func _get_deployment_system() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/DeploymentSystem")
