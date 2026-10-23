class_name SfxPoolConfig
extends Resource
## SfxPoolConfig —— SFX 池调优参数数据驱动资产（audio-manager Story 003）。
##
## [b]职责[/b]：GDD §5/§7 调优旋钮的出厂基准集中于此（`.tres` 资产），
## SfxPool 经注入读取——改数值只改资产不重编译代码（control-manifest
## Presentation 层 Forbidden「硬编码调优参数」规则的落地形态，与
## [code]default_bus_layout.tres[/code] 承载总线 dB 基准同构）。[br]
## [br]每个 [code]@export[/code] 附 GDD 调优表安全范围（设计侧调优边界；
## 本类不钳制——当前基准值均在安全范围内，超范围调整由 game-designer
## 签批后改资产）。[br]
## [br][b]注入[/b]：AudioManager 启动时 [code]load[/code] 本资产并传入
## [code]SfxPool.new(clock, rng, config)[/code]；测试可注入覆盖实例断言
## 行为随配置变化（或直接用出厂基准资产）。
##
## @experimental
## 来源: design/gdd/audio-system.md §5/§7 调优表、audio Story 003、ADR-0031。

## 同时播放 SFX 上限（GDD 调优表：12，安全范围 8~16）。
@export var max_simultaneous: int = 12

## SFX 池总节点数（GDD：16 = 12 活跃 + 4 余量，安全范围 12~20）。
@export var pool_size: int = 16

## 同 sfx_id 冷却时长（GDD 调优表：50ms，安全范围 30~100）。
@export var cooldown_ms: int = 50

## 战斗中攻击 SFX 最小间隔（GDD 调优表：100ms，安全范围 50~150）。
@export var attack_interval_ms: int = 100

## UI 音效最低播放时长（GDD §7：80ms，安全范围 50~150）。
@export var ui_min_duration_ms: int = 80

## UI 音效默认音量（GDD §7：-8dB，比 SFX 低 5dB）。
@export var ui_default_db: float = -8.0

## SFX pitch 随机化范围（GDD：±10% → 0.9~1.1，安全范围 ±0%~±25%）。
@export var pitch_min: float = 0.9
@export var pitch_max: float = 1.1

## SFX volume 随机化范围（GDD：「-3dB±3dB」→ -6.0~0.0 dB）。
@export var volume_min_db: float = -6.0
@export var volume_max_db: float = 0.0
