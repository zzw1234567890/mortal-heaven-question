
# 技能测试规格：/ux-review

## 技能概述

`/ux-review` 根据无障碍和交互标准验证现有的用户体验规格 (UX Spec) 或 HUD 设计文档。它检查必需的章节（用户流程 (User Flows)、交互状态 (Interaction States)、线框描述 (Wireframe Description)、无障碍说明 (Accessibility Notes)）、交互状态定义的完整性（悬停、聚焦、禁用、错误）、无障碍合规性（键盘导航、色彩对比说明、屏幕阅读器考虑事项），以及与艺术圣经 (Art Bible) 或设计系统 (Design System) 的一致性（如果这些文档存在）。

该技能是只读的 —— 不产生任何文件写入。判定结果：APPROVED（所有检查通过）、NEEDS REVISION（发现可修复的问题）或 MAJOR REVISION NEEDED（结构性或无障碍失败）。不涉及总监关卡 —— `/ux-review` 本身就是用户体验规格的审查关卡。

---

## 静态断言（结构）

由 `/skill-test static` 自动验证 —— 无需测试夹具。

- [ ] 包含必需的前置元数据字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 包含 ≥2 个阶段标题
- [ ] 包含判定关键词：APPROVED、NEEDS REVISION、MAJOR REVISION NEEDED
- [ ] 不包含"我可以写入吗"（May I write）措辞（技能为只读）
- [ ] 包含下一步交接说明（例如，返回 `/ux-design` 进行修订，或继续实施）

---

## 总监关卡检查

无。`/ux-review` 本身就是用户体验规格的审查关卡。此技能内不调用其他总监关卡。

---

## 测试用例

### 用例 1：正常路径 —— 完整的用户体验规格包含所有必需章节，APPROVED

**测试夹具：**
- `design/ux/hud.md` 存在，所有必需章节均已填充：
  - 用户流程 (User Flows)：完整的玩家流程图示
  - 交互状态 (Interaction States)：正常、悬停、聚焦、禁用、错误均已定义
  - 线框描述 (Wireframe Description)：布局已描述
  - 无障碍说明 (Accessibility Notes)：键盘导航、对比度、屏幕阅读器说明

**输入：** `/ux-review hud`

**预期行为：**
1. 技能读取 `design/ux/hud.md`
2. 技能检查所有 4 个必需章节 —— 全部存在且非空
3. 技能检查交互状态 —— 所有 5 个状态均已定义
4. 技能检查无障碍说明 —— 涵盖键盘、对比度和屏幕阅读器
5. 技能输出：所有通过的检查清单
6. 判定结果为 APPROVED

**断言：**
- [ ] 检查所有 4 个必需章节
- [ ] 验证所有 5 个交互状态存在
- [ ] 判定结果为 APPROVED
- [ ] 不写入任何文件

---

### 用例 2：缺少无障碍章节 —— NEEDS REVISION

**测试夹具：**
- `design/ux/hud.md` 存在，但无障碍说明 (Accessibility Notes) 章节为空
- 所有其他章节已完全填充

**输入：** `/ux-review hud`

**预期行为：**
1. 技能读取文件并检查所有章节
2. 无障碍说明章节为空 —— 检查失败
3. 技能输出："NEEDS REVISION —— 无障碍说明章节为空"
4. 技能列出需要添加的具体项目：键盘导航、色彩对比度、屏幕阅读器标签
5. 判定结果为 NEEDS REVISION
6. 交接建议返回 `/ux-design hud` 以填充该章节

**断言：**
- [ ] 返回 NEEDS REVISION 判定（而非 APPROVED 或 MAJOR REVISION NEEDED）
- [ ] 列出具体的缺失内容项目
- [ ] 交接指向 `/ux-design hud` 进行修订
- [ ] 不写入任何文件

---

### 用例 3：交互状态不完整 —— NEEDS REVISION

**测试夹具：**
- `design/ux/settings-menu.md` 存在
- 交互状态 (Interaction States) 章节仅定义了：正常、悬停
- 缺少：聚焦、禁用、错误状态

**输入：** `/ux-review settings-menu`

**预期行为：**
1. 技能读取文件并检查交互状态
2. 仅定义了 5 个必需状态中的 2 个
3. 技能报告："NEEDS REVISION —— 交互状态不完整：缺少聚焦、禁用、错误"
4. 判定结果为 NEEDS REVISION，明确列出缺失的状态名称

**断言：**
- [ ] 返回 NEEDS REVISION 判定
- [ ] 输出中明确列出所有 3 个缺失的状态名称
- [ ] 对于可修复的缺失，技能不返回 MAJOR REVISION NEEDED
- [ ] 交接建议返回 `/ux-design settings-menu`

---

### 用例 4：文件未找到 —— 附带修复建议的错误

**测试夹具：**
- `design/ux/inventory-screen.md` 不存在

**输入：** `/ux-review inventory-screen`

**预期行为：**
1. 技能尝试读取 `design/ux/inventory-screen.md` —— 文件未找到
2. 技能输出："未找到用户体验规格：design/ux/inventory-screen.md"
3. 技能建议先运行 `/ux-design inventory-screen` 以创建规格
4. 不执行审查；不下达判定

**断言：**
- [ ] 错误信息包含缺失文件的完整路径
- [ ] 建议 `/ux-design inventory-screen` 作为修复方案
- [ ] 不产生审查清单
- [ ] 不下达判定（错误状态，而非 APPROVED/NEEDS REVISION）

---

### 用例 5：总监关卡检查 —— 无关卡；ux-review 本身就是审查

**测试夹具：**
- 有效的用户体验规格文件

**输入：** `/ux-review hud`

**预期行为：**
1. 技能执行审查并下达判定
2. 不启动其他总监代理
3. 输出中不出现关卡 ID

**断言：**
- [ ] 不调用总监关卡
- [ ] 不出现关卡跳过消息
- [ ] 判定结果为 APPROVED、NEEDS REVISION 或 MAJOR REVISION NEEDED —— 非关卡判定

---

## 协议合规性

- [ ] 检查所有 4 个必需章节（用户流程 (User Flows)、交互状态 (Interaction States)、线框描述 (Wireframe Description)、无障碍说明 (Accessibility Notes)）
- [ ] 检查所有 5 个交互状态（正常、悬停、聚焦、禁用、错误）
- [ ] 检查无障碍覆盖范围（键盘导航、对比度、屏幕阅读器）
- [ ] 不写入任何文件
- [ ] 当判定并非 APPROVED 时，提供具体、可操作的反馈
- [ ] 以下一步交接结束，指向 `/ux-design` 进行修订或指向实施

---

## 覆盖说明

- MAJOR REVISION NEEDED 在结构性章节完全缺失（而非仅空置）或基本交互流程完全缺失时触发；此处未使用单独的测试夹具进行测试。
- 艺术圣经 / 设计系统一致性检查（调色板对齐）被提及为一项能力，但未单独通过测试夹具测试。
- 现有规格是为现已重命名的屏幕编写的情况未测试；技能将根据路径审查文件，无论名称如何。
