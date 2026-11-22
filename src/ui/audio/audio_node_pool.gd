extends RefCounted
## AudioNodePool —— 常驻音频节点池（自 AudioManager 拆出）。
##
## [b]职责[/b]：按 GDD §4/§5/§7 的架构建造并持有全部常驻播放器节点，逐个挂入
## SceneManager 的 PersistentLayer（[code]register_persistent[/code]），并把
## SFX 侧接线交给 [code]SfxPool[/code]（池节点 / UI 槽 / 流解析器）。[br]
## [br][b]所有权[/b]：本类持有三个数组/槽位，AudioManager 经访问器转发消费。
## 节点一旦建好整局常驻、重入不重建，故引用不会失效。[br]
## [br][b]节点归属[/b]：节点是 Node（非 RefCounted），挂在 PersistentLayer 上；
## 本类持引用不影响其生命周期。[br]
## [br][b]SFX 池只持引用[/b]：节点所有权归本类/PersistentLayer——
## [code]SfxPool[/code] 拿到的是同一批节点对象。[br]
## [br][b]静默跳过[/b]：SceneManager 为 null 时（单元测试直建 AudioManager）
## 全部跳过，三处访问器均为空——API 不崩溃。
##
## 来源: design/gdd/audio-system.md §4/§5/§7、audio Story 001/003、
## ADR-0031 §1.2（PersistentLayer 结构 + PROCESS_MODE_ALWAYS）。

## BGM 双播放器（交叉淡化两侧——轮换归 BgmFadeExecutor）。
var _bgm_players: Array[AudioStreamPlayer] = []

## SFX 通用池播放器（16 个——12 活跃 + 4 余量，规模由 SfxPoolConfig 数据驱动）。
var _sfx_players: Array[AudioStreamPlayer] = []

## UI 音效单实例播放器（UI 总线——独立槽，不参与通用池）。
var _ui_sfx_player: AudioStreamPlayer = null


## 建造并挂载整个节点池。[br]
## [br]节点命名与 GDD §4/§5 一致（[code]bgm_player_a/bgm_player_b[/code]、
## [code]sfx_player_0..15[/code]、[code]ui_sfx_player[/code]）；
## [code]process_mode = PROCESS_MODE_ALWAYS[/code]（ADR-0031 §1.2——暂停中节点
## 不被冻结，暂停行为由暂停逻辑显式控制）。[br]
## [br][param scene_manager]: SceneManager 引用（null 时整池跳过——单元测试场景）。[br]
## [param sfx_pool]: SfxPool Logic 内核（接线目标——池节点/UI 槽/流解析器）。[br]
## [param sfx_stream_resolver]: sfx_id → AudioStream 解析器（归 AudioManager
## 所有，本类只转发给 SfxPool）。[br]
## [b]返回[/b]：本方法幂等性未定义——调用方（AudioManager._init）只调一次；
## 重复调用会重复建节点并重复 register_persistent。
func build(scene_manager: Node, sfx_pool: RefCounted,
		sfx_stream_resolver: Callable) -> void:
	if scene_manager == null:
		return
	for player_name: String in [&"bgm_player_a", &"bgm_player_b"]:
		var player: AudioStreamPlayer = _make_player(player_name,
				AudioEnums.AudioBus.BGM)
		_bgm_players.append(player)
		scene_manager.register_persistent(player)
	# SFX 通用池：规模由配置驱动（GDD §5/§7 调优表——12 活跃 + 4 余量）
	for i: int in sfx_pool.pool_size():
		var sfx_player: AudioStreamPlayer = _make_player("sfx_player_%d" % i,
				AudioEnums.AudioBus.SFX)
		_sfx_players.append(sfx_player)
		scene_manager.register_persistent(sfx_player)
	# UI 音效单实例槽（独立——不参与通用池，GDD §7 打断语义）
	_ui_sfx_player = _make_player(&"ui_sfx_player", AudioEnums.AudioBus.UI)
	scene_manager.register_persistent(_ui_sfx_player)
	# 注入 SFX 池（节点池所有权仍归本类/PersistentLayer——SfxPool 只持引用）
	sfx_pool.set_pool_nodes(_sfx_players)
	sfx_pool.set_ui_player(_ui_sfx_player)
	sfx_pool.set_stream_resolver(sfx_stream_resolver)


## BGM 双播放器（AudioManager.get_bgm_players 转发消费）。
func bgm_players() -> Array[AudioStreamPlayer]:
	return _bgm_players


## SFX 通用池播放器（AudioManager.get_sfx_players 转发消费）。
func sfx_players() -> Array[AudioStreamPlayer]:
	return _sfx_players


## UI 音效单实例播放器（AudioManager.get_ui_sfx_player 转发消费）。
func ui_player() -> AudioStreamPlayer:
	return _ui_sfx_player


## 建单个播放器节点（总线按枚举名取——一律按名称访问，避免硬编码总线串）。[br]
## [br][param player_name]: 节点名（GDD §4/§5 命名）。[br]
## [param bus]: [enum AudioEnums.AudioBus] 枚举值。
func _make_player(player_name: StringName, bus: AudioEnums.AudioBus) \
		-> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.bus = AudioEnums.BUS_NAMES[bus]
	# 暂停中节点不被冻结（暂停行为由暂停逻辑显式控制——ADR-0031 §1.2）
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	return player
