# 架构审查报告

**日期**：2026-07-25
**引擎**：Godot 4.6
**已审查 GDD**：42 个（通过 systems-index.md 枚举 36 个系统 + 6 个附属文档）
**已审查 ADR**：14 个（ADR-0001 至 ADR-0014）
**状态**：2026-07-25 全部 5 个冲突已解决

---

## 可追溯性摘要

总需求：14 个 ADR 覆盖 14 个核心系统
✅ 已覆盖：14 个系统（GSM、存档/读档、事件、输入、场景、卡牌、信号通信、战斗、卡牌效果引擎、境界、状态效果、跨局元进度、绑定、探索）
❌ 缺口：22 个系统尚无对应 ADR（费用、上场阵位、阵法、阵营、AI、修为养成、渡劫突破、资源、卡组编辑、炼丹炼器、法宝铭刻、开局身份、流派、轮回天赋、剧情、对话、结局分支、战斗UI、探索UI、卡组编辑UI、HUD、主菜单、音频）

---

## 跨 ADR 冲突

### ✅ 冲突 1：ADR 编号体系不一致（系统性偏移）—— 已解决（2026-07-25）

**类型**：跨 ADR 引用断裂
**涉及 ADR**：ADR-0002 至 ADR-0006
**解决方式**：所有 5 个 ADR 文件（ADR-0002~ADR-0006）的内部标题行和全部交叉引用已修正为与文件名一致。ADR-0007 的信号表和正文中的 Foundation 层 ADR 引用同步修正。`architecture.md` ADR 审计中的 Core 层系统计数从 "3 个" 修正为 "4 个"（卡牌+信号通信+境界+状态效果）。

### ✅ 冲突 2：ADR-0002（SaveLoad）内部依赖"ADR-0002（CardSystem）"——编号歧义 —— 已解决

**类型**：依赖关系
**解决方式**：作为冲突 1 修复的一部分同步修正。ADR-0002（SaveLoad）现在正确引用 ADR-0006（CardSystem）——`reconstitute_instances()` 契约的交叉引用已更新。

### ✅ 冲突 3：ADR-0012 取代 ADR-0001 `progression.*` 域 —— 已解决

**类型**：所有权冲突
**解决方式**：ADR-0001 的「ADR 依赖关系 → 启用」中新增取代声明："`progression.*` 域所有权已由 ADR-0012 取代"。ADR-0001 的「相关决策」中新增 ADR-0012 条目。读取 ADR-0001 时即可看到 progression 域已被取代。

### ✅ 冲突 4：ADR-0002（SaveLoad）的 progression_updated 信号源未同步 —— 已解决

**类型**：信号源冲突
**解决方式**：ADR-0002（SaveLoad）中全部 4 处 `GSM.progression_updated` 引用改为 `ProgressionSystem.progression_updated`。ADR-0002 的「相关决策」中 `progression_updated` 信号源条目更新为引用 ADR-0012。

### ⚠️ 关切 5：所有 14 个 ADR 均处于 "Proposed" 状态

**类型**：生命周期
没有任何 ADR 进入 "Accepted" 状态。Foundation 层 ADR（ADR-0001 ~ ADR-0007）已经过 godot-specialist 和 technical-director 审查，具备 Accepted 条件。

**建议**：在翻转到 Accepted 之前完成对抗性审查（ADR-0001 ~ ADR-0007 优先——它们是所有上层 ADR 的依赖基础）。

---

## ADR 依赖排序

### 推荐的 ADR 实现顺序（拓扑排序）

**基础层（无依赖）**：
1. ADR-0001：游戏状态管理器
2. ADR-0004：输入管理器
3. ADR-0005：场景管理器

**依赖基础层**：
4. ADR-0002：存档/读档系统（依赖 ADR-0001 + ADR-0006[CardSystem]）
5. ADR-0003：事件系统（依赖 ADR-0001 + ADR-0006[CardSystem]）
6. ADR-0006：卡牌数据模型（依赖 ADR-0001）
7. ADR-0007：信号驱动通信（依赖 ADR-0001/0002/0003/0004/0005）

**核心/功能层**：
8. ADR-0010：境界系统（依赖 ADR-0001/0007）
9. ADR-0011：状态效果系统（依赖 ADR-0001/0007/0008/0009）
10. ADR-0008：战斗系统（依赖 ADR-0001/0002/0003/0004/0005/0006/0007/0009/0010/0011）
11. ADR-0009：卡牌效果引擎（依赖 ADR-0001/0002/0004/0007/0008/0010/0011）

**成长与元进度层**：
12. ADR-0012：跨局元进度系统（依赖 ADR-0001/0002/0007）

**功能扩展层**：
13. ADR-0013：绑定系统（依赖 ADR-0001/0006/0007/0008/0009/0010/0011）
14. ADR-0014：探索系统（依赖 ADR-0001/0003/0005/0007/0008/0010）

### 未解决的依赖

⚠️ ADR-0008（战斗系统）标记为依赖 ADR-0009（卡牌效果引擎），但 ADR-0009 也标记为依赖 ADR-0008——形成**相互依赖**。实际上 ADR-0008 §依赖关系 写 "ADR-0009（卡牌效果引擎——效果解析在出牌/攻击阶段被调用）"——这是设计依赖（战斗阶段需要效果引擎），不是实现依赖。需要澄清：ADR-0008 的接口定义在 ADR-0009 之前完成，但 ADR-0009 的实现细节可以在 ADR-0008 之后确定。

⚠️ ADR-0010（境界系统）标记为依赖 ADR-0009（卡牌效果引擎——通过 get_realm_property() 查询 card_pool_tier）。反向依赖也存在：ADR-0009 依赖 ADR-0010（RealmSystem——"境界压制可能影响状态效果强度"）。需要澄清实现顺序。

---

## GDD 修订标志

无——所有 GDD 假设与已验证的引擎行为一致。

---

## 引擎兼容性问题

### 具有引擎兼容性部分的 ADR：14 / 14（100%）

所有 14 个 ADR 均包含引擎兼容性部分——无盲点。

### 截止后 API 使用汇总

| ADR | 截止后 API | 风险 |
|-----|-----------|------|
| ADR-0001 | `Array[String]`（4.4+ 类型化集合） | LOW |
| ADR-0003 | `FileAccess.store_*` 返回 `bool`（4.4+ 破坏性变更） | MEDIUM |
| ADR-0006 | `ResourceLoader.load_threaded_request()`、`Array[StringName]`、`duplicate_deep()` | HIGH |
| ADR-0009 | `@abstract`、GDScript 可变参数、类型化 `Array[EffectInstance]` | HIGH |
| ADR-0005 | 4.6 双焦点系统、SDL3 手柄驱动 | HIGH |
| ADR-0007 | None——核心信号 API 自 4.0 起稳定 | LOW |
| ADR-0008 | None——核心编排逻辑不依赖 4.4+ 新 API | LOW |
| ADR-0010 | None——Dictionary/信号/Autoload 均为 4.0+ 稳定 | LOW |
| ADR-0011 | None——核心逻辑不依赖 4.4+ 新增 API | LOW |
| ADR-0012 | None——所有 API 自 4.0 起稳定 | LOW |
| ADR-0013 | None——核心逻辑不依赖 4.4+ 新增 API | LOW |
| ADR-0014 | None——核心 DAG 生成和导航逻辑不依赖 4.4+ 新 API | LOW |

**总览**：3 个 ADR 有 HIGH 知识风险（ADR-0006、ADR-0009、ADR-0005），1 个 MEDIUM（ADR-0003），其余为 LOW。

### 已弃用 API 引用

无——所有 14 个 ADR 均不引用已弃用 API。

### 引擎版本一致性

所有 14 个 ADR 均一致声明 Godot 4.6——无版本漂移。

---

## 架构文档覆盖

`docs/architecture/architecture.md` 已验证：

| 检查项 | 状态 |
|--------|------|
| systems-index.md 的 36 个系统是否全部出现在架构层中？ | ✅ 是（通过 5 层映射） |
| 是否有架构中没有对应 GDD 的系统？ | ✅ 无（所有系统均有 GDD + 架构归属） |
| 数据流部分是否覆盖了跨系统通信？ | ✅ 是（路径 A/B/C/D） |
| API 边界是否支持 GDD 集成需求？ | ✅ 是（GSM 三层 + 战斗阶段机 + 效果引擎 + 输入管理器 + 场景管理器） |
| 是否有架构中定义但无 GDD 的系统？ | ✅ 无（输入管理器、场景管理器、存档模式版本控制均有明确需求来源——system-mapping-2026-07-24.md 附录） |

---

## 裁决：CONCERNS → RESOLVING

**通过**：所有 14 个 ADR 覆盖了 Foundation/Core/Feature 层的关键系统。无弃用 API 引用。引擎版本一致性良好。全部 5 个跨 ADR 冲突已解决。

**关切**：
1. ~~ADR 编号体系不一致（冲突 1 + 2）~~ → ✅ 已解决
2. ~~ADR-0012 对 ADR-0001/ADR-0002 的取代尚未在源文件中反映（冲突 3 + 4）~~ → ✅ 已解决
3. 所有 14 个 ADR 仍处于 "Proposed" 状态（关切 5）——Foundation 层 ADR 需要推进到 Accepted
4. 22 个系统尚无 ADR——需在进入实现阶段前按优先级逐步创建

**失败**：无阻塞性冲突。

---

## 立即行动

1. ~~修复 ADR-0002 ~ ADR-0006 的编号不一致~~ → ✅ 已完成
2. 接受 Foundation 层 ADR：运行对抗性审查（`code-reviewer adr_review: true`），处理发现的问题，然后翻转为 Accepted
3. 创建费用系统 ADR：`/architecture-decision 费用系统`
4. 创建上场阵位系统 ADR：`/architecture-decision 上场阵位系统`

---

## 关卡前检查清单

- `tests/unit/` 和 `tests/integration/` 目录：❌ 未创建 → 运行 `/test-setup`
- `.github/workflows/tests.yml`：❌ 未创建 → 运行 `/test-setup`
- `design/accessibility-requirements.md`：❌ 未创建 → 运行 `/ux-design`
- `design/ux/interaction-patterns.md`：❌ 未创建 → 运行 `/ux-design`