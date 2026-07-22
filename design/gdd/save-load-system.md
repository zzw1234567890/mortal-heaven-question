# 存档/读档系统 (Save/Load System)

> **状态 (Status)**：设计中 (In Design)
> **作者 (Author)**：Claude Code + 用户
> **最后更新 (Last Updated)**：2026-07-22
> **最后验证 (Last Verified)**：—
> **实现的支柱 (Implements Pillar)**：支柱2「苟道成长，步步为营」

## 概述

存档/读档系统负责游戏所有持久化数据的I/O操作，作为游戏状态管理器（GSM）的数据持久化层。系统管理存档文件的创建、读取、删除、覆盖和版本迁移，支持多存档槽位和自动/手动两种存档模式。系统同时管理跨局元进度（progression）的独立读写——该数据不随单局游戏重置，保留玩家跨局的永久性解锁和成就。

对玩家来说，存档系统提供了游戏进度的安全感——「我可以随时停下来，下次继续」。自动存档让玩家专注于决策而不必担心丢失进度，手动存档让玩家可以在关键节点前保存（或回退）。存档系统的稳定性直接影响玩家对游戏的信任——存档损坏是最让玩家沮丧的问题之一。

暂无相关ADR。

## 玩家幻想

存档系统是玩家对游戏世界信任感的最后一道防线。当玩家看到「存档中…」的提示、几秒后读到自己的进度完好无损时，那种安心感就是存档系统的核心价值。存档系统的理想状态是**玩家意识不到它的存在**——自动存档在后台静默完成，读档过程流畅无缝。只有当存档损坏或玩家想手动保存时，系统才出现在玩家的视野中。

跨局元进度则承载了另一种情感——**积累的骄傲**。每次死亡后的轮回，看到「历史最高境界：金丹」和已解锁的天赋，玩家知道自己的努力没有白费。

## 详细设计

### 核心规则

#### 1. 存档类型

| 类型 | 触发时机 | 槽位规则 | 说明 |
|------|---------|---------|------|
| **自动存档 (AutoSave)** | 场景切换、战斗结束、探索节点完成、重要事件后 | 固定使用 `autosave` 槽位（每局唯一，自动覆盖） | 玩家不可命名，不可删除（但可被手动存档覆盖） |
| **手动存档 (ManualSave)** | 玩家在菜单或特定节点主动保存 | 3个槽位：`save_1`、`save_2`、`save_3` | 玩家可命名、覆盖、删除 |
| **战斗前快照 (BattleSnapshot)** | 进入战斗前自动生成 | 固定 `pre_battle` 槽位 | 战斗中战败后可选择「读档重来」。战斗胜利或撤退后自动清除 |
| **跨局元进度 (Progression)** | 境界突破、获得新卡牌解锁、天赋解锁、成就达成时 | 独立文件 `progression.dat` | 不随存档重置，跨局永久保留 |

#### 2. 文件结构

```
user://saves/
├── autosave/
│   └── save.json              # 自动存档数据
├── manual/
│   ├── save_1.json            # 手动存档1
│   ├── save_2.json            # 手动存档2
│   └── save_3.json            # 手动存档3
├── snapshot/
│   └── pre_battle.json        # 战斗前快照（战斗中自动清除）
├── progression.dat            # 跨局元进度（独立存储）
└── meta.json                  # 存档元信息（各槽位的名称、时间、境界、时长）
```

#### 3. 存档数据格式

存档数据使用 **JSON 格式**，结构如下：

```
# save.json / save_N.json 结构
{
  "version": "1.0.0",                    # 存档格式版本
  "timestamp": "2026-07-22T15:30:00Z",   # 存档时间
  "playtime_seconds": 3600,              # 当前局已玩时间
  "meta": {                              # 展示用元信息
    "player_name": "凡人001",
    "realm": "筑基",
    "chapter": 2,
    "map_name": "乱星海·外海",
    "deck_size": 32
  },
  "game_state": { ... }                  # GSM.serialize() 输出
}

# meta.json 结构
{
  "version": "1.0.0",
  "slots": {
    "autosave": {
      "name": "自动存档",
      "timestamp": "2026-07-22T15:30:00Z",
      "realm": "筑基",
      "playtime": 3600,
      "exists": true
    },
    "save_1": {
      "name": "渡劫前备份",
      "timestamp": "2026-07-22T14:00:00Z",
      "realm": "金丹",
      "playtime": 7200,
      "exists": true
    },
    "save_2": { "exists": false },
    "save_3": { "exists": false }
  }
}

# progression.dat 结构
{
  "version": "1.0.0",
  "highest_realm": "金丹",
  "total_playtime_seconds": 86400,
  "unlocked_cards": ["card_001", "card_002", ...],
  "unlocked_talents": ["talent_001", ...],
  "achievements": {
    "ach_001": { "unlocked": true, "unlocked_at": "2026-07-20T10:00:00Z" },
    "ach_002": { "unlocked": false }
  },
  "statistics": {
    "total_battles": 120,
    "total_victories": 85,
    "total_deaths": 15,
    "highest_damage": 999
  }
}
```

#### 4. 存档流程

```
保存流程（save_game(slot_type, slot_id)）：
① 调用 GSM.serialize() → 获取全量状态 Dictionary
② 封装存档容器（添加 version / timestamp / meta 等元数据）
③ 写入 user://saves/{type}/{id}.json
④ 更新 meta.json（槽位元信息）
⑤ 返回 SaveResult.SUCCESS 或 SaveResult.ERROR

自动存档流程：
① 监听 GSM 信号（scene_changed、battle_ended、exploration_node_completed）
② 延迟 0.5s 后执行保存（防频繁写入）
③ 写入 autosave 槽位
④ 写入完成后，删除 pre_battle 快照（如果存在）
⑤ 静默执行（不显示UI提示，仅全局日志记录）

战斗前快照流程：
① 监听 battle_started 信号
② 立即调用 GSM.serialize()（排除当前 battle 域？——否，包含战斗开始前的全状态）
③ 写入 snapshot/pre_battle.json
④ 战斗结束后（battle_ended 信号）→ 删除 pre_battle.json

战斗读档重来（retry）：
① 检查 snapshot/pre_battle.json 是否存在
② 存在 → 调用 GSM.deserialize(pre_battle_data.game_state)
③ 删除 pre_battle.json
④ 加载战斗场景，玩家回到战斗开始前
⑤ 不存在 → 提示"无可用战斗快照"，返回探索地图
```

#### 5. 读档流程

```
读档流程（load_game(slot_type, slot_id)）：
① 读取 user://saves/{type}/{id}.json
② 校验文件完整性（非空、合法JSON）
③ 校验 version 兼容性（major.minor 匹配当前版本）
④ 提取 game_state 字段
⑤ 调用 GSM.deserialize(game_state)
⑥ GSM 校验状态完整性：
   - 缺失字段 → 默认值填充（向前兼容）
   - 数据损坏 → 返回 false
⑦ deserialize 成功 → 切换场景到 state.exploration.current_map_id
⑧ deserialize 失败 → 清空内存状态，显示"存档损坏"UI，返回主菜单
⑨ 删除 pre_battle.json（读档后清除旧快照）
⑩ 返回 LoadResult.SUCCESS 或 LoadResult.ERROR
```

#### 6. 版本兼容策略

存档版本号语义：`MAJOR.MINOR.PATCH`

| 版本变化 | 兼容性 | 处理方式 |
|---------|-------|---------|
| MAJOR 增加 | **不兼容** | 拒绝加载，提示"存档版本过旧，无法兼容新版本" |
| MINOR 增加 | 向前兼容 | 缺失字段用默认值填充，不报错 |
| PATCH 增加 | 完全兼容 | 直接加载，无任何特殊处理 |

**存档升级路径**：当游戏版本更新时（如从 v1.0 到 v1.1），系统不修改旧存档文件。在 `deserialize()` 中通过默认值填充处理新字段。如果需要结构变更（如重命名字段），在存档系统外部编写迁移脚本，不内置在运行时加载路径中。

#### 7. 跨局元进度（Progression）的读写

```
save_progression():
① 从 GSM 读取 progression 域数据
② 写入 user://saves/progression.dat
③ 写入失败 → 静默重试2次，仍失败则记录日志（不阻塞游戏）

load_progression():
① 读取 user://saves/progression.dat
② 文件不存在 → 返回初始默认值（首次启动）
③ 文件损坏 → 重置为初始值，记录日志，发射 progression_reset 信号
④ 文件正常 → 加载到 GSM.progression 域
```

progression 使用 `.dat` 扩展名并采用简单混淆（非真正加密），防止玩家轻易修改。目的不是防作弊（单机游戏无此必要），而是防止误修改导致数据损坏。

#### 8. 存档删除

```
delete_save(slot_type, slot_id):
① 删除 user://saves/{type}/{id}.json
② 更新 meta.json 对应槽位为 { exists: false }
③ 返回 true（始终返回 true——即使文件不存在也视为删除成功）

clear_battle_snapshot():
① 删除 snapshot/pre_battle.json
② 静默执行（外部只在战斗胜利/撤退时调用）
```

#### 9. 自动存档频率防抖

为避免频繁的场景切换导致连续写入，自动存档使用**防抖机制**：

- 两次自动存档之间至少间隔 **10秒**
- 同一场景下的多次场景切换（如探索地图上连续移动）→ 仅保存最后一次
- 不同场景间的切换（探索→战斗→结算）→ 每次场景变更都保存（不受10秒限制）
- 玩家在菜单中手动触发保存 → 不受任何限制

#### 10. 新游戏流程

```
new_game(player_identity):
① 清空 autosave 槽位 → 写入新存档
② 清空所有 manual save 槽位的 exists 标记（不删除文件，仅标记）
③ 删除 pre_battle.json
④ progression 文件**不删除**
⑤ 调用 GSM.new_game(player_identity) 初始化状态
```

### 状态与转换

存档系统自身不维护运行时状态机。以下为存档文件的生命周期：

```
写入生命周期：
  不存在 → save() → 存在（可读）
  存在 → save()（覆盖）→ 存在（更新）
  存在 → delete() → 不存在

战斗快照生命周期：
  不存在 → battle_started → 存在（pre_battle.json）
  存在 → battle_ended（胜利）→ delete() → 不存在
  存在 → battle_ended（战败）+ 玩家选「读档」→ load() + delete() → load后→ 不存在
  存在 → battle_ended（战败）+ 玩家选「放弃」→ delete() → 不存在
  存在 → 读档（非战斗）→ delete() → 不存在（防止旧快照残留）
```

### 与其他系统的交互

| 系统 | 数据流入（本系统→目标） | 数据流出（目标→本系统） |
|------|----------------------|---------------------|
| **游戏状态管理器** | serialize() 请求 / deserialize(data) 调用 | serialize() 返回全量Dictionary；deserialize 成功/失败返回值 |
| **战斗系统** | 预战斗快照的读写；battle_started/ended 信号监听 | 战斗开始/结束事件 |
| **探索系统** | 场景切换事件→触发自动存档 | 节点完成事件 |
| **UI系统** | 存档槽信息（meta.json 数据）→存档选择界面；保存/读档操作结果回调 | 玩家保存/读档/删除操作 |
| **主菜单系统** | 存档列表展示、新游戏/读档/删除操作 | 玩家选择结果 |
| **HUD系统** | 自动存档时不输出，手动存档成功时发射存档成功提示 | — |

## 公式

### 1. 存档路径解析

```
save_path(slot_type, slot_id) → String:
  path = "user://saves/"
  match slot_type:
    AUTOSAVE: path += "autosave/save.json"
    MANUAL:   path += "manual/save_{slot_id}.json"
    SNAPSHOT: path += "snapshot/pre_battle.json"
    PROGRESSION: path += "progression.dat"
  return path
```

### 2. 版本兼容校验

```
is_version_compatible(save_version, current_version) → bool:
  return save_version.major == current_version.major
```

| 变量 | 类型 | 范围 | 描述 |
|------|------|------|------|
| save_version | Version | MAJOR.MINOR.PATCH | 存档文件记录的版本号 |
| current_version | Version | MAJOR.MINOR.PATCH | 当前游戏版本号 |

**验证：** save=v1.2.0, current=v1.3.0 → major均为1 → true；save=v1.2.0, current=v2.0.0 → 1≠2 → false

### 3. 自动存档防抖校验

```
can_autosave() → bool:
  if last_autosave == null: return true
  elapsed = now() - last_autosave
  if last_scene != current_scene: return true  # 跨场景不受限
  return elapsed >= AUTOSAVE_COOLDOWN
```

| 变量 | 类型 | 范围 | 描述 |
|------|------|------|------|
| AUTOSAVE_COOLDOWN | float | 固定值 | 同一场景内自动存档最小间隔（默认10秒） |
| elapsed | float | ≥0 | 距上次自动存档的秒数 |
| last_scene | String | — | 上次自动存档时的场景路径 |

## 边界情况

- **存档空间不足**：文件写入失败→返回 SaveResult.DISK_FULL→UI显示"存储空间不足，请清理后重试"
- **存档写入中断（游戏崩溃）**：JSON写入非原子操作→写入中崩溃可能产生不完整文件→通过文件末尾的 `"complete": true` 标记校验完整性；不完整的文件视为损坏
- **多档同时操作**：Godot单线程，无并发写冲突。同一帧内不会出现两个写入请求
- **读档时游戏版本更新**：major不变→兼容加载；major增加→拒绝加载，显示"存档版本不兼容"
- **手动存档覆盖自动存档**：允许——手动保存时选择自动存档槽位→自动存档升级为手动存档（不再被自动存档覆盖）
- **删除正在进行游戏的存档**：允许——玩家可以删除当前局的存档槽，但不会影响正在运行的游戏中状态。下次游戏启动时读档会显示空槽位
- **战斗快照不存在时点击"重试"**：检查快照文件存在性→不存在时按钮灰色不可用，提示"无可用战斗快照"
- **跨局元数据文件被删除**：视为首次启动，重新初始化默认值，不报错
- **存档日期异常（远在未来/过去）**：接受但记录警告日志。存档时间仅用于展示，不用于逻辑判定
- **新游戏后旧手动存档仍在文件系统上**：标记槽位为不存在，但保留旧文件。玩家在加载界面看不到该槽位，但文件系统上文件未被删除（可在存档管理中选择删除操作）
- **游戏中关闭自动存档功能**：不提供此选项——自动存档是强制性的（战斗安全和防数据丢失）。但玩家可通过修改配置文件禁用（需自行承担风险）
- **存档数量达到上限**：手动存档固定3个槽位，不支持额外增加。"未使用"的槽位不计入，每个槽位只保留一份文件

## 依赖关系

| 依赖系统 | 性质 | 说明 |
|----------|------|------|
| **游戏状态管理器** | 硬依赖 | 通过 serialize/deserialize 接口存取全部游戏状态；progression 域读写也通过GSM完成 |

### 上游依赖设计顺序

游戏状态管理器（已设计） → 存档/读档系统

所有下游系统不直接依赖存档系统（它们通过GSM读写状态，由存档系统统一持久化）。

## 调优参数

| 参数 | 默认值 | 安全范围 | 过低影响 | 过高影响 |
|------|:-----:|:--------:|---------|---------|
| 手动存档槽位数 | 3 | 2-10 | 存档策略空间小 | 存档太多难以管理 |
| 自动存档防抖间隔 | 10秒 | 5-60秒 | 频繁写入浪费SSD寿命 | 丢失30秒以上进度 |
| 战斗快照保留上限 | 1个 | 1-3 | 无（1个够用） | 保留多快照浪费空间 |
| 存档压缩 | 否（纯JSON） | 无压缩/gzip | 存档文件较大（~1MB） | 压缩增加读写时间 |
| 版本兼容策略 | major锁定 | major/minor/patch | 向前兼容太严格 | 结构变更风险 |

## 视觉/音频需求

| 事件 | 动画 | 时长 |
|------|------|:----:|
| 手动保存完成 | 右下角浮现"存档完成"文字提示 | 1.5s淡出 |
| 存档删除 | 无动画（列表刷新） | — |
| 读档加载 | 加载界面/转场动画（由主菜单系统统一管理） | — |

### 音效需求
- 手动保存：轻快的纸页合拢声（可选，低优先级）
- 存档完成提示：轻柔的确认音

## 用户界面需求

| 界面 | 触发场景 | 核心功能 |
|------|----------|----------|
| **存档选择界面** | 玩家在菜单选择「载入游戏」或「保存游戏」 | 显示所有槽位的 meta 信息（时间、境界、游戏时长、玩家命名）；自动存档标注"自动"标记；空槽位显示"空"；保存模式/载入模式不同按钮文字 |
| **存档详情** | 悬停/选中存档 | 显示更详细的存档信息：卡组张数、当前地图、章节进度 |
| **删除确认弹窗** | 玩家选择删除存档 | "确定删除 [存档名称]？此操作不可恢复"；确认/取消按钮 |
| **覆盖确认弹窗** | 保存到已有存档的槽位 | "保存将覆盖 [存档名称] 的进度。继续？"；确认/取消 |
| **战斗快照提示** | 战败后 | 显示"要回到战斗前重试吗？"；[重试]/[放弃]按钮。提示"仅保留最近一次战斗的快照" |

> **📌 用户体验标记—存档/读档系统**：此系统有UI需求。在预生产中运行 `/ux-design` 为存档选择界面和战斗快照提示创建用户体验规格。

## 验收标准

- **GIVEN** 玩家手动保存，**WHEN** 保存完成，**THEN** 存档文件写入到 user://saves/manual/save_N.json
- **GIVEN** 自动存档触发，**WHEN** 保存完成，**THEN** 存档文件写入到 user://saves/autosave/save.json
- **GIVEN** 战斗开始，**WHEN** battle_started 信号触发，**THEN** 战斗前快照写入 user://saves/snapshot/pre_battle.json
- **GIVEN** 战斗胜利，**WHEN** battle_ended(victory) 信号触发，**THEN** pre_battle.json 被删除
- **GIVEN** 战斗战败且快照存在，**WHEN** 玩家选择「重试」，**THEN** GSM 通过 deserialize() 恢复到战斗前状态
- **GIVEN** 读档操作，**WHEN** 加载完成，**THEN** GSM 状态与存档时的状态一致
- **GIVEN** 存档版本 major 不匹配，**WHEN** 尝试加载，**THEN** 拒绝加载并提示版本不兼容
- **GIVEN** 存档版本 minor 低于当前，**WHEN** 加载，**THEN** 缺失字段使用默认值填充
- **GIVEN** 存档文件损坏，**WHEN** 尝试加载，**THEN** deserialize 返回 false，显示"存档损坏"
- **GIVEN** 手动存档覆盖已有存档，**WHEN** 玩家确认，**THEN** 旧文件被覆盖，meta.json 更新
- **GIVEN** 删除存档，**WHEN** 操作完成，**THEN** meta.json 对应槽位标记为 { exists: false }
- **GIVEN** 新游戏开始，**WHEN** 身份选择完成，**THEN** 自动存档写入，手动存档槽位被清空标记
- **GIVEN** progression 文件不存在，**WHEN** 游戏启动，**THEN** 初始化为默认值，不报错
- **GIVEN** 同一场景内连续触发自动存档，**WHEN** 两次间隔 <10秒，**THEN** 第二次被跳过
- **GIVEN** 跨场景自动存档（探索→战斗），**WHEN** 场景切换，**THEN** 不受10秒间隔限制，立即保存
- **GIVEN** 玩家读到一半退出，**WHEN** 重新启动并读档，**THEN** 进度完全恢复到上次保存点

## 待解决问题

| # | 问题 | 影响 | 建议解决时间 |
|---|------|------|------------|
| 1 | `progression.dat` 是否要加密/混淆？当前设计为简单混淆（防误改而非防作弊）。如果未来有速通排行榜需求，可能需要更强的完整性校验 | 防作弊策略 | 上线前决定 |
| 2 | Steam 云存档集成——存档路径是否需要配合 Steam Cloud API？Godot 4.6 的 user:// 路径在 Steam 环境下自动映射到 Steam Cloud 吗？ | 存档同步 | 架构阶段决定 |
| 3 | 自动存档防抖间隔 10 秒是否合理？需要实际游戏测试验证 | 用户体验 | QA 阶段调优 |
