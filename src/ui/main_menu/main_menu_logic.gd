class_name MainMenuLogic
extends RefCounted
## MainMenuLogic —— 主菜单存档判定 Logic 内核（main-menu Story 001）。
##
## [b]纯函数静态类[/b]（ADR-0031 + control-manifest Presentation 必需模式——
## 「存档存在性判定提取纯函数」；先例 [CultivationBarState]）：不 extends Node、
## 不访问任何 Autoload、不持有任何状态——全部逻辑在单次静态调用内完成。[br]
## [br][b]数据契约[/b]：入参为 [code]SaveLoadSystem.list_slots()[/code] 返回的
## 槽位元数据数组，每项含 [code]slot_type / slot_id / exists / name / timestamp /
## realm / playtime[/code]（meta.json 槽位条目）。[br]
## [br][b]损坏感知收窄[/b]（QL-STORY-READY 2026-09-19 裁决）：meta 列表无损坏
## 字段——[code]exists == true[/code] 即视为可继续；损坏检测在
## [code]SaveLoadSystem.load_game()[/code] 读档时发生，点击后走损坏路径弹提示。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：UI 节点每次刷新从 SaveLoadSystem
## 读取后调用本内核，不在内核或 UI 缓存列表。
##
## @experimental
## 来源: ADR-0031、control-manifest §Presentation、design/gdd/main-menu-system.md
## §边缘情况、story-001-main-menu-scene.md（2026-09-19 裁决）。

## === 数据驱动配置 =============================================================

## 时间戳相同槽位的 tie-break——升序取首个（语义：低槽序号优先）。[br]
## [code]SLOT_ORDER[/code] 为槽位排序权重（数值小者优先）：AUTOSAVE=0 为玩家
## 最近一局的固定自动槽，权重低于 MANUAL（1-3）。等权重（两个 MANUAL 同时间戳）
## 时按 [code]slot_id[/code] 升序——「槽 1 优先于槽 2」（story Implementation
## Notes 裁决：tie-break 定义为存档槽序号升序）。调整优先级只改此表。
const SLOT_ORDER: Dictionary = {
	0: 0,  # SaveSlotType.AUTOSAVE —— 权重 0（自动槽最优先）
	1: 1,  # SaveSlotType.MANUAL —— 权重 = slot_id（1-3 升序）
	2: 9,  # SaveSlotType.SNAPSHOT —— 权重 9（战前快照殿后）
}

## 存档摘要文本模板（GDD 边界澄清 2026-09-19——realm + playtime 均取自
## meta.json；chapter 不在 meta.json，本 MVP 不引入）。[br]
## 项目暂无本地化系统——先例 [CultivationBarState] LABEL_* 同源豁免注记，
## 本地化入库后替换为本地化键。
const SUMMARY_TEMPLATE: String = "上次：%s · 游玩 %s"

## 「读档」界面列出的槽位（见 [method loadable_slots]）。[br]
## [br][b]为什么不遍历 [code]list_slots()[/code][/b]：那份列表是给判定用的（含战前
## 快照槽 [code]snapshot_0[/code]），展示清单是 UI 的决定——混在一起后，往
## [code]list_slots()[/code] 里加一个槽位就会悄悄改变玩家看到的列表（多出一格
## 「预战斗快照」），而战前快照是战斗管线的中间产物，不该让玩家从主菜单读。
const LOADABLE_SLOT_SPECS: Array[Dictionary] = [
	{"slot_type": 0, "slot_id": 0},  # SaveSlotType.AUTOSAVE
	{"slot_type": 1, "slot_id": 1},  # SaveSlotType.MANUAL 1
	{"slot_type": 1, "slot_id": 2},  # SaveSlotType.MANUAL 2
	{"slot_type": 1, "slot_id": 3},  # SaveSlotType.MANUAL 3
]

## 无存档时摘要返回空串（story AC：无存档时摘要行隐藏——UI 以空串判定隐藏）。
const SUMMARY_EMPTY: String = ""

## 「读档」列表里每种槽位的中文名（本地化豁免注记同 [constant SUMMARY_TEMPLATE]）。[br]
## [br][b]只列玩家能自己选的两种[/b]：自动槽 + 三个手动槽。战前快照
## [code]snapshot_0[/code] 不进列表——它是战斗管线的中间产物，让玩家从主菜单
## 读一份「打之前的状态」既不是存档语义、也会和战斗恢复流程抢同一份文件。
const SLOT_LABEL_AUTOSAVE: String = "自动存档"
const SLOT_LABEL_MANUAL: String = "手动存档 %d"
## 空槽位的后缀（玩家要能一眼看出哪几格还能存）。
const SLOT_EMPTY_SUFFIX: String = "（空）"
## 槽位名与摘要之间的分隔（纯排版，无本地化语义）。
const SLOT_LABEL_SEPARATOR: String = " — "

## 读档列表的槽位清单——顺序即展示顺序：自动槽在前，手动 1-3 依次。[br]
## [br][b]为什么顺序写死而不是遍历 list_slots()[/b]：那份列表是给判定用的（含快照槽
## 与全部已知键），展示顺序是 UI 的决定——两件事混在一起后，往 [code]list_slots()[/code]
## 里加槽位会悄悄改变玩家看到的列表顺序。[br]
## [br][b]返回[/b]：[code]{slot_type, slot_id, exists, label}[/code] 四项的数组，
## [code]label[/code] 已含「存在 → 摘要 / 不存在 → （空）」两种文案。[br]
## [br][b]空状态防御[/b]：同 [method has_continuable_save]——null / 非数组一律按
## 「四个槽位都空」返回，调用方不必先判空。[br]
## [b]来源[/b]: design/gdd/main-menu-system.md（新游戏 / 继续游戏 / 读档三条路径）。
static func loadable_slots(save_meta_list: Variant) -> Array[Dictionary]:
	var by_key: Dictionary = {}
	if save_meta_list is Array:
		for meta in save_meta_list:
			if not (meta is Dictionary):
				continue
			by_key[_meta_key(meta)] = meta

	var out: Array[Dictionary] = []
	for spec: Dictionary in LOADABLE_SLOT_SPECS:
		var slot_type: int = int(spec["slot_type"])
		var slot_id: int = int(spec["slot_id"])
		var meta: Dictionary = by_key.get(_slot_key(slot_type, slot_id), {})
		var exists: bool = bool(meta.get("exists", false))
		var name: String = SLOT_LABEL_AUTOSAVE if slot_type == 0 \
				else SLOT_LABEL_MANUAL % slot_id
		var label: String = name + SLOT_EMPTY_SUFFIX if not exists \
				else name + SLOT_LABEL_SEPARATOR + build_save_summary(meta)
		out.append({
			"slot_type": slot_type,
			"slot_id": slot_id,
			"exists": exists,
			"label": label,
		})
	return out

## === 判定纯函数 ===============================================================

## 存档存在性判定（AC-1 / AC-main-menu-002）。[br]
## [br][param save_meta_list]: [code]list_slots()[/code] 返回的槽位元数据数组。[br]
## [b]返回[/b]: ≥1 槽位 [code]exists == true[/code] → [code]true[/code]；
## 空列表或全部不存在 → [code]false[/code]（continue 按钮灰色不可用）。[br]
## [br][b]空状态防御[/b]：入参为 null（Autoload 缺失时 UI 层回退安全默认）或
## 非数组 → [code]false[/code]——无存档是安全默认态（按钮禁用而非误亮起）。[br]
## [br][b]参数类型注记[/b]：[param save_meta_list] 标 [code]Variant[/code]——
## 显式类型注解满足静态类型强制，同时保留 null 接受性（类型化 [code]Array[/code]
## 拒绝 null 在编译期报错，防御分支不可达；「此参数刻意宽松」由签名表达）。
static func has_continuable_save(save_meta_list: Variant) -> bool:
	if not (save_meta_list is Array) or save_meta_list.is_empty():
		return false
	for meta in save_meta_list:
		if meta is Dictionary and bool(meta.get("exists", false)):
			return true
	return false


## 最近存档选取（AC-2 / AC-main-menu-003）。[br]
## [br]按 [code]timestamp[/code]（ISO-8601 UTC 字符串，[code]Time.
## get_datetime_string_from_system(true)[/code] 产物——字典序即时间序）取最新；
## 时间戳相同 → 按 [constant SLOT_ORDER] 槽序权重升序 tie-break（见常量注释）。[br]
## [br][b]返回[/b]: 最新存在槽位的完整元数据字典（含 slot_type/slot_id 供
## [code]load_game()[/code] 消费）；无可继续存档 → 空字典（调用方守卫——按钮
## disabled 时不可达，防御返回值）。[br]
## [br][b]空状态防御[/b]：null / 空列表 / 全部不存在 → 空字典。[br]
## [br][b]参数类型注记[/b]：同 [method has_continuable_save]——[code]Variant[/code]
## 显式注解，保留 null 接受性。
static func select_latest_save(save_meta_list: Variant) -> Dictionary:
	var latest: Dictionary = {}
	var latest_key: String = ""
	var latest_order: int = -1
	if not (save_meta_list is Array):
		return {}
	for meta in save_meta_list:
		if not (meta is Dictionary) or not bool(meta.get("exists", false)):
			continue
		var ts: String = str(meta.get("timestamp", ""))
		var order: int = _slot_order(meta)
		# 首个候选（latest_order < 0）直接落位；其后：时间戳严格更新替换；
		# 时间戳相同 → 槽序权重升序 tie-break（权重小者优先——显式比较，
		# 不依赖入参遍历顺序；语义见 SLOT_ORDER 常量注释）。
		if latest_order < 0 or ts > latest_key \
				or (ts == latest_key and order < latest_order):
			latest = meta
			latest_key = ts
			latest_order = order
	return latest


## 存档摘要文本组装（story AC / UX 规范第三眼层级）。[br]
## [br][param meta]: 槽位元数据（[code]realm[/code] 境界名 + [code]playtime[/code]
## 游玩秒数，均来自 meta.json）。入参 [code]Variant[/code]——统一宽松策略
## （同 [method has_continuable_save] 注记；空字典走空串分支，防御路径可达）。[br]
## [b]返回[/b]: 「上次：[境界] · 游玩 [时长]」；槽位不存在（[code]exists != true[/code]）
## 或入参无效 → 空串（UI 判空隐藏摘要行）。[br]
## [br]时长格式：秒 → [code]X小时Y分[/code]（向下取整；<1 分钟显示 [code]0小时0分[/code]
## ——首局刚存档的极端场景，语义仍正确）。[br]
## [b]不产生额外 IO[/b]——纯文本组装，境界名原样透传（本地化入库后由调用方
## 先行翻译）。
static func build_save_summary(meta: Variant) -> String:
	# Variant 入参注记：调用方（_refresh_save_state）传入 Logic.select_latest_save
	# 产物（恒为 Dictionary 或空字典）——空字典走 SUMMARY_EMPTY 分支语义等价
	# null 防御，签名统一 Variant 策略（H-2 裁决）。
	if not (meta is Dictionary) or not bool(meta.get("exists", false)):
		return SUMMARY_EMPTY
	var dict_meta: Dictionary = meta
	var realm: String = str(dict_meta.get("realm", ""))
	var playtime_sec: int = int(dict_meta.get("playtime", 0))
	return SUMMARY_TEMPLATE % [realm, _format_playtime(playtime_sec)]


## === 内部辅助 ================================================================

## 槽位键——与 [code]SaveLoadSystem._slot_key[/code] 同一口径
## （[code]"autosave_0"[/code] / [code]"manual_1"[/code] / [code]"snapshot_0"[/code]）。[br]
## [br][b]为什么本地重写一份而不是调系统那边[/b]：本内核是纯静态函数（不访问任何
## Autoload），而 [code]_slot_key[/code] 是实例方法。两侧口径由单测锁定同源——
## 改槽位编号规则时那条用例会先红。
static func _slot_key(p_slot_type: int, p_slot_id: int) -> String:
	match p_slot_type:
		0:
			return "autosave_0"
		1:
			return "manual_%d" % p_slot_id
		2:
			return "snapshot_0"
		_:
			return "unknown"


## 槽位元数据 → 它的键（从 [code]slot_type[/code] / [code]slot_id[/code] 反解）。[br]
## 未知槽位类型也返回一个不会与 [constant LOADABLE_SLOT_SPECS] 撞车的键
## （[code]"unknown_<type>_<id>"[/code]）——查表落空、进不了读档列表，且不会
## 顶掉某个真槽位的条目。
static func _meta_key(meta: Dictionary) -> String:
	var slot_type: int = int(meta.get("slot_type", -1))
	if slot_type < 0 or slot_type > 2:
		return "unknown_%d_%d" % [slot_type, int(meta.get("slot_id", -1))]
	return _slot_key(slot_type, int(meta.get("slot_id", 0)))


## 槽位 tie-break 权重（SLOT_ORDER 表驱动；MANUAL 以 slot_id 内插权重）。
static func _slot_order(meta: Dictionary) -> int:
	var slot_type: int = int(meta.get("slot_type", -1))
	if SLOT_ORDER.has(slot_type):
		if slot_type == 1:  # SaveSlotType.MANUAL——权重 = slot_id（1-3 升序）
			return int(meta.get("slot_id", 0))
		return int(SLOT_ORDER[slot_type])
	return 99  # 未知槽位类型——殿后（防御，不影响语义）


## 游玩秒数 → 「X小时Y分」文本（数据驱动组装，无本地化——同 SUMMARY_TEMPLATE 注记）。
static func _format_playtime(playtime_sec: int) -> String:
	if playtime_sec < 0:
		playtime_sec = 0  # 防御：meta 损坏负值钳 0
	var hours: int = playtime_sec / 3600
	var minutes: int = (playtime_sec % 3600) / 60
	return "%d小时%d分" % [hours, minutes]
