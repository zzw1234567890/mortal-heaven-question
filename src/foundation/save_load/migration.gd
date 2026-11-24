extends "res://src/foundation/save_load/container.gd"
## SaveLoadSystem 迁移层 —— [b]迁移注册表与逐级迁移链[/b]。[br]
## [br][b]本层职责[/b]：把一份低版本存档逐级升到 [constant CURRENT_SCHEMA_VERSION]——
## 注册表（[member MIGRATIONS] 覆盖层 / [member DEFAULT_MIGRATIONS] 生产链）、
## 查找口径（[method _migration_for]）、三个已登记的迁移函数、以及链的驱动器
## （[method _migrate_if_needed]）。[br]
## [br][b]为什么单独一层[/b]：迁移只在 schema_version 递增时变，与「容器长什么样」
## （容器层，每轮都可能增删字段）和「怎么安全落盘」（原子 IO 层）是三个变更节奏不同的事。
## 原文件 1027 行严重超 300 行软上限（.claude/docs/coding-standards.md）。[br]
## [br][b]⚠️ ADR-0002 规则[/b]：迁移函数必须是纯函数 [code]Dictionary → Dictionary[/code]——
## 不访问 GSM、不读写磁盘、无副作用。[br]
## [br][b]成员名逐字保留[/b]：Story 005 的验收（AC-001 ~ AC-011）直接写在
## [member MIGRATIONS] / [member DEFAULT_MIGRATIONS] / [method _migrate_if_needed] /
## [method _migrate_v1_to_v2] 上，且用例用 [code]sls.MIGRATIONS[0] = f[/code] 注入、
## [code]sls.MIGRATIONS.clear()[/code] 清空。探针实测 [code]static var[/code] 经派生脚本类
## 与实例访问[b]解析到同一份存储[/b]，故这些写法照旧有效。[br]
## [br]来源: ADR-0002 §迁移链纯函数契约、design/gdd/game-state-manager.md §存档。

## 迁移函数注册表（[b]覆盖层[/b]）——键为迁移前的 schema_version，值为迁移函数
## （纯函数 Dictionary → Dictionary）。[br]
## [br]每个函数是纯函数：接收完整存档容器，返回修改后的存档容器。[br]
## [br][b]为什么与 [constant DEFAULT_MIGRATIONS] 分开[/b]：本表是
## [code]static var[/code]——测试可以注入自己的迁移函数（[code]MIGRATIONS[0] = f[/code]），
## 也可以 [code]clear()[/code] 掉它来构造「迁移链缺失」场景。既有测试正是这么做的，
## 而它们在 [code]after_each[/code] 里 [code]clear()[/code] 之后不会（也无法）
## 把生产迁移装回去——若生产链也放在这里，测试执行顺序一变就会让后续用例
## 读 v1 档时报 [code]MIGRATION_MISSING[/code]。故：生产链常驻
## [constant DEFAULT_MIGRATIONS]，本表只在[b]同名版本[/b]上覆盖它。[br]
## [br][b]查找顺序[/b]：本表 > [constant DEFAULT_MIGRATIONS]（见 [method _migration_for]）。
static var MIGRATIONS: Dictionary[int, Callable] = {}

## 生产迁移链——随版本发布固定，不受测试注入 / [code]clear()[/code] 影响。[br]
## [br]已登记：[br]
## [code]  1: _migrate_v1_to_v2,[/code]  # 探索域新增 events_shown[br]
## [code]  2: _migrate_v2_to_v3,[/code]  # GSM 新增 battle_resume 段[br]
## [code]  3: _migrate_v3_to_v4,[/code]  # 续战段新增 cards / debuffs[br]
static var DEFAULT_MIGRATIONS: Dictionary[int, Callable] = {
	1: _migrate_v1_to_v2,
	2: _migrate_v2_to_v3,
	3: _migrate_v3_to_v4,
}


## 取某个起始版本的迁移函数——覆盖层优先，其次生产链（无则返回空 Callable）。[br]
## [br][param p_from] 迁移前的 schema_version。[br]
static func _migration_for(p_from: int) -> Callable:
	if MIGRATIONS.has(p_from):
		return MIGRATIONS[p_from]
	if DEFAULT_MIGRATIONS.has(p_from):
		return DEFAULT_MIGRATIONS[p_from]
	return Callable()


## v1 → v2 迁移——探索域补齐 [code]events_shown[/code]（纯函数，无副作用）。[br]
## [br][b]补的是默认值，不是数据[/b]：v1 档里每张图的 [code]map_states[/code] 条目
## 没有 [code]events_shown[/code] 键，读侧按「未弹过」处理——功能上已经向后兼容，
## 这里显式补键是为了让存档形状与 v2 一致（下一次写盘就是完整 v2 形态，不必让
## 每张老图都留着一个「靠 .get 缺省」的键）。[br]
## [br][b]不碰任何已有键[/b]：通关记录 / 已访问节点 / 已采槽位 / 灵泉次数原样透传
## ——迁移不得改变玩家已有的进度（旧档不许丢档）。[br]
## [br][b]容错[/b]：域缺失 / 非字典 / 图条目非字典一律跳过（不是崩溃，也不是臆造）。[br]
## [br]来源: ADR-0002 §迁移链纯函数契约、本轮「事件已弹进存档」任务。
static func _migrate_v1_to_v2(data: Dictionary) -> Dictionary:
	var game_state: Variant = data.get("game_state", null)
	if not (game_state is Dictionary):
		return data
	var exploration: Variant = (game_state as Dictionary).get("exploration", null)
	if not (exploration is Dictionary):
		return data
	var map_states: Variant = (exploration as Dictionary).get("map_states", null)
	if not (map_states is Dictionary):
		return data
	for map_id: Variant in (map_states as Dictionary).keys():
		var state: Variant = (map_states as Dictionary)[map_id]
		if not (state is Dictionary):
			continue
		if not (state as Dictionary).has("events_shown"):
			(state as Dictionary)["events_shown"] = []
	return data


## v2 → v3 迁移——GSM 补 [code]battle_resume[/code] 段（纯函数，无副作用）。[br]
## [br][b]补的是默认值，不是数据[/b]：v2 档没有这个段，读侧按
## [code]{}[/code]（没有进行中的战斗）处理——功能上已经向后兼容，这里显式补键
## 是为了让存档形状与 v3 一致（写完一次就是完整 v3 形态）。[br]
## [br][b]空字典不是「丢了一条命」[/b]：它准确表示「这份档不是在战斗中存的」。
## 老档玩家读档后回到探索地图，与升级前完全一致（旧档不许丢档）。[br]
## [br][b]不碰任何已有键[/b]：角色 / 卡组 / 探索 / 叙事各域原样透传。[br]
## [br][b]容错[/b]：域缺失 / 非字典一律跳过（不是崩溃，也不是臆造）。[br]
## [br][b]已有段不覆盖[/b]：手动构造的 v2 容器若已带 [code]battle_resume[/code]
## （测试或提前写盘），迁移保持它——迁移的职责是补缺，不是重置。[br]
## [br]来源: ADR-0002 §迁移链纯函数契约、本轮「战斗中存档 → 读档回到战斗」。
static func _migrate_v2_to_v3(data: Dictionary) -> Dictionary:
	var game_state: Variant = data.get("game_state", null)
	if not (game_state is Dictionary):
		return data
	if not (game_state as Dictionary).has("battle_resume"):
		(game_state as Dictionary)["battle_resume"] = {}
	return data


## v3 → v4 迁移——续战段补 [code]cards[/code] / [code]debuffs[/code] 两个形状
## （纯函数，无副作用）。[br]
## [br][b]只补「正在进行的」战斗段[/b]：空段（[code]{}[/code]）的含义是
## 「这份档不是在战斗中存的」，往里塞两个空形状会把「没有战斗」变成一个带内容的段，
## 读侧与既有断言都按空字典判「没有进行中的战斗」。故先确认这个段是战斗中的那份。[br]
## [br][b]补的是空形状，不是数据[/b]：空 = 「这份档没存过牌面 / debuff」，读侧
## （[code]battle_resume_cards.has_state[/code] 等）据此走自然发牌那条老路——
## 手牌按开局手牌重抽、debuff 为空，与升级前的行为逐位一致（旧档不许丢档）。[br]
## [br][b]已有键不覆盖[/b]：手改档 / 提前写盘若已带这两个键，迁移保持它——
## 迁移的职责是补缺，不是重置。[br]
## [br][b]形状的真理来源在特征层[/b]（[code]battle_resume_cards.gd[/code] /
## [code]battle_resume_debuffs.gd[/code]）：本层只写字面量，因为 Foundation 不得
## 依赖 Feature（分层方向：foundation ← feature）。两处一旦漂移，症状是
## [code]has_state[/code] 判不出「没存过」——本迁移只写空值，漂移面为零。[br]
## [br]来源: ADR-0002 §迁移链纯函数契约、本轮「牌面与 debuff 进存档」。
static func _migrate_v3_to_v4(data: Dictionary) -> Dictionary:
	var game_state: Variant = data.get("game_state", null)
	if not (game_state is Dictionary):
		return data
	var resume: Variant = (game_state as Dictionary).get("battle_resume", null)
	# 空段 / 缺段 / 非字典一律不动——见「只补正在进行的战斗段」
	if not (resume is Dictionary) or (resume as Dictionary).is_empty():
		return data
	if not (resume as Dictionary).has("cards"):
		(resume as Dictionary)["cards"] = {}
	if not (resume as Dictionary).has("debuffs"):
		(resume as Dictionary)["debuffs"] = []
	return data


## 存档迁移入口——基于 [member CURRENT_SCHEMA_VERSION] 和 [member MIGRATIONS] 注册表
## 执行逐级迁移链。
##
## 迁移规则（ADR-0002）：[br]
## - [code]save_schema == CURRENT[/code] → 直接返回 data（无迁移）。[br]
## - [code]save_schema < CURRENT[/code] → 从 save_schema 开始逐级执行迁移函数，每步后
##   [code]data["schema_version"][/code] 递增 1，直到等于 CURRENT。[br]
## - [code]save_schema > CURRENT[/code] → 返回 [code]{"error": "VERSION_MISMATCH", ...}[/code]。[br]
## - 迁移链中缺少某版本对应函数 → 返回 [code]{"error": "MIGRATION_MISSING", ...}[/code]。[br]
## - data 中无 [code]schema_version[/code] 字段 → [code]save_schema = 0[/code]（默认值）。[br]
## [br]
## [b]参数[/b]: [param data] 已读入并通过校验的存档容器。[br]
## [b]返回[/b]: 迁移后的存档容器——或包含 error 键的错误字典。[br]
## [br][b]⚠️ ADR-0002 规则[/b]: 迁移函数必须是纯函数 [code]Dictionary → Dictionary[/code]——
## 不访问 GSM、不读写磁盘、无副作用。
func _migrate_if_needed(data: Dictionary) -> Dictionary:
	var save_schema: int = data.get("schema_version", 0)

	# AC-006：版本高于当前——拒绝加载
	if save_schema > CURRENT_SCHEMA_VERSION:
		return {
			"error": "VERSION_MISMATCH",
			"save_schema": save_schema,
			"current_schema": CURRENT_SCHEMA_VERSION
		}

	# AC-003/AC-004：逐级执行迁移链
	while save_schema < CURRENT_SCHEMA_VERSION:
		var migrate: Callable = _migration_for(save_schema)
		if not migrate.is_valid():
			# AC-005：迁移链中缺少对应版本函数
			return {
				"error": "MIGRATION_MISSING",
				"from": save_schema
			}
		data = migrate.call(data)
		assert(typeof(data) == TYPE_DICTIONARY, "迁移函数 %d 必须返回 Dictionary" % save_schema)
		save_schema += 1
		data["schema_version"] = save_schema

	return data
