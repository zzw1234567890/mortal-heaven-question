
# 技能测试规格：/prototype

## 技能概述 (Skill Summary)

`/prototype` 管理快速原型制作流程，用于在投入完整制作实现之前验证游戏机制。原型创建在 `prototypes/[mechanic-name]/` 目录下，故意设计为可抛弃的——编码标准放宽（无需 ADR，验收标准 (AC) 可以极简，允许硬编码值）。实现后，技能生成一份发现文档（findings document），总结所学内容并推荐下一步。

技能在创建文件前询问"我可以写入 `prototypes/[name]/` 吗？"。如果原型已存在，技能主动提供扩展（extend）、替换（replace）或归档（archive）选项。不适用主管关口。判定结果：PROTOTYPE COMPLETE（原型已构建，发现已记录）或 PROTOTYPE ABANDONED（发现机制不可行）。

---

## 静态断言（结构性）

由 `/skill-test static` 自动验证——无需测试夹具。

- [ ] 包含必需的 frontmatter 字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 包含 ≥2 个阶段标题
- [ ] 包含判定关键词：PROTOTYPE COMPLETE、PROTOTYPE ABANDONED
- [ ] 在创建原型文件前包含"May I write"用语
- [ ] 包含下一步交接（例如 `/design-system` 用于正式化，或归档）

---

## 主管关口检查

无。原型是可抛弃的验证工件。不适用主管关口。

---

## 测试用例

### 用例 1：正常路径——机制概念已原型化，发现已记录

**测试夹具：**
- `prototypes/` 目录存在
- 无针对"grapple-hook"的现有原型

**输入：** `/prototype grapple-hook`

**预期行为：**
1. 技能询问"我可以写入 `prototypes/grapple-hook/` 吗？"
2. 批准后：创建 `prototypes/grapple-hook/` 目录和基本实现骨架（主场景、玩家控制器扩展）
3. 技能实现一个极简的抓钩机制（有意粗糙——无需打磨，允许硬编码值）
4. 技能生成 `prototypes/grapple-hook/findings.md`，包含：
   - 测试了什么
   - 哪些有效
   - 哪些无效
   - 建议（推进 / 放弃 / 修改概念）
5. 判定结果为 PROTOTYPE COMPLETE

**断言：**
- [ ] 在创建任何文件前询问"我可以写入 `prototypes/grapple-hook/` 吗？"
- [ ] 实现隔离在 `prototypes/` 中（而非 `src/`）
- [ ] `findings.md` 至少包含：测试内容、有效部分、无效部分、建议
- [ ] 判定结果为 PROTOTYPE COMPLETE

---

### 用例 2：原型已存在——提供扩展、替换或归档选项

**测试夹具：**
- `prototypes/grapple-hook/` 已存在（来自之前的原型会话）
- 其中包含基本实现和 findings.md

**输入：** `/prototype grapple-hook`

**预期行为：**
1. 技能检测到现有的 `prototypes/grapple-hook/` 目录
2. 技能报告："grapple-hook 的原型已存在"
3. 技能提供 3 个选项：
   - 扩展 (Extend)：向现有原型添加新功能
   - 替换 (Replace)：重新开始（询问"我可以替换 `prototypes/grapple-hook/` 吗？"）
   - 归档 (Archive)：移至 `prototypes/archive/grapple-hook/` 并重新开始
4. 用户选择；技能相应执行

**断言：**
- [ ] 检测到并报告了现有原型
- [ ] 正好提供 3 个选项（扩展、替换、归档）
- [ ] 替换路径包含"May I replace"确认
- [ ] 归档路径移动（而非删除）现有原型

---

### 用例 3：原型验证了机制——建议推进至制作

**测试夹具：**
- 原型实现已完成
- 发现：抓钩机制有趣且技术上可行

**输入：** `/prototype grapple-hook`（原型会话完成）

**预期行为：**
1. 原型构建并测试后，总结发现
2. findings.md 中的建议："机制已验证——建议使用 `/design-system` 进行完整规格制定"
3. 技能交接消息明确建议 `/design-system grapple-hook`
4. 判定结果为 PROTOTYPE COMPLETE

**断言：**
- [ ] `findings.md` 包含明确的建议
- [ ] 当机制已验证时，建议引用 `/design-system`
- [ ] 交接消息呼应建议内容
- [ ] 判定结果为 PROTOTYPE COMPLETE（而非 PROTOTYPE ABANDONED）

---

### 用例 4：原型揭示机制不可行——PROTOTYPE ABANDONED

**测试夹具：**
- 已实现"procedural-dialogue"的原型
- 测试后：该机制产生不连贯的对话树，游戏体验令人沮丧

**输入：** `/prototype procedural-dialogue`

**预期行为：**
1. 原型已构建
2. 发现记录失败原因：输出不连贯、玩家困惑、技术复杂性
3. findings.md 中的建议："机制不可行——放弃"
4. `findings.md` 记录机制失败的具体原因
5. 技能在交接中建议替代方案（例如使用策划对话替代）
6. 判定结果为 PROTOTYPE ABANDONED

**断言：**
- [ ] 判定结果为 PROTOTYPE ABANDONED（而非 PROTOTYPE COMPLETE）
- [ ] `findings.md` 记录了具体的失败原因（不模糊）
- [ ] 在交接中建议了替代方法
- [ ] 原型文件被保留（而非删除）供参考

---

### 用例 5：主管关口检查——无关卡；原型是验证工件

**测试夹具：**
- 提供了机制概念

**输入：** `/prototype wall-jump`

**预期行为：**
1. 技能创建并记录原型
2. 不生成任何主管智能体
3. 输出中不出现关口 ID

**断言：**
- [ ] 未调用主管关口
- [ ] 不出现关口跳过消息
- [ ] 判定结果为 PROTOTYPE COMPLETE 或 PROTOTYPE ABANDONED——无关口判定

---

## 协议合规性

- [ ] 在创建任何文件前询问"我可以写入 `prototypes/[name]/` 吗？"
- [ ] 所有文件创建在 `prototypes/` 下（而非 `src/`）
- [ ] 生成 `findings.md`，包含测试内容/有效部分/无效部分/建议
- [ ] 注明生产编码标准有意放宽
- [ ] 当原型已存在时，提供扩展/替换/归档选项
- [ ] 判定结果为 PROTOTYPE COMPLETE 或 PROTOTYPE ABANDONED

---

## 覆盖说明

- 原型实现质量（代码风格）有意不测试——原型是可抛弃的工件，质量标准不适用。
- 用例 2 中提到了归档机制，但未对归档格式进行详细断言测试。
- 引擎特定的原型搭建（GDScript 场景 vs. C# MonoBehaviour）遵循相同流程，使用引擎适用的文件类型。