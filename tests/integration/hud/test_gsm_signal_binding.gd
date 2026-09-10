extends GutTest
## hud Story 003 集成测试：灵石数据绑定（AC-3）——LingshiDeckBar 直连真实 GSM。
##
## 覆盖 AC-3（resource_changed 灵石 +25 → 显示文本更新为新余额）与 edge cases
## （连续多次变更最后一次生效；战斗隐藏恢复后显示最新值——可见性归 Story 001
## 矩阵，此处以 ContentLayer.visible 模拟验证恢复路径）。
##
## 测试策略（G4 裁决 2026-09-10）：复用 tests/unit/cultivation_system/ 直连
## 真实 GSM Autoload 的模式（写 player.resources.ling_shi + 等待帧末 flush +
## 断言显示文本）——共享 mock_gsm 仅 session 域无 resource_changed 信号，免建
## hud 专用 mock。
##
## Story 类型为 Integration（含 Logic 内核 BLOCKING 单测在 unit/hud/）——
## 此文件为 AC-3 阻塞项。[br]风格先例：tests/unit/cultivation_system/
## test_gain_cultivation.gd（真实 GSM + _flush + after_each 复原）。

const BAR_SCENE: PackedScene = preload("res://src/ui/hud/LingshiDeckBar.tscn")

var gsm: Node = null
var bar: Control = null
var _saved_lingshi: int = 0


func before_each() -> void:
	gsm = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/GameStateManager")
	if gsm == null:
		fail_test("GSM Autoload 未注册")
		return
	# 保存原值——after_each 复原（测试自行清理，G4 裁决）
	_saved_lingshi = int(gsm.player.resources.ling_shi)
	# 独立基线值——避免与用例间残留耦合
	gsm.player.resources.ling_shi = 100
	gsm.set("_signal_chain_depth", 0)
	gsm.get("_signal_router").set("_pending_changes", [])
	bar = BAR_SCENE.instantiate()
	# AC-3 规格「自动化断言显示文本，不含动画」——关闭滚动 Tween，
	# 信号处理后显示文本直接落位终值（组件 animate 注入点，测试/共享）。
	bar.animate = false
	add_child(bar)


func after_each() -> void:
	if bar != null and is_instance_valid(bar):
		# 断开 GSM 信号——bar 释放前摘除订阅（防后续用例误触发已释放节点）
		if gsm != null and is_instance_valid(gsm):
			if gsm.resource_changed.is_connected(bar._on_resource_changed):
				gsm.resource_changed.disconnect(bar._on_resource_changed)
			if gsm.batch_updated.is_connected(bar._on_batch_updated):
				gsm.batch_updated.disconnect(bar._on_batch_updated)
		bar.free()
	bar = null
	if gsm != null and is_instance_valid(gsm):
		# 复原灵石原值（测试自行清理——G4 裁决；直写绕过缓冲不触发信号）
		gsm.set("_signal_chain_depth", 0)
		gsm.get("_signal_router").set("_pending_changes", [])
		gsm.player.resources.ling_shi = _saved_lingshi
	gsm = null


## 刷新 GSM 帧末缓冲（信号帧末 flush——先例 test_gain_cultivation._flush）。
func _flush() -> void:
	await get_tree().process_frame


func _lingshi_text() -> String:
	return str(bar.get_node(^"LingshiLabel").text)


# ═══════════════════════════════════════════════════════════════════════════════
# AC-3：灵石数据绑定（单变更 resource_changed 路径）
# ═══════════════════════════════════════════════════════════════════════════════

func test_ac003_initial_mount_shows_current_lingshi() -> void:
	## AC-3 前置: 挂载后首刷显示当前值（before_each 直写 100——不经缓冲无信号，
	## 组件 _ready → setup → _refresh 静默落位）
	# Arrange + Act —— before_each 已 add_child（触发 _ready）
	# Assert
	assert_eq(_lingshi_text(), "🪙 100", "挂载后应显示当前灵石值 100")


func test_ac003_resource_changed_updates_display() -> void:
	## AC-3 主体: GSM._set_resource_ling_shi(100+25) → 信号帧末 flush 后
	## 显示文本更新为新余额 125（自动化断言显示文本，不含动画——story 规格）
	# Arrange —— 基线 100（before_each）
	# Act —— 原子写入经缓冲（单变更帧末发 resource_changed + batch_updated 双信号）
	gsm._set_resource_ling_shi(125)
	await _flush()
	# Assert
	assert_eq(_lingshi_text(), "🪙 125", "+25 后应显示新余额 125")


func test_ac003_batch_updated_updates_display() -> void:
	## AC-3 补充（G1 裁决）: batch_updated 路径——直写 player.resources.ling_shi
	## 后手动 emit batch_updated（模拟同帧多变更——域信号不发射，batch 为唯一入口）
	# Arrange —— 基线 100（before_each）
	# Act —— 直接写 + 手动发 batch（载荷 {old, new}）
	gsm.player.resources.ling_shi = 150
	gsm.batch_updated.emit({"player.resources.ling_shi": {"old": 100, "new": 150}})
	# Assert —— 同帧同步信号，无需 flush
	assert_eq(_lingshi_text(), "🪙 150", "batch 路径 +50 后应显示 150")


func test_ac003_consecutive_changes_last_one_wins() -> void:
	## AC-3 edge: 连续多次变更——最后一次生效
	# Arrange —— 基线 100（before_each）
	# Act —— 同帧三次原子写入（_buffer_change 同路径保留首次 old、更新末次 new）
	gsm._set_resource_ling_shi(120)
	gsm._set_resource_ling_shi(180)
	gsm._set_resource_ling_shi(200)
	await _flush()
	# Assert
	assert_eq(_lingshi_text(), "🪙 200", "连续变更后应显示最后值 200")


func test_ac003_k_format_updates_on_change() -> void:
	## AC-3 与 AC-hud-004 交叉: 跨 k 阈值变更——999 → 1250 显示「1.2k」
	## （显示文本走 LingshiFormatter 格式化路径）
	# Arrange —— 基线改为 999（直写绕过信号）
	gsm.player.resources.ling_shi = 999
	bar._refresh()
	assert_eq(_lingshi_text(), "🪙 999", "前置：基线显示 999")
	# Act
	gsm._set_resource_ling_shi(1250)
	await _flush()
	# Assert
	assert_eq(_lingshi_text(), "🪙 1.2k", "跨阈值后应显示 k 格式 \"1.2k\"")


func test_ac003_hidden_then_restored_shows_latest_value() -> void:
	## AC-3 edge: 变更时 HUD 处于战斗隐藏状态——恢复可见后显示最新值。
	## ContentLayer 整体显隐归 hud.gd 可见性矩阵（Story 001 边界）——本组件
	## 不处理可见性、隐藏期间信号照常刷新数据。此处手动模拟 ContentLayer
	## 隐藏（等价战斗隐藏）验证恢复路径；完整 12 值矩阵归 Story 001 集成测试
	## （tests/integration/hud/test_hud_scene_visibility.gd）覆盖。
	# Arrange —— 模拟战斗隐藏：组件 visible=false（ContentLayer 隐藏的等价效果）
	bar.visible = false
	# Act —— 隐藏期间变更（信号照常处理——组件未脱树，订阅保持）
	gsm._set_resource_ling_shi(175)
	await _flush()
	# Assert —— 恢复可见后显示最新值（无需再刷新）
	bar.visible = true
	assert_eq(_lingshi_text(), "🪙 175", "隐藏期间变更、恢复可见后应显示最新值 175")


func test_ac003_resource_changed_other_type_ignored() -> void:
	## AC-3 补充（G1 裁决过滤）: resource_changed 非灵石类型（灵材 low）——
	## 不触发灵石行刷新（基线文本保持）
	# Arrange —— 基线 100（before_each）
	var text_before: String = _lingshi_text()
	# Act —— 直写 + 手动发非灵石资源信号（模拟灵材变更）
	gsm.player.resources.ling_cai.low = 5
	gsm.resource_changed.emit(&"ling_cai.low", 5, 5)
	# Assert —— 文本未变（无多余刷新路径误触发）
	assert_eq(_lingshi_text(), text_before, "非灵石资源信号不应改变灵石显示")


func test_ac003_batch_updated_deck_path_refreshes_deck_row() -> void:
	## AC-3 补充（G1 裁决卡组入口）: batch_updated 携带 deck.current_deck →
	## 卡组行刷新（经 DeckEditingSystem.get_deck_summary 读取真实现值）。
	## Autoload 环境下 DeckEditingSystem 直连真实 GSM——直写 current_deck 后
	## emit batch 信号驱动刷新。
	# Arrange —— 直写卡组内容（绕过缓冲）
	gsm.deck.current_deck = [1, 2, 3, 4, 5, 6, 7, 8]
	var deck_label: Label = bar.get_node(^"DeckLabel")
	# Act —— 手动发 deck 路径 batch（卡组变更唯一刷新入口）
	gsm.batch_updated.emit({"deck.current_deck": {"old": [], "new": [1, 2, 3, 4, 5, 6, 7, 8]}})
	# Assert —— 8 张 / 系统上限（探索链 Autoload 下 get_deck_limit 按 player.realm
	## 计算——不钉死具体上限，仅断言 total 段与刷新行为）
	var expected_total: int = 8
	assert_true(str(deck_label.text).begins_with("📜 %d/" % expected_total),
			"deck 路径 batch 后卡组行应显示 total=%d（实际 %s）" % [expected_total, deck_label.text])
