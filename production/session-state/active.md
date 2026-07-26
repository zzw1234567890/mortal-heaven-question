# 活跃会话状态

> **会话 ID**：2026-07-25
> **上次更新**：2026-07-26（Foundation 层 ADR Accepted + architecture.md v1.4 同步）

## 本会话成果

### Foundation 层 ADR 全部 Accepted ✅

| ADR | 系统 | 审查结果 | 修复项 | 最终状态 |
|-----|------|:--:|:--:|:--:|
| ADR-0001 | GSM 三层 API | 7 HIGH | 交叉引用 ×3、缺 6 章节、GDD 路径 | **Accepted** |
| ADR-0002 | 存档/读档 | 3 HIGH | meta + current_scene、event_resolved 连接 | **Accepted** |
| ADR-0003 | 事件系统 | ✅ PASS | 仅 ADR-0001 L112 引用修正 | **Accepted** |
| ADR-0004 | 输入管理器 | 3 CONCERNS | 白名单语义修正、MODAL 覆盖机制 | **Accepted** |
| ADR-0005 | 场景管理器 | ✅ PASS | assert→if、注释修正 | **Accepted** |

### 法宝铭刻 ADR 创建 ✅

| ADR | 系统 | 模式 | 状态 |
|-----|------|------|:--:|
| ADR-0030 | 法宝铭刻系统 | RefCounted + class_name（零 Autoload） | **Proposed** |

### 跨 ADR 修复

- ADR-0008 战斗系统 Phase 3 ATTACK_DECLARATION 锁冲突修复（pop/push ANIMATION）
- architecture.md ADR-0005→ADR-0004 输入管理器编号引用修正
- architecture.md v1.3→v1.4：30 ADR + Foundation Accepted 标注

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
Feature: Foundation ADR Accepted + ADR-0030 创建
Task: architecture.md v1.4 同步 — complete ✅
<!-- /STATUS -->

## 关键架构决策

1. **ADR 覆盖 30/36 GDD 系统**：剩余 6 个为 UI 层（6 个）——编码阶段直接决策。法宝铭刻已由 ADR-0030 覆盖
2. **Autoload 链 25 个**：超出 Godot 20 软上限 ⚠️——第三批后新增系统（对话/炼丹炼器/结局分支/法宝铭刻）全部采用 RefCounted 阻止进一步膨胀
3. **Foundation 层 5 个 ADR 全部 Accepted ✅**：编码阶段可开始实现 Foundation 系统
4. **Core 层"静态数据表三剑客"**：RealmSystem(#11) + FactionSystem(#15) + SchoolSystem(#19)——均采用 const Dictionary + 纯查询接口
5. **GSM 例外清单四条目**：StatusEffectSystem + BindingManager + DeploymentSystem + FormationSystem——战斗热路径内部管理 + 战斗结束 GSM 快照
6. **ADR-0001 第二层原子方法**：24 个方法（8 个明确签名 + 3 个图表中存在 + 12 个其他 ADR 定义 + 1 个最终状态变更）——需汇总回 ADR-0001（见遗留问题 #3）

## ADR 总数统计

| 层 | 数量 | Autoload | 非 Autoload | Accepted |
|-----|------|:--:|:--:|:--:|
| Foundation | 5 | 5 | 0 | 5 ✅ |
| Core | 9 | 8 | 0 | 0 |
| Feature | 11 | 11 | 0 | 0 |
| Meta | 1 | 1 | 0 | 0 |
| Narrative | 2 | 0 | 2 | 0 |
| Economy | 2 | 0 | 2 | 0 |
| **总计** | **30** | **25** | **4** | **5** |

## 已知遗留问题

1. **行数超标**：多个 ADR 超出 ≤250 行目标
2. **ADR-0015 双重信号路径**：cost_changed (Cat 2b) + batch_updated (Cat 1)
3. **GSM 第二层方法碎片化**：24 个原子方法分布在 ADR-0001（8+3）、ADR-0014（6）、ADR-0020/0021（1）、ADR-0022（1）、ADR-0026（5）——需汇总回 ADR-0001
4. **Autoload 25 超 20 软上限**：已在所有相关 ADR 中明确记录风险
5. **Core/Feature/Narrative/Economy/Meta 层 ADR 仍为 Proposed**：25 个非 Foundation 层 ADR 等待实现前审查
