---
name: ux-review
description: "验证UX规范、HUD设计或交互模式库的完整性、可访问性合规性、GDD对齐性及实现就绪度。生成带有具体差距的APPROVED / NEEDS REVISION / MAJOR REVISION NEEDED评定结论。"
argument-hint: "[file-path or 'all' or 'hud' or 'patterns']"
user-invocable: true
allowed-tools: Read, Glob, Grep

agent: ux-designer
---


## 概述

在UX设计文档进入实现管线（implementation pipeline）之前对其进行验证。
在`/team-ui`管线中充当UX设计与视觉设计/实现之间的质量门（quality gate）。

**运行此技能：**
- 在使用`/ux-design`完成UX规范（UX spec）后
- 在移交给`ui-programmer`或`art-director`之前
- 在预制作到制作的关卡检查（gate check）之前（该检查要求关键屏幕有经过审核的UX规范）
- 在对UX规范进行重大修订后

**评定等级（Verdict levels）：**
- **APPROVED** — 规范完整、一致且已具备实现条件
- **NEEDS REVISION** — 发现具体差距；在移交前修复，但无需全面重新设计
- **MAJOR REVISION NEEDED** — 范围、玩家需求（player need）或完整性存在根本性问题；需要重大返工

---

## 阶段1：解析参数

- **特定文件路径**（例如 `/ux-review design/ux/inventory.md`）：验证该单个文档
- **`all`**：查找 `design/ux/` 中的所有文件并逐一验证
- **`hud`**：专门验证 `design/ux/hud.md`
- **`patterns`**：专门验证 `design/ux/interaction-patterns.md`
- **无参数**：询问用户要验证哪个规范

对于 `all`，先输出汇总表格（文件 | 结论 | 主要问题），然后逐项显示完整详情。

---

## 阶段2：加载交叉引用上下文

在验证任何规范之前，加载以下内容：

1. **输入与平台配置**：读取 `.claude/docs/technical-preferences.md` 并提取 `## Input & Platform`。这是游戏支持哪些输入方式（input methods）的权威来源——用于驱动阶段3A中的输入方式覆盖检查，而非规范自身的头部信息。如果未配置，则回退到规范头部。
2. `design/accessibility-requirements.md` 中承诺的可访问性等级（accessibility tier）（如果存在）
3. `design/ux/interaction-patterns.md` 中的交互模式库（interaction pattern library）（如果存在）
4. 规范头部中引用的GDD（阅读其UI需求章节）
5. `design/player-journey.md` 中的玩家旅程图（player journey map）（如果存在），用于上下文到达验证（context-arrival validation）

---

## 阶段3A：UX规范验证检查清单

针对基于 `ux-spec.md` 的文档运行所有检查。

### 完整性（必需章节）

- [ ] 文档头部存在，包含状态、作者、目标平台（Status, Author, Platform Target）
- [ ] 目的与玩家需求（Purpose & Player Need）——包含玩家视角的需求陈述（而非开发者视角）
- [ ] 到达时的玩家上下文（Player Context on Arrival）——描述玩家状态和先前活动
- [ ] 导航位置（Navigation Position）——显示屏幕在层级中的位置
- [ ] 进入与退出点（Entry & Exit Points）——记录所有进入来源和退出目标
- [ ] 布局规范（Layout Specification）——定义区域，包含组件清单表
- [ ] 状态与变体（States & Variants）——至少记录：加载态、空/填充态和错误态
- [ ] 交互映射（Interaction Map）——覆盖所有目标输入方式（检查头部中的目标平台）
- [ ] 数据需求（Data Requirements）——每个显示的数据元素都有来源系统和拥有者
- [ ] 触发事件（Events Fired）——每个玩家操作都有对应事件或空值说明
- [ ] 过渡与动画（Transitions & Animations）——至少指定进入/退出过渡
- [ ] 可访问性需求（Accessibility Requirements）——存在屏幕级需求
- [ ] 本地化考量（Localization Considerations）——文本元素的最大字符数
- [ ] 验收标准（Acceptance Criteria）——至少5个具体的可测试标准

### 质量检查

**玩家需求清晰度**
- [ ] 目的从玩家视角而非系统/开发者视角撰写
- [ ] 到达时的玩家目标明确无歧义（"玩家到达时想要___"）
- [ ] 到达时的玩家上下文是具体的（不仅仅是"他们打开了背包"）

**状态完整性**
- [ ] 记录错误态（不仅是快乐路径）
- [ ] 记录空态（无数据场景）
- [ ] 如果屏幕获取异步数据，记录加载态
- [ ] 任何带有计时器或自动关闭的状态都记录时长

**输入方式覆盖**
- [ ] 如果平台包含PC：完全指定纯键盘导航
- [ ] 如果平台包含主机/手柄：记录方向键导航和正面按键映射
- [ ] 手柄操作无需鼠标级精确度
- [ ] 定义焦点顺序（键盘的Tab键顺序，手柄的方向键顺序）

**数据架构**
- [ ] 没有数据元素将"UI"列为拥有者（UI不得拥有游戏状态）
- [ ] 所有实时数据指定更新频率（不仅仅是"实时"——什么触发更新？）
- [ ] 所有数据元素指定空值处理（数据不可用时显示什么？）

**可访问性**
- [ ] 达到或超过 `accessibility-requirements.md` 中的可访问性等级
- [ ] 如果为基础等级（Basic）：没有仅靠颜色传递信息的指示器
- [ ] 如果为标准等级以上（Standard+）：记录焦点顺序，指定文本对比度
- [ ] 如果为全面等级以上（Comprehensive+）：关键状态变化有屏幕朗读器播报
- [ ] 色盲检查：任何颜色编码元素都有非颜色替代方案

**GDD对齐性**
- [ ] 头部引用的每个GDD UI需求都在此规范中得到处理
- [ ] 没有UI元素显示或修改游戏状态而无对应GDD需求
- [ ] 没有GDD UI需求在此规范中缺失（交叉检查引用的GDD章节）

**模式库一致性**
- [ ] 所有交互式组件引用模式库（或标注为新模式）
- [ ] 如果模式库中已存在行为，不从头重新指定
- [ ] 此规范中创建的任何新模式都标记为需添加到模式库

**本地化**
- [ ] 所有文本密集元素存在字符数限制警告
- [ ] 任何布局关键文本已标记需预留40%扩展空间

**验收标准质量**
- [ ] 标准足够具体，未看过设计文档的QA测试员也能评估
- [ ] 存在性能标准（屏幕在Xms内打开）
- [ ] 存在分辨率标准
- [ ] 不需要阅读另一份文档即可评估标准

---

## 阶段3B：HUD验证检查清单

针对基于 `hud-design.md` 的文档运行所有检查。

### 完整性

- [ ] 定义HUD理念（HUD Philosophy）
- [ ] 信息架构（Information Architecture）表覆盖GDD中所有带有UI需求的系统
- [ ] 定义布局区域（Layout Zones），包含所有目标平台的安全区域边距（safe zone margins）
- [ ] 每个HUD元素都有完整规格（区域、可见性触发条件、数据来源、优先级）
- [ ] 按玩法上下文的HUD状态至少覆盖：探索、战斗、对话/过场、暂停
- [ ] 定义视觉预算（Visual Budget）（最大同时元素数，最大屏幕占比）
- [ ] 平台适配（Platform Adaptation）覆盖所有目标平台
- [ ] 存在玩家可调元素的调节旋钮（Tuning Knobs）

### 质量检查

- [ ] 没有HUD元素覆盖中央游玩区域而无相应的隐藏可见性规则
- [ ] 任何GDD中存在的每个信息项要么在HUD中，要么明确归类为"隐藏/按需显示"
- [ ] 所有颜色编码的HUD元素都有色盲友好变体
- [ ] 反馈与通知部分的HUD元素定义了队列/优先级行为
- [ ] 视觉预算合规：同时显示的元素总数在预算内

### GDD对齐性

- [ ] `design/gdd/systems-index.md` 中所有带有UI类别的系统都在HUD中有体现（或有合理的缺席说明）

---

## 阶段3C：模式库验证检查清单

- [ ] 模式目录索引是最新的（与文档中的实际模式匹配）
- [ ] 指定所有标准控制模式：按钮变体、开关、滑块、下拉框、列表、网格、模态框、对话框、toast提示、工具提示、进度条、输入框、标签栏、滚动
- [ ] 当前UX规范所需的所有游戏专用模式都存在
- [ ] 每个模式包含：何时使用、何时不使用、完整状态规格、可访问性规格、实现说明
- [ ] 存在动画标准表
- [ ] 存在音效标准表
- [ ] 模式之间没有冲突行为（例如，"返回"行为在所有导航模式中保持一致）

---

## 阶段4：输出结论

```markdown
## UX审查：[文档名称]
**日期**：[date]
**审查者**：ux-review skill
**文档**：[文件路径]
**目标平台**：[来自头部]
**可访问性等级**：[来自头部或 accessibility-requirements.md]

### 完整性：[X/Y 章节存在]
- [x] 目的与玩家需求
- [ ] 状态与变体 — 缺失：未记录错误态

### 质量问题：[发现 N 个]
1. **[问题标题]** [BLOCKING / ADVISORY]
   - 问题描述：[具体说明]
   - 位置：[章节名称]
   - 修复方案：[具体操作]

### GDD对齐性：[ALIGNED / GAPS FOUND]
- GDD [名称] UI需求 — [X/Y 需求已覆盖]
- 缺失：[列出任何未覆盖的GDD需求]

### 可访问性：[COMPLIANT / GAPS / NON-COMPLIANT]
- 目标等级：[等级]
- [列出具体的可访问性发现]

### 模式库：[CONSISTENT / INCONSISTENCIES FOUND]
- [发现]

### 结论：APPROVED / NEEDS REVISION / MAJOR REVISION NEEDED
**阻塞性问题**：[N] 个 — 必须在实现前解决
**建议性问题**：[N] 个 — 推荐但不阻塞

[对于 APPROVED]：此规范已准备好移交给 `/team-ui` 阶段2（视觉设计）。

[对于 NEEDS REVISION]：解决以上 [N] 个阻塞性问题，然后重新运行 `/ux-review`。

[对于 MAJOR REVISION NEEDED]：规范在 [领域] 存在根本性差距。建议返回 `/ux-design` 返工 [章节]。
```

---

## 阶段5：协作协议

此技能为只读——从不编辑或写入文件。仅报告发现。

在交付结论后：
- 对于 **APPROVED**：建议运行 `/team-ui` 以开始实现协调
- 对于 **NEEDS REVISION**：主动提供帮助修复具体差距（"需要我帮忙起草缺失的错误状态吗？"）——但不自动修复；等待用户指示
- 对于 **MAJOR REVISION NEEDED**：建议返回 `/ux-design`，明确指出需要返工的具体章节

绝不阻止用户继续——结论仅为建议性。记录风险、呈现发现，让用户决定是否仍有顾虑地继续。选择在有 NEEDS REVISION 规范的情况下继续的用户需承担已记录的风险。
