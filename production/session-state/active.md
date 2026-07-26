# 活跃会话状态

> **会话 ID**：2026-07-25
> **上次更新**：2026-07-25（第三批 ADR 3 个 + architecture.md v1.3 同步完成）

## 本会话成果

### 三批 ADR 全部完成（共 15 个）

| 批次 | ADR | 系统 | 层 | Autoload # |
|------|-----|------|-----|-----------|
| 1 | 0015 | 费用系统 (CostSystem) | Core | #7 |
| 1 | 0016 | 上场阵位系统 (DeploymentSystem) | Feature | #17 |
| 1 | 0017 | AI 系统 (AISystem) | Feature | #18 |
| 1 | 0018 | 阵营系统 (FactionSystem) | Core | #15 |
| 1 | 0019 | 资源系统 (ResourceSystem) | Core | #16 |
| 2 | 0025 | 流派系统 (SchoolSystem) | Core | #19 |
| 2 | 0020 | 修炼养成系统 (CultivationSystem) | Feature | #20 |
| 2 | 0022 | 开局身份系统 (IdentitySelectionSystem) | Feature | #21 |
| 2 | 0023 | 卡组编辑系统 (DeckEditingSystem) | Feature | #22 |
| 2 | 0024 | 阵法系统 (FormationSystem) | Feature | #23 |
| 2 | 0021 | 渡劫突破系统 (TribulationSystem) | Feature | #24 |
| 2 | 0026 | 剧情系统 (StorySystem) | Feature | #25 |
| 3 | 0027 | 对话系统 (DialogueSystem) | Narrative | **零 Autoload** |
| 3 | 0028 | 炼丹炼器系统 (AlchemyCraftingSystem) | Economy | **零 Autoload** |
| 3 | 0029 | 结局分支系统 (EndingBranchSystem) | Narrative | **零 Autoload** |

### 跨 ADR 一致性修复

1. **第一批**：Autoload #14 冲突 → #17/#18；全链统一 18 个；architecture.md v1.0→v1.1
2. **第二批**：#19 七路冲突 → 按依赖链分配 #19~#25；流派 Feature→Core 迁移；architecture.md v1.1→v1.2
3. **第三批**：零 Autoload 扩容——对话（RefCounted 服务类）、炼丹炼器（class_name 工具类）、结局分支（嵌入 StorySystem）；architecture.md v1.2→v1.3

## Autoload 全链（25 个）

```
#1  GSM                 (FOUNDATION)
#2  InputManager         (FOUNDATION)
#3  SceneManager         (FOUNDATION)
#4  SaveLoadSystem       (FOUNDATION)
#5  EventSystem          (FOUNDATION)
#6  CardSystem           (CORE)
#7  CostSystem           (CORE)      ← ADR-0015
#8  StatusEffectSystem   (CORE)
#9  CombatSystem         (FEATURE)
#10 CardEffectEngine     (FEATURE)
#11 RealmSystem           (CORE)
#12 ProgressionSystem     (META)
#13 BindingManager        (FEATURE)
#14 ExplorationSystem     (FEATURE)
#15 FactionSystem         (CORE)      ← ADR-0018
#16 ResourceSystem        (CORE)      ← ADR-0019
#17 DeploymentSystem      (FEATURE)   ← ADR-0016
#18 AISystem              (FEATURE)   ← ADR-0017
#19 SchoolSystem          (CORE)      ← ADR-0025
#20 CultivationSystem     (FEATURE)   ← ADR-0020
#21 IdentitySelectionSystem (FEATURE) ← ADR-0022
#22 DeckEditingSystem     (FEATURE)   ← ADR-0023
#23 FormationSystem       (FEATURE)   ← ADR-0024
#24 TribulationSystem     (FEATURE)   ← ADR-0021
#25 StorySystem           (FEATURE)   ← ADR-0026
```

## 非 Autoload 系统（3 个——均为第三批）

| 系统 | 模式 | ADR |
|------|------|-----|
| 对话系统 | RefCounted 服务类（DialoguePlayer + DialogueDatabase + BarkManager）+ JSON 按需加载 | ADR-0027 |
| 炼丹炼器系统 | RefCounted + class_name 工具类 + PRD 独立 RNG 实例 | ADR-0028 |
| 结局分支系统 | EndingEvaluator 纯函数工具类嵌入 StorySystem | ADR-0029 |

<!-- STATUS -->
Epic: Architecture Foundation
Feature: ADR 全批次（0015~0029）
Task: architecture.md v1.3 同步 — complete ✅
<!-- /STATUS -->

## 关键架构决策

1. **ADR 覆盖 29/36 GDD 系统**：剩余 7 个为 UI 层（6 个）+ 法宝铭刻（1 个）——编码阶段直接决策
2. **Autoload 链 25 个**：超出 Godot 20 软上限 ⚠️——第三批全部采用 RefCounted 阻止进一步膨胀
3. **RefCounted 轻量模式确立**：对话/炼丹炼器/结局分支三系统论证了"非 Autoload 架构"的可行性——为未来系统（法宝铭刻等）提供先例
4. **Core 层"静态数据表三剑客"**：RealmSystem(#11) + FactionSystem(#15) + SchoolSystem(#19)——均采用 const Dictionary + 纯查询接口
5. **GSM 例外清单四条目**：StatusEffectSystem + BindingManager + DeploymentSystem + FormationSystem——战斗热路径内部管理 + 战斗结束 GSM 快照

## ADR 总数统计

| 层 | 数量 | Autoload | 非 Autoload |
|-----|------|:--:|:--:|
| Foundation | 5 | 5 | 0 |
| Core | 9 | 8 | 0 |
| Feature | 11 | 11 | 0 |
| Meta | 1 | 1 | 0 |
| Narrative | 2 | 0 | 2 |
| Economy | 1 | 0 | 1 |
| **总计** | **29** | **25** | **3** |

## 已知遗留问题

1. **行数超标**：多个 ADR 超出 ≤250 行目标
2. **ADR-0015 双重信号路径**：cost_changed (Cat 2b) + batch_updated (Cat 1)
3. **GSM 第二层方法碎片化**：多家 ADR 各自定义 GSM 原子方法——需汇总回 ADR-0001
4. **Autoload 25 超 20 软上限**：已在所有相关 ADR 中明确记录风险
5. **法宝铭刻系统无 ADR**：与炼丹炼器紧密关联——编码前应决策
