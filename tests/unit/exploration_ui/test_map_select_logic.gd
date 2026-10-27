extends GutTest
## exploration-ui Story S16-2 单元测试：地图选择界面 Logic 内核纯函数。
##
## 覆盖故事 AC-1/3/4/5/6/7 的 Logic 内核：[br]
##   - should_show_lock：锁定卡判定（缺字段安全默认不锁定）[br]
##   - is_reenterable：重入资格（苍玄古战场 reentry_allowed=false → 无入口）[br]
##   - can_confirm_reentry：重入确认按钮启用态（灵石不足 → false）[br]
##   - unlock_requirement_text：解锁条件悬停文本（需X境界）[br]
##   - entry_action：卡片点击分流决策（含 QA-S16-2-001 苍玄古战场回归）[br]
##
## [b]纯函数直调[/b]：static 函数以 [code]MAP_SCRIPT.func(...)[/code] 直接
## 调用（GUT 直调模式，不实例化场景——S16-1 先例）。class_name 在测试动态
## 加载下不可靠，故 preload 脚本常量。
##
## 来源: story-002-map-select-screen.md QA Test Cases、
## ADR-0031 §2、ADR-0014 §get_map_list 契约、story-002 stub 载荷契约。

const MAP_SCRIPT := preload("res://src/ui/exploration/map_select_screen.gd")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-1/AC-10：should_show_lock 锁定卡判定
# ═══════════════════════════════════════════════════════════════════════════════

func test_should_show_lock_unlocked_entry_returns_false() -> void:
	## AC-1: is_unlocked=true → 不锁定（彩色可点击）
	var entry: Dictionary = {"map_id": &"qing_yun_jian_zong", "is_unlocked": true}
	assert_false(MAP_SCRIPT.should_show_lock(entry), "已解锁地图不应显示锁定")


func test_should_show_lock_locked_entry_returns_true() -> void:
	## AC-1/AC-10: is_unlocked=false → 锁定（灰显+🔒）
	var entry: Dictionary = {"map_id": &"xi_yu_gu_lin", "is_unlocked": false}
	assert_true(MAP_SCRIPT.should_show_lock(entry), "未解锁地图应显示锁定")


func test_should_show_lock_missing_field_defaults_unlocked() -> void:
	## AC-1 Edge: 缺 is_unlocked 字段 → 安全默认 false（.get 默认值 true → 不锁定）
	var entry: Dictionary = {"map_id": &"unknown"}
	assert_false(MAP_SCRIPT.should_show_lock(entry),
			"缺 is_unlocked 字段应安全默认不锁定")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-3/AC-5：is_reenterable 重入资格判定
# ═══════════════════════════════════════════════════════════════════════════════

func test_is_reenterable_cleared_allowed_returns_true() -> void:
	## AC-3: 已通关 + reentry_allowed=true → 可重入（点击弹确认窗）
	var entry: Dictionary = {"map_id": &"xue_yuan_mi_jing", "is_cleared": true,
			"reentry_allowed": true}
	assert_true(MAP_SCRIPT.is_reenterable(entry), "已通关可重入地图应返回 true")


func test_is_reenterable_cang_xuan_gu_zhan_chang_returns_false() -> void:
	## AC-5: 苍玄古战场已通关但 reentry_allowed=false → 不可重入（无重入入口）
	var entry: Dictionary = {"map_id": &"cang_xuan_gu_zhan_chang",
			"is_cleared": true, "reentry_allowed": false}
	assert_false(MAP_SCRIPT.is_reenterable(entry), "苍玄古战场应不可重入")


func test_is_reenterable_uncleared_returns_false() -> void:
	## AC-3 Edge: 未通关地图 → 不可重入（走直接进入路径）
	var entry: Dictionary = {"map_id": &"yun_lan_cheng", "is_cleared": false,
			"reentry_allowed": false}
	assert_false(MAP_SCRIPT.is_reenterable(entry), "未通关地图不应走重入路径")


func test_is_reenterable_missing_fields_defaults_false() -> void:
	## AC-3 Edge: 缺字段 → 安全默认 false
	var entry: Dictionary = {"map_id": &"unknown"}
	assert_false(MAP_SCRIPT.is_reenterable(entry), "缺字段应安全默认不可重入")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-4：can_confirm_reentry 重入确认按钮启用态
# ═══════════════════════════════════════════════════════════════════════════════

func test_can_confirm_reentry_sufficient_returns_true() -> void:
	## AC-4: 可重入 + can_reenter=true（灵石充足）→ 确认按钮可用
	var entry: Dictionary = {"map_id": &"qing_yun_jian_zong", "is_cleared": true,
			"reentry_allowed": true, "can_reenter": true}
	assert_true(MAP_SCRIPT.can_confirm_reentry(entry), "灵石充足应可确认重入")


func test_can_confirm_reentry_insufficient_returns_false() -> void:
	## AC-4: 可重入 + can_reenter=false（灵石不足）→ 按钮灰显不可点
	var entry: Dictionary = {"map_id": &"xue_yuan_mi_jing", "is_cleared": true,
			"reentry_allowed": true, "can_reenter": false}
	assert_false(MAP_SCRIPT.can_confirm_reentry(entry), "灵石不足应禁用确认按钮")


func test_can_confirm_reentry_not_reenterable_returns_false() -> void:
	## AC-4 Edge: 苍玄古战场（不可重入）→ 即便 can_reenter=true 也不可确认
	var entry: Dictionary = {"map_id": &"cang_xuan_gu_zhan_chang",
			"is_cleared": true, "reentry_allowed": false, "can_reenter": true}
	assert_false(MAP_SCRIPT.can_confirm_reentry(entry),
			"不可重入地图即便灵石充足也不可确认")


func test_can_confirm_reentry_missing_fields_defaults_false() -> void:
	## AC-4 Edge: 缺字段 → 安全默认 false
	var entry: Dictionary = {"map_id": &"unknown"}
	assert_false(MAP_SCRIPT.can_confirm_reentry(entry), "缺字段应安全默认不可确认")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-6：unlock_requirement_text 解锁条件悬停文本
# ═══════════════════════════════════════════════════════════════════════════════

func test_unlock_requirement_text_realm_three() -> void:
	## AC-6: 西域古林需金丹（realm_requirement=3）→ 「需3境界」
	var entry: Dictionary = {"map_id": &"xi_yu_gu_lin", "realm_requirement": 3}
	assert_eq(MAP_SCRIPT.unlock_requirement_text(entry), "需3境界",
			"解锁条件文本应为「需3境界」")


func test_unlock_requirement_text_realm_five() -> void:
	## AC-6: 归墟·浮云陆需化神（realm_requirement=5）→ 「需5境界」
	var entry: Dictionary = {"map_id": &"gui_xu_fu_yun_lu", "realm_requirement": 5}
	assert_eq(MAP_SCRIPT.unlock_requirement_text(entry), "需5境界",
			"解锁条件文本应为「需5境界」")


func test_unlock_requirement_text_missing_field_defaults_zero() -> void:
	## AC-6 Edge: 缺 realm_requirement 字段 → 安全默认「需0境界」
	var entry: Dictionary = {"map_id": &"unknown"}
	assert_eq(MAP_SCRIPT.unlock_requirement_text(entry), "需0境界",
			"缺字段应安全默认「需0境界」")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-3/AC-5/AC-7：entry_action 卡片点击分流决策
# ═══════════════════════════════════════════════════════════════════════════════

func test_entry_action_locked_entry_returns_ignore() -> void:
	## AC-1: 锁定卡（未解锁）→ IGNORE（无操作，仅 tooltip）
	var entry: Dictionary = {"map_id": &"xi_yu_gu_lin", "is_unlocked": false}
	assert_eq(MAP_SCRIPT.entry_action(entry), MAP_SCRIPT.EntryAction.IGNORE,
			"锁定卡点击应无操作")


func test_entry_action_cleared_reenterable_returns_reenter() -> void:
	## AC-3: 已通关可重入 → REENTER（弹重入确认窗）
	var entry: Dictionary = {"map_id": &"xue_yuan_mi_jing", "is_cleared": true,
			"is_unlocked": true, "reentry_allowed": true}
	assert_eq(MAP_SCRIPT.entry_action(entry), MAP_SCRIPT.EntryAction.REENTER,
			"已通关可重入卡应弹确认窗")


func test_entry_action_cang_xuan_gu_zhan_chang_returns_ignore() -> void:
	## AC-5 回归（QA-S16-2-001）：苍玄古战场已通关但 reentry_allowed=false →
	## IGNORE（不得落入直接进入分支——缺陷本应被本测试捕获）
	var entry: Dictionary = {"map_id": &"cang_xuan_gu_zhan_chang",
			"is_cleared": true, "is_unlocked": true, "reentry_allowed": false}
	assert_eq(MAP_SCRIPT.entry_action(entry), MAP_SCRIPT.EntryAction.IGNORE,
			"苍玄古战场已通关不可重入应无操作（不可进入）")


func test_entry_action_uncleared_returns_enter() -> void:
	## AC-7: 未通关 + 境界达标（is_unlocked=true）→ ENTER（直接进入 0 灵石）
	var entry: Dictionary = {"map_id": &"yun_lan_cheng", "is_cleared": false,
			"is_unlocked": true}
	assert_eq(MAP_SCRIPT.entry_action(entry), MAP_SCRIPT.EntryAction.ENTER,
			"未通关境界达标卡应直接进入")


func test_entry_action_missing_fields_defaults_enter() -> void:
	## AC-7 Edge: 缺字段（is_unlocked 缺省 true、is_cleared 缺省 false）→ ENTER
	## （安全默认——缺字段视为已解锁未通关，允许进入而非锁死）
	var entry: Dictionary = {"map_id": &"unknown"}
	assert_eq(MAP_SCRIPT.entry_action(entry), MAP_SCRIPT.EntryAction.ENTER,
			"缺字段应安全默认按未通关进入处理")
