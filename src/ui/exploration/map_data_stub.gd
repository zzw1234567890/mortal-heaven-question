class_name MapDataStub
## MapDataStub —— 地图选择界面的 stub 地图载荷数据源（exploration-ui Story S16-2）。
##
## [b]角色[/b]：承载地图选择界面的临时 stub 载荷——探索系统
## [code]get_map_list()[/code] 载荷扩展（reentry_base/reentry_multiplier/
## reentry_total/can_reenter/is_permanent_free）尚未实现（Feature 层依赖缺口，
## story-002 Dependencies 已裁决「stub 先行」）。[br]
## [br][b]生命周期[/b]：Feature 层补齐后 [method MapSelectScreen._get_map_list]
## 返回真实载荷，本文件整体删除——stub 数据与 UI 逻辑分离，删除不牵连 UI。[br]
## [br][b]契约[/b]：单条目 Dictionary 字段与 story-002 stub 载荷契约一致——
## Feature 层补齐时必须沿用同一契约（UI 零数值计算：reentry_total 为总额、
## can_reenter 为灵石预判，UI 只读展示不拆算）。
##
## 来源: ADR-0014 §get_map_list 契约、story-002-map-select-screen.md stub 契约。

## 单张地图条目契约字段（供 Feature 层对齐）：
##   map_id: StringName   —— 地图 ID
##   name: String         —— 显示名（中文）
##   difficulty: int      —— 1-4（低/中/高/极高 → ⭐数量）
##   realm_requirement: int —— 解锁所需境界等级
##   is_cleared: bool     —— 是否已通关
##   is_unlocked: bool    —— 是否已解锁
##   reentry_allowed: bool —— 是否可重入（苍玄古战场=false）
##   reentry_base: int    —— 重入基础价（明细展示用）
##   reentry_multiplier: int —— 重入次数倍率（明细展示用）
##   reentry_total: int   —— 重入总费用（Feature 层算好，UI 不拆算）
##   can_reenter: bool    —— 灵石是否充足（Feature 层预判，UI 仅渲染）
##   is_permanent_free: bool —— 永久免费地图（重入 0 费）


## 返回 stub 地图列表——覆盖三类卡片 + 苍玄古战场不可重入 + 未解锁境界不足。
static func stub_map_list() -> Array[Dictionary]:
	return [
		{"map_id": &"qing_yun_jian_zong", "name": "青云剑宗", "difficulty": 1,
			"realm_requirement": 1, "is_cleared": true, "is_unlocked": true,
			"reentry_allowed": true, "reentry_base": 30, "reentry_multiplier": 1,
			"reentry_total": 30, "can_reenter": true, "is_permanent_free": true},
		{"map_id": &"xue_yuan_mi_jing", "name": "血渊秘境", "difficulty": 2,
			"realm_requirement": 1, "is_cleared": true, "is_unlocked": true,
			"reentry_allowed": true, "reentry_base": 60, "reentry_multiplier": 1,
			"reentry_total": 60, "can_reenter": true, "is_permanent_free": false},
		{"map_id": &"yun_lan_cheng", "name": "云澜城", "difficulty": 3,
			"realm_requirement": 2, "is_cleared": false, "is_unlocked": true,
			"reentry_allowed": false, "reentry_base": 0, "reentry_multiplier": 0,
			"reentry_total": 0, "can_reenter": false, "is_permanent_free": false},
		{"map_id": &"dan_xia_gu", "name": "丹霞谷", "difficulty": 4,
			"realm_requirement": 2, "is_cleared": false, "is_unlocked": true,
			"reentry_allowed": false, "reentry_base": 0, "reentry_multiplier": 0,
			"reentry_total": 0, "can_reenter": false, "is_permanent_free": false},
		{"map_id": &"cang_xuan_zheng_dao_meng", "name": "苍玄正道盟", "difficulty": 1,
			"realm_requirement": 2, "is_cleared": false, "is_unlocked": true,
			"reentry_allowed": false, "reentry_base": 0, "reentry_multiplier": 0,
			"reentry_total": 0, "can_reenter": false, "is_permanent_free": false},
		{"map_id": &"cang_xuan_gu_zhan_chang", "name": "苍玄古战场", "difficulty": 2,
			"realm_requirement": 2, "is_cleared": true, "is_unlocked": true,
			"reentry_allowed": false, "reentry_base": 0, "reentry_multiplier": 0,
			"reentry_total": 0, "can_reenter": false, "is_permanent_free": false},
		{"map_id": &"xi_yu_gu_lin", "name": "西域古林", "difficulty": 3,
			"realm_requirement": 3, "is_cleared": false, "is_unlocked": false,
			"reentry_allowed": false, "reentry_base": 0, "reentry_multiplier": 0,
			"reentry_total": 0, "can_reenter": false, "is_permanent_free": false},
		{"map_id": &"gui_xu_fu_yun_lu", "name": "归墟·浮云陆", "difficulty": 4,
			"realm_requirement": 5, "is_cleared": false, "is_unlocked": false,
			"reentry_allowed": false, "reentry_base": 0, "reentry_multiplier": 0,
			"reentry_total": 0, "can_reenter": false, "is_permanent_free": false},
	]
