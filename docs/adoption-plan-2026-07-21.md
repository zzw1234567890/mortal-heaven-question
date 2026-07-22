# 接入计划

> **生成日期**：2026-07-21
> **项目阶段**：Concept
> **引擎**：Godot 4.6（已配置）
> **模板版本**：v1.0+

按顺序完成这些步骤。每完成一项就勾选它。随时重新运行 `/adopt` 检查剩余的差距。

---

## 步骤 1：修复高优先级差距

### 1a. 迁移设计文档到标准位置

**问题**：`《凡人修仙传：掌天问道》核心玩法完整设计.md` 和 `《凡人修仙传：掌天问道》卡牌完整设计文档.md` 位于项目根目录。模板技能只从 `design/gdd/` 读取 GDD，完全看不到它们。

**修复**：将文件移动到 `design/gdd/` 并重命名为符合规范的名称：
```
mv "《凡人修仙传：掌天问道》核心玩法完整设计.md" design/gdd/core-gameplay-design.md
mv "《凡人修仙传：掌天问道》卡牌完整设计文档.md" design/gdd/card-system-design.md
```

**时间**：5 分钟
- [ ] 文件已迁移到 `design/gdd/`

### 1b. 创建 game-concept.md

**问题**：缺少标准化的游戏概念文档（`game-concept.md`），这是所有技能读取的入口文档。

**修复**：运行 `/brainstorm` 或者手动创建 `design/gdd/game-concept.md`，包含一句话宣传语、核心循环、目标受众、平台、视觉风格锚点等。

**时间**：30 分钟
- [ ] `design/gdd/game-concept.md` 已创建

### 1c. 创建 game-pillars.md

**问题**：设计中有三大核心（自由组牌 + 苟道成长 + 原作剧情），但未正式化为游戏支柱文档。

**修复**：创建 `design/gdd/game-pillars.md`（可手动或用 `/brainstorm` 生成）。

**时间**：15 分钟
- [ ] `design/gdd/game-pillars.md` 已创建

### 1d. 创建 systems-index.md

**问题**：完整的游戏系统（探索、战斗、养成、炼丹炼器、渡劫突破、卡牌收集）未被分解为独立系统并注册。

**修复**：运行 `/map-systems` 将概念分解为系统，或手动创建 `design/gdd/systems-index.md`。

**时间**：30 分钟
- [ ] `design/gdd/systems-index.md` 已创建

---

## 步骤 2：中级优先差距

### 2a. 填充 TR 注册表

**问题**：`docs/architecture/tr-registry.yaml` 是空模板框架，无实际需求条目。

**修复**：在创建系统 GDD 后运行 `/architecture-review` 引导 TR 注册表。

**时间**：1 个 session
- [ ] tr-registry.yaml 已填充

### 2b. 写入 stage.txt 和 review-mode.txt

**问题**：`stage.txt` 已存在设为 `Concept`，但 `review-mode.txt` 尚未设置。

**修复**：通过 `/start` 设置审查模式，或手动创建 `production/review-mode.txt`。

**时间**：2 分钟
- [ ] `production/review-mode.txt` 已写入

---

## 步骤 3：GDD 标准格式化（长期任务）

### 3a. 将核心玩法设计转化为标准 GDD

**问题**：现有设计文档内容丰富，但缺少 GDD 模板所需的 8 个必需章节中的大部分。

**修复**：利用现有内容，为每个系统独立运行 `/design-system` 填充完整 GDD。建议分解为以下独立 GDD：

1. **探索系统** — `design/gdd/exploration-system.md`（地图移动、随机事件、行动力）
2. **战斗系统** — `design/gdd/combat-system.md`（回合制流程、费用、绑定额、阵法）
3. **养成系统** — `design/gdd/progression-system.md`（修为、卡槽、境界突破）
4. **炼丹炼器系统** — `design/gdd/crafting-system.md`（灵材、丹药制作、法宝铭刻）
5. **渡劫突破系统** — `design/gdd/tribulation-system.md`（天劫BOSS、渡劫丹、越阶奖励）
6. **卡牌系统** — `design/gdd/card-system.md`（222张卡牌数据库、卡组构建、阵营规则）

每个 GDD 使用 `/design-system [名称]` 创建。

**时间**：每个系统 1 个 session
- [ ] 探索系统 GDD
- [ ] 战斗系统 GDD
- [ ] 养成系统 GDD
- [ ] 炼丹炼器系统 GDD
- [ ] 渡劫突破系统 GDD
- [ ] 卡牌系统 GDD

---

## 对现有工件的预期

现有的设计文件（核心玩法、卡牌设计）在手动迁移到 `design/gdd/` 并分解为各系统 GDD 之前，不会被模板技能识别。它们的内容不会丢失——在运行 `/design-system` 时，可以引用它们作为内容来源。

---

## 重新运行

完成步骤 1（文件迁移）后再次运行 `/adopt`，以验证结构差距是否已解决。新的运行将反映项目的当前状态。
