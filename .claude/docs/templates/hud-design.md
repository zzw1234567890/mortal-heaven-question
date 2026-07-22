
# HUD 设计： [Game Name]

> **状态 (Status)**：Draft | In Review | Approved | Implemented
> **作者 (Author)**：[Name or agent — e.g., ui-designer]
> **最后更新 (Last Updated)**：[Date]
> **游戏 (Game)**：[Game name — this is a single document per game, not per element]
> **目标平台 (Platform Targets)**：[All platforms this HUD must work on — e.g., PC, PS5, Xbox Series X, Steam Deck]
> **相关 GDD (Related GDDs)**：[Every system that exposes information through the HUD — e.g., `design/gdd/combat.md`, `design/gdd/progression.md`, `design/gdd/quests.md`]
> **可访问性等级 (Accessibility Tier)**：Basic | Standard | Comprehensive | Exemplary
> **风格参考 (Style Reference)**：[Link to art bible HUD section if it exists — e.g., `design/art/art-bible.md § HUD Visual Language`]


> **注意——范围边界 (Note — Scope boundary)**：本文档规定了在活跃游戏过程中覆盖在游戏世界上的所有元素——血条、弹药计数器、小地图、任务追踪器、字幕、伤害数字和通知提示。对于菜单界面、暂停菜单、背包和玩家主动导航的对话框，请改用 `ux-spec.md`。判断标准：如果它出现在玩家直接控制角色时，则属于本文档。

---

## 1. HUD 设计理念 (Philosophy)

> **本节存在的意义 (Why this section exists)**：HUD 设计理念不是装饰——它是一个设计约束，每一项后续决策都将以此衡量。没有理念，各个元素就会随需求随意添加（"任务追踪器想要更大的图标"），而没有任何原则性的方式来拒绝。有了理念，就有了一个共享的、明确的标准。更重要的是，设计理念可以防止 HUD 在每一次看似合理的单独添加中慢慢膨胀覆盖整个游戏世界。请在指定任何元素之前编写本节。

**本游戏与屏幕信息的关系是什么？ (What is this game's relationship with on-screen information?)**

[一段话。这是一个设计陈述，而非功能描述。请考虑游戏的类型、节奏和玩家愿景。潜行游戏的 HUD 设计理念可能是："世界本身就是界面。如果玩家为了生存而必须将视线从环境中移开，那么 HUD 就失败了。"战术游戏可能会说："完整的态势感知就是游戏本身。HUD 不是覆盖层——它就是战场。"

如果有所帮助，可以引用同类游戏作为参考，但请描述你的具体立场：
示例——以叙事驱动优先的动作角色扮演游戏："我们将屏幕信息视为一种妥协，而非功能。每个 HUD 元素必须通过回答以下问题来赢得其像素空间：如果没有这些信息，玩家是否会做出明显更差的决策？如果答案是'他们会适应'，我们就将其放在环境中。"]

**可见性原则 (Visibility principle)**——有疑问时，显示还是隐藏？

[说明模棱两可情况下的默认处理方式。选项：
- 默认隐藏：信息按需提供（例如《黑暗之魂》——无任务追踪器、无小地图、数据在菜单中）
- 默认显示：玩家更倾向于知情；信息密集总好过不确定
- 默认按情境显示：信息在相关时出现，不相关时淡出
大多数游戏适合按情境显示。明确说明你的游戏默认值，使每个元素的决策保持一致。]

**本游戏的必要性法则 (The Rule of Necessity for this game)**：

[完成这句话："一个 HUD 元素获得其位置的条件是______________。"

示例："……玩家如果不看这些信息就必须停止游玩才能在其他地方找到，或者在缺少信息时会做出明显更差的决策。"

示例："……在游戏测试中，移除该元素导致超过 25% 的测试者在游戏第一小时内出现可衡量的挫败感或困惑。"

这条法则是拒绝添加 HUD 元素的功能请求的否决权。将其记录下来，以便在设计评审中引用。]

---

## 2. 信息架构 (Information Architecture)

> **本节存在的意义 (Why this section exists)**：在指定任何 HUD 元素的视觉设计、位置或行为之前，你必须回答一个更基本的问题：这些信息是否应该出现在 HUD 上？本节是一个强制机制——它要求你对游戏世界产生的每一条信息进行分类，并就每种信息的呈现方式做出明确、有意的决策。"我们以后再解决"是导致游戏最终在玩家外围视野中塞满 18 个竞争元素的原因。下表是游戏信息的完整清单，而不仅仅是 HUD 信息。

| 信息类型 | 始终显示 | 按情境显示（相关时显示） | 按需显示（菜单/按钮） | 隐藏（环境/叙事内嵌） | 理由 |
|-----------------|-------------|--------------------------------|------------------------|----------------------------------|-----------|
| [Health / Vitality] | [X if action game — player needs constant awareness] | [X if exploration game — show only when injured] | [ ] | [ ] | [示例：始终可见，因为在战斗中生命值决策（撤退、治疗）必须即时做出] |
| [Primary resource (mana / stamina / ammo)] | [ ] | [X — show when resource is being consumed or is critically low] | [ ] | [ ] | [示例：按情境显示，因为稳定状态的资源水平不涉及决策] |
| [Secondary resource (currency / materials)] | [ ] | [ ] | [X — check in inventory] | [ ] | [示例：按需显示，因为资源总额不影响即时游戏决策] |
| [Minimap / Compass] | [X] | [ ] | [ ] | [ ] | [示例：始终可见，因为在探索过程中导航决策是持续进行的] |
| [Quest objective] | [ ] | [X — show when objective changes or player is near it] | [ ] | [ ] | [示例：按情境显示——玩家知道自己的目标；仅在关键时刻提醒] |
| [Enemy health bar] | [ ] | [X — show only during combat encounters] | [ ] | [ ] | [示例：按情境显示，因为敌人生命值在战斗之外无关紧要] |
| [Status effects (buffs/debuffs)] | [ ] | [X — show when active] | [ ] | [ ] | [示例：按情境显示，因为状态效果仅在存在时影响决策] |
| [Dialogue subtitles] | [X when dialogue is playing] | [ ] | [ ] | [ ] | [示例：对话进行时始终显示——可访问性要求] |
| [Combo / streak counter] | [ ] | [X — show while combo is active, hide on reset] | [ ] | [ ] | [示例：按情境显示，因为它传达的是当前表现，而非基准状态] |
| [Timer] | [ ] | [X — show only in timed sequences] | [ ] | [ ] | [示例：按情境显示，因为计时器仅存在于特定关卡类型中] |
| [Tutorial prompts] | [ ] | [X — show for first-time situations only] | [ ] | [ ] | [示例：按情境显示且仅一次；切勿向有经验的玩家重复显示] |
| [Score / points] | [ ] | [X — show in score-relevant modes only] | [ ] | [ ] | [示例：按游戏模式按情境显示；在分数无关的模式中隐藏] |
| [XP / level progress] | [ ] | [ ] | [X — available via character screen] | [ ] | [示例：按需显示，因为成长进度不影响即时的游戏决策] |
| [Waypoint / objective marker] | [ ] | [X — show when player is navigating to objective] | [ ] | [ ] | [示例：按情境显示——在过场动画、电影时刻和自由探索期间隐藏] |

---

## 3. 布局区域 (Layout Zones)

> **本节存在的意义 (Why this section exists)**：游戏世界是主要内容——HUD 是围绕它的框架。在放置任何元素之前，将屏幕划分为命名的区域，并明确标注位置和安全边距。本节可防止两种失败模式：(1) 元素随意堆放，直到屏幕拥挤不堪；(2) 元素重叠平台要求的安全区域，导致认证被拒。第 4 节中的每个元素必须分配到这里定义的某个区域。

### 3.1 区域示意图 (Zone Diagram)

```
[绘制你的 HUD 布局区域。请根据游戏实际布局进行自定义。
坐标轴代表屏幕百分比的大致位置。调整区域名称和大小。

 0%                                             100%
 ┌──────────────────────────────────────────────────┐  0%
 │  [安全边距 — 距各边 10%]                          │
 │  ┌────────────────────────────────────────────┐  │
 │  │ [左上]                 [顶部居中]  [右上]  │  │  ~15%
 │  │  生命值、资源            任务名称       弹药、弹匣  │  │
 │  │                                              │  │
 │  │                                              │  │
 │  │               [屏幕中央]                    │  │  ~50%
 │  │                准星 / 瞄准线                  │  │
 │  │              (此处 HUD 元素最少)              │  │
 │  │                                              │  │
 │  │                                              │  │
 │  │ [左下]           [底部居中]        [右下]    │  │  ~85%
 │  │  小地图            字幕              通知     │  │
 │  │  技能图标          教程提示                    │  │
 │  └────────────────────────────────────────────┘  │
 │                                                  │
 └──────────────────────────────────────────────────┘  100%
```

> 区域放置规则：屏幕中央 40%（横向和纵向）是玩家的主要聚焦区域。请始终保持该区域尽可能干净。出现在中央区域的 HUD 元素——准星、交互提示、命中标记——必须最小化、高对比度且短暂。

### 3.2 区域规格表 (Zone Specification Table)

| 区域名称 | 屏幕位置 | 符合安全区域 | 主要元素 | 最大同时元素数 | 备注 |
|-----------|----------------|---------------------|-----------------|--------------------------|-------|
| [Top Left] | [Top-left corner, within safe margin] | [Yes — 10% from top, 10% from left] | [Health bar, stamina bar, shield bar] | [3] | [Vital status — player's own resources. Priority zone for player state.] |
| [Top Center] | [Top edge, centered horizontally] | [Yes — 10% from top] | [Quest objective, area name (on enter)] | [1 — only one message at a time] | [Use for narrative context, not mechanical information. Keep text minimal.] |
| [Top Right] | [Top-right corner, within safe margin] | [Yes — 10% from top, 10% from right] | [Ammo count, ability cooldowns] | [2] | [Weapon/ability state. Most relevant during active combat.] |
| [Center] | [Screen center ±15%] | [N/A — not a margin zone] | [Crosshair, interaction prompt, hit marker] | [1 active at a time] | [CRITICAL: Nothing persistent here. Only momentary indicators.] |
| [Bottom Left] | [Bottom-left corner, within safe margin] | [Yes — 10% from bottom, 10% from left] | [Minimap, ability icons] | [2] | [Navigation and ability readout. Small, non-intrusive.] |
| [Bottom Center] | [Bottom edge, centered horizontally] | [Yes — 10% from bottom] | [Subtitles, tutorial prompts] | [2 — subtitle + tutorial may coexist] | [Highest-priority accessibility zone. Never place other elements here.] |
| [Bottom Right] | [Bottom-right corner, within safe margin] | [Yes — 10% from bottom, 10% from right] | [Notification toasts, pick-up feedback] | [3 stacked] | [Transient notifications. Stack vertically. Oldest disappears first.] |

**各平台安全边距 (Safe zone margins by platform)**：

| 平台 | 顶部 | 底部 | 左侧 | 右侧 | 备注 |
|----------|-----|--------|------|-------|-------|
| [PC — windowed] | [0% — no safe zone required] | [0%] | [0%] | [0%] | [But respect minimum resolution — elements must not crowd at 1280x720] |
| [PC — fullscreen] | [3%] | [3%] | [3%] | [3%] | [Slight margin for 4K TV-connected PCs] |
| [Console — TV] | [10%] | [10%] | [10%] | [10%] | [Action-safe zone for broadcast-spec TVs. Some TVs overscan beyond this.] |
| [Steam Deck] | [5%] | [5%] | [5%] | [5%] | [Small screen; safe zone is smaller but crowding risk is higher] |
| [Mobile — portrait] | [15% top] | [10% bottom] | [5%] | [5%] | [15% top avoids notch/camera cutout on most devices] |
| [Mobile — landscape] | [5%] | [5%] | [15% left] | [15% right] | [Thumb placement on landscape — side zones are obscured by hands] |

---

## 4. HUD 元素规格 (Element Specifications)

> **本节存在的意义 (Why this section exists)**：每个 HUD 元素需要自己的规格说明才能正确构建。临时拼凑的 HUD 元素会导致尺寸不一致、更新频率不匹配、缺少紧急状态标记以及可访问性问题。本节是每个元素的实现摘要——在任何元素进入开发之前，请完整填写本节。

### 4.1 元素概览表 (Element Overview Table)

> 每行对应一个 HUD 元素。这是实现规划的完整清单。

| 元素名称 | 区域 | 始终可见 | 可见性触发条件 | 数据来源 | 更新频率 | 最大尺寸（屏幕宽度百分比） | 最小可读尺寸 | 重叠优先级 | 可访问性替代方案 |
|-------------|------|---------------|-------------------|-------------|-----------------|----------------------|------------------|-----------------|------------------|
| [Health Bar] | [Top Left] | [Yes] | [N/A] | [PlayerStats] | [On value change] | [20%] | [120px wide] | [1 — highest] | [Numerical text label showing current/max: "80/100"] |
| [Stamina Bar] | [Top Left] | [No — context] | [Show when consuming stamina; hide 3s after full] | [PlayerStats] | [Realtime during use] | [15%] | [80px wide] | [2] | [Numerical label, or hide if full (accessible assumption)] |
| [Shield Indicator] | [Top Left] | [No — context] | [Show when shield is active or recently hit] | [PlayerStats] | [On value change] | [20%] | [120px wide] | [3] | [Numerical label. Must not use color alone — add shield icon.] |
| [Ammo Counter] | [Top Right] | [No — context] | [Show when weapon is equipped; hide when unarmed] | [WeaponSystem] | [On fire / on reload] | [10%] | ["88/888" readable at game's min resolution] | [4] | [Text-only fallback: "32 / 120"] |
| [Minimap] | [Bottom Left] | [Yes] | [N/A — but suppressed in cinematic mode] | [NavigationSystem] | [Realtime] | [18%] | [150x150px] | [5] | [Cardinal direction compass strip as fallback; must be toggleable] |
| [Quest Objective] | [Top Center] | [No — context] | [Show on objective change; show when near objective location; hide after 5s] | [QuestSystem] | [On event] | [30%] | [Legible at body text size] | [6] | [Read aloud on objective change via screen reader] |
| [Crosshair] | [Center] | [No — context] | [Show when ranged weapon equipped; hide in melee or unarmed] | [WeaponSystem / AimSystem] | [Realtime] | [3%] | [12px diameter minimum] | [1 — center zone priority] | [Reduce motion: static crosshair only. Option to enlarge.] |
| [Interaction Prompt] | [Center] | [No — context] | [Show when player is within interaction range of an interactive object] | [InteractionSystem] | [On enter/exit interaction range] | [15%] | [24px icon + readable text] | [2 — center zone] | [Text description of interaction always present, not icon-only] |
| [Subtitles] | [Bottom Center] | [No — always on when dialogue plays, if setting enabled] | [Show during any voiced line or ambient dialogue] | [DialogueSystem] | [Per dialogue line] | [60%] | [Minimum 24px font] | [1 — highest in zone] | [This IS the accessibility feature — see Section 8 for subtitle spec] |
| [Damage Numbers] | [World-space / anchored to entity] | [No — context] | [Show on any damage event; duration 800ms] | [CombatSystem] | [On event] | [5% per number] | [18px minimum] | [3] | [Option to disable; numbers can overwhelm for photosensitive players] |
| [Status Effect Icons] | [Top Left — below health bar] | [No — context] | [Show when any status effect is active on player] | [StatusSystem] | [On effect add/remove] | [3% per icon] | [24px per icon] | [3] | [Icon + text label on hover/focus. Never icon-only.] |
| [Notification Toast] | [Bottom Right] | [No — event-driven] | [On loot, XP gain, achievement, quest update] | [Multiple — see Section 6] | [On event] | [25%] | [Legible at body text size] | [7 — lowest] | [Queued; never overlapping. Read by screen reader if subtitle mode on.] |

### 4.2 元素详情块 (Element Detail Blocks)

> 为上方表格中的每个元素编写一个详情块。每个元素复制并填写一个块。

---

**生命值条 (Health Bar)**

- 视觉描述：[水平填充条。从左到右的填充方向。在 25/50/75% 处分段，便于快速读取。背景：深色半透明（40% 不透明度）。填充颜色：取决于情境——参见紧急状态。]
- 显示数据：[当前 HP 以填充百分比显示。数值始终以文字形式显示在条下方："80 / 100"。]
- 更新行为：[条填充使用 150ms 的线性插值平滑减少或增加。大额伤害（单次 >25%）触发短暂闪烁（1 帧白色，然后减少）。]
- 紧急状态：
  - 正常 (>50% HP)：[绿色填充，无特殊行为]
  - 警戒 (25–50% HP)：[黄色填充，每 4 秒一次低频警告脉冲]
  - 危急 (<25% HP)：[红色填充，持续慢速脉冲（1 Hz），屏幕边缘出现暗角]
  - 归零 (0% HP)：[条清空并变为灰色；死亡状态开始]
- 交互方式：[仅显示。不可交互。玩家无法点击、悬停或聚焦此元素作为操作目标。]
- 玩家自定义：[不透明度可调（参见第 7 节调优参数）。可在无障碍设置中由玩家重定位到任意角落。]

---

**小地图 (Minimap)**

- 视觉描述：[圆形遮罩，半径 = 75px（参考分辨率 1920x1080）。玩家图标位于中心。默认北方向上，除非玩家解锁了"旋转小地图"设置。范围 = 可配置，默认 80 世界单位半径。]
- 显示数据：[玩家位置、附近敌人（如果已解锁侦测特权）、范围内的任务标记、兴趣点图标、移动障碍物（墙壁、落差）。]
- 更新行为：[实时。每帧更新。敌人在 300ms 内随进入/离开侦测范围而淡入/淡出。]
- 紧急状态：[地图本身无紧急状态。敌人图标在战斗警戒状态下变为红色。]
- 交互方式：[游戏内不可交互。按下专用地图按钮打开完整地图界面（独立 UX spec）。]
- 玩家自定义：[尺寸：小/中/大（70/90/110px 半径）。不透明度：30–100%。旋转：北向锁定或随玩家旋转。可完全禁用（指南针条作为备选显示）。]

---

**[每个第 4.1 节中的元素重复此块]**

---

## 5. 按游戏情境划分的 HUD 状态 (HUD States by Gameplay Context)

> **本节存在的意义 (Why this section exists)**：HUD 不是静态覆盖层——它必须根据玩家正在做的事情进行动态调整。仅为标准游戏玩法设计的 HUD 会在过场动画中显得不合适，在探索中感觉拥挤，在 Boss 战中遮挡关键信息。本节定义了 HUD 在每种游戏情境下的变换规则。它也是管理 HUD 可见性的系统——HUD 状态机——的规格说明。

| 情境 (Context) | 显示的元素 | 隐藏的元素 | 修改的元素 | 进入该状态的过渡方式 |
|---------|---------------|-----------------|------------------|---------------------------|
| [Exploration — no threats] | [Minimap, Quest Objective (faded, 60%), Subtitles (if active)] | [Ammo Counter, Crosshair, Damage Numbers, Status Effects (if none active)] | [Health Bar fades to 40% opacity — visible but not dominant] | [Fade transition, 500ms, when no enemies detected for 10s] |
| [Combat — active threat] | [Health Bar (full opacity), Stamina Bar (when used), Ammo Counter, Crosshair, Damage Numbers, Status Effects, Enemy Health Bars] | [Quest Objective (temporarily hidden), Notification Toasts (paused queue)] | [Minimap scales down 15% and raises opacity to 100%] | [Immediate snap in on first enemy detection — no fade. Combat readiness requires instant info.] |
| [Dialogue / Cutscene] | [Subtitles, Dialogue speaker name] | [All gameplay HUD elements: health, ammo, minimap, crosshair, damage numbers] | [N/A] | [All gameplay elements fade out over 300ms when cutscene flag is set] |
| [Cinematic (scripted camera sequence)] | [Subtitles only] | [Everything else including speaker name] | [Letterbox bars appear (if applicable to this game's style)] | [Immediate on cinematic flag; letterbox slides in from top/bottom over 400ms] |
| [Inventory / Menu open] | [None — inventory renders full-screen or as overlay] | [All HUD elements] | [Game world visible but paused behind inventory screen] | [All HUD elements hide over 150ms as menu opens] |
| [Death / Respawn pending] | [Death screen overlay — separate spec] | [All gameplay HUD elements] | [Screen desaturates and darkens over 800ms] | [Death state begins when HP reaches 0 — HUD elements fade over 600ms] |
| [Loading / Transition] | [Loading indicator, tip text] | [All gameplay HUD elements] | [N/A] | [Instant on level transition trigger] |
| [Tutorial — new mechanic] | [Standard context HUD + Tutorial Prompt overlay] | [Nothing additional hidden] | [Tutorial prompt dims background subtly to draw attention to prompt] | [Tutorial system fires ShowTutorial event; prompt fades in over 200ms] |
| [Boss Encounter] | [Boss health bar appears (large, bottom of screen or top center), all combat elements] | [Quest Objective] | [Boss bar renders in a distinct visual style — must not be confused with player health] | [Boss health bar slides in on boss encounter trigger over 400ms] |

---

## 6. 信息层级 (Information Hierarchy)

> **本节存在的意义 (Why this section exists)**：并非所有 HUD 信息都同等重要。当屏幕空间有限、玩家处于高压状态或元素争夺同一区域时，必须有一个原则性的优先级顺序来决定哪些元素保留、哪些被抑制。本节正式确定该层级结构，以便系统地执行，而不是在实现时仅凭"感觉明显"的决策。

| 元素 | 优先级层级 | 理由 | 隐藏时的替代方案 |
|---------|--------------|-----------|---------------------------|
| [Subtitles] | [MUST KEEP — never hide during dialogue] | [Accessibility requirement. Legal requirement in some markets. Story clarity.] | [N/A — nothing replaces subtitles] |
| [Health Bar] | [MUST KEEP — during any state where the player can be damaged] | [Without health visibility, survival decisions become impossible] | [Auditory cues (heartbeat, breathing) supplement but do not replace] |
| [Crosshair] | [MUST KEEP — while aiming with a ranged weapon] | [Targeting without a crosshair is a precision failure, not a difficulty feature] | [Alternative: dot-only mode for minimalists; never fully hidden while aiming] |
| [Interaction Prompt] | [MUST KEEP — when player is in interaction range] | [Without it, interactive objects are invisible to the player] | [Environmental visual cues can supplement but interaction affordance must be explicit] |
| [Ammo Counter] | [SHOULD KEEP] | [Low ammo decisions (switch weapon, reload) require awareness; can be contextual] | [Auditory "click" on empty chamber is acceptable fallback for experienced players] |
| [Minimap] | [SHOULD KEEP] | [Navigation requires spatial awareness; loss forces repeated map opens] | [Compass strip (simplified directional indicator) is acceptable fallback] |
| [Status Effects] | [SHOULD KEEP — while active] | [Active debuffs change what actions are viable; invisible debuffs feel unfair] | [Character animation states can partially communicate status effects (limping, sparks)] |
| [Quest Objective] | [CAN HIDE] | [Player can hold objective in memory for extended periods; contextual is correct default] | [Player remembers objective from context] |
| [Damage Numbers] | [CAN HIDE] | [Feedback element, not decision-critical. Many players turn these off.] | [Hit sounds and enemy reactions communicate hit registration] |
| [Notification Toasts] | [CAN HIDE in high-intensity moments] | [Mid-combat "You gained 50 XP" is noise, not signal. Queue and show after combat.] | [Queue held and released when combat ends] |
| [Combo Counter] | [ALWAYS HIDE when combo resets or player is not attacking] | [Stale combo information is actively misleading] | [N/A — simply hidden] |

---

## 7. 视觉预算 (Visual Budget)

> **本节存在的意义 (Why this section exists)**：没有明确的预算约束，HUD 元素会不断累积，直到游戏世界几乎不可见。这些数字是硬性限制，而非建议。任何会突破限制的元素添加都需要明确批准，并且必须替换或缩减现有元素。

| 预算约束 | 限制值 | 测量方法 | 当前估算 | 状态 |
|------------------|-------|--------------------|-----------------|--------|
| 最大同时活跃 HUD 元素数 | [8] | [Count all visible, non-faded elements at any one frame] | [TBD — verify at implementation] | [To verify] |
| HUD 占屏幕最大百分比（探索模式） | [12%] | [Pixel area of all HUD elements / total screen pixels] | [TBD] | [To verify] |
| HUD 占屏幕最大百分比（战斗模式） | [22%] | [Same method — combat adds ammo, crosshair, enemy bars] | [TBD] | [To verify] |
| 屏幕中央区域（屏幕宽高的 40%）最大占用 | [5%] | [Only crosshair and interaction prompt allowed here] | [TBD] | [To verify] |
| HUD 文本在任何背景上的最小对比度 | [4.5:1 (WCAG AA)] | [Measured against the darkest and lightest game world areas the element will appear over] | [TBD] | [To verify] |
| HUD 背景面板的最大不透明度 | [65%] | [Opacity of any panel behind HUD text — must preserve world visibility through panel] | [TBD] | [To verify] |
| 最低支持分辨率下的最小 HUD 元素尺寸 | [40px for icons, 18px for text] | [Measure at lowest target resolution] | [TBD] | [To verify] |

> **如何应用这些预算 (How to apply these budgets)**：对于制作过程中提议的每个新 HUD 元素，要求提议者说明 (1) 它影响哪条预算线，(2) 新的总计值是多少，(3) 将减少或改为按情境显示的现有元素是什么。"只是个小图标"不是分析。

---

## 8. 反馈与通知系统 (Feedback & Notification Systems)

> **本节存在的意义 (Why this section exists)**：通知是大多数 HUD 中最常添加却最难控制的部分。每个系统都想告诉玩家一些事情。没有明确的通知优先级、堆叠限制和队列行为规则，通知区域就会变成一个重叠提示的消防水管，玩家最终完全无视。本节建立了所有系统的通知契约。

| 通知类型 | 触发系统 | 屏幕位置 | 持续时间 (ms) | 入场/出场动画 | 最大同时显示数 | 优先级 | 队列行为 | 可关闭？ |
|------------------|---------------|-----------------|--------------|-------------------|-----------------|----------|---------------|-------------|
| [Item Pickup] | [InventorySystem] | [Bottom Right — toast] | [2000] | [Slide in from right 200ms / fade out 300ms] | [3 stacked] | [Low] | [FIFO queue; older toasts pushed up as new ones enter] | [No — auto-dismiss] |
| [XP Gain] | [ProgressionSystem] | [Bottom Right — toast, below item toasts] | [1500] | [Fade in 150ms / fade out 300ms] | [1 — XP messages merge: "XP +150"] | [Very Low — suppress during combat, queue for post-combat] | [Combat-aware queue] | [No] |
| [Level Up] | [ProgressionSystem] | [Center screen — persistent until dismissed] | [Persistent — requires input to dismiss] | [Scale up from 80% + fade in 400ms] | [1] | [High — interrupts normal toasts] | [Pauses all other notifications until dismissed] | [Yes — any input] |
| [Quest Update] | [QuestSystem] | [Top Center] | [4000] | [Slide down from top 250ms / fade out 400ms] | [1 — top center is single-message zone] | [Medium] | [If quest update arrives while previous is visible, extend duration by 2000ms; do not stack] | [No] |
| [Objective Complete] | [QuestSystem] | [Top Center] | [3000] | [Same as Quest Update but with additional completion sound] | [1] | [Medium-High — preempts Quest Update] | [Preempts any queued top-center message] | [No] |
| [Critical Warning (low health, hazard)] | [CombatSystem / EnvironmentSystem] | [Screen edge vignette + text at center-bottom] | [Persistent while condition active] | [Fade in 200ms; fades out 500ms when condition clears] | [1 per warning type] | [Critical — never suppressed] | [Renders immediately, bypasses all queues] | [No] |
| [Achievement Unlocked] | [AchievementSystem] | [Bottom Right — distinct from item toasts] | [4000] | [Slide in from right with icon expansion 300ms / fade out 400ms] | [1] | [Low] | [Queues behind item toasts; never more than one achievement toast at a time] | [No] |
| [Hint / Tutorial] | [TutorialSystem] | [Bottom Center] | [Persistent — until player performs the action or dismisses] | [Fade in 300ms] | [1] | [Medium] | [Only one tutorial hint at a time; queue others] | [Yes — B button / Esc] |

**通知队列规则 (Notification queue rules)**：
1. 战斗感知队列：标记为低优先级的通知在玩家处于战斗状态时进入队列而不显示。当玩家退出战斗时，队列以批量方式刷新最多 3 条依次显示。
2. 合并规则：在 500ms 内触发的相同类型通知合并为单条通知，数值合并（例如显示"物品拾取 x3"而非三条独立提示）。
3. 关键通知（生命值警告、环境危险）永不排队、永不合并，无论战斗状态或现有通知如何，始终立即显示。

---

## 9. 平台适配 (Platform Adaptation)

> **本节存在的意义 (Why this section exists)**：在显示器上以 1920x1080 设计的 HUD 可能在 55 英寸 4K 电视上难以辨认，在 1280x720 的 Steam Deck 上显示异常，或在手机上被刘海遮挡。平台适配不是可选的发售后工作——它是在实现前必须明确的设计要求，以便架构从一开始就支持。此处列出的每个平台在认证前都需要经过明确的布局测试。

| 平台 | 安全区域 | 分辨率范围 | 输入方式 | HUD 专项说明 |
|----------|-----------|-----------------|-------------|-------------------|
| [PC — Windows, 1920x1080 reference] | [3% margin] | [1280x720 min to 3840x2160 max] | [Mouse + keyboard, controller optional] | [HUD must scale correctly at all resolutions. Test at 1280x720 — minimum before cert. Consider ultrawide (21:9) — minimap must not stretch.] |
| [PC — Steam Deck, 1280x800] | [5% margin] | [Fixed 1280x800] | [Controller + touchscreen] | [Smaller screen means minimum text sizes are critical. Test ALL elements at this resolution. Touch targets irrelevant (controller-only by default).] |
| [PlayStation 5 / Xbox Series X] | [10% margin] | [1080p to 4K] | [Controller] | [Console certification requires TV safe zone compliance. Action-safe is 90% of screen area. Test on a real TV, not a monitor — overscan behavior differs.] |
| [Mobile — iOS / Android] | [15% top, 10% other sides] | [360x640 min to 414x896 common] | [Touch] | [Notch/camera cutout avoidance at top. Bottom home indicator zone avoidance. Portrait and landscape layouts may differ significantly — specify both.] |

**HUD 可重定位要求 (HUD repositionability requirement)**：玩家必须能够使用游戏内 HUD 布局编辑器重定位以下至少元素（控制台可访问性合规要求）：
- 生命值条 (Health bar)
- 小地图 (Minimap)
- 技能栏 (Ability bar) —— 如果存在

重定位设置保存到玩家档案，而非单个存档位。适用于整个游戏过程各次会话。

---

## 10. 可访问性——HUD 专有 (Accessibility — HUD Specific)

> **本节存在的意义 (Why this section exists)**：HUD 可访问性问题是游戏中最显而易见的可访问性失败——玩家在每次会话、每个游戏时刻都会遇到 HUD。色盲缺陷、最小比例下难以辨认的文字、以及无法关闭干扰性动画，是游戏评论中可访问性投诉最多的问题之一。本节定义 HUD 专项要求；完整的项目标准请参考项目的 `docs/accessibility-requirements.md`。

### 10.1 色盲模式 (Colorblind Modes)

| 元素 | 仅依赖色彩的信息风险 | 色盲模式修复方案 |
|---------|----------------------------|---------------------|
| [Health bar fill] | [Red = low health uses red/green distinction] | [Add icon pulse + vignette as non-color indicators. Red fill is supplemental, not sole indicator.] |
| [Damage numbers] | [Red = taken, green = healed] | [Add minus (-) prefix for damage, plus (+) for healing. Symbols, not color.] |
| [Enemy health bars] | [If colored by faction or threat level] | [Add text label or icon badge for faction/threat level. Never color-only.] |
| [Status effect icons] | [If icon tint communicates status type] | [All status icons must have distinct shapes, not just distinct colors. Shape encodes meaning; color is secondary.] |
| [Minimap icons] | [If player vs. enemy vs. objective distinguished by color] | [Distinct icon shapes: circle = player, triangle = enemy, star = objective. Color supplements shape.] |

### 10.2 文本缩放 (Text Scaling)

[描述当玩家将 UI 文本缩放设置为 150%（你的可访问性等级所要求的最大值）时发生的情况。哪些元素会重新排列？哪些会裁剪？哪些在架构上无法缩放（例如固定尺寸的画布）？

示例："生命值条的数字标签随文本缩放而增大——条会略微扩展以适应。任务目标文本在 150% 缩放时自动换行——需要验证顶部居中区域能否容纳两行目标。伤害数字不缩放（它们是世界空间而非屏幕空间）——这是在此处记录的已接受限制。"]

**文本缩放测试矩阵 (Text scaling test matrix)**：

| 元素 | 100%（基准） | 125% | 150% | 溢出行为 |
|---------|----------------|------|------|-------------------|
| [Health bar label] | [Pass] | [Pass] | [TBD] | [Bar expands; does not overlap stamina bar] |
| [Quest objective text] | [Pass] | [TBD] | [TBD] | [Wraps to second line; zone height expands] |
| [Notification toast text] | [Pass] | [TBD] | [TBD] | [Toast width expands to max 35% screen width, then wraps] |
| [Subtitle text] | [Pass] | [TBD] | [TBD] | [Dedicated subtitle zone — must accommodate scale] |

### 10.3 运动敏感度 (Motion Sensitivity)

| 动画/运动元素 | 严重程度 | 在"减少运动"设置下禁用？ | 替代行为 |
|---------------------------|----------|-------------------------------------|---------------------|
| [Health bar low-HP pulse] | [Mild] | [Yes] | [Solid fill, no pulse. Vignette remains as it is less likely to trigger sensitivity.] |
| [Screen edge vignette] | [Moderate] | [Optional — separate toggle] | [Replace with static darkened corners at 30% opacity] |
| [Damage numbers float upward] | [Mild] | [Yes] | [Instant appear/disappear in place, no float] |
| [Notification toast slide-in] | [Mild] | [Yes] | [Instant appear at final position] |
| [Level up center animation] | [High] | [Yes — required] | [Static level up card, no scale animation, no particle effects] |
| [Combo counter scale pulse] | [Mild] | [Yes] | [Number increments without scale animation] |

### 10.4 字幕规格 (Subtitles Specification)

> 字幕是 HUD 中影响最大的可访问性功能。请以与 HUD 其他部分相同的严谨程度进行规格说明。不要将字幕行为留给实现方自行决定。

- **默认设置 (Default setting)**：[ON or OFF — document your game's default and the rationale. Industry standard is ON by default.]
- **位置 (Position)**：底部居中区域，水平居中，位于底部安全边距上方
- **每行最大字符数 (Max characters per line)**：[42 characters — the readable limit for subtitle lines at minimum text size on TV viewing distance]
- **最大同时行数 (Max simultaneous lines)**：[2 lines before scrolling — do not display more than 2 lines at once]
- **说话者标识 (Speaker identification)**：[Speaker name displayed in color or above subtitle text — never rely on color alone; add colon prefix: "ARIA: The door is locked."]
- **背景 (Background)**：[Semi-transparent black panel, 70% opacity, behind all subtitle text — ensures contrast against any game world background]
- **最小字号 (Font size minimum)**：[24px at 1080p reference — scales with text scale setting]
- **换行行为 (Line break behavior)**：[Break at natural language pause points — before conjunctions, after commas, never mid-word]
- **字幕持续时间 (Subtitle persistence)**：[Each subtitle line holds for the duration of the spoken line plus 300ms after it ends — never disappear while audio is still playing]
- **非对话字幕 (Non-dialogue captions)**：[Document whether ambient sounds, music descriptions, and sound effects are captioned — e.g., "[tense music]", "[explosion in the distance]" — and where these appear if different from dialogue subtitles]

### 10.5 HUD 不透明度与可见性控制 (HUD Opacity and Visibility Controls)

以下玩家可调设置必须可在无障碍菜单中找到：

| 设置项 | 范围 | 默认值 | 效果 |
|---------|-------|---------|--------|
| [HUD Opacity — Global] | [0% (HUD hidden) to 100%] | [100%] | [Scales all HUD element opacities simultaneously] |
| [HUD Text Scale] | [75% to 150%] | [100%] | [Scales all HUD text elements; layout adapts] |
| [Damage Number Visibility] | [On / Off] | [On] | [Enables or disables all floating damage numbers] |
| [Minimap Visibility] | [On / Off / Compass Only] | [On] | [Compass strip shown as fallback when minimap off] |
| [Notification Verbosity] | [All / Important Only / Off] | [All] | [All = all toasts; Important Only = quest + level up; Off = no toasts] |
| [Motion Reduction] | [On / Off] | [Off] | [When On, replaces all animated HUD transitions with instant state changes] |
| [High Contrast Mode] | [On / Off] | [Off] | [Applies high contrast visual theme to all HUD elements — see art bible for HC variants] |

---

## 11. 调优参数 (Tuning Knobs)

> **本节存在的意义 (Why this section exists)**：HUD 行为应像游戏系统一样采用数据驱动。硬编码的值需要工程师才能修改。配置中的值可以由设计师调优或根据玩家偏好进行调整。在实现前记录所有可调优参数，以便程序员知道哪些值需要外部化。

| 参数 | 当前值 | 范围 | 增大效果 | 减小效果 | 玩家可调？ | 备注 |
|-----------|-------------|-------|-------------------|-------------------|-------------------|-------|
| [Notification display duration (default)] | [2000ms] | [500ms – 5000ms] | [Toasts persist longer — less likely to be missed, more screen clutter] | [Toasts disappear faster — cleaner, higher miss risk] | [No — but player can adjust verbosity level] | [Per-type overrides in Section 8 take precedence] |
| [Notification queue max size] | [8] | [3 – 15] | [More messages preserved but queue takes longer to clear] | [Older messages dropped earlier] | [No] | [Expand if playtesting reveals important messages being lost] |
| [Health bar low-HP pulse frequency] | [1 Hz] | [0.5 – 2 Hz] | [More urgent feeling — can become fatiguing] | [Calmer — may fail to communicate urgency] | [No — but Reduced Motion disables it] | [Linked to accessibility setting] |
| [Combat HUD reveal duration] | [0ms (instant)] | [0 – 300ms] | [Softer reveal — feels less jarring] | [Instant — highest responsiveness] | [No] | [Keep at 0ms — combat information must be instant] |
| [Exploration HUD fade-out delay] | [10000ms (10s after last threat)] | [3000 – 30000ms] | [HUD fades sooner — cleaner exploration] | [HUD stays longer — more reassurance] | [No] | [Tune based on playtest; 10s is a starting estimate] |
| [Minimap range (world units visible)] | [80] | [40 – 200] | [More map context visible] | [Tighter local view] | [Yes — Small/Medium/Large preset] | [Exposed as S/M/L, not raw unit value] |
| [Minimap size (px radius at 1080p)] | [75] | [50 – 120] | [Larger map, more screen space consumed] | [Smaller, less intrusive] | [Yes — S/M/L preset] | [Three sizes exposed to player] |
| [Damage number duration (ms)] | [800] | [400 – 1500] | [Numbers linger longer — easier to read, more cluttered] | [Numbers clear faster — cleaner, harder to parse] | [No] | [Tune based on visual noise in dense combat] |
| [Global HUD opacity] | [100%] | [0 – 100%] | [Fully visible] | [Fully hidden] | [Yes — opacity slider in Accessibility settings] | [0% = full HUD off; some players prefer this] |

---

## 12. 验收标准 (Acceptance Criteria)

> **本节存在的意义 (Why this section exists)**：这些标准是 HUD 的认证检查清单。每一项都必须在 HUD 可标记为"已批准"之前通过。QA 必须能够独立验证每一项。

**布局与可见性 (Layout & Visibility)**
- [ ] 所有目标平台上所有 HUD 元素均位于平台安全边距内
- [ ] 在任何记录的游戏情境中，没有两个 HUD 元素重叠
- [ ] HUD 在探索情境下占用不到 [12]% 的屏幕面积（以参考分辨率测量）
- [ ] HUD 在战斗情境下占用不到 [22]% 的屏幕面积
- [ ] 在探索期间，没有 HUD 元素占用屏幕中央 [40]% 的区域（战斗期间准星除外）
- [ ] 所有 HUD 元素在所有平台的最低支持分辨率下可见且清晰可读

**各情境正确性 (Per-Context Correctness)**
- [ ] HUD 在第 5 节定义的每种情境下正确显示仅指定的元素
- [ ] 情境过渡（进入/退出战斗、对话、过场动画）在过渡时间规格内显示正确元素
- [ ] Boss 生命值条在触发 Boss 遭遇时正确出现，在 Boss 被击败后消失
- [ ] 死亡状态正确隐藏所有游戏 HUD 元素

**可访问性 (Accessibility)**
- [ ] 所有 HUD 文本元素在其出现的所有背景上满足 4.5:1 对比度（在明亮和黑暗场景中均测试）
- [ ] 没有 HUD 元素仅使用颜色作为唯一区分手段（验证：移除每个元素的颜色并确认信息仍能传达）
- [ ] 启用字幕设置时，所有配音台词和环境对话都显示字幕
- [ ] 音频仍在播放时，字幕文本不会消失
- [ ] "减少运动"设置禁用第 10.3 节列出的所有 HUD 动画
- [ ] 150% 文本缩放不会导致任何 HUD 文本溢出其容器或重叠其他元素
- [ ] 第 10.5 节中所有玩家可调 HUD 设置均功能正常并在会话之间保持

**通知 (Notifications)**
- [ ] 500ms 内触发的相同类型通知合并为单条通知
- [ ] 低优先级通知在战斗期间进入队列（不显示）并在战斗结束后释放
- [ ] 关键警告（低生命值、危险）无论队列状态或战斗状态如何，立即显示
- [ ] 同时可见的通知提示不超过 [3] 条
- [ ] 关卡过渡时正确清除通知队列（无来自前一个区域的过时通知）

**平台 (Platform)**
- [ ] 所有元素在主机上遵守 10% 安全边距（在实体电视上测试——而非显示器）
- [ ] HUD 在 1280x720（Steam Deck）下正确显示，无元素裁剪或重叠
- [ ] HUD 元素可重定位（生命值、小地图、技能栏）且重定位设置持续保存
- [ ] 游戏过程中断开控制器不会导致 HUD 状态损坏

---

## 13. 未决问题 (Open Questions)

> 在此追踪未解决的设计问题。所有问题必须在 HUD 设计文档可以标记为"已批准"之前解决。

| 问题 | 负责人 | 截止日期 | 解决方案 |
|----------|-------|----------|-----------|
| [e.g., Should the minimap show enemy positions by default, or only after a detection skill is unlocked?] | [systems-designer + ui-designer] | [Sprint 5, Day 2] | [Pending — depends on progression GDD decision] |
| [e.g., Does the game have a boss health bar, or do bosses use the standard enemy health bar? Bosses need a visually distinct treatment if they are significantly more important than normal enemies.] | [game-designer] | [Sprint 5, Day 1] | [Pending] |
| [e.g., Damage numbers: diegetic (floating in world space, occluded by geometry) or screen space (always readable, overlaid on HUD layer)?] | [ui-designer + lead-programmer] | [Sprint 4, Day 5] | [Pending — architecture decision affects rendering layer choice] |
| [e.g., Mobile portrait vs. landscape: does the game support both orientations? If yes, each requires its own zone layout.] | [producer] | [Sprint 3, Day 3] | [Pending — platform scope decision required first] |
