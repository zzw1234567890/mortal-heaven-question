# 架构审查报告

**日期**：2026-07-25
**引擎**：Godot 4.6
**已审查 GDD**：42 个（通过 systems-index.md 枚举 36 个系统 + 6 个附属文档）
**已审查 ADR**：14 个（ADR-0001 至 ADR-0014）

---

## 可追溯性摘要

总需求：14 个 ADR 覆盖 14 个核心系统
✅ 已覆盖：11 个系统（GSM、存档/读档、事件、输入、场景、卡牌、信号通信、战斗、卡牌效果引擎、境界、状态效果）
⚠️ 部分覆盖：3 个系统（跨局元进度——ADR-0012 取代了 ADR-0001 的 progression 域、绑定——ADR-0013、探索——ADR-0014）
❌ 缺口：22 个系统尚无对应 ADR（费用、上场阵位、阵法、阵营、AI、修为养成、渡劫突破、资源、卡组编辑、炼丹炼器、法宝铭刻、开局身份、流派、轮回天赋、剧情、对话、结局分支、战斗UI、探索UI、卡组编辑UI、HUD、主菜单、音频、成就）

---

## 覆盖缺口（不存在 ADR 的系统）

### 基础层缺口（编码前必须创建）

无——Foundation 层所有 5 个 ADR（GSM、存档/读档、事件、输入、场景）已创建。

### 核心层缺口

| # | 系统 | 建议 ADR | 领域 | 引擎风险 |
|---|------|---------|------|---------|
| 1 | 费用系统 | `/architecture-decision 费用系统` | Core | LOW |
| 2 | 行动力系统 | 已部分融入 ADR-0014（探索系统）——可能需要独立 ADR | Core | LOW |

### 功能层缺口（在相关系统构建前应有）

| # | 系统 | 建议 ADR | 领域 | 引擎风险 |
|---|------|---------|------|---------|
| 3 | 上场阵位系统 | `/architecture-decision 上场阵位系统` | Feature | LOW |
| 4 | 阵法系统 | `/architecture-decision 阵法系统` | Feature | LOW |
| 5 | 阵营系统 | `/architecture-decision 阵营系统` | Feature | LOW |
| 6 | AI系统 | `/architecture-decision AI系统` | Feature | LOW |
| 7 | 修为养成系统 | `/architecture-decision 修为养成系统` | Core/Progression | LOW |
| 8 | 渡劫突破系统 | `/architecture-decision 渡劫突破系统` | Feature | LOW |
| 9 | 资源系统 | `/architecture-decision 资源系统` | Economy | LOW |
| 10 | 卡组编辑系统 | `/architecture-decision 卡组编辑系统` | Feature | LOW |

### 可推迟到实现阶段

| # | 系统 | 建议 ADR | 领域 |
|---|------|---------|------|
| 11 | 炼丹炼器系统 | `/architecture-decision 炼丹炼器系统` | Economy |
| 12 | 法宝铭刻系统 | `/architecture-decision 法宝铭刻系统` | Economy |
| 13 | 开局身份选择系统 | `/architecture-decision 开局身份选择系统` | Feature |
| 14 | 流派系统 | `/architecture-decision 流派系统` | Meta |
| 15 | 轮回天赋系统 | `/architecture-decision 轮回天赋系统` | Progression |
| 16 | 剧情系统 | `/architecture-decision 剧情系统` | Narrative |
| 17 | 对话系统 | `/architecture-decision 对话系统` | Narrative |
| 18 | 结局分支系统 | `/architecture-decision 结局分支系统` | Narrative |
| 19-24 | UI 系统（战斗UI/探索UI/卡组编辑UI/HUD/主菜单/音频） | 各自 ADR | Presentation |

---

## 跨 ADR 冲突

### 🔴 冲突 1：ADR 编号体系不一致（系统性偏移）

**类型**：跨 ADR 引用断裂
**涉及 ADR**：ADR-0002 至 ADR-0006（文件名 vs 内部 self-identification）

| 文件名 | 文件内部自称 | 偏移量 |
|--------|------------|--------|
| `ADR-0001-*.md` | ADR-0001 | 0 ✅ |
| `ADR-0002-save-load-system-*.md` | **ADR-0003** | +1 ❌ |
| `ADR-0003-event-system-*.md` | **ADR-0004** | +1 ❌ |
| `ADR-0004-input-manager-*.md` | **ADR-0005** | +1 ❌ |
| `ADR-0005-scene-manager-*.md` | **ADR-0006** | +1 ❌ |
| `ADR-0006-card-data-model-*.md` | **ADR-0002** | -4 ❌ |
| `ADR-0007` 至 `ADR-0014` | 各自一致 | 0 ✅ |

**影响**：ADR-0007（信号通信）的「现有 ADR 信号汇总」表引用了 ADR-0001/0003/0004/0006——这些引用在文件内部编号体系下是正确的，但从文件名来看会产生混淆。ADR-0013 明确指出了此问题（"CardSystem ADR 编号为 ADR-0006，文件命名为 ADR-0002——历史命名遗留问题"）。

**解决方案选项**：
1. **重命名文件**使文件名与内部编号一致：`ADR-0002-save-load-*` → `ADR-0003-save-load-*`，`ADR-0003-event-*` → `ADR-0004-event-*`，依次类推，`ADR-0006-card-data-model-*` → `ADR-0002-card-data-model-*`
2. **重写内部编号**使内部编号与文件名一致（在 ADR-0002 ~ ADR-0006 的标题行和交叉引用中修改）
3. **保持现状**——接受这是历史命名遗留问题，在 architecture.md 中记录映射表

### ⚠️ 冲突 2：ADR-0003（SaveLoad）内部依赖 ADR-0002 但该文件是 CardSystem ADR

**类型**：依赖关系
**ADR-0003**（文件 `ADR-0002-*.md`）声称依赖 ADR-0001（GSM）和 ADR-0002（CardSystem——用于 `reconstitute_instances()`）。但在文件编号体系中，"ADR-0002" 正是 SaveLoad 自己（文件 `ADR-0002-*.md`）。实际的 CardSystem ADR 是文件 `ADR-0006-*.md`。

**影响**：如果开发者按照文件名查找依赖，将得到错误的目标文件。

### ⚠️ 冲突 3：ADR-0012 取代 ADR-0001 `progression.*` 域但 ADR-0001 尚未同步更新

**类型**：所有权冲突
**ADR-0012** 声明 `progression.*` 域所有权从 GSM 转移到 ProgressionSystem。ADR-0001 §state_ownership 的原始条目在 `architecture.yaml` 中已标记为 `superseded_by: ADR-0012`——但 ADR-0001 的 markdown 文件本身未包含此更新。

**影响**：读取 ADR-0001 时不会看到 progression 域已被取代——读者可能错误地认为 GSM 仍持有此域。

### ⚠️ 冲突 4：ADR-0003 的 progression_updated 信号源未同步

**类型**：信号源冲突
**ADR-0012** 将 `progression_updated` 信号源从 `GSM` 变更为 `ProgressionSystem`。ADR-0003 的 `_on_progression_changed` 仍引用 `GSM.progression_updated`。

**影响**：SaveLoadSystem 的实现者如果只读 ADR-0003 而不读 ADR-0012，将监听错误的信号源。

### ⚠️ 关切 5：所有 14 个 ADR 均处于 "Proposed" 状态

**类型**：生命周期
没有任何 ADR 进入 "Accepted" 状态。Foundation 层 ADR（ADR-0001 ~ ADR-0007）已经过 godot-specialist 和 technical-director 审查，具备 Accepted 条件。

**建议**：在翻转到 Accepted 之前完成对抗性审查（ADR-0001 ~ ADR-0007 优先——它们是所有上层 ADR 的依赖基础）。

---

## ADR 依赖排序

### 推荐的 ADR 实现顺序（拓扑排序）

**基础层（无依赖）**：
1. ADR-0001：游戏状态管理器
2. ADR-0005：输入管理器
3. ADR-0006：场景管理器

**依赖基础层**：
4. ADR-0003：存档/读档系统（依赖 ADR-0001 + ADR-0002[CardSystem]）
5. ADR-0004：事件系统（依赖 ADR-0001 + ADR-0002[CardSystem]）
6. ADR-0002：卡牌数据模型（依赖 ADR-0001）
7. ADR-0007：信号驱动通信（依赖 ADR-0001/0003/0004/0005/0006）

**核心/功能层**：
8. ADR-0010：境界系统（依赖 ADR-0001/0007）
9. ADR-0011：状态效果系统（依赖 ADR-0001/0007/0008/0009）
10. ADR-0008：战斗系统（依赖 ADR-0001/0002/0003/0004/0005/0006/0007/0009/0010/0011）
11. ADR-0009：卡牌效果引擎（依赖 ADR-0001/0002/0004/0007/0008/0010/0011）

**成长与元进度层**：
12. ADR-0012：跨局元进度系统（依赖 ADR-0001/0003/0007）

**功能扩展层**：
13. ADR-0013：绑定系统（依赖 ADR-0001/0002/0007/0008/0009/0010/0011）
14. ADR-0014：探索系统（依赖 ADR-0001/0004/0006/0007/0008/0010）

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

### architecture.md 需更新的内容

1. **ADR 审计部分**：从"0 覆盖，50 缺口"更新为"14 个 ADR 已创建"
2. **必需的 ADR 表**：所有 14 个已列出的 ADR 现已存在——更新状态为"已创建（Proposed）"
3. **系统层映射**：境界系统应从 Feature 层迁移至 Core 层（ADR-0010 §层分类决议）
4. **架构原则 #1 例外清单**：需记录 ADR-0011（StatusEffectSystem）和 ADR-0013（BindingManager）的 GSM 例外
5. **Foundation 层模块归属**：「存档模式版本控制」独立行应移除（已合并入 SaveLoadSystem——ADR-0003）
6. **Autoload 完整链**：更新为 14 个（`GSM→Input→Scene→SaveLoad→Event→Card→Cost→StatusEffect→Combat→CardEffect→Realm→Progression→Binding→Exploration`）

---

## 裁决：CONCERNS

**通过**：所有 14 个 ADR 覆盖了 Foundation/Core/Feature 层的关键系统。无弃用 API 引用。引擎版本一致性良好。

**关切**：
1. ADR 编号体系不一致（冲突 1 + 2）——系统性偏移导致跨 ADR 引用在文件名和内部编号之间产生歧义
2. 所有 14 个 ADR 仍处于 "Proposed" 状态（关切 5）——Foundation 层 ADR 需要推进到 Accepted
3. ADR-0012 对 ADR-0001/ADR-0003 的取代尚未在源文件中反映（冲突 3 + 4）
4. 22 个系统尚无 ADR——需在进入实现阶段前按优先级逐步创建

**失败**：无阻塞性冲突。

---

## 阻塞性问题（必须在通过前解决）

1. **修复 ADR-0002 ~ ADR-0006 的编号不一致**：选择方案——统一文件名与内部编号，或在 `architecture.md` 中显式建立映射表
2. **将 ADR-0001 ~ ADR-0007 推进到 Accepted**：这些是 Foundation 层 ADR，所有上层 ADR 均依赖它们。在它们被接受之前，任何 Core/Feature 层编码都有架构风险

---

## 所需的 ADR（优先列表）

### 下一批（阻塞实现的关键缺口）
1. **费用系统**（Core 层——CombatSystem 的直接依赖）
2. **上场阵位系统**（Feature 层——战斗系统的备战阶段依赖）

### 可并行创建
3. AI 系统
4. 修为养成系统
5. 渡劫突破系统
6. 资源系统

### 实现阶段按需创建
7-22. 其余 16 个系统

---

## 立即行动

1. **修复 ADR 编号体系不一致**——选择方案并执行
2. **接受 Foundation 层 ADR**：运行对抗性审查（ADR-0001 ~ ADR-0007），处理发现的问题，然后翻转为 Accepted
3. **创建费用系统 ADR**：`/architecture-decision 费用系统`
4. **创建上场阵位系统 ADR**：`/architecture-decision 上场阵位系统`

---

## 关卡前检查清单

- `tests/unit/` 和 `tests/integration/` 目录：❌ 未创建 → 运行 `/test-setup`
- `.github/workflows/tests.yml`：❌ 未创建 → 运行 `/test-setup`
- `design/accessibility-requirements.md`：❌ 未创建 → 运行 `/ux-design`
- `design/ux/interaction-patterns.md`：❌ 未创建 → 运行 `/ux-design`