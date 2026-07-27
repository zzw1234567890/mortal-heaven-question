# 需求可追溯性矩阵 (Requirements Traceability Matrix)

> **日期**：2026-07-27
> **引擎**：Godot 4.6
> **状态**：初始化——制作阶段逐步填充

## 支柱 → GDD 需求 → ADR → Story 映射

本文档追踪每个游戏支柱如何通过 GDD 需求、ADR 决策和 Story 实现得到覆盖。

### 支柱 1：自由组牌，策略为王

| GDD 需求 ID | 需求描述 | ADR 覆盖 | Story 覆盖 |
|-------------|---------|----------|-----------|
| TR-card-001 | 卡牌模板/实例分离数据模型 | ADR-0006 | 待 /create-stories |
| TR-card-002 | 222 张卡牌数据库 | ADR-0006 | 待 /create-stories |
| TR-card-003 | 卡组编辑系统 | ADR-0023 | 待 /create-stories |
| TR-combat-001 | 7 阶段战斗状态机 | ADR-0008 | 待 /create-stories |
| TR-combat-002 | 卡牌效果解析引擎 | ADR-0009 | 待 /create-stories |

### 支柱 2：苟道成长，步步为营

| GDD 需求 ID | 需求描述 | ADR 覆盖 | Story 覆盖 |
|-------------|---------|----------|-----------|
| TR-realm-001 | 5 境界成长体系 | ADR-0010 | 待 /create-stories |
| TR-cult-001 | 修为获取 6 条途径 | ADR-0020 | 待 /create-stories |
| TR-trib-001 | 渡劫突破机制 | ADR-0021 | 待 /create-stories |
| TR-save-001 | 存档/读档系统 | ADR-0002 | 待 /create-stories |

### 支柱 3：机缘巧合，意外之喜

| GDD 需求 ID | 需求描述 | ADR 覆盖 | Story 覆盖 |
|-------------|---------|----------|-----------|
| TR-expl-001 | 程序化探索 DAG | ADR-0014 | 待 /create-stories |
| TR-event-001 | 事件系统模板化 | ADR-0003 | 待 /create-stories |
| TR-res-001 | 资源经济系统 | ADR-0019 | 待 /create-stories |

### 支柱 4：修仙问道，唯我独行

| GDD 需求 ID | 需求描述 | ADR 覆盖 | Story 覆盖 |
|-------------|---------|----------|-----------|
| TR-story-001 | 5 章剧情推进 | ADR-0026 | 待 /create-stories |
| TR-dial-001 | 对话系统 | ADR-0027 | 待 /create-stories |
| TR-end-001 | 结局分支评估 | ADR-0029 | 待 /create-stories |

---

**注**：此矩阵为骨架版本。在每个 Epic 运行 `/create-stories` 后，Story 列将填充具体的 Story 文件路径和 ID。