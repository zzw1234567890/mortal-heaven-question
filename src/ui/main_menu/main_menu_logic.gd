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

## 无存档时摘要返回空串（story AC：无存档时摘要行隐藏——UI 以空串判定隐藏）。
const SUMMARY_EMPTY: String = ""

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
