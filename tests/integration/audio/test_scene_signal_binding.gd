extends GutTest
## audio-manager Story 004 集成测试：场景信号驱动 set_state（AC-4）。
##
## 覆盖 QA Test Cases AC-4：
##   Given: AudioManager 已挂载
##   When: SceneManager 发 pre_transition(EXPLORATION, COMBAT, EXPLORE_TO_COMBAT)
##   Then: set_state(IN_COMBAT) 被调用，BGM 开始按矩阵行过渡
##   Edge: 转场中二次 pre_transition（续接语义委托 Story 002——不崩溃 + 状态正确）
##
## Story 类型 Logic + Integration——此文件为 BLOCKING 证据（Integration 侧）。
## 风格先例：tests/integration/audio/test_bgm_crossfade.gd（真实 SceneManager +
## mock 依赖 + stream override + await）。

const AudioManagerScript := preload("res://src/ui/audio/audio_manager.gd")
const Matrix := preload("res://src/ui/audio/state_transition_matrix.gd")
const AE := preload("res://src/ui/audio/audio_enums.gd")
const Planner := preload("res://src/ui/audio/bgm_fade_planner.gd")
const SM_SCRIPT := preload("res://src/foundation/scene_manager.gd")
const MockFactory := preload("res://tests/integration/scene_manager/mocks/mock_factory.gd")

## 缩放后的过渡时长（QA 规格：真实过渡缩至 0.05s + await）。
const FADE_SEC: float = 0.05
## 矩阵行真实淡入时长（探索→战斗 0.5s）——set_state 路径用矩阵数值（非测试
## 缩放的 FADE_SEC），等待窗口须覆盖真实淡入完成（0.5s + 余量）。
const SETTLE_SEC: float = 0.8

var manager: AudioManager = null
var sm: Node = null
var _mock_gsm: Node = null
var _mock_im: Node = null
var _mock_sl: Node = null


func before_each() -> void:
	sm = SM_SCRIPT.new()
	# 不调用 sm._ready()——它会经 _get_audio_manager() 内部创建第二个 AudioManager
	# 并再次绑定 pre_transition，造成双监听污染（QA 缺口 5）。PersistentLayer 由
	# AudioManager._setup_node_pool → register_persistent 惰性创建。
	sm._test_mode = true
	_mock_gsm = MockFactory.build_gsm()
	_mock_im = MockFactory.build_im()
	_mock_sl = MockFactory.build_sl()
	sm.set_dependencies(_mock_gsm, _mock_im, _mock_sl)
	add_child_autofree(sm)
	# AudioManager 构造经 sm——_init 自动绑定 pre_transition 信号（AC-4 链路）
	manager = AudioManagerScript.new(sm)
	# 注入为 sm 的 AudioManager 实例（防后续 get_audio_manager 再建重复实例）
	sm.set_audio_manager(manager)
	# 注入静音 WAV 流对象（对象注入免落盘——切曲目标曲可解析）
	_stream_override(&"bgm_explore")
	_stream_override(&"bgm_combat")
	_stream_override(&"bgm_tribulation")
	_stream_override(&"bgm_main_menu")


## 注入静音 AudioStreamWAV 流对象（4.0s @ 24kHz 单声道——全零静音；时长须
## 覆盖全部等待窗口——矩阵行真实淡入 0.5s + 幂等测试二次等待，超 1.0s 流会
## 先于断言播完导致 playing=false）。
func _stream_override(bgm_id: StringName) -> void:
	var data: PackedByteArray = PackedByteArray()
	data.resize(48000 * 4)  # 4.0s @ 24kHz
	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 24000
	wav.stereo = false
	manager._stream_overrides[bgm_id] = wav


func after_each() -> void:
	if sm != null and is_instance_valid(sm):
		sm.free()
	sm = null
	manager = null
	for m: Node in [_mock_gsm, _mock_im, _mock_sl]:
		if m != null and is_instance_valid(m):
			m.free()
	_mock_gsm = null
	_mock_im = null
	_mock_sl = null


# ═══════════════════════════════════════════════════════════════════════════════
# AC-4：场景信号驱动
# ═══════════════════════════════════════════════════════════════════════════════

func test_pre_transition_drives_set_state_in_combat() -> void:
	# Given: AudioManager 已挂载（_init 绑定信号）
	assert_eq(manager._current_state, -1, "前置：初始状态 -1（未设置）")
	# When: SceneManager 发 pre_transition(EXPLORATION, COMBAT, EXPLORE_TO_COMBAT)
	sm.pre_transition.emit(SM_SCRIPT.SceneID.EXPLORATION,
			SM_SCRIPT.SceneID.COMBAT, SM_SCRIPT.TransitionType.EXPLORE_TO_COMBAT)
	# Then: set_state(IN_COMBAT) 被调用 → _current_state 推进
	assert_eq(manager._current_state, AE.AudioState.IN_COMBAT,
			"EXPLORE_TO_COMBAT 信号应驱动 set_state(IN_COMBAT)")


func test_pre_transition_starts_bgm_transition() -> void:
	# AC-4: BGM 开始按矩阵行过渡（探索→战斗 0.5s 切曲）
	sm.pre_transition.emit(SM_SCRIPT.SceneID.EXPLORATION,
			SM_SCRIPT.SceneID.COMBAT, SM_SCRIPT.TransitionType.EXPLORE_TO_COMBAT)
	var players: Array[AudioStreamPlayer] = manager.get_bgm_players()
	await sm.get_tree().create_timer(SETTLE_SEC).timeout
	assert_true(manager._current_bgm_id == &"bgm_combat",
			"战斗目标曲应切换为 bgm_combat（当前=%s）" % manager._current_bgm_id)
	assert_true(_cur(players).playing, "战斗 BGM 应播放中")


func test_pre_transition_combat_to_explore() -> void:
	# 战斗→探索（COMBAT_TO_EXPLORE）→ set_state(EXPLORING)
	sm.pre_transition.emit(SM_SCRIPT.SceneID.COMBAT,
			SM_SCRIPT.SceneID.EXPLORATION, SM_SCRIPT.TransitionType.COMBAT_TO_EXPLORE)
	assert_eq(manager._current_state, AE.AudioState.EXPLORING,
			"COMBAT_TO_EXPLORE 信号应驱动 set_state(EXPLORING)")


func test_pre_transition_tribulation_sequential() -> void:
	# 渡劫（TRIBULATION）→ set_state(IN_TRIBULATION)（顺序式矩阵行）
	sm.pre_transition.emit(SM_SCRIPT.SceneID.EXPLORATION,
			SM_SCRIPT.SceneID.TRIBULATION, SM_SCRIPT.TransitionType.TRIBULATION)
	assert_eq(manager._current_state, AE.AudioState.IN_TRIBULATION,
			"TRIBULATION 信号应驱动 set_state(IN_TRIBULATION)")
	# 矩阵行 sequential=true（渡劫顺序式——Boss 冲击感例外）
	var row: Dictionary = Matrix.transition_params(
			AE.AudioState.EXPLORING, AE.AudioState.IN_TRIBULATION)
	assert_true(bool(row[Matrix.K_SEQUENTIAL]), "渡劫矩阵行应为顺序式")


func test_pre_transition_game_to_menu() -> void:
	# 游戏→主菜单（GAME_TO_MENU）→ set_state(MAIN_MENU)
	sm.pre_transition.emit(SM_SCRIPT.SceneID.EXPLORATION,
			SM_SCRIPT.SceneID.MAIN_MENU, SM_SCRIPT.TransitionType.GAME_TO_MENU)
	assert_eq(manager._current_state, AE.AudioState.MAIN_MENU,
			"GAME_TO_MENU 信号应驱动 set_state(MAIN_MENU)")


func test_second_pre_transition_during_transition_no_crash() -> void:
	# AC-4 Edge：转场中二次 pre_transition（续接语义委托 Story 002——
	# 本测试只断言不崩溃 + 状态推进到最新目标态）
	sm.pre_transition.emit(SM_SCRIPT.SceneID.EXPLORATION,
			SM_SCRIPT.SceneID.COMBAT, SM_SCRIPT.TransitionType.EXPLORE_TO_COMBAT)
	assert_eq(manager._current_state, AE.AudioState.IN_COMBAT)
	# 淡入进行中二次切换（战斗→探索）
	sm.pre_transition.emit(SM_SCRIPT.SceneID.COMBAT,
			SM_SCRIPT.SceneID.EXPLORATION, SM_SCRIPT.TransitionType.COMBAT_TO_EXPLORE)
	assert_eq(manager._current_state, AE.AudioState.EXPLORING,
			"二次 pre_transition 应推进到最新目标态（不崩溃）")
	await sm.get_tree().create_timer(SETTLE_SEC).timeout
	assert_true(manager._current_bgm_id == &"bgm_explore",
			"二次切换后目标曲应为 bgm_explore")


func test_same_state_pre_transition_idempotent() -> void:
	# AC-6 场景侧：同目标态二次 pre_transition 幂等（无 BGM 重启）
	sm.pre_transition.emit(SM_SCRIPT.SceneID.EXPLORATION,
			SM_SCRIPT.SceneID.COMBAT, SM_SCRIPT.TransitionType.EXPLORE_TO_COMBAT)
	var players: Array[AudioStreamPlayer] = manager.get_bgm_players()
	await sm.get_tree().create_timer(SETTLE_SEC).timeout
	var cur: AudioStreamPlayer = _cur(players)
	# 再次发同目标态信号（当前已 IN_COMBAT）
	sm.pre_transition.emit(SM_SCRIPT.SceneID.EXPLORATION,
			SM_SCRIPT.SceneID.COMBAT, SM_SCRIPT.TransitionType.EXPLORE_TO_COMBAT)
	assert_eq(manager._current_state, AE.AudioState.IN_COMBAT, "同态信号状态不变")
	await sm.get_tree().create_timer(SETTLE_SEC).timeout
	assert_true(cur.playing, "同态信号不应重启 BGM（继续播放）")
	assert_almost_eq(cur.volume_db, Planner.NORMAL_DB, 1.0,
			"同态信号不应重复淡化（音量保持 0dB 附近）")


func test_entry_bgm_guides_direct_fade_in() -> void:
	# 引导进入（QA 缺口 2）：_current_state=-1 → set_state(EXPLORING) 走
	# _enter_state——入口曲 bgm_explore 直接淡入（fade_out=0.0，无前置状态）
	assert_eq(manager._current_state, -1, "前置：初始 -1（未设置）")
	manager.set_state(AE.AudioState.EXPLORING)
	var players: Array[AudioStreamPlayer] = manager.get_bgm_players()
	await sm.get_tree().create_timer(SETTLE_SEC).timeout
	assert_eq(manager._current_state, AE.AudioState.EXPLORING, "引导进入推进状态")
	assert_eq(manager._current_bgm_id, &"bgm_explore", "引导进入应播探索入口曲")
	assert_true(_cur(players).playing, "入口曲应播放中")


func test_n_a_transition_via_signal_rolls_back_state() -> void:
	# N/A 转换经真实信号路径（code-review 阻塞项回归）：先引导进入 IN_SHOP，
	# 再发 EXPLORE_TO_COMBAT 信号——但当前态 IN_SHOP → IN_COMBAT 是 N/A，
	# _on_pre_transition 经 set_state 回滚，状态保持 IN_SHOP
	manager.set_state(AE.AudioState.IN_SHOP)
	assert_eq(manager._current_state, AE.AudioState.IN_SHOP, "前置：当前 IN_SHOP")
	sm.pre_transition.emit(SM_SCRIPT.SceneID.EXPLORATION,
			SM_SCRIPT.SceneID.COMBAT, SM_SCRIPT.TransitionType.EXPLORE_TO_COMBAT)
	assert_eq(manager._current_state, AE.AudioState.IN_SHOP,
			"商店→战斗 N/A 应回滚——信号路径状态保持 IN_SHOP")


## 取当前播放侧播放器（轮换语义——执行层 a/b 按 _current_player_index 映射）。
func _cur(players: Array[AudioStreamPlayer]) -> AudioStreamPlayer:
	return players[manager._current_player_index]
