# 音频管理系统 (Audio Management System)

> **状态 (Status)**：设计中 (In Design)
> **作者 (Author)**：Claude Code + 用户
> **最后更新 (Last Updated)**：2026-07-23
> **最后验证 (Last Verified)**：—
> **实现的支柱 (Implements Pillar)**：P1（自由组牌）、P2（苟道成长）、P3（机缘巧合）、P4（修仙问道）

---

## 概述

音频管理系统负责游戏中所有音频资源的加载、播放、混音和场景切换时的音频过渡——包括背景音乐（BGM）、音效（SFX）、环境音、UI音效以及语音/对话音频。音频管理系统不直接决定播放什么音频（那是各系统的职责），而是提供**播放接口和混音控制**，确保音频在场景切换时平滑过渡，不出现爆音、重叠或丢失。

对于玩家而言，音频是游戏沉浸感的核心支柱——战斗的紧张大鼓、探索时笛箫营造的宁静山水、突破时编钟齐鸣的恢弘音效，共同以纯粹的**中国传统民乐**编织修仙世界的听觉体验。

---

## 玩家幻想

闭上眼睛，只听声音：

- **探索时**——你听见远处山谷的鸟鸣与溪流，脚下碎石轻响。古琴低吟，笛箫悠远，仿佛独自漫步于云雾缭绕的仙山。这是"凡人修仙"的孤寂与坚定。
- **战斗触发时**——大鼓骤然擂响，琵琶急弦如雨。敌我交锋，每一击都有金石之声。你的心跳随鼓点加速，但你必须冷静——卡牌在手，策略在心。
- **渡劫突破时**——雷声从远及近，低沉的嗡鸣压迫胸腔。天雷劈下，编钟轰响，而后……静默。一息之后，金色光芒伴随着古琴的泛音升起——你成功了。境界突破的瞬间，是你几十小时努力的最高潮。
- **成长弧线**——从炼气期笛箫的单薄清亮，到筑基期琵琶的逐渐厚重，再到金丹期后编钟与乐队的壮阔恢弘。你听到的不仅是地图的变换，更是你自己从凡人走向飞升的声音旅程。
- **关键时刻的静默**——Boss倒下后的片刻寂静、渡劫前最后一息、进入三星洞时环境音骤然收敛——静默不是空白，是让玩家"感到"这一刻的重量。

---

## 详细设计

### 核心规则

#### 1. 声音调色板——纯传统中国民乐

所有音频资产统一使用中国传统乐器制作：

| 乐器 | 用途 | 情感调性 |
|------|------|---------|
| **古琴 (Guqin)** | 主菜单、探索BGM主旋律、渡劫成功泛音 | 空灵、深邃、精神性 |
| **笛箫 (Dizi/Xiao)** | 探索BGM（炼气/筑基）、环境音层 | 悠远、孤寂、宁静 |
| **琵琶 (Pipa)** | 战斗BGM节奏部、卡牌SFX | 紧张、灵动、急促 |
| **二胡 (Erhu)** | Boss/战败BGM、剧情悲壮时刻 | 悲怆、史诗、深沉 |
| **编钟 (Bianzhong)** | 渡劫BGM高潮、境界突破音效 | 恢弘、神圣、庄严 |
| **大鼓 (Dagu)** | 战斗BGM底鼓、Boss登场音效 | 压迫、力量、冲击 |

**卡牌类型 SFX 区分原则**：
- 功法牌：气息/内力流动感——笛箫短促音阶
- 法宝牌：金属碰撞/法器激活——编钟或金属打击乐
- 丹药牌：液体沸腾/丹炉开启——陶瓷/水声类音效
- 符箓牌：纸张燃烧/灵力注入——纸质感+低频嗡鸣

**流派风格化**：
- 正道流派（如剑修）：清亮高亢（笛箫+编钟）
- 魔道流派：暗沉低音（大鼓+低音二胡）
- 散修/丹修：中性温和（古琴+琵琶中音区）

#### 2. 音频分类与总线架构（Godot 4.6）

**AudioBusLayout 资产**：`resources/audio/default_bus_layout.tres`

总线结构通过 Godot `AudioBusLayout` 资源定义，运行时由 `AudioServer` 管理。总线使用整数索引访问，音量使用**分贝 (dB)** 表示。以下为总线层次结构及默认dB值：

```
Master Bus (0dB, 带 Limiter 效果防止削波)
├── BGM Bus     (索引1, 默认 0dB, 带 EQ 效果)
├── SFX Bus     (索引2, 默认 -3dB, 带 Limiter 效果)
│   ├── Combat SFX  (子总线)
│   ├── Card SFX    (子总线)
│   └── Explore SFX (子总线)
├── UI Bus      (索引3, 默认 -8dB)
├── Ambient Bus (索引4, 默认 -10dB, 带 Reverb 效果)
└── Voice Bus   (索引5, 默认 -1dB)  [基础设施，MVP无配音资产]
```

**总线效果最低要求**：
- Master: `AudioEffectLimiter`（ceiling -0.5dB，防止削波）
- SFX: `AudioEffectLimiter`（ceiling -1dB，12个SFX叠加时保护）
- Ambient: `AudioEffectReverb`（可选，修仙洞穴/洞府场景）

**音量规格表**：

| 总线 | 默认 dB | 线性系数 | 安全范围 (dB) | 说明 |
|------|:------:|:------:|:------------:|------|
| Master | 0 | 1.00 | — | 总输出；Limiter 保护 |
| BGM | 0 | 1.00 | -6 ~ +3 | 参考基准——其他总线以此为参照 |
| SFX | -3 | 0.71 | -12 ~ +0 | 低于BGM 3dB，保留冲击力余量 |
| UI | -8 | 0.40 | -20 ~ -3 | 比SFX低5dB，频发但不扰人 |
| Ambient | -10 | 0.32 | -20 ~ -5 | 最低——作为背景层，不宜突出 |
| Voice | -1 | 0.89 | -6 ~ +0 | 略低于0dB——台词必须清晰 |

**为什么不能用百分比而必须用 dB？**
Godot 的 `AudioServer.set_bus_volume_db(bus_idx, volume_db)` 以 dB 为单位。线性百分比（如"60%"）与听觉感知响度不成正比（-6dB ≈ 线性50% ≈ 感知半音量），直接在 dB 域定义避免了转换歧义。

#### 3. 音频闪避 (Ducking)

当高优先级音频播放时，自动降低其他总线音量：

| 触发条件 | 受影响总线 | 闪避量 | 起音 (Attack) | 释音 (Release) |
|----------|-----------|:------:|:------------:|:-------------:|
| Voice 播放 | BGM | -10 dB | 200 ms | 500 ms |
| Voice 播放 | Ambient | -15 dB | 200 ms | 500 ms |
| Boss 战 | Ambient | -8 dB | 300 ms | —（Boss战后恢复） |
| 重要系统通知 | SFX | -6 dB | 100 ms | 300 ms |

闪避通过 Godot `AudioEffectCompressor` 的侧链功能实现（Voice 总线 → sidechain → BGM/Ambient 总线的 Compressor 效果）。MVP 中无配音资产，Voice 闪避规则在实现时保留但不会触发。Boss 战闪避通过状态切换时调用 `set_bus_volume_db()` 实现。

#### 4. BGM 管理

**BGM 曲目表（MVP: 8首）：**

| # | 场景 | 风格 | 主要乐器 | 过渡方式 |
|---|------|------|---------|---------|
| 1 | 主菜单 | 空灵、悠远的修仙主题 | 古琴独奏 | 启动时播放 |
| 2 | 探索（炼气期） | 宁静的山水意境 | 笛箫为主 | 淡入 |
| 3 | 探索（筑基期） | 略带紧张的冒险感 | 笛箫+琵琶 | 淡入 |
| 4 | 探索（金丹期+） | 壮阔的仙侠风格 | 编钟+乐队 | 淡入 |
| 5 | 普通战斗 | 节奏适中的战斗曲 | 大鼓+琵琶 | 从探索BGM快速过渡 |
| 6 | 精英战斗 | 较紧张的战斗变奏 | 大鼓+二胡 | 从普通战斗BGM变调 |
| 7 | Boss/渡劫战 | 恢弘、紧迫的主题曲 | 编钟+大鼓+二胡 | 独立BGM直接播放 |
| 8 | 胜利/战败 | 凯旋或低沉 | 编钟（胜）/二胡（败） | Boss战后过渡 |

**Full Vision 扩展**（非MVP）：元婴、化神独立探索BGM；商店/事件专用BGM；身份选择BGM；每个章节独立叙事BGM。

**BGM 架构**：
- 需 2 个 `AudioStreamPlayer` 节点（`bgm_player_a`、`bgm_player_b`）用于交叉淡入淡出
- Godot `AudioStreamPlayer.finished` 信号在循环模式下**不触发**——交叉淡入淡出通过 `Tween` + 计时器编排，而非依赖 `finished`

**BGM 播放规则**：
- 同一时间仅播放 1 首 BGM（唯一性）
- 场景切换时：旧BGM **淡出**，新BGM **淡入**（具体时长见过渡矩阵）
- Boss 战时：战斗BGM直接切为Boss BGM
- BGM 循环播放
- **无间隙循环限制**：Godot 4.6 的 Ogg Vorbis 在循环边界存在约 5-30ms 间隙。缓解方案：BGM 资产使用 WAV 格式 + `AudioStreamWAV` 的 `loop_begin`/`loop_end` 属性手动设置循环点。如 WAV 文件过大，则使用 OGG 并接受轻微间隙（< 30ms）。

**BGM 加载**：
- 不是"流式"——Godot 不支持从磁盘流式播放。BGM 通过 `ResourceLoader.load_threaded_request()` **异步加载**到内存
- 当前 BGM + 下一首预加载在内存中；不再需要的 BGM 通过 `ResourceLoader.unload()` 释放
- 8首 BGM × 约 5-15 MB/首 (WAV) ≈ 40-120 MB —— 常驻 2 首（当前+预加载下一首）约 10-30 MB

#### 5. SFX 管理

**SFX 分类索引：**

| 子系统 | 音效示例 | 加载层级 |
|--------|---------|:------:|
| 战斗 | 攻击命中、技能释放、阵法激活、角色阵亡、暴击额外音 | T2 |
| 卡牌 | 抽牌、出牌（分类型：功法/法宝/丹药/符箓）、卡牌升级 | T1 |
| 探索 | 移动脚步声、传送、节点到达、宝箱打开、灵泉涌动 | T2 |
| 事件 | 事件弹出、选项选中、获得奖励、失败惩罚 | T2 |
| UI | 按钮确认、取消、面板打开/关闭（悬停/滚动无声） | T1 |
| 突破 | 渡劫雷声、突破成功金光音、失败低沉音 | T2 |

**分层加载策略：**

| 层级 | 数量（估计） | 加载时机 | 内存占用（估计） |
|:----:|:----------:|---------|:---------------:|
| **T1 常驻** | ~15 个（UI音效 + 核心卡牌SFX） | 游戏启动时异步加载 | ~5-10 MB |
| **T2 按场景** | ~20 个（战斗 + 探索 + 事件SFX） | 进入对应场景时异步加载 | ~10-15 MB |
| **T3 按需** | ~15 个（突破、稀有SFX） | 触发前预加载（如渡劫准备阶段） | ~5-10 MB |

- T1 加载通过 `ResourceLoader.load_threaded_request()` 异步完成，不阻塞主线程
- 内存估算基于 Ogg Vorbis q5 (44.1kHz, 单声道, ~0.3MB/个)
- MVP 预估总计约 50 个 SFX
- T2/T3 在场景退出时释放

**SFX 播放规则**：
- 最多同时播放 **12** 个 SFX（运行时配置参数 `sfx_max_simultaneous`）
- SFX 池通过预创建 16 个 `AudioStreamPlayer` 节点实现（12 活跃 + 4 余量）
- 池满时的淘汰算法：**先按淘汰优先级（低→高），同优先级内按播放时间（旧→新）**。淘汰优先级分三级：
  - 0 — 装饰性 (Ambient SFX、装饰音)
  - 1 — 功能性 (卡牌出牌声、脚步声)
  - 2 — 关键性 (命中确认、警告音) —— 永远不会被淘汰，如果12个槽全是优先级2的SFX则拒绝新请求并记录日志
- 同 `sfx_id` 冷却时间：**50ms**（按 `sfx_id` 独立计时，非跨类型共享）。冷却窗口内在第2次请求被静默丢弃，第3次及之后同样丢弃。冷却到期后接受下一次请求。日志信号：`sfx_cooldown_discarded(sfx_id, elapsed_ms)`
- 战斗中攻击 SFX 最小间隔：**100ms**——防止多角色同时攻击时音效堆叠
- 随机化（防"机关枪效应"）：每次播放时 `pitch_scale` ±10% 随机（0.9-1.1），`volume_db` ±3dB 随机。可通过 `options` 参数覆盖

**SFX 池实现复杂度说明**：SFX 池（含优先级淘汰、冷却跟踪、随机化）预计需 200-400 行 GDScript，为一个独立的 `SfxPool` 类。这比简单的"播放 AudioStreamPlayer"显著复杂，实现时应予充分估算。

#### 6. 环境音管理

环境音作为 BGM 的补充层：

- 每张地图有对应的环境音预设（风声、水声、鸟鸣等）
- 环境音与 BGM 叠加播放（互不干扰）
- 最多同时 **3 层**环境音叠加（超过时淘汰最旧的层）
- 环境音音量随场景状态动态调整：
  - 战斗中：环境音降低 **-8dB**
  - 事件/商店中：环境音降低 **-6dB** 但不停止
- 地图间环境音切换：淡出 1.0s → 淡入 1.5s
- 探索中环境音持续播放，不随节点移动中断

#### 7. UI 音效

**分层设计——并非所有 UI 交互都有声音**：

| UI 交互类型 | 音效 | 原因 |
|------------|:----:|------|
| 主操作（确认/提交/打开面板） | 有 | 关键反馈，玩家需确认操作已生效 |
| 次级操作（取消/返回/关闭面板） | 有 | 与确认音色不同——确认=清亮短促，取消=低沉短促 |
| 通知/警告 | 有 | 吸引注意，须与 HUD 上的视觉提示同步 |
| 悬停 (Hover) | **无** | 避免菜单浏览时的音频疲劳 |
| 滚动 (Scroll) | **无** | 频繁触发，有声音会令人烦躁 |
| 卡牌检视/翻转 | **无**（或有极微妙音） | 频繁操作 |

- UI 音效不叠加（新音效打断旧音效）
- 但每个 UI 音效有最低播放时长 **80ms**——防止快速导航时音频"卡顿"
- UI 音效目标时长：确认 ~80ms，取消 ~60ms，通知 ~150ms，错误 ~120ms
- UI 音效默认音量 -8dB（比 SFX 低 5dB，避免频繁点击过于刺耳）

#### 8. 音频事件接口——Godot 实现映射

各系统通过统一的音频事件接口触发播放。API 使用 GDScript 实现，参数直接映射到 Godot API：

```gdscript
# 播放SFX
# sfx_id: StringName — SFX资源标识符
# options.volume_db: float = 0.0 — 音量偏移 (dB)，叠加在SFX总线设置之上，范围 -80 到 +6
# options.pitch: float = 1.0 — pitch_scale，安全范围 0.5-2.0
# options.eviction_priority: int = 1 — 淘汰优先级 (0=装饰, 1=功能, 2=关键)
# options.delay_sec: float = 0.0 — 延迟 (秒)
func play_sfx(sfx_id: StringName, options: Dictionary = {}) -> void

# 播放BGM（自动处理交叉淡入淡出）
# bgm_id: StringName — BGM资源标识符
# options.fade_in_sec: float = 1.5 — 淡入时长
# options.loop: bool = true — 是否循环
func play_bgm(bgm_id: StringName, options: Dictionary = {}) -> void

# 停止BGM
# options.fade_out_sec: float = 1.0 — 淡出时长
func stop_bgm(options: Dictionary = {}) -> void

# 暂停所有音频（用于游戏暂停状态）
func pause_all() -> void

# 恢复所有音频（用于取消暂停）
func resume_all() -> void

# 播放环境音
# ambient_id: StringName — 环境音预设标识符
func play_ambient(ambient_id: StringName) -> void

# 停止环境音
# fade_out_sec: float = 1.0 — 淡出时长
func stop_ambient(fade_out_sec: float = 1.0) -> void

# 设置总线音量
# bus: AudioBus — 枚举值（MASTER, BGM, SFX, UI, AMBIENT, VOICE）
# volume_db: float — 目标音量 (dB)，范围 -80 到 +6
func set_bus_volume(bus: AudioBus, volume_db: float) -> void

# 获取总线当前音量
# bus: AudioBus — 枚举值
# 返回: float — 当前音量 (dB)
func get_bus_volume(bus: AudioBus) -> float

# 静音/取消静音所有音频（F1热键调用）
func toggle_mute() -> void

# 切换指定场景音频状态（编排BGM切换、环境音淡入淡出、SFX清理等）
# state: AudioState — 枚举值
func set_state(state: AudioState) -> void
```

**AudioBus 枚举**：`MASTER, BGM, SFX, UI, AMBIENT, VOICE`

**AudioState 枚举**：`MAIN_MENU, IDENTITY_SELECT, EXPLORING, IN_COMBAT, IN_TRIBULATION, IN_EVENT, IN_SHOP, MAP_CLEARED, DEFEATED, PAUSED, DECK_EDITING, CULTIVATING`

**`set_state()` 内部映射**：
```
AudioState → 读取过渡矩阵 → 执行对应音频动作（交叉淡入淡出BGM、加载/卸载环境音）
```
各系统无需手动编排多个 `play_bgm`/`play_ambient` 调用——调用 `set_state()` 即可。

#### 9. 音频状态与过渡矩阵

| 状态 | 含义 | 音频表现 |
|------|------|---------|
| **主菜单** (MAIN_MENU) | 游戏启动 | 主菜单BGM（循环） |
| **身份选择** (IDENTITY_SELECT) | 开局选择身份 | 主菜单BGM继续，降低至 -6dB |
| **卡组编辑** (DECK_EDITING) | 编辑卡组 | 静默BGM（可选低音量古琴氛围），卡牌放入/移出SFX |
| **修为养成** (CULTIVATING) | 消耗修为点 | BGM保持低音量，修为条里程碑提示音 |
| **探索中** (EXPLORING) | 玩家在地图上移动 | 地图BGM + 环境音 + 探索SFX |
| **战斗中** (IN_COMBAT) | 回合制对战 | 战斗BGM + 战斗SFX（环境音 -8dB） |
| **渡劫战中** (IN_TRIBULATION) | 渡劫Boss战 | 渡劫BGM + 渡劫SFX（环境音 -8dB） |
| **事件中** (IN_EVENT) | 事件面板打开 | BGM保持 + UI音效（环境音 -6dB） |
| **商店中** (IN_SHOP) | 商店界面 | BGM降低至 -10dB + UI音效（环境音 -6dB） |
| **地图通关** (MAP_CLEARED) | Boss击败 | 胜利BGM + 通关SFX |
| **战败** (DEFEATED) | 战斗失败 | 战败BGM + 低沉失败音 |
| **暂停** (PAUSED) | 游戏暂停 | 所有音频暂停（BGM从当前位置暂停，恢复时继续） |

**场景切换音频过渡矩阵（完整版）：**

| 从→到 | 当前音频动作 | 新音频动作 |
|--------|-------------|-----------|
| 主菜单→身份选择 | 主菜单BGM降低至 -6dB（0.5s） | — |
| 身份选择→主菜单 | 主菜单BGM恢复至 0dB（0.5s） | — |
| 身份选择→探索 | 主菜单BGM淡出(1.0s) | 地图BGM淡入(1.5s) + 环境音 |
| 探索→战斗 | 探索BGM快速淡出(0.5s) | 战斗BGM淡入(0.5s)，环境音 -8dB |
| 战斗→探索 | 战斗BGM淡出(1.0s) | 探索BGM淡入(1.0s)，环境音恢复至 -10dB |
| 探索→商店 | 探索BGM降低至 -10dB（0.5s，不断） | 商店环境音淡入(0.5s)，环境音 -6dB |
| 商店→探索 | 商店环境音淡出(0.3s) | 探索BGM恢复至 0dB（0.5s），环境音恢复至 -10dB |
| 探索→事件 | 探索BGM降低至 -6dB（0.3s，不断） | 环境音 -6dB |
| 事件→探索 | — | 探索BGM恢复至 0dB（0.3s），环境音恢复至 -10dB |
| 事件→战斗 | 探索BGM快速淡出(0.3s) | 战斗BGM淡入(0.5s)，环境音 -8dB |
| 战斗→通关结算 | 战斗BGM淡出(0.3s) | 胜利BGM淡入(0.5s) |
| 战斗→战败 | 战斗BGM快速渐弱(0.5s) | 战败BGM淡入(0.3s) |
| 探索→渡劫 | 探索BGM淡出(0.3s) | 渡劫BGM淡入(0.3s) |
| 渡劫战中→通关结算 | 渡劫BGM淡出(0.3s) | 胜利BGM淡入(0.5s) |
| 渡劫战中→战败 | 渡劫BGM淡出(0.5s) | 战败BGM淡入(0.3s) |
| 暂停→任意状态 | `resume_all()` — 从暂停点恢复所有音频 | — |
| 任意状态→暂停 | `pause_all()` — 所有音频暂停 | — |
| 通关结算→探索 | 胜利BGM淡出(1.0s) | 探索BGM淡入(1.0s) + 环境音 |
| 战败→主菜单 | 战败BGM淡出(1.0s) | 主菜单BGM淡入(1.5s) |
| 通关结算→主菜单 | 胜利BGM淡出(1.0s) | 主菜单BGM淡入(1.5s) |
| 任意→卡组编辑 | BGM降低至 -12dB（0.5s） | — |
| 卡组编辑→任意 | 恢复前一状态BGM | — |

标记 N/A 的转换（不会在游戏中发生）：
- 商店中→战斗中（商店不触发战斗）
- 身份选择→战斗中（无此流程）
- 战败→任意非主菜单状态（战败后必须回到主菜单）

#### 10. 对话与音频的配合

对话系统通过音频系统播放角色语音：

| 对话事件 | 音频 | MVP 状态 |
|---------|------|:--------:|
| 新说话者出现 | 该角色的"发声"短音效（0.3s，区分角色） | ✅ MVP |
| 打字机文本效果 | 逐字显示音（可选） | ✅ MVP |
| 重要剧情节点 | 叙事BGM短暂变调 | ⏳ VS |
| bark 气泡弹出 | 轻快气泡音效 | ✅ MVP |
| 角色完整配音 | 每句台词对应语音文件 | ❌ Full Vision |

- MVP 有 **1 个「发声」短音效/角色**（说话者出现时播放，0.3s）+ **1 个「情绪反应」短音效/角色**（惊恐/愤怒/喜悦，0.5s）
- Voice 总线基础设施（索引5, -1dB）在 MVP 中搭建，但完整配音资产延后至 Full Vision
- 角色发声短音效示例：林渊=沉稳低音，苏剑鸣=中音，月清霜=清脆高音

#### 11. 无障碍音频设计

| 功能 | 说明 | MVP状态 |
|------|------|:------:|
| **字幕系统** | 所有对话内容可选择显示字幕（开/关，默认开） | ✅ MVP |
| **单声道切换** | 设置 → 音频 → 单声道输出开关（适合单侧听力玩家） | ✅ MVP |
| **视觉音频提示** | 关键音频事件伴有屏幕边缘闪烁/HUD图标（伤害命中、低HP警告、渡劫雷击） | ⏳ VS |
| **F1 静音视觉指示** | HUD 角落显示静音图标（扬声器 + 斜线） | ✅ MVP |
| **音频音量 0% = 停止播放** | 音量滑动条拖至 0% 时完全停止该总线的播放（与F1静音的Master Mute区分） | ✅ MVP |

---

## 公式

### 1. 交叉淡入淡出曲线

BGM 过渡使用 **ease-in-out (S曲线)** 以获得最自然的听觉过渡：

```
Tween 插值类型: Tween.TRANS_SINE, Tween.EASE_IN_OUT
target_volume_db = 目标 dB 值
fade_duration_sec = 过渡时长

旧BGM: 从 当前dB 插值到 -80dB（静音），duration = fade_out_sec
新BGM: 从 -80dB（静音）插值到 目标dB，duration = fade_in_sec
```

两段 Tween 同时启动（平行淡出+淡入 = 交叉淡入淡出），而非顺序执行。Boss 战过渡例外：先淡出完成(0.3s)再淡入(0.3s)——制造冲击感。

### 2. SFX 池淘汰算法

```python
def request_sfx(sfx_id, eviction_priority):
    if sfx_id in cooldown_tracker and (now - cooldown_tracker[sfx_id]) < 50ms:
        emit signal("sfx_cooldown_discarded", sfx_id, now - cooldown_tracker[sfx_id])
        return  # 静默丢弃
    
    if active_player_count < MAX_SIMULTANEOUS:  # MAX = 12
        player = acquire_free_player()
        assign_stream(player, sfx_id)
        start_playback_with_randomization(player)
        cooldown_tracker[sfx_id] = now
        return
    
    # 池已满——按淘汰优先级→年龄排序，找牺牲者
    candidate = min(active_players,
                    key=lambda p: (p.eviction_priority, p.start_time))
    
    if eviction_priority <= candidate.eviction_priority:
        # 新SFX的优先级不高于任何现存SFX → 拒绝
        emit signal("sfx_pool_exhausted", sfx_id)
        return
    
    # 淘汰牺牲者，播放新SFX
    stop_player(candidate)
    assign_to_player(candidate, sfx_id, eviction_priority)
    start_playback_with_randomization(candidate)
    cooldown_tracker[sfx_id] = now
```

### 3. 闪避dB计算

```
当 Voice 播放时:
  BGM target_db = BGM.current_db - DUCK_VOICE_BGM  # -10dB
  Ambient target_db = Ambient.current_db - DUCK_VOICE_AMBIENT  # -15dB
  
Tween 过渡:
  BGM: Tween BGM Bus volume_db → target_db, attack=200ms
  当 Voice 停止时:
    BGM: Tween BGM Bus volume_db → 原值, release=500ms
```

### 4. 音量总线公式

```
玩家听到的实际BGM音量计算:
  effective_bgm_db = master_db + bgm_bus_db + player_bgm_slider_offset

其中:
  master_db = AudioServer.get_bus_volume_db(MASTER_INDEX)
  bgm_bus_db = AudioServer.get_bus_volume_db(BGM_INDEX)
  player_bgm_slider_offset = 映射自设置UI滑动条 0%-100% → dB范围[-40, 0]
  
  effective_bgm_db 上限 = -0.5dB (Master Limiter ceiling)
```

---

## 边缘情况

| # | 场景 | 行为 |
|---|------|------|
| 1 | **BGM 文件损坏/缺失** | `play_bgm()` 失败时记录错误日志，降至静默（不崩溃），保持上一首BGM继续播放(如存在)。在开发构建中弹出警告对话框 |
| 2 | **SFX 文件损坏/缺失** | `play_sfx()` 静默失败 + `push_warning("SFX not found: " + sfx_id)`。不影响其他SFX播放 |
| 3 | **过渡期间二次场景切换** | 中断当前 Tween → 从当前dB值立即启动新过渡。例如：探索→战斗 淡入途中切换到商店→从当前中间dB值淡出到商店BGM |
| 4 | **SFX池完全饱和** | 12个槽全被优先级2 SFX占用 → 新请求被拒绝，emit `sfx_pool_exhausted(sfx_id)` 信号，不播放 |
| 5 | **F1 快速连打(Spam)** | `toggle_mute()` 内部使用 debounce 200ms——200ms内的重复调用被忽略。防止静音/恢复状态抖动 |
| 6 | **F1 静音后场景切换** | 静音状态为全局持久——新场景BGM同样静音。取消静音后恢复 |
| 7 | **游戏窗口失焦/最小化** | 默认所有音频继续播放（不暂停）。可在设置中添加"后台静音"选项(默认关) |
| 8 | **音频设备热插拔** | Godot `AudioServer` 自动处理设备切换。不崩溃。播放中的音频继续在新设备上输出 |
| 9 | **设置中拖动音量滑动条为0%** | 该总线完全静音(volume_db = -80)，但不停止播放（BGM继续循环只是听不到）。与F1的Master Mute不同——F1是停止Master输出 |
| 10 | **存档时BGM正在播放** | 存档记录当前BGM ID和播放位置(ms)。读档后恢复到存档时的BGM和位置，继续播放 |
| 11 | **读档后场景不匹配** | 如果存档中的BGM与读档后场景不匹配，优先播放当前场景的默认BGM（忽略存档BGM） |
| 12 | **同一BGM重复请求** | 如果请求的 `bgm_id` 与当前播放相同 → 忽略（不重新开始，不交叉淡入淡出到自己） |
| 13 | **环境音预设缺失** | `play_ambient()` 对不存在的 ambient_id 静默失败 + 日志警告。不影响BGM/SFX |
| 14 | **Godot AudioServer 初始化失败** | 游戏启动时 AudioServer 不可用（极罕见） → 音频系统进入"静默模式"——所有API调用为no-op，不崩溃。在开发日志中记录 |
| 15 | **内存不足时加载SFX** | `ResourceLoader.load_threaded_request()` 失败 → 日志错误，该SFX标记为"不可用"，对后续请求静默丢弃。不影响已加载的SFX |

---

## 调优参数

| 参数 | 默认值 | 安全范围 | 单位 | 说明 |
|------|:-----:|:--------:|:----:|------|
| BGM 默认音量 | 0 | -6 ~ +3 | dB | 参考基准 |
| SFX 默认音量 | -3 | -12 ~ +0 | dB | 低于BGM 3dB |
| UI 默认音量 | -8 | -20 ~ -3 | dB | 低于SFX 5dB |
| Ambient 默认音量 | -10 | -20 ~ -5 | dB | 最低背景层 |
| Voice 默认音量 | -1 | -6 ~ +0 | dB | 清晰优先 |
| BGM 淡入时长 | 1.5 | 0.5 ~ 3.0 | s | 普通场景切换 |
| BGM 淡出时长 | 1.0 | 0.3 ~ 2.0 | s | 普通场景切换 |
| 战斗 BGM 切换速度 (淡出) | 0.5 | 0.3 ~ 1.0 | s | 探索→战斗快速过渡 |
| 战斗 BGM 切换速度 (淡入) | 0.5 | 0.3 ~ 1.0 | s | 探索→战斗快速过渡 |
| Boss 战 BGM 淡入 | 0.3 | 0.2 ~ 0.5 | s | 冲击力优先 |
| 胜利 BGM 淡入 | 0.5 | 0.3 ~ 1.0 | s | — |
| 战败 BGM 淡入 | 0.3 | 0.2 ~ 0.5 | s | — |
| 商店中 BGM 降低 | -10 | -6 ~ -15 | dB | 相对BGM默认值 |
| 事件中 BGM 降低 | -6 | -3 ~ -10 | dB | 相对BGM默认值 |
| 同时播放 SFX 上限 | 12 | 8 ~ 16 | 个 | 超过时触发淘汰 |
| SFX 池总节点数 | 16 | 12 ~ 20 | 个 | 4 个余量 |
| 同 SFX 最小间隔 | 50 | 30 ~ 100 | ms | 防连击爆音 |
| 战斗中攻击 SFX 间隔 | 100 | 50 ~ 150 | ms | 防多角色叠加 |
| SFX pitch 随机化范围 | ±10% | ±0% ~ ±25% | pitch_scale | 防机械重复 |
| SFX volume 随机化范围 | ±3 | ±0 ~ ±6 | dB | 防机械重复 |
| 战斗中环境音降低 | -8 | -5 ~ -12 | dB | 突出战斗音效 |
| 事件/商店环境音降低 | -6 | -3 ~ -10 | dB | — |
| Voice→BGM 闪避量 | -10 | -6 ~ -15 | dB | — |
| Voice→Ambient 闪避量 | -15 | -10 ~ -20 | dB | — |
| 闪避起音时间 | 200 | 100 ~ 500 | ms | — |
| 闪避释音时间 | 500 | 200 ~ 1000 | ms | — |
| UI 最低播放时长 | 80 | 50 ~ 150 | ms | 防快速导航卡顿 |
| F1 静音防连打 debounce | 200 | 100 ~ 500 | ms | 防止状态抖动 |
| BGM 交叉淡入淡出曲线 | S曲线 | 线性/S曲线/指数 | — | Tween.TRANS_SINE, EASE_IN_OUT |

---

## 音频资产格式规范

| 类别 | 格式 | 采样率 | 声道 | 比特率/质量 | 响度目标 | 循环 |
|------|:----:|:------:|:----:|:----------:|:--------:|:----:|
| **BGM** | WAV (MVP) / OGG (备选) | 44.1 kHz | 立体声 | WAV 16-bit / OGG q7 | -16 LUFS (Integrated) | 是 |
| **SFX** | OGG Vorbis | 44.1 kHz | 单声道 | q5 (~160 kbps) | -14 LUFS (Short-term) | 否（例外：环境持续音效可循环） |
| **UI 音效** | OGG Vorbis | 44.1 kHz | 单声道 | q4 (~128 kbps) | -14 LUFS (Short-term) | 否 |
| **环境音** | OGG Vorbis | 44.1 kHz | 立体声 | q5 (~160 kbps) | -20 LUFS (Integrated) | 是 |
| **角色发声** | OGG Vorbis | 22.05 kHz | 单声道 | q5 (~160 kbps) | -16 LUFS (Short-term) | 否 |

**Godot 导入设置**：
- BGM: Load Mode = `Sampled`, Loop Mode = `Forward`（WAV 通过 `loop_begin`/`loop_end` 设置循环点）
- SFX: Load Mode = `Sampled`, Loop Mode = `Disabled`
- 环境音: Load Mode = `Sampled`, Loop Mode = `Forward`
- 角色发声: Load Mode = `Sampled`, Loop Mode = `Disabled`

---

## 用户界面需求

| 界面 | 核心功能 |
|------|----------|
| **设置-音频** | 总音量(Master) / 音乐(BGM) / 音效(SFX) / 环境音(Ambient) 滑动条 + 语音(Voice)滑动条 [灰显，标注"即将推出"] |
| **设置-音频** | 单声道输出开关 |
| **设置-音频** | 字幕开关（默认开） |
| **设置-无障碍** | 视觉音频提示开关（默认关，VS阶段实现） |
| **HUD** | F1静音状态图标（扬声器+斜线，静音时显示） |

---

## 依赖关系

| 系统 | 数据流出（目标→本系统） | 数据流入（本系统→目标） |
|------|----------------------|---------------------|
| **游戏状态管理器** | 场景切换信号 → `set_state()` | —（音频系统是纯粹事件消费者） |
| **事件系统** | 事件触发 → `play_sfx()` | — |
| **战斗系统** | 战斗回合/阶段信号 → `set_state()` / `play_sfx()` | — |
| **探索系统** | 地图切换 → `set_state()` | — |
| **渡劫突破系统** | 渡劫触发/成功/失败 → `set_state()` / `play_sfx()` | — |
| **UI系统** | UI交互信号 → `play_sfx()` | — |
| **设置系统** (`main-menu-system.md`) | 音量变更 → `set_bus_volume()`；静音切换 → `toggle_mute()` | — |
| **卡牌系统** | 抽牌/出牌/升级 → `play_sfx()` | — |
| **卡组编辑系统** | 卡牌放入/移出 → `play_sfx()` | — |
| **身份选择系统** | 身份确认 → `set_state()` | — |
| **修为养成系统** | 修为条里程碑 → `play_sfx()` | — |
| **对话系统** | 角色发声 → `play_sfx()` | — |
| **炼丹炼器系统** | (Vertical Slice) 炼丹/铭刻 → `play_sfx()` | — |

**注**：音频系统不向任何其他系统主动推送数据。它是游戏中最纯粹的"事件消费者"——仅接收请求并播放，不产生对其他系统有影响的输出。所有"数据流入"列均为空。

---

## 验收标准

### BGM

- **AC-BGM-01**：GIVEN 游戏启动完成，WHEN 进入主菜单，THEN `bgm_main_menu` 开始播放，BGM Bus `volume_db = 0dB`，播放状态为循环
- **AC-BGM-02**：GIVEN 主菜单BGM正在播放，WHEN 玩家选择"新游戏"并确认身份进入探索，THEN `bgm_main_menu` 在 1.0s 内淡出至 -80dB，同时 `bgm_explore_qi_refining` 在 1.5s 内从 -80dB 淡入至 0dB（交叉淡入淡出），环境音预设开始播放
- **AC-BGM-03**：GIVEN 探索BGM正在播放，WHEN 触发战斗场景切换，THEN 探索BGM在 0.5s 内淡出至 -80dB，同时战斗BGM在 0.5s 内从 -80dB 淡入至 0dB
- **AC-BGM-04**：GIVEN 战斗BGM正在播放，WHEN 战斗以胜利结束进入结算，THEN 战斗BGM在 0.3s 内淡出至 -80dB，`bgm_victory` 在 0.5s 内从 -80dB 淡入至 0dB
- **AC-BGM-05**：GIVEN 战斗BGM正在播放，WHEN 战斗以战败结束，THEN 战斗BGM在 0.5s 内渐弱至 -80dB，`bgm_defeat` 在 0.3s 内从 -80dB 淡入至 0dB
- **AC-BGM-06**：GIVEN 探索BGM正在播放，WHEN 进入商店，THEN BGM Bus `volume_db` 在 0.5s 内降低至 -10dB（BGM继续播放不停止），商店环境音在 0.5s 内淡入至 -10dB
- **AC-BGM-07**：GIVEN 在商店中，WHEN 离开商店回到探索，THEN BGM Bus `volume_db` 在 0.5s 内恢复至 0dB，商店环境音在 0.3s 内淡出，探索环境音恢复至 -10dB
- **AC-BGM-08**：GIVEN 渡劫战斗触发，WHEN 场景切换，THEN 渡劫BGM (`bgm_tribulation`) 在 0.3s 内淡入至 0dB，独立于普通战斗BGM
- **AC-BGM-09**：GIVEN 同一首BGM正在播放，WHEN 再次请求播放相同 `bgm_id`，THEN 请求被忽略（不重新开始，不交叉淡入淡出到自己）
- **AC-BGM-10**：GIVEN BGM正在播放，WHEN 场景切换过渡期间（淡入/淡出未完成）触发第二次场景切换，THEN 当前Tween被中断，从当前dB值启动新过渡

### SFX

- **AC-SFX-01**：GIVEN 战斗中玩家打出一张卡牌，WHEN `play_sfx("card_play_gongfa")` 被调用，THEN 对应卡牌类型SFX播放，`pitch_scale` 在 0.9-1.1 范围内随机，`volume_db` 在 -3dB±3dB 范围内随机
- **AC-SFX-02**：GIVEN 12个SFX正在同时播放（`active_player_count = 12`），WHEN 第13个SFX请求到达且其淘汰优先级(2)高于池中最低优先级(0或1)的某个SFX，THEN 最低优先级中最旧的SFX被停止，新SFX播放
- **AC-SFX-03**：GIVEN 12个SFX正在同时播放且全部为优先级2，WHEN 第13个SFX请求到达，THEN 请求被拒绝，`sfx_pool_exhausted(sfx_id)` 信号被 emit，不播放
- **AC-SFX-04**：GIVEN `sfx_id = "sword_hit"` 在 t=0ms 播放，WHEN 同一 `sfx_id` 在 t=30ms 再次请求，THEN 请求被静默丢弃，`sfx_cooldown_discarded("sword_hit", 30)` 信号被 emit，不产生可听输出
- **AC-SFX-05**：GIVEN `sfx_id = "sword_hit"` 最后一次播放距今超过50ms，WHEN 同一 `sfx_id` 再次请求，THEN SFX正常播放，冷却计时器重置
- **AC-SFX-06**：GIVEN 战斗中多角色同时攻击，WHEN 同一100ms窗口内超过1个攻击SFX请求，THEN 间隔短于100ms的请求被丢弃（战斗攻击间隔门控）
- **AC-SFX-07**：GIVEN SFX资源文件在磁盘上缺失或损坏，WHEN `play_sfx("missing_sfx")` 被调用，THEN 静默失败，`push_warning("SFX not found: missing_sfx")` 被记录，不影响其他SFX播放

### 总线独立性

- **AC-BUS-01**：GIVEN 所有总线正常播放，WHEN 通过设置UI将SFX音量滑动条拖至 -40dB，THEN SFX Bus `volume_db = -40dB`，BGM Bus 保持 0dB 不变，Ambient Bus 保持 -10dB 不变（其他总线同样不变）
- **AC-BUS-02**：GIVEN 设置UI音频面板打开，WHEN 调用 `get_bus_volume(AudioBus.BGM)`，THEN 返回当前BGM Bus的dB值，与设置面板显示一致（±0.5dB 精度）

### 暂停/恢复

- **AC-PAUSE-01**：GIVEN BGM正在播放（t=5.0s位置），WHEN 玩家按下暂停，THEN 所有音频暂停（`pause_all()` 被调用），BGM在 t=5.0s 处停止
- **AC-PAUSE-02**：GIVEN 游戏处于暂停状态，WHEN 玩家取消暂停，THEN 所有音频恢复（`resume_all()` 被调用），BGM从 t=5.0s 处继续播放

### 静音

- **AC-MUTE-01**：GIVEN 所有音频正常播放，WHEN 玩家按下F1，THEN Master Bus `volume_db = -80dB`（静音），HUD显示静音图标（扬声器+斜线）
- **AC-MUTE-02**：GIVEN 处于静音状态，WHEN 玩家再次按下F1，THEN Master Bus `volume_db` 恢复至静音前的值，HUD静音图标消失
- **AC-MUTE-03**：GIVEN 处于静音状态，WHEN 玩家在200ms内连续按下F1 3次，THEN 只有第一次被处理，后续调用被debounce忽略（静音状态保持，不抖动）
- **AC-MUTE-04**：GIVEN 处于静音状态，WHEN 场景切换到新场景，THEN 新场景BGM开始播放但保持静音（Master Bus仍为 -80dB），取消静音后正常听到

### 环境音

- **AC-AMBIENT-01**：GIVEN 进入探索中，WHEN 地图加载完成，THEN 对应地图的环境音预设开始播放，Ambient Bus `volume_db = -10dB`，与BGM叠加
- **AC-AMBIENT-02**：GIVEN 环境音正在播放，WHEN 进入战斗，THEN Ambient Bus `volume_db` 在 0.5s 内降低至 -18dB（=-10dB - 8dB），环境音继续播放不停止
- **AC-AMBIENT-03**：GIVEN 战斗结束回到探索，WHEN 场景切换完成，THEN Ambient Bus `volume_db` 在 0.5s 内恢复至 -10dB

### 无障碍

- **AC-ACCESS-01**：GIVEN 字幕设置为开启，WHEN 对话文本显示，THEN 字幕文本在对话文本出现后100ms内渲染在屏幕底部
- **AC-ACCESS-02**：GIVEN 单声道开关设为开启，WHEN 任何音频播放，THEN 左右声道输出相同信号（通过 AudioEffect 验证或手动听觉测试）
- **AC-ACCESS-03**：GIVEN 所有音量滑动条拖至0%，WHEN 游戏运行，THEN 所有总线输出 -80dB，无音频可听

---

## 待解决问题

| # | 问题 | 影响 | 建议解决时间 |
|---|------|------|------------|
| 1 | 8首 BGM 的制作预算和外包时间线需要确认（古琴/笛箫/琵琶/二胡/编钟/大鼓的录音或采样库采购） | 资产制作排期 | 预生产阶段 |
| 2 | SFX 具体数量需在卡牌系统、战斗系统和探索系统的音频审计完成后最终确定（当前 MVP 估算 50 个） | 加载策略微调 | 架构阶段 |
| 3 | 是否支持音频资源的热更新（不更新游戏本体替换音频）？取决于 Godot 导出打包方式 | 运维 | 架构阶段 |
| 4 | 元婴/化神独立探索BGM、商店/事件BGM、身份选择BGM是否在Vertical Slice还是Full Vision追加 | 内容规划 | VS 规划时 |
| 5 | Godot Ogg Vorbis 循环间隙（5-30ms）是否在 WAV 方案下完全消除？需在 MVP 原型的 Godot 4.6 上实测验证 | 技术验证 | 架构阶段 |
| 6 | 完整配音管线（录音、本地化、唇同步）的范围和预算——Full Vision 决策 | 预算规划 | VS 后评估 |