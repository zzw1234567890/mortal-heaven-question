extends GutTest
## TD-007（S15-1）: realm_bar.gd 信号接线自动化覆盖——hud 专用 mock GSM 驱动。
##
## 补齐 Story 002 遗留测试缺口（docs/tech-debt-register.md TD-007）：
##   1. batch_updated 四路径过滤（player.realm / player.cultivation /
##      player.max_cultivation / player.is_fallen——命中即刷新，无关路径忽略）
##   2. setup 重入防重复连接（多次 setup 不产生重复订阅）
##   3. G-H1 脉动合成翻转序列（化神期满隐藏 pulsing=true→回落重显→脉动恢复）
##   4. _refresh 幂等（重复信号不重启 Tween/不重复写文本）
##
## 测试策略：hud_mock_gsm（本目录 mocks/）+ realm_bar.setup(gsm, realm_table)
## 依赖注入接口——完全脱离真实 GSM Autoload，信号手动 emit 同步驱动（无帧时序）。
## Story 类型 Integration——此文件为 TD-007 阻塞项。[br]风格先例：
## tests/integration/hud/test_gsm_signal_binding.gd（LingshiDeckBar 同模式）。

const RealmBarScene: PackedScene = preload("res://src/ui/hud/RealmBar.tscn")
const HudMockGsmScript: GDScript = preload("res://tests/integration/hud/mocks/hud_mock_gsm.gd")

## 与 RealmSystem.realm_table 同构的最小注入表（realm_bar.setup 第二参数——
## G2 裁决：境界名静态数据由测试注入，UI 不访问 Autoload）。
const REALM_TABLE: Dictionary = {
	1: {"name": "炼气期"},
	2: {"name": "筑基期"},
	3: {"name": "金丹期"},
	4: {"name": "元婴期"},
	5: {"name": "化神期"},
}

var gsm: Node = null
var bar: Control = null


func before_each() -> void:
	gsm = HudMockGsmScript.new()
	# 化神期满判定基准（SPIRIT_TRANSFORMATION_LEVEL == 5）
	gsm.player.max_cultivation = 100
	bar = RealmBarScene.instantiate()
	add_child(bar)


func after_each() -> void:
	if bar != null and is_instance_valid(bar):
		bar.free()
	bar = null
	if gsm != null and is_instance_valid(gsm):
		gsm.free()
	gsm = null


# ═══════════════════════════════════════════════════════════════════════════════
# 覆盖 1：batch_updated 四路径过滤
# ═══════════════════════════════════════════════════════════════════════════════

func test_batch_path_player_realm_triggers_refresh() -> void:
	## player.realm 路径命中 → 刷新（HIGH-3：realm 与其他路径同帧变更时
	## batch_updated 是唯一刷新入口——此过滤路径必须生效）
	bar.setup(gsm, REALM_TABLE)
	gsm.player.realm = 2
	gsm.player.cultivation = 10
	var label: Label = bar.get_node(^"RealmNameLabel")
	# Act —— 仅发 batch 信号携带 realm 路径（模拟同帧多变更——域信号不发射）
	gsm.batch_updated.emit({"player.realm": {"old": 1, "new": 2}})
	# Assert —— 境界名已按 mock 新值刷新
	assert_eq(str(label.text), "筑基期", "player.realm 路径应触发刷新显示新境界名")


func test_batch_path_cultivation_triggers_fill_update() -> void:
	## player.cultivation 路径命中 → 修为条刷新（以 _last_ratio 数据终态断言——
	## 不断言 Tween 插值中的 size.x，0.3s 过渡未播完时视觉值未到位）
	bar.setup(gsm, REALM_TABLE)
	gsm.player.cultivation = 50
	gsm.batch_updated.emit({"player.cultivation": {"old": 0, "new": 50}})
	assert_almost_eq(float(bar._last_ratio), 0.5, 0.01, "cultivation 路径应触发比例更新至 0.5")


func test_batch_path_max_cultivation_triggers_refresh() -> void:
	## player.max_cultivation 路径命中 → 刷新（上限变化改变比例分母）
	bar.setup(gsm, REALM_TABLE)
	gsm.player.cultivation = 50
	gsm.player.max_cultivation = 200
	gsm.batch_updated.emit({"player.max_cultivation": {"old": 100, "new": 200}})
	assert_almost_eq(float(bar._last_ratio), 0.25, 0.01, "max_cultivation 路径应触发刷新（比例 50/200=0.25）")


func test_batch_path_is_fallen_triggers_flicker() -> void:
	## player.is_fallen 路径命中 → 落难闪烁接线（G1 前置接线——写入端归
	## 后续 story，此处验证消费端过滤路径）
	bar.setup(gsm, REALM_TABLE)
	gsm.player.is_fallen = true
	gsm.batch_updated.emit({"player.is_fallen": {"old": false, "new": true}})
	# 落难态激活——_last_fallen 翻转为 true（合成值 is_fallen and show_bar）
	assert_true(bool(bar._last_fallen), "is_fallen 路径应触发落难闪烁接线")
	# label 切换为「炼气·落难」（CultivationBarState.LABEL_FALLEN）
	var label: Label = bar.get_node(^"RealmNameLabel")
	assert_eq(str(label.text), "炼气·落难", "落难态 label 应为 LABEL_FALLEN")


func test_batch_path_irrelevant_ignored() -> void:
	## 无关路径（deck/资源等）→ 忽略不刷新（过滤的区分性半边）
	bar.setup(gsm, REALM_TABLE)
	gsm.player.realm = 2
	gsm.player.cultivation = 50
	gsm.batch_updated.emit({"deck.current_deck": {"old": [], "new": [1, 2]}})
	# _refresh 未被调用——_last_ratio 保持首刷的 0
	assert_almost_eq(float(bar._last_ratio), 0.0, 0.001, "无关路径不应触发刷新")


# ═══════════════════════════════════════════════════════════════════════════════
# 覆盖 2：setup 重入防重复连接
# ═══════════════════════════════════════════════════════════════════════════════

func test_setup_reentrant_no_duplicate_connections() -> void:
	## 多次 setup 不产生重复订阅——连接计数直接断言（域信号路径的等价验证，
	## 见 test_setup_reentrant_connection_count）
	bar.setup(gsm, REALM_TABLE)
	bar.setup(gsm, REALM_TABLE)
	bar.setup(gsm, REALM_TABLE)
	# _connect_once 守卫——三信号各恰好 1 条连接
	for sig_name: StringName in [&"realm_changed", &"cultivation_changed", &"batch_updated"]:
		var s: Signal = gsm.get(sig_name)
		assert_eq(s.get_connections().size(), 1,
			"三次 setup 后 %s 应恰好 1 条连接（无重复订阅）" % sig_name)


func test_setup_reentrant_connection_count() -> void:
	## 连接计数的直接断言——三信号各恰好 1 条连接
	bar.setup(gsm, REALM_TABLE)
	bar.setup(gsm, REALM_TABLE)
	for sig_name: StringName in [&"realm_changed", &"cultivation_changed", &"batch_updated"]:
		var s: Signal = gsm.get(sig_name)
		assert_eq(s.get_connections().size(), 1,
			"多次 setup 后 %s 应恰好 1 条连接" % sig_name)


# ═══════════════════════════════════════════════════════════════════════════════
# 覆盖 3：G-H1 脉动合成翻转序列
# ═══════════════════════════════════════════════════════════════════════════════

func test_pulse_composite_flip_spirit_full_then_refall() -> void:
	## G-H1 序列（code-review HIGH-1 修复回归）：化神期满隐藏（pulsing=true 但
	## show_bar=false）→ 修为回落重显进度条 → 脉动恢复。[br]合成值
	## [code]pulsing and show_bar[/code] 必须翻转——纯 pulsing 在隐藏期间
	## 保持 true，重显时若检测纯值会不翻转导致永无脉动。
	# Arrange —— 化神期满：realm=5、修为满值（ratio 1.0 → pulsing=true）
	gsm.player.realm = 5
	gsm.player.cultivation = 100
	bar.setup(gsm, REALM_TABLE)
	# 化神期满 show_bar=false 使合成脉动 false（纯 pulsing 仍 true——
	## HIGH-1 场景正是这一「pulsing=true 但合成 false」的窗口）
	assert_false(bool(bar._last_pulsing), "前置：化神期满合成脉动应为 false（show_bar=false）")
	assert_false(bar.get_node(^"BarFill").visible, "前置：化神期满进度条应隐藏")
	# Act —— 修为回落至 95%（realm=5 仍非满值 → show_bar 恢复 + ratio≥90% 脉动）
	gsm.player.cultivation = 95
	gsm.batch_updated.emit({"player.cultivation": {"old": 100, "new": 95}})
	# Assert —— 重显 + 脉动恢复（合成值翻转：false→true 重建 Tween）
	assert_true(bar.get_node(^"BarFill").visible, "回落后进度条应重显")
	assert_true(bool(bar._last_pulsing), "回落重显后脉动应恢复（合成翻转——HIGH-1 回归）")
	assert_ne(bar._pulse_tween, null, "脉动 Tween 应重建（合成值翻转触发）")


# ═══════════════════════════════════════════════════════════════════════════════
# 覆盖 4：_refresh 幂等（双发射重复触发无操作）
# ═══════════════════════════════════════════════════════════════════════════════

func test_refresh_idempotent_duplicate_signal_no_restart() -> void:
	## cultivation_changed 与 batch_updated 对同一变更双发射——第二路不重启
	## Tween/不重复写文本（_last_ratio 守卫）
	bar.setup(gsm, REALM_TABLE)
	gsm.player.cultivation = 60
	gsm.cultivation_changed.emit(60, 60, 100)
	var tween_after_first: Tween = bar._fill_tween
	var ratio_after_first: float = float(bar._last_ratio)
	# Act —— 同值重复信号（batch 路径双发射）
	gsm.batch_updated.emit({"player.cultivation": {"old": 0, "new": 60}})
	# Assert —— 幂等：Tween 句柄不变（未 kill 重建）、比例不变
	assert_eq(bar._fill_tween, tween_after_first, "重复信号不应重建填充 Tween（幂等守卫）")
	assert_almost_eq(float(bar._last_ratio), ratio_after_first, 0.0001, "重复信号比例不应变化")


func test_refresh_idempotent_same_ratio_no_tween() -> void:
	## 同比例信号（不同 delta 路径但相同 current/max）——无 Tween 重建
	bar.setup(gsm, REALM_TABLE)
	gsm.player.cultivation = 60
	gsm.cultivation_changed.emit(60, 60, 100)
	var tween_first: Tween = bar._fill_tween
	gsm.cultivation_changed.emit(0, 60, 100)
	assert_eq(bar._fill_tween, tween_first, "同比例信号不应重建 Tween")
