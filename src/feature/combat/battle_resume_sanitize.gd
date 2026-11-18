extends RefCounted
## BattleResumeSanitize —— 把「这场仗的开战配置」折叠成 JSON 安全形态（纯函数）。[br]
## [br][b]为什么单独一处[/b]：[code]battle_resume_payload.gd[/code] 肩负「续战段存什么、
## 怎么解释」这一整块，已逼近 300 行软上限
## （.claude/docs/coding-standards.md）；而「哪些键能进存档、对象怎么丢」与「进度 /
## 名册的形状」是两件事——前者只关心[b]类型安全[/b]，后者关心[b]语义[/b]。[br]
## [br][b]为什么要白名单而不是整份配置照搬[/b]：开战配置里带
## [code]enemy_roster[/code]（[code]EnemyBattleState[/code] 对象）——对象过不了存档的
## JSON 兼容校验（[code]SaveLoadSystem._is_json_compatible[/code]），整份存档会被判
## [code]VALIDATION_ERROR[/code]，连探索进度一起写不进去。故按白名单逐键折叠，
## 且折叠要发生在[b]组装阶段[/b]（一路走到校验处才发现，坏的是整份档）。[br]
## [br][b]为什么 StringName 落 String[/b]：存档往返会把 StringName 变成 String；写侧存
## StringName、读侧还原成 String 会让「存前与读后逐项相等」这条断言永远不成立。[br]
## [br]来源: ADR-0002 §JSON 容器、ADR-0017 §EnemyFactory、
## [code]battle_resume_payload.gd[/code] §「为什么不存整套配置」。


## 按白名单折叠开战配置（非字典 / 缺键一律跳过——不臆造）。[br]
## [br][param p_config] 本场 [code]battle_start[/code] 的配置副本。[br]
## [param p_whitelist] 允许进存档的键（真理来源留在载荷模块，本函数只做折叠）。
static func config(p_config: Variant, p_whitelist: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	if not (p_config is Dictionary):
		return out
	var source: Dictionary = p_config
	for key: String in p_whitelist:
		if not source.has(key):
			continue
		out[key] = value(source[key])
	return out


## 递归折叠为 JSON 安全形态（StringName → String；对象 / 不可表示类型丢弃）。[br]
## [br][b]与 [code]GsmSaveTypes.to_save_safe[/code] 的分工[/b]：那一份在写盘时统一归一整份
## 载荷，但[b]不拒绝[/b]对象（拒绝归 [code]SaveLoadSystem._is_json_compatible[/code]）
## ——本函数在组装阶段就把对象丢掉。[br]
## [br][b]返回[/b]：折叠后的值；对象 / 资源等不可表示类型返回 [code]null[/code]
## （调用方据此把该条目整个丢掉，而不是留一个占位）。
static func value(p_value: Variant) -> Variant:
	match typeof(p_value):
		TYPE_STRING_NAME:
			return String(p_value)
		TYPE_ARRAY:
			var out_array: Array = []
			for item: Variant in (p_value as Array):
				var clean: Variant = value(item)
				if clean != null:
					out_array.append(clean)
			return out_array
		TYPE_DICTIONARY:
			var out_dict: Dictionary = {}
			for raw_key: Variant in (p_value as Dictionary).keys():
				var clean: Variant = value((p_value as Dictionary)[raw_key])
				if clean != null:
					out_dict[str(raw_key)] = clean
			return out_dict
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return p_value
		_:
			return null
