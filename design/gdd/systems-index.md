# 系统索引 (Systems Index)：凡人修仙传：掌天问道

> **状态 (Status)**：草稿 (Draft)
> **创建日期 (Created)**：2026-07-21
> **最后更新 (Last Updated)**：2026-07-23
> **来源概念 (Source Concept)**：design/gdd/game-concept.md

---

## 概述 (Overview)

《凡人修仙传：掌天问道》是一款Roguelike卡牌对战游戏，核心循环为：**新档开局→地图探索→触发事件/战斗→获得资源/卡牌→养成强化→渡劫突破→开启新地图→挑战最终BOSS**。

游戏系统覆盖五大循环阶段（开局、探索、战斗、养成、渡劫突破），包含222张卡牌的卡牌系统、5种流派方向、5大境界（炼气→筑基→金丹→元婴→化神）以及跟随原著的章节式剧情。

---

## 系统枚举 (Systems Enumeration)

| # | 系统名称 | 类别 | 优先级 | 状态 | 设计文档 | 依赖项 |
|---|-------------|----------|----------|--------|------------|------------|
| 1 | 游戏状态管理器 | 核心 (Core) | MVP | 已设计 | game-state-manager.md | — |
| 2 | 存档/读档系统 | 核心 (Core) | MVP | 已设计 | save-load-system.md | 游戏状态管理器 |
| 3 | 事件系统 | 核心 (Core) | MVP | 已设计 | event-system.md | — |
| 4 | 探索系统 | 玩法 (Gameplay) | MVP | 已设计 | exploration-system.md | 事件系统、行动力系统 |
| 5 | 行动力系统 | 核心 (Core) | MVP | 已设计 | action-point-system.md | 游戏状态管理器 |
| 6 | 战斗系统（回合制流程） | 玩法 (Gameplay) | MVP | 已设计 | combat-system.md | 卡牌系统、费用系统、AI系统 |
| 7 | 卡牌系统（数据/收藏） | 玩法 (Gameplay) | MVP | 需修订 (Needs Revision) | card-system.md | 游戏状态管理器 |
| 8 | 卡牌效果解析引擎 | 玩法 (Gameplay) | MVP | 设计中 | card-effect-engine.md | 卡牌系统、绑定系统、状态效果系统 |
| 9 | 费用系统 | 玩法 (Gameplay) | MVP | 已设计 | cost-system.md | 战斗系统 |
| 10 | 角色上场与阵位系统 | 玩法 (Gameplay) | MVP | 已设计 | deployment-system.md | 战斗系统、卡牌系统 |
| 11 | 功法/法宝绑定系统 | 玩法 (Gameplay) | MVP | 已设计 | binding-system.md | 战斗系统、卡牌系统 |
| 12 | 阵法系统 | 玩法 (Gameplay) | MVP | 已设计 | formation-system.md | 战斗系统、阵营系统 |
| 13 | 阵营系统 | 玩法 (Gameplay) | MVP | 已设计 | faction-system.md | 卡牌系统 |
| 14 | AI系统（敌方AI） | 玩法 (Gameplay) | MVP | 已设计 | ai-system.md | 战斗系统、卡牌效果解析引擎 |
| 15 | 状态效果系统 | 核心 (Core) | MVP | 已设计 | status-system.md | 游戏状态管理器 |
| 16 | 修为养成系统 | 成长 (Progression) | MVP | 已设计 | cultivation-system.md | 游戏状态管理器 |
| 17 | 境界系统 | 成长 (Progression) | MVP | 已设计 | realm-system.md | 修为养成系统 |
| 18 | 境界压制规则 | 玩法 (Gameplay) | MVP | 已设计 | realm-system.md（压制系数由境界系统定义） | 境界系统、战斗系统 |
| 19 | 渡劫突破系统 | 成长 (Progression) | MVP | 已设计 | tribulation-system.md | 境界系统、战斗系统 |
| 20 | 资源系统（灵石/灵材） | 经济 (Economy) | MVP | 已设计 | resource-system.md | 卡牌系统、探索系统 |
| 21 | 卡组编辑系统 | 玩法 (Gameplay) | MVP | 已设计 | deck-editing-system.md | 卡牌系统 |
| 22 | 炼丹炼器系统 | 经济 (Economy) | Vertical Slice | 已设计 | alchemy-crafting-system.md | 资源系统、卡牌系统 |
| 23 | 法宝铭刻系统 | 经济 (Economy) | Vertical Slice | 已设计 | inscription-system.md | 炼丹炼器系统 |
| 24 | 开局身份选择系统 | 玩法 (Gameplay) | MVP | 已设计 | identity-selection-system.md | 游戏状态管理器、卡牌系统 |
| 25 | 流派系统 | 元 (Meta) | MVP | 已设计 | school-system.md | 阵营系统、卡牌系统 |
| 26 | 轮回天赋系统 | 成长 (Progression) | Vertical Slice | 已设计 | reincarnation-talent-system.md | 存档系统 |
| 27 | 剧情系统（章节推进） | 叙事 (Narrative) | Vertical Slice | 已设计 | story-system.md | 探索系统、境界系统 |
| 28 | 对话系统 | 叙事 (Narrative) | Vertical Slice | 已设计 | dialogue-system.md | 剧情系统 |
| 29 | 结局分支系统 | 叙事 (Narrative) | Full Vision | 已设计 | ending-branch-system.md | 剧情系统 |
| 30 | 战斗UI系统 | UI | MVP | 已设计 | combat-ui-system.md | 战斗系统 |
| 31 | 探索UI系统（地图） | UI | MVP | 已设计 | exploration-ui-system.md | 探索系统 |
| 32 | 卡组编辑UI | UI | MVP | 已设计 | deck-editing-ui-system.md | 卡组编辑系统 |
| 33 | HUD系统 | UI | MVP | 已设计 | hud-system.md | 所有系统 |
| 34 | 主菜单与设置 | UI | MVP | 已设计 | main-menu-system.md | 游戏状态管理器 |
| 35 | 音频管理系统 | 音频 (Audio) | MVP | 已设计 | audio-system.md | 事件系统 |
| 36 | 成就系统 | 元 (Meta) | Full Vision | 已设计 | achievement-system.md | 存档系统 |

---

## 类别 (Categories)

| 类别 | 描述 | 典型系统 |
|----------|-------------|-----------------|
| **核心 (Core)** | 一切依赖的基础系统 | 游戏状态管理器、存档/读档、事件系统、行动力系统、状态效果系统 |
| **玩法 (Gameplay)** | 让游戏有趣的系统 | 探索、战斗、卡牌系统、绑定、阵法、AI、阵营、费用、上场阵位、卡组编辑、开局身份 |
| **成长 (Progression)** | 玩家随时间成长的方式 | 修为养成、境界、渡劫突破、轮回天赋 |
| **经济 (Economy)** | 资源创建与消耗 | 灵石/灵材、炼丹炼器、法宝铭刻 |
| **叙事 (Narrative)** | 故事和对白交付 | 剧情系统、对话系统、结局分支 |
| **UI** | 面向玩家的信息展示 | 战斗UI、探索UI、卡组编辑UI、HUD、主菜单 |
| **音频 (Audio)** | 声音和音乐系统 | 音频管理器 |
| **元 (Meta)** | 核心游戏循环之外的系统 | 流派系统、成就系统 |

---

## 优先级层级 (Priority Tiers)

| 层级 | 含义 | 计划阶段 |
|----------|-------------|-----------------|
| **MVP** | 前可玩版本必需 | 概念原型 → 验证核心循环是否有趣 |
| **Vertical Slice** | 预生产必需的完整功能 | 从MVP到垂直切片的扩展 |
| **Alpha** | 完整游戏所需 | 量产阶段 |
| **Full Vision** | 完整愿景的最终功能 | 发布或发布后更新 |

---

## 设计顺序 (Design Order)

基于依赖关系，系统应按照以下顺序设计：

### 第1层：基础 (Foundation) — 所有下游系统依赖
1. 游戏状态管理器
2. 卡牌系统（数据/收藏）
3. 事件系统
4. 资源系统

### 第2层：核心玩法 (Core Gameplay)
5. 费用系统
6. 角色上场与阵位系统
7. 战斗系统（回合制流程）
8. 功法/法宝绑定系统
9. 阵法系统
10. 阵营系统
11. AI系统
12. 卡牌效果解析引擎
13. 开局身份选择系统

### 第3层：成长与经济 (Progression & Economy)
14. 修为养成系统
15. 境界系统
16. 境界压制规则
17. 渡劫突破系统
18. 行动力系统
19. 卡组编辑系统
20. 炼丹炼器系统 + 铭刻
21. 流派系统
22. 轮回天赋系统

### 第4层：叙事与内容 (Narrative & Content)
23. 剧情系统
24. 对话系统
25. 结局分支系统

### 第5层：表现层 (Presentation)
26. 战斗UI系统
27. 探索UI系统
28. 卡组编辑UI
29. HUD系统
30. 主菜单与设置
31. 音频管理系统
32. 成就系统

---

## 数据流概览 (Data Flow Overview)

```
开局身份选择
    ↓
探索系统 ←── 事件系统 ──→ 战斗系统 ←── 卡牌系统（卡池/收藏）
    ↓              ↓              ↓              ↓
 资源系统     剧情系统     卡牌效果引擎   卡组编辑系统
    ↓                         ↓
 炼丹炼器      绑定系统 ←── 功法/法宝数据
    ↓              ↓
 法宝铭刻      阵法系统 ←── 阵营系统
                    ↓
             修为养成系统 → 境界系统 → 渡劫突破系统
                                        ↓
                                   解锁新地图/新卡池 → 继续探索循环
```

---

## 依赖关系图 (Dependency Map by Layer)

```
层1: 游戏状态管理器 ← 存档/读档
     │
     ├── 卡牌系统 ← 阵营系统
     │
     └── 事件系统

层2: 战斗系统 ─┬── 费用系统
               ├── 角色上场与阵位系统
               ├── 绑定系统 ← 功法/法宝
               ├── 阵法系统 ← 阵营系统
               ├── AI系统
               └── 卡牌效果引擎 ← 卡牌系统

层3: 修为养成 → 境界 → 渡劫突破
     资源系统 → 炼丹炼器 → 法宝铭刻
     卡组编辑 ← 卡牌系统

层4: 剧情系统 → 对话系统 → 结局分支

层5: 战斗UI → HUD
     探索UI → HUD
     卡组编辑UI
```
