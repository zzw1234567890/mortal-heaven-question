class_name AudioEnums
## AudioEnums —— 音频系统公共枚举与总线名称映射（audio Epic Story 001）。
##
## [b]AudioBus[/b]：GDD §8 音频事件接口的总线枚举（MASTER/BGM/SFX/UI/AMBIENT/VOICE）。
## 一切总线访问经 [code]AudioServer.get_bus_index(name)[/code] 按名称查询——
## GDD 总线表中的「索引1/2/3」仅为结构示意；子总线（Combat/Card/Explore SFX）
## 占用整数索引使数值不稳定，禁硬编码索引（QL-STORY-READY 2026-09-07 裁决）。
## [br][b]AudioState[/b]：GDD §8 的 12 值场景音频状态枚举——set_state 参数类型，
## 过渡矩阵消费（story 004 实现，本 story 只定义类型完整性）。
## [br][b]dB 默认值[/b]：不出现在代码中——出厂基准在
## [code]resources/audio/default_bus_layout.tres[/code]（数据驱动），
## 启动时设置文件覆盖逻辑归 audio 005。
##
## @experimental
## 来源: design/gdd/audio-system.md §8、audio Story 001（Implementation Notes）、ADR-0031。


## 总线枚举——与 [constant BUS_NAMES] 名称映射一一对应。
enum AudioBus {
	MASTER = 0,   ## 主总线（总输出，Limiter 保护）
	BGM = 1,      ## 背景音乐（参考基准 0dB）
	SFX = 2,      ## 音效（默认 -3dB，含 3 条子总线）
	UI = 3,       ## UI 音效（默认 -8dB）
	AMBIENT = 4,  ## 环境音（默认 -10dB）
	VOICE = 5,    ## 语音（默认 -1dB，MVP 基础设施无资产）
}


## AudioBus 枚举值 → AudioServer 总线名称（按名称访问的唯一真源）。
## 新增总线时同步追加——本映射即「禁硬编码索引」规则的落地形态。
const BUS_NAMES: Dictionary = {
	AudioBus.MASTER: &"Master",
	AudioBus.BGM: &"BGM",
	AudioBus.SFX: &"SFX",
	AudioBus.UI: &"UI",
	AudioBus.AMBIENT: &"Ambient",
	AudioBus.VOICE: &"Voice",
}


## 场景音频状态枚举（GDD §8 §9——12 值完整定义）。[br]
## set_state() 经此枚举查 GDD §9 过渡矩阵执行音频编排
## （矩阵实现归 story 004——本 story 仅类型定义）。
enum AudioState {
	MAIN_MENU = 0,        ## 主菜单——主菜单 BGM 循环
	IDENTITY_SELECT = 1,  ## 身份选择——主菜单 BGM 降至 -6dB
	EXPLORING = 2,        ## 探索中——地图 BGM + 环境音
	IN_COMBAT = 3,        ## 战斗中——战斗 BGM（环境音 -8dB）
	IN_TRIBULATION = 4,   ## 渡劫战——渡劫 BGM
	IN_EVENT = 5,         ## 事件中——BGM 保持（环境音 -6dB）
	IN_SHOP = 6,          ## 商店中——BGM 降至 -10dB
	MAP_CLEARED = 7,      ## 地图通关——胜利 BGM
	DEFEATED = 8,         ## 战败——战败 BGM
	PAUSED = 9,           ## 暂停——所有音频暂停
	DECK_EDITING = 10,   ## 卡组编辑——静默 BGM
	CULTIVATING = 11,     ## 修为养成——BGM 降至 -12dB
}
