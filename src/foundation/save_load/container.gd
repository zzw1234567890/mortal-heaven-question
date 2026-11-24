extends "res://src/foundation/save_load/atomic_io.gd"
## SaveLoadSystem 容器层 —— [b]存档容器的 schema、完整性校验、版本校验、完整读取[/b]。[br]
## [br][b]本层职责[/b]：回答「一份存档容器该长什么样、读进来的东西算不算一份完整存档」——
## [method _build_save_container]（构造容器）、[method _validate_save_data]（必填字段 +
## [code]complete[/code] 标记）、[method _validate_version]（高版本拒绝）、
## [method _atomic_read]（解析 + 校验的完整读取管线）。[br]
## [br][b]为什么与迁移分开[/b]：容器形状与「旧档怎么升上来」是两件事——前者随每轮存档内容
## 变更而变（字段增删），后者只在 schema_version 递增时变（迁移函数）。原文件 1027 行
## 严重超 300 行软上限（.claude/docs/coding-standards.md）。[br]
## [br][b]成员名逐字保留[/b]：Story 003 的验收（AC-001 ~ AC-016）直接写在
## [method _build_save_container] / [method _validate_save_data] / [method _validate_version] /
## [method _atomic_read] 上，探针实测这些私有面经继承链照旧解析。[br]
## [br]来源: ADR-0002 §存档容器、design/gdd/game-state-manager.md §存档。

## === 存档容器 schema =============================================================

## 当前存档格式版本——递增整数，唯一驱动迁移链的字段。
## [br][b]v4[/b]：续战段补上[b]牌面与 debuff[/b]——v3 的续战段只记
## 「谁、多少血、第几回合、什么阶段、还有多少费」，读档回来时手牌与牌堆会被
## [code]battle_start[/code] 重洗一遍、挂在敌人身上的 debuff 随状态表清空蒸发。
## v4 段里多了 [code]cards[/code]（三堆牌面）与 [code]debuffs[/code]（逐条剩余回合）。
## v3 档读入时给[b]正在进行的[/b]战斗段补两个空形状——空即「这份档没存过牌面」，
## 读侧据此走自然发牌那条老路（手牌重抽，与升级前的行为一致）。[br]
## [br][b]v3[/b]：「回到这场战斗」的存档段进容器
## （[code]game_state.battle_resume[/code]）——战斗域不可持久化，玩家在战斗中存的档
## 此前读回来只有探索地图，那场仗连同残血静默消失。v2 档读入时补一个空段
## （[code]{}[/code] 即「没有进行中的战斗」，与探索域补 [code]events_shown[/code]
## 同一口径：补的是默认值，不改变玩家已获得的任何东西）。[br]
## [br][b]v2[/b]：探索域的「已弹事件节点」进存档
## （[code]map_states[*].events_shown[/code]）——此前该状态只在事件面板的成员变量里
## （进程一退就丢，重进同一张图同一节点会再弹一次）。v1 档读入时为每张已存在的图
## 补空的 [code]events_shown[/code]（旧档没有这个键，等价于「本图什么都还没弹过」，
## 不改变玩家已获得的任何东西）。[br]
## [br][b]v1[/b]：ADR-0002 定义的第 1 版存档容器格式。[br]
## [br][b]为什么本常量住在容器层而不是迁移层[/b]：[method _build_save_container]
## （写入时盖版本戳）与 [method _validate_version]（读取时拒高版本）都先于迁移层用上它；
## GDScript 的成员解析沿继承链只向[b]基类[/b]方向走，放到迁移层会让容器层读不到。
const CURRENT_SCHEMA_VERSION: int = 4


## 构造完整存档容器——[b]存档文件顶层形状的唯一构建入口[/b]。
##
## [b]参数[/b]: [param serialized_gsm] GSM.serialize() 的输出（Dictionary）。[br]
## [b]参数[/b]: [param meta] 展示用元信息——缺失字段以默认值填充。[br]
## [b]返回[/b]: 完整存档容器 Dictionary，含 schema_version / version / timestamp /
##          playtime_seconds / meta / game_state / complete。[br]
## [br][b]⚠️ ADR-0002 规则[/b]: [code]version[/code] 为语义化版本字符串——仅用于
## 面向用户的展示，不参与任何迁移逻辑判断。[br][b]playtime_seconds[/b] 从
## [code]serialized_gsm.session.playtime_seconds[/code] 提取，缺失时默认 0。[br]
## [br][b]该字段真的会写进去了[/b]：[code]session[/code] 自本轮起在
## [constant GameStateManager.PERSISTABLE_DOMAINS] 内，其 [code]playtime_seconds[/code]
## 由 [code]SessionClock[/code] 每帧累加——此前这一句读的一直是空（域不在持久表里，
## [code]serialize()[/code] 从不输出它），故容器里恒为 0、主菜单摘要行永远是
## 「游玩 0小时0分」。[br]
## [br][b]展示口径归 [code]SessionClockRules.format_duration[/code][/b]：本方法只负责把
## 秒数原样放进容器，取整与「不到 1 分钟」的中文写法在那一处（不在此二次加工）。
func _build_save_container(serialized_gsm: Dictionary, meta: Dictionary) -> Dictionary:
	return {
		"schema_version": CURRENT_SCHEMA_VERSION,
		"version": "1.0.0",
		"timestamp": Time.get_datetime_string_from_system(true),  # true = UTC
		"playtime_seconds": int(serialized_gsm.get("session", {}).get("playtime_seconds", 0)),
		"meta": {
			"player_name": meta.get("player_name", ""),
			"realm": meta.get("realm", "炼气"),
			"chapter": meta.get("chapter", 1),
			"map_name": meta.get("map_name", ""),
			"deck_size": meta.get("deck_size", 0),
			"current_scene": meta.get("current_scene", "main_menu"),
			"current_scene_id": meta.get("current_scene_id", 0),
		},
		"game_state": serialized_gsm,
		"complete": true,
	}


## 完整性校验——检查存档容器是否包含全部必填字段和完整性标记。
##
## 三项检查（短路求值）：[br]
## 1. [code]schema_version[/code] 字段必须存在。[br]
## 2. [code]game_state[/code] 字段必须存在且类型为 Dictionary。[br]
## 3. [code]complete[/code] 标记必须存在且为 true——纵深防御，原子 rename 的主策略
##    补充。[br]
## [br][b]返回[/b]: 全部检查通过时返回 true，任一项失败时调用 [method push_error] 并返回 false。
func _validate_save_data(data: Dictionary) -> bool:
	# 1. 必须字段存在性
	if not data.has("schema_version"):
		push_error("Save file missing 'schema_version' field")
		return false
	if not data.has("game_state") or typeof(data["game_state"]) != TYPE_DICTIONARY:
		push_error("Save file missing or invalid 'game_state' field")
		return false

	# 2. 完整性标记（纵深防御——原子 rename 为主策略）
	if not data.has("complete") or data["complete"] != true:
		push_error("Save file missing 'complete' marker — possible write interruption or manual corruption")
		return false

	return true


## 版本校验——检查存档的 schema_version 是否与当前版本兼容。
##
## [b]规则[/b]: [code]save_schema > CURRENT_SCHEMA_VERSION[/code] →
## 返回 VERSION_MISMATCH 错误。[br]
## [code]save_schema <= CURRENT_SCHEMA_VERSION[/code] → 返回 ok。[br]
## [br][b]⚠️ ADR-0002 禁止[/b]: 绝不让 [code]schema_version > CURRENT[/code] 的存档
## 静默加载——必须拒绝并返回 VERSION_MISMATCH。[br]
## [br][b]注意[/b]: [method _migrate_if_needed] 中也包含 VERSION_MISMATCH 检查——
## 作为纵深防御的第二道防线，以防调用方绕过本方法直接调用迁移入口。
## 两处的错误字典结构必须保持同步。修改一处时务必同步另一处。[br]
## [br][b]返回[/b]: [code]{"ok": true}[/code] 或
## [code]{"error": "VERSION_MISMATCH", "save_schema": int, "current_schema": int}[/code]
func _validate_version(data: Dictionary) -> Dictionary:
	var save_schema: int = data.get("schema_version", 0)
	if save_schema > CURRENT_SCHEMA_VERSION:
		return {
			"error": "VERSION_MISMATCH",
			"save_schema": save_schema,
			"current_schema": CURRENT_SCHEMA_VERSION
		}
	return {"ok": true}


## 完整读取管线——委托 [method _parse_json_file] 处理 JSON 解析，追加 [method _validate_save_data]。
##
## 仅读取规范文件名（忽略同目录下的 .tmp 和 .bak 文件）。[br]
## 读取流程（3 阶段）：[br]
## 1. [method _parse_json_file] → 存在性检查 + 读取 + JSON 解析 + 类型检查。[br]
## 2. [method _validate_save_data] → 完整性校验。[br]
## 3. 校验通过 → 返回存档数据。[br]
## [br]
## [b]参数[/b]: [param path] 规范文件完整路径——调用方负责构造正确路径。[br]
## [b]返回[/b]: [code]{"result": LoadResult, "data": Dictionary}[/code]。[br]
## [param result] 为 [enum LoadResult.SUCCESS] 时 [param data] 包含存档容器全部字段。
func _atomic_read(path: String) -> Dictionary:
	# 阶段 1：委托 _parse_json_file 处理读取 + JSON 解析（复用 Story 001 管线）
	var parsed := _parse_json_file(path)
	if parsed["result"] != LoadResult.SUCCESS:
		return parsed

	# 阶段 2：完整性校验
	if not _validate_save_data(parsed["data"]):
		return {"result": LoadResult.CORRUPTED, "data": {}}

	# 阶段 3：返回校验通过的存档数据
	return parsed
