
# Level: [Level Name]

## 快速参考 (Quick Reference)

- **区域 (Area/Region)**： [Where in the game world]
- **类型 (Type)**： [Combat / Exploration / Puzzle / Hub / Boss / Mixed]
- **预估游戏时间 (Estimated Play Time)**： [X-Y minutes]
- **难度 (Difficulty)**： [1-10 relative scale]
- **前置条件 (Prerequisite)**： [What the player must have done to reach this level]
- **状态 (Status)**： [Concept | Layout | Graybox | Art Pass | Polish | Final]

## 叙事背景 (Narrative Context)

- **故事节点 (Story Moment)**： [Where in the narrative arc does this level occur]
- **叙事目的 (Narrative Purpose)**： [What story beat this level delivers]
- **情感目标 (Emotional Target)**： [What the player should feel during this level]
- **传说发现 (Lore Discoveries)**： [What world-building the player can find here]

## 布局 (Layout)

### 总览地图 (Overview Map)

```
[ASCII diagram of the level layout. Use these symbols:]
[S] = Start point
[E] = Exit/end point
[C] = Combat encounter
[P] = Puzzle
[R] = Reward/loot
[!] = Story beat
[?] = Secret/optional
[>] = One-way passage
[=] = Two-way passage
[@] = NPC
[B] = Boss encounter
```

### 关键路径 (Critical Path)

[描述通过关卡的必经路线，逐步说明。]

1. 玩家从 [S] 进入
2. [描述沿路发生的事件]
3. 玩家从 [E] 离开

### 可选路径 (Optional Paths)

| 路径 (Path) | 进入条件 (Access Requirement) | 奖励 (Reward) | 发现提示 (Discovery Hint) |
|------|-------------------|--------|---------------|

### 兴趣点 (Points of Interest)

| 地点 (Location) | 类型 (Type) | 描述 (Description) | 目的 (Purpose) |
|----------|------|-------------|---------|

## 遭遇 (Encounters)

### 战斗遭遇 (Combat Encounters)

| ID | 位置 (Position) | 敌人构成 (Enemy Composition) | 难度 (Difficulty) | 战场备注 (Arena Notes) |
|----|----------|------------------|-----------|-------------|
| E-01 | [Map ref] | [2x Grunt, 1x Ranged] | 3/10 | 开阔地带，侧翼有掩护 |
| E-02 | [Map ref] | [1x Elite, 3x Grunt] | 5/10 | 狭窄走廊，无法撤退 |

### 非战斗遭遇 (Non-Combat Encounters)

| ID | 位置 (Position) | 类型 (Type) | 描述 (Description) | 解法提示 (Solution Hint) |
|----|----------|------|-------------|---------------|

## 节奏图 (Pacing Chart)

```
Intensity
10 |                              *
 8 |                         *   * *
 6 |            *  *        * * *   *
 4 |     *  *  * ** *   *  *
 2 | * ** ** *        * * *          *
 0 |S-----------------------------------------E
     [Start]    [Mid]              [Climax] [Exit]
```

[描述预期的节奏：高峰、低谷和休息点分别在哪里？]

## 音频方向 (Audio Direction)

| 区域/时刻 (Zone/Moment) | 音乐曲目 (Music Track) | 环境音 (Ambience) | 关键音效 (Key SFX) |
|-------------|------------|----------|---------|
| [Entry] | [Track] | [Ambient sounds] | [Door opening] |
| [Combat] | [Combat music] | [Muted ambience] | [Combat SFX] |
| [Post-combat] | [Calm transition] | [Return to ambience] | |

## 视觉方向 (Visual Direction)

- **光照 (Lighting)**： [Key, fill, ambient description]
- **色调 (Color Palette)**： [Dominant colors and why]
- **情绪板参考 (Mood Board References)**： [Description of visual references]
- **地标 (Landmarks)**： [Visible navigation aids and their locations]
- **视线 (Sight Lines)**： [What the player should see from key positions]

## 收藏品与秘密 (Collectibles and Secrets)

| 物品 (Item) | 位置 (Location) | 可见度 (Visibility) | 提示 (Hint) | 解锁条件 (Required For) |
|------|----------|-----------|------|-------------|

## 技术说明 (Technical Notes)

- **预估物体数量 (Estimated Object Count)**： [N]
- **流式加载区域 (Streaming Zones)**： [Where to break the level for streaming]
- **性能考量 (Performance Concerns)**： [Any known heavy areas]
- **所需系统 (Required Systems)**： [What game systems are active in this level]
