# 资产规范 — system：audio（音频资产——BGM/SFX/环境音，纯描述）

> **来源**：`design/gdd/audio-system.md`（总线/状态机/过渡矩阵/格式规范——技术真源）、`design/gdd/card-system.md` L576-630（卡牌音效唯一权威）、`design/gdd/combat-ui-system.md` L620-630、`design/gdd/tribulation-system.md` L423-428、`design/gdd/main-menu-system.md` L230-236、`design/gdd/exploration-system.md` L715-722、`design/gdd/dialogue-system.md` L309-323、`design/art/art-bible.md` §8.1（源文件格式与命名）+ §2（情绪氛围映射）
> **美术圣经**：design/art/art-bible.md
> **生成日期**：2026-10-20
> **审查模式**：Solo（audio-system.md 已有完整系统设计——本 spec 只做资产级清单化：编号、命名、时长/响度/格式逐条落实；不生成提示词，不复制系统设计）
> **状态**：25 个音频资产已规范 / 0 个已批准 / 0 个生产中 / 0 个完成
> **权威链**：总线/过渡/状态机以 audio-system.md §9 为唯一真源；卡牌音效以 card-system.md 为唯一权威；art-bible §8 管源文件格式与命名——本 spec 与三者冲突时以权威链为准

---

## 全组技术参数

| 参数 | 值 | 来源 |
|------|-----|------|
| 源文件 | WAV 48kHz/24bit（art-bible §8.1.1——BGM 按 48kHz 制作避免重采样伪影，R-06 spike 裁决） | art-bible + audio-system |
| 引擎格式 | Ogg Vorbis：BGM q5（含循环点元数据）、SFX q5、UI q4、环境音 q5 | audio-system §格式规范 |
| 声道 | SFX 单声道；BGM/环境音 立体声 | audio-system |
| 响度 | BGM -16 LUFS Integrated；SFX -14 LUFS Short-term；环境音 -20 LUFS Integrated | audio-system（裁决见下） |
| 循环 | BGM/环境音 Loop Forward（loop_begin/loop_end 元数据）；SFX Loop Disabled | audio-system §Godot 导入 |
| 命名 | `assets/audio/bgm/[chapter]/[track].wav`、`assets/audio/sfx/[category]/[sfx].wav`、`assets/audio/ambient/[layer].wav`——snake_case 小写英文，**禁止中文文件名**（D3D12 Unicode 路径风险，§8.1.2） | art-bible §8.1.2 |
| 总线 | Master(0dB Limiter) → BGM(0dB EQ)/SFX(-3dB Limiter: Combat/Card/Explore)/UI(-8dB)/Ambient(-10dB Reverb)——按总线名引用不按索引 | audio-system §总线 |
| 并发 | SFX 池 12 并发+16 节点+三级淘汰；50ms 冷却；pitch ±10%/volume ±3dB 随机化 | audio-system §混音 |
| 内存 | BGM 常驻 2 首（8 首 × 5-15MB）；SFX 三层加载 T1~15/T2~20/T3~15 | audio-system §内存预算 |

**响度冲突裁决**：card-system.md 写 SFX -18 LUFS/环境音 -23 LUFS，与 audio-system.md 的 -14/-20 不一致——**裁决以 audio-system.md §格式规范为准**（该文件是音频技术真源；card-system 的卡牌音效**内容**仍以其为权威，但**响度/格式**统一按 audio-system）。

**生产方式**：外包录音/民乐采样库授权 + Wwise 式程序化处理。**不适用 AI 生图管线**；AI 音乐生成（Suno 等）可作为原型参考但不作正式资产（民乐配器真实性不足）。本 spec 为**描述性规范**——每条给声音特征描述，供音频供应商或采购采样库时比对。

---

## 一、BGM（8 条，ASSET-339~346）

| ID | 名称 | 命名 | 场景 | 配器与情绪描述 | 时长 |
|----|------|------|------|--------------|------|
| ASSET-339 | 主菜单 BGM | `bgm/main_menu.wav` | 主菜单启动循环 | 古琴独奏；空灵悠远的修仙主题；「深夜灯下、内省」（art-bible §2） | 2-3min 循环 |
| ASSET-340 | 探索 BGM·炼气 | `bgm/explore/lianqi.wav` | 炼气域探索 | 笛箫为主；宁静山水；单薄清亮——成长弧线起点 | 2-3min 循环 |
| ASSET-341 | 探索 BGM·筑基 | `bgm/explore/zhuji.wav` | 筑基域探索 | 笛箫+琵琶；悠远中略带紧张冒险感 | 2-3min 循环 |
| ASSET-342 | 探索 BGM·金丹+ | `bgm/explore/jindan.wav` | 金丹及以上域探索 | 编钟+乐队；壮阔仙侠 | 2-3min 循环 |
| ASSET-343 | 战斗 BGM·普通 | `bgm/combat/normal.wav` | 普通战斗 | 大鼓+琵琶；节奏适中；「锐利清醒紧绷」而非热血轰炸 | 1.5-2min 循环 |
| ASSET-344 | 战斗 BGM·精英 | `bgm/combat/elite.wav` | 精英战斗 | 大鼓+二胡；普通战斗变调加压 | 1.5-2min 循环 |
| ASSET-345 | 渡劫/Boss BGM | `bgm/combat/tribulation.wav` | Boss/渡劫战 | 编钟+大鼓+二胡；恢弘紧迫；「磅礴敬畏天地共鸣」——编钟齐鸣对应丹青释放的色彩特权 | 2min 循环 |
| ASSET-346 | 胜利/战败短曲 | `bgm/outcome/victory.wav` + `defeat.wav` | 战斗结算 | 胜=编钟凯旋+「收剑入鞘的平静」；败=二胡低沉「沉重但非绝望」 | 各 15-20s 一次性 |

**过渡**：曲目切换全部走 audio-system §9 过渡矩阵（22 行状态机）——本 spec 不复制。

---

## 二、SFX——卡牌类（7 条，ASSET-347~353）

> 内容权威：card-system.md L576-630（本组描述与其一致；分歧时以 card-system 为准）

| ID | 名称 | 命名 | 描述 | 时长 |
|----|------|------|------|------|
| ASSET-347 | 抽牌 | `sfx/card/draw.wav` | 纸牌滑出的清脆摩擦声 | ~150ms |
| ASSET-348 | 出牌·角色 | `sfx/card/play_role.wav` | 沉稳落地/人物登场感 | ~200ms |
| ASSET-349 | 出牌·功法 | `sfx/card/play_technique.wav` | 书卷翻动 + 笛箫短促音阶（气息/内力流动感） | ~300ms |
| ASSET-350 | 出牌·法宝 | `sfx/card/play_artifact.wav` | 金属碰撞/编钟单音（法器激活共鸣） | ~250ms |
| ASSET-351 | 出牌·阵法 | `sfx/card/play_formation.wav` | 低沉嗡鸣 + 阵图展开环境底噪 | ~500ms |
| ASSET-352 | 出牌·丹药 | `sfx/card/play_pill.wav` | 液体倾注/陶瓷轻碰（丹炉开启） | ~300ms |
| ASSET-353 | 出牌·符箓 | `sfx/card/play_talisman.wav` | 纸张燃烧 + 低频符咒嗡鸣 | ~300ms |

**稀有度音频梯度**：参数化 pitch-shift + EQ 实现（白基准/蓝+1半音/紫+2半音/金+3半音+和声层/暗金+5半音+双和声+混响尾音）——**无需额外样本**，5 个参数配置而非资产。

---

## 三、SFX——战斗与突破（6 条，ASSET-354~359）

| ID | 名称 | 命名 | 描述 | 时长 |
|----|------|------|------|------|
| ASSET-354 | 攻击命中 | `sfx/combat/hit.wav` | 金石之声的短促打击；暴击叠加额外高音层；境界压制时低沉压迫变体 | ~200ms |
| ASSET-355 | 角色阵亡 | `sfx/combat/death.wav` | 低沉消散音——与 VFX 淡墨晕染同步的声音语言（ASSET-329） | ~600ms |
| ASSET-356 | 渡劫雷鸣 | `sfx/tribulation/thunder.wav` | 雷鸣 + 闪电击打；低频轰鸣 + 高频劈裂分层 | ~1s |
| ASSET-357 | 突破成功 | `sfx/tribulation/breakthrough.wav` | 编钟齐鸣 + 古琴泛音上扬（金光升起的声音对应丹青释放 ASSET-333） | ~1.5s |
| ASSET-358 | 突破失败 | `sfx/tribulation/fail.wav` | 二胡低沉短句 + 修为散失的下行气声 | ~1s |
| ASSET-359 | 稀有掉落 | `sfx/reward/drop_rare.wav` | 金卡=升华音高+短乐句 1s；暗金=低沉圣物共鸣+叙事揭示乐句 2-3s（参考 Hades 传奇祝福） | 1-3s |

---

## 四、SFX——探索与事件（4 条，ASSET-360~363）

| ID | 名称 | 命名 | 描述 | 时长 |
|----|------|------|------|------|
| ASSET-360 | 节点移动/到达 | `sfx/explore/node_move.wav` + `node_arrive.wav` | 移动=轻快脚步/御风声；到达=短促提示音（节点类型音调分档——参数化 pitch 区分战斗/事件/商店） | 各 ~150ms |
| ASSET-361 | 地图展开/解锁 | `sfx/explore/map_unfold.wav` + `map_unlock.wav` | 展开=轻风声+纸张舒展；解锁=清脆锁开声 | 各 ~400ms |
| ASSET-362 | 事件交互 | `sfx/event/popup.wav` + `reward.wav` | 弹出=纸张展开；获得奖励=灵石清脆确认；失败惩罚=低沉短音 | 各 ~200ms |
| ASSET-363 | 行动力耗尽 | `sfx/explore/ap_exhausted.wav` | 低沉的能量枯竭音 | ~300ms |

---

## 五、SFX——UI（2 条，ASSET-364~365）

| ID | 名称 | 命名 | 描述 | 时长 |
|----|------|------|------|------|
| ASSET-364 | UI 确认/取消 | `sfx/ui/confirm.wav` + `cancel.wav` | 确认=编钟单音清亮（主菜单点击同源）~80ms；取消=低沉短音 ~60ms；悬停/滚动**无声**；通知 ~150ms；错误 ~120ms（朱砂红告警的音频对应） | 60-150ms |
| ASSET-365 | 面板开合/按键绑定 | `sfx/ui/panel_open.wav` + `keybind_set.wav` | 面板=纸张展开/收起；绑定成功=短促确认；冲突=低沉警告（main-menu 004 story 已接线） | 各 ~150ms |

---

## 六、角色语音（1 条组，ASSET-366）

| ID | 名称 | 命名 | 描述 | 时长 |
|----|------|------|------|------|
| ASSET-366 | 角色发声组 | `sfx/voice/[char]_speak.wav` + `[char]_react.wav` | 每角色：发声短音 0.3s（林渊=沉稳低音/苏剑鸣=轻快中音/月清霜=清脆高音）+ 情绪反应 0.5s；MVP 覆盖 3 主角，OGG q5 22.05kHz 单声道 -16 LUFS | 0.3/0.5s |

---

## 七、环境音（4 条，ASSET-367~370）

> 环境音按「地图预设 + 最多 3 层叠加」结构（audio-system §6）——每域 1 个预设组合，资产层面只规范 4 个通用层模板

| ID | 名称 | 命名 | 描述 | 规格 |
|----|------|------|------|------|
| ASSET-367 | 山域环境层 | `ambient/mountain_wind.wav` + `bird.wav` + `stream.wav` | 远处鸟鸣+溪流+风声——「云雾缭绕的仙山」；3 层独立循环随机化 | 各 1-2min 循环 |
| ASSET-368 | 海域环境层 | `ambient/sea_wave.wav` + `gull.wav` | 海浪拍岸+鸥鸣——碎星/归墟水场景 | 各 1-2min 循环 |
| ASSET-369 | 洞窟环境层 | `ambient/cave_drip.wav` + `cave_wind.wav` | 滴水+低频洞风——走 Ambient 总线 Reverb；进入时环境音骤然收敛制造「静默的重量」 | 各 1-2min 循环 |
| ASSET-370 | 室内/商铺环境层 | `ambient/shop_ambient.wav` | 轻人声底噪+器物轻响；-6dB 淡入不停止（弹窗时不清场） | 1-2min 循环 |

**五域预设映射**（组合引用不另立资产）：东域=367 / 碎星=368 / 苍玄=367+城市底噪 / 西域=风沙变体（367 风层换沙鸣采样）/ 归墟=369+368 混合。域专属采样变体在 production 阶段按需追加为子交付物。

---

## 交付汇总与预算

| 组 | 数量 | ID 范围 | 格式 |
|----|:--:|:--:|------|
| BGM | 8 曲 | ASSET-339~346 | WAV 48kHz/24bit 源 → OGG q5 |
| 卡牌 SFX | 7 | ASSET-347~353 | OGG q5 单声道 |
| 战斗/突破 SFX | 6 | ASSET-354~359 | OGG q5 单声道 |
| 探索/事件 SFX | 4（8 变体） | ASSET-360~363 | OGG q5 单声道 |
| UI SFX | 2（6 变体） | ASSET-364~365 | OGG q4 单声道 |
| 角色语音 | 1 组 | ASSET-366 | OGG q5 22.05kHz |
| 环境音 | 4 组（9 层） | ASSET-367~370 | OGG q5 立体声 |
| **合计** | **25 资产条目**（约 40 个音频文件） | ASSET-339~370 | |

**MVP 优先**：339（主菜单）/343（战斗）/347-353（卡牌）/354-355（命中阵亡）/364（UI）——约 10 条先行；其余 VS/FV 分批。

**验收锚点**：
- 全部文件名 snake_case 英文（禁中文——CI 检查）
- BGM 循环点元数据完整（R-06 spike 实测零间隙标准）
- 响度达标（BGM -16 / SFX -14 / 环境 -20 LUFS——EBU R128 表头验证）
- 总线路由正确（按名称非索引）
- 关键静默场景（Boss 倒下后、渡劫前一息）环境音收敛——「静默是重量」设计验证

**跨文档冲突登记**：
1. 采样率三处不一致（44.1k/48k/48k24bit）→ **统一 48kHz/24bit 源**（R-06 裁决 + art-bible）
2. 响度 card-system(-18/-23) vs audio-system(-14/-20) → **audio-system 为准**
3. SFX 总量引用过时（card-system「30+」vs audio-system 估算 50）→ 本 spec 25 条目/40 文件为规范口径，MVP 预算 ~15-18 样本不变
