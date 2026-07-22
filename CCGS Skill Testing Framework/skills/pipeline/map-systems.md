
# 技能测试规范：/map-systems

## 技能概述

`/map-systems` 将游戏概念分解为系统索引。它读取已批准的游戏概念和设计支柱，列举显式和隐式系统，映射系统间的依赖关系，分配优先级层级（MVP / Vertical Slice / Alpha / Full Vision），并将系统组织成分层设计顺序（Foundation → Core → Feature → Presentation）。输出在用户批准后写入 `design/systems-index.md`。

该技能是游戏概念批准与每个系统 GDD 创建之间的必需步骤 — 它是管线中的强制性关卡。在 `full` 评审模式下，CD-SYSTEMS（创意总监，creative-director）和 TD-SYSTEM-BOUNDARY（技术总监，technical-director）在分解起草后并行派生。在 `lean` 或 `solo` 模式下，两个关卡均被跳过。该技能写入 `design/systems-index.md`。

---

## 静态断言（结构检查）

由 `/skill-test static` 自动验证 — 无需测试夹具。

- [ ] 具有必需的 frontmatter 字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 具有 ≥2 个阶段标题
- [ ] 包含判定关键词：COMPLETE、BLOCKED
- [ ] 包含 "May I write" 协作协议措辞（用于 systems-index.md）
- [ ] 末尾具有下一步交接（`/design-system`）
- [ ] 文档说明关卡行为：full 模式下 CD-SYSTEMS + TD-SYSTEM-BOUNDARY 并行

---

## 总监关卡检查

在 `full` 模式下：CD-SYSTEMS（创意总监，creative-director）和 TD-SYSTEM-BOUNDARY（技术总监，technical-director）在系统分解起草之后、`design/systems-index.md` 写入之前并行派生。

在 `lean` 模式下：两个关卡均被跳过。输出注明："CD-SYSTEMS skipped — lean mode" 和 "TD-SYSTEM-BOUNDARY skipped — lean mode"。

在 `solo` 模式下：两个关卡均被跳过，带有等效的说明。

---

## 测试用例

### 用例 1：正常路径 — 游戏概念存在，识别出 5-8 个系统

**测试夹具：**
- `design/gdd/game-concept.md` 存在，包含核心机制和 MVP 定义章节
- `design/gdd/game-pillars.md` 存在，定义了 ≥1 个支柱
- `design/systems-index.md` 尚不存在
- `production/session-state/review-mode.txt` 包含 `full`

**输入：** `/map-systems`

**预期行为：**
1. 技能读取 game-concept.md 和 game-pillars.md
2. 识别 5-8 个系统（显式 + 隐式）
3. 映射系统间的依赖关系并分配层级
4. CD-SYSTEMS 和 TD-SYSTEM-BOUNDARY 并行派生并返回 APPROVED
5. 询问"我可以写入 `design/systems-index.md` 吗？"
6. 获得批准后写入 systems-index.md
7. 更新 `production/session-state/active.md`

**断言：**
- [ ] 识别出 5 到 8 个系统（未合理解释的情况下不少于此数也不多于）
- [ ] CD-SYSTEMS 和 TD-SYSTEM-BOUNDARY 并行派生（非顺序）
- [ ] 在"May I write"询问之前，两个关卡均已完成
- [ ] 写入前询问"我可以写入 `design/systems-index.md` 吗？"
- [ ] systems-index.md 未经批准不会写入
- [ ] 写入后更新会话状态
- [ ] 判定为 COMPLETE

---

### 用例 2：失败路径 — 未找到游戏概念

**测试夹具：**
- `design/gdd/game-concept.md` 不存在
- `design/gdd/` 目录可能为空或不存在

**输入：** `/map-systems`

**预期行为：**
1. 技能尝试读取 `design/gdd/game-concept.md`
2. 文件未找到
3. 技能输出："未找到游戏概念。运行 `/brainstorm` 创建一个，然后返回 `/map-systems`。"
4. 技能退出，不创建 systems-index.md

**断言：**
- [ ] 技能输出清晰的错误信息，指明缺失的文件路径
- [ ] 技能推荐 `/brainstorm` 作为下一步操作
- [ ] 未创建 systems-index.md
- [ ] 判定为 BLOCKED

---

### 用例 3：总监关卡 — CD-SYSTEMS 返回 CONCERNS（缺少核心系统）

**测试夹具：**
- 游戏概念存在
- `production/session-state/review-mode.txt` 包含 `full`
- CD-SYSTEMS 关卡返回 CONCERNS："概念隐含了 [核心系统] 但未识别出来"

**输入：** `/map-systems`

**预期行为：**
1. 系统被起草（初始识别 5-8 个系统）
2. CD-SYSTEMS 关卡返回 CONCERNS，指明缺失的核心系统
3. TD-SYSTEM-BOUNDARY 返回 APPROVED
4. 技能向用户展示 CD-SYSTEMS 的关注点
5. 用户被询问：修订系统列表以添加缺失的系统，或按现状继续
6. 如果修订：在"May I write"询问前展示更新后的系统列表

**断言：**
- [ ] CD-SYSTEMS 的关注点在写入前向用户展示
- [ ] 当 CONCERNS 未解决时，技能不会自动写入 systems-index.md
- [ ] 用户被给予修订或继续的选项
- [ ] 修订后的系统列表在最终"May I write"前重新展示

---

### 用例 4：边界情况 — systems-index.md 已存在

**测试夹具：**
- `design/gdd/game-concept.md` 存在
- `design/systems-index.md` 已存在，包含 N 个系统

**输入：** `/map-systems`

**预期行为：**
1. 技能读取现有的 systems-index.md 并展示其当前状态
2. 技能询问："systems-index.md 已存在，包含 [N] 个系统。是否更新新系统，或者查看并修订优先级？"
3. 用户选择一个操作
4. 技能不会静默覆盖现有索引

**断言：**
- [ ] 技能在继续前检测并读取现有的 systems-index.md
- [ ] 向用户提供更新/查看选项 — 不会被自动覆盖
- [ ] 现有系统数量向用户展示
- [ ] 除非用户选择，技能不会进行完整的重新分解

---

### 用例 5：总监关卡 — Lean 模式和 solo 模式均跳过关卡，注明跳过

**测试夹具（lean 模式）：**
- 游戏概念存在
- `production/session-state/review-mode.txt` 包含 `lean`

**Lean 模式预期行为：**
1. 系统被分解和起草
2. CD-SYSTEMS 和 TD-SYSTEM-BOUNDARY 均被跳过
3. 输出注明："CD-SYSTEMS skipped — lean mode" 和 "TD-SYSTEM-BOUNDARY skipped — lean mode"
4. "May I write" 询问直接进行

**断言（lean 模式）：**
- [ ] 两个关卡的跳过说明均出现在输出中
- [ ] 技能无需关卡批准即可进入"May I write"环节
- [ ] 用户批准后写入 systems-index.md

**测试夹具（solo 模式）：**
- 相同的游戏概念，`production/session-state/review-mode.txt` 包含 `solo`

**Solo 模式预期行为：**
1. 相同的分解工作流
2. 两个关卡均被跳过 — 在输出中注明"solo mode"
3. "May I write" 询问进行

**断言（solo 模式）：**
- [ ] 两个跳过说明均出现，带有"solo mode"标签
- [ ] 对于该技能，行为与 lean 模式相同

---

## 协议合规性

- [ ] 在任何分解之前读取 game-concept.md 和 game-pillars.md
- [ ] 写入前询问"我可以写入 `design/systems-index.md` 吗？"
- [ ] systems-index.md 未经用户批准不会写入
- [ ] full 模式下 CD-SYSTEMS 和 TD-SYSTEM-BOUNDARY 并行派生
- [ ] 跳过的关卡在 lean/solo 输出中按名称和模式注明
- [ ] 以下一步交接结尾：`/design-system [next-system]`

---

## 覆盖说明

- 循环依赖检测（系统 A 依赖系统 B，系统 B 又依赖系统 A）是依赖映射阶段的一部分 — 未在此独立进行夹具测试。
- 优先级层级分配（MVP 启发式规则）作为用例 1 协作工作流的一部分进行评估，而非独立评估。
- `next` 参数模式（将最高优先级的未设计系统交接给 `/design-system`）在此未测试 — 它是一个索引创建后的便捷功能。
