extends "res://src/foundation/save_load/snapshots.gd"
## SaveLoadSystem (Autoload #4) —— 存档/读档系统的持久化引擎。[b]链尾：公共 API 编排面[/b]。[br]
## [br][b]枚举[/b]: SaveSlotType（槽位类型）、SaveResult（保存结果）、LoadResult（读取结果）[br]
## [b]JSON 引擎[/b]: [method _parse_json_file]（读取 + Error 检查）+
## [method _serialize_to_json]（格式化写入）[br]
## [br][b]⚠️ ADR-0002 强制规则[/b]: 解析存档必须使用 [method JSON.new].parse()——
## 绝不使用 [method JSON.parse_string]（无法区分合法 null 和解析错误）。[br]
## [br][b]Story 001 范围[/b]: 枚举定义 + JSON 引擎核心。[br]
## [b]Story 002 范围[/b]: 原子写入管线 + Windows 重试 + 重入防护 + 路径解析。[br]
## [br][b]继承链[/b]（原单文件 1027 行 → 各段守 300 行软上限，
## .claude/docs/coding-standards.md；成员名与访问路径逐字不变，机械拆分、行为零改动）：[br]
## [code]  save_load/contract.gd[/code]     枚举 / 信号 / 依赖注入[br]
## [code]  save_load/atomic_io.gd[/code]    JSON 引擎 / 路径 / 原子写盘[br]
## [code]  save_load/container.gd[/code]    容器 schema / 完整性 / 版本 / 完整读取[br]
## [code]  save_load/migration.gd[/code]    迁移注册表 / 逐级迁移链[br]
## [code]  save_load/slots.gd[/code]        meta.json / 槽位查询 / 删除[br]
## [code]  save_load/snapshots.gd[/code]    跨局进度 / 战斗快照[br]
## [code]  save_load_system.gd[/code] ← 本层：公共 API 编排（Autoload 入口不变）[br]
## [br][b]本层职责[/b]：四个公开入口的编排——[method save_game]（校验 → 构造容器 → 原子写 →
## 信号 → meta.json）、[method load_game]（读 → 版本 → 迁移 → GSM 落地 → 收尾清理）、
## [method auto_save] 与 [method build_slot_meta]（转发给 [SaveAutoSave] 子模块）。[br]
## [br][b]为什么拆成继承链而不是组合子模块[/b]：本库用例与产品代码大量直取
## [code]SaveLoadSystem.SaveSlotType[/code] 这类脚本类成员，也直调
## [code]sls._atomic_write[/code] / [code]sls._get_save_root[/code] /
## [code]sls.MIGRATIONS[/code] 这些私有面与 [code]static var[/code]。探针实测这些访问
## [b]都沿继承链解析[/b]（而 RefCounted 子模块做不到，那要给每个成员补一层转发器
## ——转发器与实体漂移即静默失效）。信号只声明一处（[code]save_load/contract.gd[/code]），
## 避免「同名两个信号、发了外部连不上」。[br]
## [br]来源: ADR-0002 §存档容器与迁移链、ADR-0006 §CardInstance 契约、
## ADR-0016 §不可用角色生命周期、design/gdd/game-state-manager.md §存档。

## === 自动存档子模块 ============================================================

## 自动存档的实现子模块——「什么时候该自动存、存什么元信息」在那边，
## 本类只留一个转发（见 [method auto_save]）。
const SaveAutoSaveScript := preload("res://src/foundation/save_auto_save.gd")
## 子模块实例——惰性创建并持有引用（防 RefCounted 提前释放）。
var _auto_save: RefCounted = null

## === 内置虚方法 ================================================================

func _ready() -> void:
	pass

## === 公共 API =================================================================

## [b]保存游戏[/b]——将已序列化的 GSM 数据封装为存档容器并原子写入。
##
## [b]参数[/b]: [br]
##   [param slot_type] 槽位类型——AUTOSAVE / MANUAL / SNAPSHOT。[br]
##   [param slot_id] 槽位编号——MANUAL 时为 1-3，其他类型忽略。[br]
##   [param data] 调用方已序列化的 GSM 数据——必须是 [method GameStateManager.serialize] 的输出。
##     该输出已归一为 JSON 安全形态（String 键 + 标量；见
##     [method GSMSerializer.serialize]），故正常路径不会触发校验失败。[br]
##   [param meta] 展示用元信息字典——参见 [method _build_save_container]。[br]
## [b]返回[/b]: [enum SaveResult]——SUCCESS 或错误码。[br]
## [br][b]信号[/b]: 保存完成后发射 [signal save_completed]。[br]
## [br][b]⚠️ AC-002[/b]: data 中包含非 JSON 兼容类型（Vector2/Color 等）→
## [method JSON.stringify] 会失败 → 返回 [enum SaveResult.VALIDATION_ERROR]。
## [br]这是[b]最后一道关[/b]：类型归一在 [method GameStateManager.serialize]
## （StringName → String、int 键 → String 键），此处只负责拒绝归一化不了的
## 类型（对象 / Vector2 / Color）——不在这里再归一一次，否则两处口径会漂。[br]
func save_game(slot_type: SaveSlotType, slot_id: int = 0,
               data: Dictionary = {}, meta: Dictionary = {}) -> int:
	# AC-002：类型校验——data 必须仅含 JSON 兼容类型
	if not data.is_empty() and not _is_json_compatible(data):
		push_error("SaveLoadSystem: save_game 数据类型校验失败——data 包含非 JSON 兼容类型")
		save_completed.emit(slot_type, slot_id, false)
		return SaveResult.VALIDATION_ERROR

	var container := _build_save_container(data, meta)
	var path := _save_path(slot_type, slot_id)
	var result := _atomic_write(path, container)

	# AC-014/AC-015：发射 save_completed 信号
	save_completed.emit(slot_type, slot_id, result == SaveResult.SUCCESS)

	# AC-016：保存成功后更新 meta.json
	if result == SaveResult.SUCCESS:
		_update_meta_json(slot_type, slot_id, meta)

	return result


## [b]自动存档[/b]——把当前 GSM 状态写进自动槽位（[constant SaveSlotType.AUTOSAVE]）。[br]
## [br][b]谁在调[/b]：[code]SceneManager.request_scene_change[/code] 在 Phase 2
## 经 [code]has_method("auto_save")[/code] 守卫调用（AC-2：「每次场景变更都保存」）
## ——本方法此前根本不存在，那条调用是[b]静默空操作[/b]，于是玩家的进度只在
## 手动点「保存并退出」时才落盘，「继续游戏」多数时候读不到东西。[br]
## [br][b]fire-and-forget[/b]：不阻塞转场管线；因此返回 null 是正常结果（还没开局
## ——详见 [method SaveAutoSave.run]），调用方不必区分「没写」与「写成功」，
## 只有测试与排障需要这个返回值。[br]
## [br][b]实现为什么不在本文件[/b]：本类由「存不存、存什么元信息」与「原子写盘、
## JSON 引擎、迁移链」两件事构成，后者已按职责拆进 [code]save_load/[/code] 各层；
## 自动存档的决策逻辑仍是独立子模块。[br]
## [br][b]返回[/b]：写入的 [enum SaveResult]；未开局 / 依赖不可用时
## [code]null[/code]（没写也没出错）。[br]
## [br]来源: GDD save-load-system.md §9 自动存档、scene_manager.gd §Phase 2（AC-2）。
func auto_save() -> Variant:
	if _auto_save == null:
		_auto_save = SaveAutoSaveScript.new(self)
	return _auto_save.call(&"run")


## 槽位元信息（境界显示名 / 场景落点 / 已游玩时长）——[b]唯一的构建入口[/b]。[br]
## [br][b]为什么要有这个门[/b]：[code]save_game[/code] 的 [param meta] 由调用方给
## （自动存档、暂停菜单手动存档各一处），而它决定 meta.json 里那条槽位记录写什么。
## 暂停菜单此前传的是空字典 [code]{}[/code]——存档容器顶层的
## [code]playtime_seconds[/code] 是对的，meta.json 里却是 0，主菜单读 meta.json，
## 于是摘要行写「游玩 0小时0分」。两处共用一个构建入口，就没有第二份口径。[br]
## [br][b]实现仍在 [code]SaveAutoSave[/code][/b]（它的 [method SaveAutoSave.build_meta]
## 已是「境界名要查 RealmSystem」这一条的唯一实现处）——本方法只做转发，
## 不重复一份「怎么拼 meta」。[br]
## [br][b]缺席即空字典[/b]：GSM 不可用时返回 [code]{}[/code]——[code]save_game[/code]
## 的默认值填充会把缺失字段写成默认，存档照常（不比「因为没有 meta 而不存」更差）。
func build_slot_meta(p_gsm: Node = null) -> Dictionary:
	var gsm: Node = p_gsm if p_gsm != null else _get_gsm()
	if gsm == null:
		return {}
	if _auto_save == null:
		_auto_save = SaveAutoSaveScript.new(self)
	return _auto_save.call(&"build_meta", gsm)


## [b]读取游戏[/b]——从指定槽位读取存档并恢复完整游戏状态。
##
## 完整流程（5 阶段）：[br]
##   1. 发射 [signal load_started] 信号。[br]
##   2. [method _atomic_read] 读取 + 完整性校验。[br]
##   3. [method _validate_version] 版本校验 + [method _migrate_if_needed] 迁移。[br]
##   4. [method GameStateManager.deserialize] 反序列化 game_state。[br]
##   5. [method CardSystem.reconstitute_instances] 重构 CardInstance（前向兼容）。[br]
## [br]
## [b]返回[/b]: [code]{"result": LoadResult, "data": Dictionary}[/code]。成功时 data 包含存档容器全部字段。[br]
## [br][b]信号[/b]: [signal load_started] + [signal load_completed]。[br]
## [b]信号（错误路径）[/b]: [signal save_corrupted]（DESERIALIZE_ERROR 时）。
func load_game(slot_type: SaveSlotType, slot_id: int = 0) -> Dictionary:
	# AC-003：发射 load_started 信号
	load_started.emit(slot_type, slot_id)

	var path := _save_path(slot_type, slot_id)
	var read_result := _atomic_read(path)
	if read_result["result"] != LoadResult.SUCCESS:
		load_completed.emit(false)
		return read_result

	var data: Dictionary = read_result["data"]

	# 版本校验
	var version_result := _validate_version(data)
	if version_result.has("error"):
		load_completed.emit(false)
		return {"result": LoadResult.VERSION_MISMATCH, "data": data}

	# 迁移
	data = _migrate_if_needed(data)
	if data.has("error"):
		push_error("SaveLoadSystem: 迁移失败——%s (from=%d)" % [data["error"], data.get("from", data.get("save_schema", -1))])
		save_corrupted.emit(slot_type, slot_id, data.get("error", "MIGRATION_ERROR"))
		load_completed.emit(false)
		return {"result": LoadResult.DESERIALIZE_ERROR, "data": data}

	# AC-003：GSM 反序列化
	var gsm: Node = _get_gsm()
	if gsm == null or not gsm.has_method("deserialize"):
		push_error("SaveLoadSystem: GSM 不可用——无法反序列化")
		save_corrupted.emit(slot_type, slot_id, "DESERIALIZE_ERROR")
		load_completed.emit(false)
		return {"result": LoadResult.DESERIALIZE_ERROR, "data": {}}
	if not gsm.deserialize(data["game_state"]):
		# AC-004：GSM.deserialize 返回 false
		save_corrupted.emit(slot_type, slot_id, "DESERIALIZE_ERROR")
		load_completed.emit(false)
		return {"result": LoadResult.DESERIALIZE_ERROR, "data": {}}

	# CardInstance 重构（ADR-0006 契约）——前向兼容空检查
	var cs: Node = _get_card_system()
	if cs != null and cs.has_method("reconstitute_instances"):
		var owned_cards: Array = data["game_state"].get("collection", {}).get("owned_cards", [])
		cs.reconstitute_instances(owned_cards)

	# 阵亡名单落地（ADR-0016 §跨战斗持久）——把 GSM 里的存档值拉回
	# DeploymentSystem 的本地权威表；不拉的话「读档后阵亡角色照常上场、
	# 下次存档又抹平死亡记录」。GSM 不可用 / 系统缺席时静默跳过（前向兼容）。
	_restore_deployment_from_gsm()

	# 输入锁栈镜像清空（session 域自本轮起可持久——见 NON_PERSISTABLE_DOMAINS 注记）。
	# 存档里的 input_locks 是「上一次退出时栈的样子」，而读档时真实的 InputManager
	# 栈是进程级的另一回事：把镜像带回来会让它声称一把并不存在的锁（
	# [method InputManager.has_lock] 读的正是这个镜像）。故读档后显式清成空。
	_clear_session_input_locks()

	# 清理旧战斗快照
	clear_battle_snapshot()

	load_completed.emit(true)
	return {"result": LoadResult.SUCCESS, "data": data}


## 读档后清空 [code]session.input_locks[/code] 镜像——见 [method load_game] 的调用点注记。[br]
## [br][b]为什么不用 [method InputManager.clear_locks][/b]：那把锁是真的要清（读档后
## 任何旧锁都不该生效），但 InputManager 是 Autoload、可能缺席（headless 单测）；
## 而本方法要保证的是「镜像与真实栈一致」这个不变式——直接写空数组即可，真实栈在
## 转场管线里由 [code]SceneManager[/code] 统一清（同 [code]clear_locks()[/code] 的
## 既有职责，本方法不越界去重设它）。
func _clear_session_input_locks() -> void:
	var gsm: Node = _get_gsm()
	if gsm == null:
		return
	var session: Variant = gsm.get(&"session")
	if session is Dictionary:
		(session as Dictionary)["input_locks"] = []


## 读档后把 GSM 里的阵亡名单拉回 DeploymentSystem（读档链路第 6 阶段）。[br]
## [br][b]为什么在 SaveLoadSystem 而不是 GSM[/b]：拉回来的是 [b]Feature 层[/b]的本地权威表
## （[code]DeploymentSystem._unavailable_characters[/code]），Foundation 不该反向依赖
## Feature——本方法只做「找到 Autoload、调它的公开入口」，与
## [method _get_card_system] 调 [code]CardSystem.reconstitute_instances[/code] 同一形态
## （同层级的读取后落地）。[br]
## [br][b]缺席即跳过[/b]：headless 单测 / 早期启动没有 DeploymentSystem 时静默返回
## ——读档本身照常成功（[method _get_card_system] 的前向兼容先例）。[br]
func _restore_deployment_from_gsm() -> void:
	var ds: Node = _get_deployment_system()
	if ds == null or not ds.has_method("restore_unavailable_from_storage"):
		return
	ds.call("restore_unavailable_from_storage")
