class_name NotificationStack
extends RefCounted
## NotificationStack —— 通知队列 Logic 内核（hud Story 004）。
##
## [b]时间注入模式[/b]（G1 裁决 2026-09-10）：不持有任何节点/Timer——时间推进统一经
## [method advance] 注入（单测直调 advance(3.0)，UI 层 Timer 每 tick 调同一入口；
## 先例 status_effect_system.gd [code]tick_all[/code] 离散步进而非 Timer 驱动）。[br]
## [br][b]接口形状已锁定[/b]（story Implementation Notes 2026-09-10 裁决——不得改
## 签名语义）：[br]
##   - [method push]：入队返回通知 id（递增，首次为 1；普通通知被容量规则拒绝时
##     返回 0）[br]
##   - [method dismiss]：立即移除；false = 不存在或已移除[br]
##   - [method advance]：移除所有已到期通知并返回被移除条目（供 UI 播滑出动画）[br]
##   - [method get_active]：只读快照（每条含 id/type/text/剩余时长/映射元数据）[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2.1）：通知队列为瞬态交互状态（story ADR 摘要
## 明示「可存于 HUD 组件本地，不写回 GSM」）——本类为纯数据结构，不访问任何
## Autoload、不持有节点。[br]
## [br][b]语义来源[/b]：design/gdd/hud-system.md §4 通知类型表（8+1 行——2026-09-10
## 拆分战斗事件两行 + 未知类型安全默认行）+ story 004 G1-G8 裁决。
##
## [br]来源: ADR-0031（Logic 内核模式）、story-004-notification-system.md。

## === 数据驱动配置 =============================================================

## 同时显示上限（GDD §4 规则「通知最多同时显示3条」+ §调优参数表「2~5条」）。
const MAX_ACTIVE: int = 3

## 类型→{时长, 颜色标识, blink, 重要} 映射全值表（G3/G4/G6 裁决 2026-09-10；
## GDD §4 类型表逐行对齐）。[b]color 为 String 标识[/b]（"green"/"gold"/"purple"/
## "red"/"blue"/"white"）——Color 构造在 UI 层完成（ADR-0031 先例：Logic 内核不
## 返回 Color——LingshiFormatter/CultivationBarState 同源）。仅 error 类型
## blink=true；「重要」判定 = 类型属于 system/error（GDD §4 边界澄清 2026-09-07）。
const TYPE_META: Dictionary = {
	"item": {&"duration": 3.0, &"color": "green", &"blink": false, &"important": false},
	"card": {&"duration": 3.0, &"color": "gold", &"blink": false, &"important": false},
	"lingshi": {&"duration": 2.0, &"color": "gold", &"blink": false, &"important": false},
	"cultivation": {&"duration": 2.0, &"color": "purple", &"blink": false, &"important": false},
	"combat_event_offensive": {&"duration": 3.0, &"color": "red", &"blink": false, &"important": false},
	"combat_event_defensive": {&"duration": 3.0, &"color": "blue", &"blink": false, &"important": false},
	"system": {&"duration": 5.0, &"color": "white", &"blink": false, &"important": true},
	"error": {&"duration": 5.0, &"color": "red", &"blink": true, &"important": true},
}

## === 队列状态（瞬态交互状态——ADR-0031 §2.1，不进存档，丢弃即弃）===============

## 活动通知条目数组（入队序）。每条字段：[code]{id, type, text, remaining,
## color, blink, important}[/code]——[code]remaining[/code] 为剩余时长（秒），
## 由 [method advance] 递减。
var _entries: Array = []
## 下一个通知 id 分配器（递增，首次成功 push 返回 1；被拒绝的 push 不消耗 id——
## id 语义为「成功入队的递增序号」，拒绝路径无条目产生）。
var _next_id: int = 1

## === 锁定接口（story G1 裁决——签名语义不得更改）================================

## 入队一条通知。[br]
## [br][param type]: 通知类型（TYPE_META 键；未知类型按系统提示安全默认处理
## + push_warning——G3 裁决）。[br]
## [param text]: 通知文本。[br]
## [br][b]返回[/b]：通知 id（递增，首次为 1）；普通通知被容量规则拒绝时返回 0。[br]
## [br][b]容量规则[/b]（G2 裁决 2026-09-10，锁定）：push 后若队列超
## [constant MAX_ACTIVE] 条，移除[b]除本次 push 外[/b]最早的非重要通知，逐个移除
## 直至回落到上限内（「在下一条普通通知 push 或超时后回落」——移除可能多于一条，
## 如 3 普通+1 重要 = 4 条时下一条普通 push 需移除 2 条旧普通通知方回落到 3）；
## 若不存在可移除项（其余全为重要），丢弃本次 push 的普通通知并返回 id=0。
## [b]重要通知 push 永不丢弃[/b]——允许队列临时超上限。
func push(type: String, text: String) -> int:
	var meta: Dictionary = get_type_meta(type)
	var entry: Dictionary = {
		&"id": _next_id,
		&"type": type,
		&"text": text,
		&"remaining": meta[&"duration"],
		&"color": meta[&"color"],
		&"blink": meta[&"blink"],
		&"important": meta[&"important"],
	}
	_entries.append(entry)
	# G2 容量规则——仅普通通知参与挤出判定（重要通知永不丢弃，临时超上限合法）。
	if not entry[&"important"]:
		while _entries.size() > MAX_ACTIVE:
			var victim_idx: int = _find_earliest_removable(int(entry[&"id"]))
			if victim_idx < 0:
				# 其余全为重要——无可移除项：丢弃本次 push（队列保持原状）。
				_entries.erase(entry)
				return 0
			_entries.remove_at(victim_idx)
	_next_id += 1
	return int(entry[&"id"])


## 立即移除指定通知（玩家点击关闭）。[br]
## [br][param id]: 通知 id（push 返回值）。[br]
## [br][b]返回[/b]：移除成功 true；false = 不存在或已移除（重复 dismiss 不报错）。
func dismiss(id: int) -> bool:
	for i: int in range(_entries.size()):
		if int(_entries[i][&"id"]) == id:
			_entries.remove_at(i)
			return true
	return false


## 推进时间并移除所有已到期通知（时间注入——G1 裁决）。[br]
## [br][param delta_seconds]: 推进的秒数（UI 层 Timer 每 tick 传入间隔；
## 单测注入精确值）。负数防御性钳 0（时间不可倒流）。[br]
## [br][b]返回[/b]：被移除条目数组（入队序，含完整元数据）——供 UI 播放滑出动画
## 与测试断言。[br]
## [br][b]到期边界[/b]（G8 裁决 2026-09-10）：advance 后剩余时长 [b]≤ 0[/b] 即移除
## ——t=duration 恰好到达 → 已移除；duration-0.01 → 仍在队列。
func advance(delta_seconds: float) -> Array:
	var delta: float = maxf(delta_seconds, 0.0)
	var removed: Array = []
	var kept: Array = []
	for entry: Dictionary in _entries:
		var remaining: float = float(entry[&"remaining"]) - delta
		entry[&"remaining"] = remaining
		if remaining <= 0.0:
			removed.append(entry)
		else:
			kept.append(entry)
	_entries = kept
	return removed


## 活动通知只读快照。[br]
## [br][b]返回[/b]：条目字典的 duplicate 数组（入队序）——调用方修改快照不影响
## 内部队列。每条字段见 [member _entries] 头注释。
func get_active() -> Array:
	var snapshot: Array = []
	for entry: Dictionary in _entries:
		snapshot.append(entry.duplicate())
	return snapshot

## === 查询辅助 ==================================================================

## 查询类型映射元数据（AC-6 全值表测试入口）。[br]
## [br][param type]: 通知类型。[br]
## [br][b]返回[/b] [code]{duration: float, color: String, blink: bool,
## important: bool}[/code] 的独立副本（调用方修改不污染常量表）。[br]
## [br][b]未知类型安全默认[/b]（G3 裁决）：按系统提示处理（5s/白/重要）+
## push_warning——不崩溃、不静默吞掉。
static func get_type_meta(type: String) -> Dictionary:
	if TYPE_META.has(type):
		return (TYPE_META[type] as Dictionary).duplicate()
	push_warning("NotificationStack: 未知通知类型 \"%s\"——按系统提示安全默认处理" % type)
	return (TYPE_META[&"system"] as Dictionary).duplicate()

## === 内部辅助 ==================================================================

## 找到[b]除本次 push 外[/b]最早的非重要通知下标（G2 裁决——本次 push 的普通
## 通知自身不可作为挤出候选）。[br]
## [br][b]返回[/b]：候选下标；无候选（其余全为重要）返回 -1。
func _find_earliest_removable(exclude_id: int) -> int:
	for i: int in range(_entries.size()):
		var entry: Dictionary = _entries[i]
		if int(entry[&"id"]) != exclude_id and not entry[&"important"]:
			return i
	return -1
