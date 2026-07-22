---
name: setup-engine
description: "配置项目的游戏引擎和版本。在 CLAUDE.md 中锁定引擎，检测知识缺口，并在版本超出 LLM 训练数据时通过 WebSearch 填充引擎参考文档。"
argument-hint: "[engine] | [engine version] | refresh | upgrade [old-version] [new-version] | no args for guided selection"
user-invocable: true
allowed-tools: Read, Glob, Grep, Write, Edit, WebSearch, WebFetch, Task, AskUserQuestion

---


当此技能被调用时：

## 1. 解析参数

四种模式：

- **完整指定**：`/setup-engine godot 4.6` — 引擎和版本均已提供
- **仅引擎**：`/setup-engine unity` — 提供了引擎，版本将查询
- **无参数**：`/setup-engine` — 完全引导模式（引擎推荐 + 版本）
- **刷新**：`/setup-engine refresh` — 更新参考文档（见第 10 节）
- **升级**：`/setup-engine upgrade [old-version] [new-version]` — 迁移到新的引擎版本（见第 11 节）

---

## 2. 引导模式（无参数）

如果未指定引擎，运行交互式引擎选择过程：

### 检查现有游戏概念
- 读取 `design/gdd/game-concept.md`（如果存在）— 提取类型、范围、平台目标、美术风格、团队规模以及来自 `/brainstorm` 的任何引擎推荐
- 如果不存在概念，告知用户：
  > "未找到游戏概念。考虑先运行 `/brainstorm` 来发现你想要构建什么——它也会推荐引擎。或者告诉我你的游戏情况，我可以帮你选择。"

### 如果用户希望在没有概念的情况下选择，按此顺序询问：

**问题 1 — 先前经验**（始终先问这个，使用 `AskUserQuestion`）：
- 提示："你以前使用过这些引擎中的任何一个吗？"
- 选项：`Godot` / `Unity` / `Unreal Engine 5` / `多个——我会解释` / `都没有`
- 如果他们选择了特定引擎 → 推荐该引擎。先前经验超过所有其他因素。与他们确认并跳过矩阵。
- 如果"都没有"或"多个" → 继续回答以下问题。

**问题 2-6 — 决策矩阵输入**（仅在无先前引擎经验时）：

**问题 2 — 目标平台**（始终第二个问，使用 `AskUserQuestion` — 平台在任何其他因素之前消除或加权引擎）：
- 提示："你的游戏针对哪些平台？"
- 选项：`PC（Steam / Epic）` / `移动端（iOS / Android）` / `主机` / `网页/浏览器` / `多个平台`
- 直接影响推荐的平台规则：
  - 移动端 → Unity 强烈优先；Unreal 不合适；Godot 适合简单手游
  - 主机 → Unity 或 Unreal；Godot 主机支持需要第三方发行商或大量额外工作
  - 网页 → Godot 干净地导出到网页；Unity WebGL 功能可用；Unreal 网页支持较差
  - 仅 PC → 所有引擎均可；其他因素决定
  - 多个 → Unity 在 PC/移动/主机之间最可移植

1. **什么类型的游戏？**（2D、3D 还是两者都有？）
2. **主要输入方式？**（键盘/鼠标、手柄、触控还是混合？）
3. **团队规模和经验？**（单人新手、单人经验丰富、小团队？）
4. **有偏好的语言吗？**（GDScript、C#、C++、可视化脚本？）
5. **引擎授权的预算？**（仅免费，还是商业授权也可以？）

### 生成推荐

不要使用消除引擎的简单评分矩阵。相反，根据用户的画像对照诚实的权衡进行推理，然后呈现 1-2 个带有完整上下文的推荐。始终以用户选择结束——永远不要强制裁决。

**引擎诚实权衡：**

**Godot 4**
- 真正优势：2D（同类最佳）、风格化/独立 3D、快速迭代、永久免费（MIT）、开源、最平缓的学习曲线、最适合想要完全控制的独立开发者
- 实际限制：3D 生态系统与 Unity/Unreal 相比薄弱（更少的教程、资源、3D 特定问题的社区答案）；大型开放世界 3D 非常困难且在 Godot 中基本未经验证；主机导出需要第三方发行商或大量额外工作；较小的专业就业市场
- 授权现实：真正免费，无任何收入门槛。MIT 许可意味着你拥有所有内容。
- 最佳适用：任何范围的 2D 游戏；风格化/氛围 3D；封闭式 3D 世界（非开放世界）；学习曲线重要的第一个游戏项目；任何规模下预算都是硬约束的项目

**Unity**
- 真正优势：中等范围 3D 和移动端的行业标准；庞大的资源商店和教程生态系统；C# 是一种专业语言；对独立开发者最好的主机认证支持；几乎每种类型都有强大的社区
- 实际限制：2023 年的授权争议损害了信任（运行时费用被提出后又撤回——政策变更的风险仍然真实存在）；C# 比 GDScript 有更陡峭的初始曲线；对于简单项目来说，编辑器比 Godot 更重
- 授权现实：收入低于 20 万美元且安装量低于 20 万时免费（Unity Personal/Plus）。只有在游戏真正成功时才会变得昂贵——大多数独立游戏从未达到这个门槛。2023 年争议值得了解，但实际的当前条款对大多数独立开发者来说是合理的。
- 最佳适用：移动游戏；中等范围 3D；针对主机的游戏；有 C# 背景的开发者；需要大型资源商店的项目；2-5 人的团队

**Unreal Engine 5**
- 真正优势：同类最佳的 3D 视觉效果（Lumen、Nanite、Chaos 物理）；AAA 和写实 3D 的行业标准；大型开放世界支持成熟且经过生产测试；Blueprint 可视化脚本降低了 C++ 门槛；针对高端 PC 或主机的游戏表现出色
- 实际限制：最陡峭的学习曲线；最重的编辑器（编译时间长、项目体积大）；对于风格化/2D/小范围游戏过度杀伤；C++ 确实很难；不适合移动端或网页端；总收入超过 100 万美元后收取 5% 版税
- 授权现实：5% 版税仅适用于每款游戏总收入超过 100 万美元后。对于第一款游戏或任何达不到 100 万美元的游戏，无需付费。这个门槛高到大多数独立开发者永远不会支付。
- 最佳适用：AAA 质量 3D；大型开放世界游戏；写实视觉效果；有 C++ 经验或愿意使用 Blueprint 的开发者；针对高端 PC/主机的游戏，视觉效果是核心卖点

**类型特定指导**（将其纳入推荐）：
- 任何风格 2D → Godot 强烈优先
- 风格化/氛围/封闭世界 3D → Godot 可行，Unreal 作为可靠备选
- 3D 开放世界（大型、无缝） → Unity 或 Unreal；Godot 对此未经过生产验证
- 写实 3D / AAA 质量 → Unreal
- 移动端优先 → Unity 强烈优先
- 主机优先 → Unity 或 Unreal；Godot 主机支持需要额外工作
- 恐怖/叙事/步行模拟 → 任何引擎；匹配美术风格和团队经验
- 动作 RPG / 魂系 → 3D 使用 Unity 或 Unreal；社区支持和资源很重要
- 2D 平台游戏 → Godot
- 策略/俯视角/RTS → Godot 或 Unity，取决于 2D 或 3D

**推荐格式：**
1. 显示以用户特定因素为行的比较表
2. 给出主要推荐并附上诚实的理由
3. 命名最佳替代方案以及何时选择它
4. 明确说明："这是一个起点，不是最终裁决——你随时可以迁移引擎，许多开发者会在项目之间切换。"
5. 使用 `AskUserQuestion` 确认："这个推荐感觉对吗，或者你想探索不同的引擎？"
   - 选项：`[首选引擎]（推荐）` / `[备选引擎]` / `[第三个引擎]` / `进一步探索` / `输入其他内容`

**如果用户选择"进一步探索"：**
使用 `AskUserQuestion`，提供概念特定的深入话题。始终从用户的实际概念生成这些选项——不要使用通用选项。始终至少包括：
- 首选引擎对此概念的具体限制（例如，"Godot 3D 对于[类型]实际上能走多远？"）
- 备选引擎对此概念的具体权衡
- 语言选择对此概念技术挑战的影响
- 任何概念特定的技术问题（例如，自适应音频、开放世界流式加载、多人在线 netcode）

用户可以选择多个话题。深入回答每个选定的话题，然后返回到引擎确认问题。

---

## 3. 查找当前版本

一旦选择了引擎：

- 如果提供了版本，使用它
- 如果未提供版本，使用 WebSearch 查找最新稳定版本：
  - 搜索：`"[engine] latest stable version [current year]"`
  - 与用户确认："最新的稳定版 [engine] 是 [version]。使用这个版本？"

---

## 4. 更新 CLAUDE.md 技术栈

### 语言选择（仅 Godot）

如果选择了 Godot，在展示提议的技术栈之前，先询问用户使用哪种语言：

> "Godot 支持两种主要语言：
>
>   **A) GDScript** — 类 Python，Godot 原生，最快迭代。最适合新手、独立开发者和来自 Python 或 Lua 的团队。
>   **B) C#** — .NET 8+，Unity 开发者熟悉，更强的 IDE 工具支持（Rider / Visual Studio），在繁重逻辑上有轻微性能优势。
>   **C) 两者** — GDScript 用于游戏玩法/UI 脚本，C# 用于性能关键系统。高级设置——需要除了 Godot 之外的 .NET SDK。
>
> 本项目主要使用哪一种？"

记录选择。它决定 CLAUDE.md 模板、命名约定、专家路由以及在整个项目中为代码文件生成的代理。

---

读取 `CLAUDE.md` 并向用户展示提议的技术栈变更。
询问："我可以将这些引擎设置写入 `CLAUDE.md` 吗？"

等待确认后再做任何编辑。

更新技术栈部分，将 `[CHOOSE]` 占位符替换为实际值：

**对于 Godot** — 使用上面选择的语言对应的模板。参见本技能底部的**附录 A**，了解所有三种变体（GDScript、C#、两者）。

**对于 Unity：**
```markdown
- **Engine**: Unity [version]
- **Language**: C#
- **Build System**: Unity Build Pipeline
- **Asset Pipeline**: Unity Asset Import Pipeline + Addressables
```

**对于 Unreal：**
```markdown
- **Engine**: Unreal Engine [version]
- **Language**: C++（主要），Blueprint（游戏玩法原型）
- **Build System**: Unreal Build Tool (UBT)
- **Asset Pipeline**: Unreal Content Pipeline
```

---

## 5. 填充技术偏好

在更新 CLAUDE.md 后，创建或更新 `.claude/docs/technical-preferences.md`，使用引擎适当的默认值。先读取现有模板，然后填写：

### 引擎和语言部分
- 从第 4 步的引擎选择中填写

### 命名约定（引擎默认值）

**对于 Godot** — 参见**附录 A** 了解 GDScript、C# 和两者变体。

**对于 Unity（C#）：**
- 类：PascalCase（例如 `PlayerController`）
- 公共字段/属性：PascalCase（例如 `MoveSpeed`）
- 私有字段：_camelCase（例如 `_moveSpeed`）
- 方法：PascalCase（例如 `TakeDamage()`）
- 文件：与类匹配的 PascalCase（例如 `PlayerController.cs`）
- 常量：PascalCase 或 UPPER_SNAKE_CASE

**对于 Unreal（C++）：**
- 类：带前缀的 PascalCase（`A` 代表 Actor，`U` 代表 UObject，`F` 代表结构体）
- 变量：PascalCase（例如 `MoveSpeed`）
- 函数：PascalCase（例如 `TakeDamage()`）
- 布尔值：`b` 前缀（例如 `bIsAlive`）
- 文件：与类匹配但不带前缀（例如 `PlayerController.h`）

### 输入和平台部分

使用第 2 节中收集的答案（或从游戏概念中提取）填充 `## Input & Platform`。使用此映射推导值：

| 目标平台 | 手柄支持 | 触控支持 |
|-----------------|-----------------|---------------|
| 仅 PC | 部分（推荐） | 无 |
| 主机 | 完整 | 无 |
| 移动端 | 无 | 完整 |
| PC + 主机 | 完整 | 无 |
| PC + 移动端 | 部分 | 完整 |
| 网页端 | 部分 | 部分 |

对于**主要输入**，使用游戏类型的主导输入：
- 针对主机的动作/RPG/平台游戏 → 手柄
- 策略/点击冒险/RTS → 键盘/鼠标
- 移动游戏 → 触控
- 跨平台 → 询问用户

呈现推导的值，并要求用户在写入前确认或调整。

示例填充部分：
```markdown
## Input & Platform
- **Target Platforms**: PC, Console
- **Input Methods**: Keyboard/Mouse, Gamepad
- **Primary Input**: Gamepad
- **Gamepad Support**: Full
- **Touch Support**: None
- **Platform Notes**: All UI must support d-pad navigation. No hover-only interactions.
```

### 其余部分
- **性能预算**：使用 `AskUserQuestion`：
  - 提示："我现在设置默认性能预算，还是稍后再设置？"
  - 选项：`[A] 现在设置默认值（60fps，16.6ms 帧预算，引擎适当的绘制调用限制）` / `[B] 保持为[待配置]—我了解目标硬件后再设置`
  - 如果 [A]：使用建议的默认值填充。如果 [B]：保留为占位符。
- **测试**：建议引擎适当的框架（Godot 用 GUT，Unity 用 NUnit 等）— 添加前询问。
- **禁止的模式**：保留为占位符 — 不要预填充。
- **允许的库**：保留为占位符 — 不要预填充项目当前不需要的依赖。只有在积极集成时才在此处添加库，而不是推测性地添加。

> **护栏**：永远不要将推测性依赖添加到允许的库。例如，不要添加 GodotSteam，除非 Steam 集成正在此会话中积极开始。发布后集成应在该工作开始时添加到允许的库，而不是在引擎设置期间。

### 引擎专家路由

同时在 `technical-preferences.md` 中填充 `## Engine Specialists` 部分，为所选引擎配置正确的路由：

**对于 Godot** — 参见**附录 A** 了解与所选语言匹配的路由表。

**对于 Unity：**
```markdown
## Engine Specialists
- **Primary**: unity-specialist
- **Language/Code Specialist**: unity-specialist（C# 审查——主要已涵盖）
- **Shader Specialist**: unity-shader-specialist（Shader Graph、HLSL、URP/HDRP 材质）
- **UI Specialist**: unity-ui-specialist（UI Toolkit UXML/USS、UGUI Canvas、运行时 UI）
- **Additional Specialists**: unity-dots-specialist（ECS、Jobs 系统、Burst 编译器）、unity-addressables-specialist（资产加载、内存管理、内容目录）
- **Routing Notes**: 为架构和通用 C# 代码审查调用主要。为任何 ECS/Jobs/Burst 代码调用 DOTS 专家。为渲染和视觉效果调用着色器专家。为所有界面实现调用 UI 专家。为资产管理系统调用 Addressables 专家。

### File Extension Routing

| File Extension / Type | Specialist to Spawn |
|-----------------------|---------------------|
| Game code (.cs files) | unity-specialist |
| Shader / material files (.shader, .shadergraph, .mat) | unity-shader-specialist |
| UI / screen files (.uxml, .uss, Canvas prefabs) | unity-ui-specialist |
| Scene / prefab / level files (.unity, .prefab) | unity-specialist |
| Native extension / plugin files (.dll, native plugins) | unity-specialist |
| General architecture review | unity-specialist |
```

**对于 Unreal：**
```markdown
## Engine Specialists
- **Primary**: unreal-specialist
- **Language/Code Specialist**: ue-blueprint-specialist（Blueprint 图形）或 unreal-specialist（C++）
- **Shader Specialist**: unreal-specialist（无专门的着色器专家——主要涵盖材质）
- **UI Specialist**: ue-umg-specialist（UMG 小部件、CommonUI、输入路由、小部件样式）
- **Additional Specialists**: ue-gas-specialist（Gameplay Ability System、属性、游戏效果）、ue-replication-specialist（属性复制、RPC、客户端预测、netcode）
- **Routing Notes**: 为 C++ 架构和广泛的引擎决策调用主要。为 Blueprint 图形架构和 BP/C++ 边界设计调用 Blueprint 专家。为所有能力和属性代码调用 GAS 专家。为任何多人在线或联网系统调用复制专家。为所有 UI 实现调用 UMG 专家。

### File Extension Routing

| File Extension / Type | Specialist to Spawn |
|-----------------------|---------------------|
| Game code (.cpp, .h files) | unreal-specialist |
| Shader / material files (.usf, .ush, Material assets) | unreal-specialist |
| UI / screen files (.umg, UMG Widget Blueprints) | ue-umg-specialist |
| Scene / prefab / level files (.umap, .uasset) | unreal-specialist |
| Native extension / plugin files (Plugin .uplugin, modules) | unreal-specialist |
| Blueprint graphs (.uasset BP classes) | ue-blueprint-specialist |
| General architecture review | unreal-specialist |
```

### 协作步骤
向用户展示填写好的偏好。对于 Godot，包括所选语言并注明完整命名约定和路由表所在位置：
> "这是 [engine]（[language]（如果是 Godot））的默认技术偏好。命名约定和专家路由在此技能的附录 A 中——我将应用 [GDScript/C#/Both] 变体。您想自定义其中的任何内容，还是直接保存默认值？"

对于所有其他引擎，直接呈现默认值，无需引用附录。

在写入文件前等待批准。

---

## 6. 确定知识缺口

检查引擎版本是否可能超出 LLM 的训练数据。

**已知大致覆盖范围**（随着模型的变化更新）：
- LLM 知识截止日期：**2025 年 5 月**
- Godot：训练数据可能覆盖到约 4.3
- Unity：训练数据可能覆盖到约 2023.x / 早期 6000.x
- Unreal：训练数据可能覆盖到约 5.3 / 早期 5.4

将用户选择的版本与这些基准进行比较：

- **在训练数据内** → `LOW RISK` — 参考文档可选但推荐
- **接近边界** → `MEDIUM RISK` — 推荐参考文档
- **超出训练数据** → `HIGH RISK` — 参考文档必需

告知用户他们属于哪个类别及其原因。

---

## 7. 填充引擎参考文档

### 如果在训练数据内（低风险）：

创建最小化的 `docs/engine-reference/<engine>/VERSION.md`：

```markdown
# [Engine] — 版本参考

| 字段 | 值 |
|-------|-------|
| **引擎版本** | [version] |
| **项目锁定日期** | [today's date] |
| **LLM 知识截止日期** | May 2025 |
| **风险等级** | LOW — 版本在 LLM 训练数据内 |

## 备注

此引擎版本在 LLM 的训练数据内。引擎参考
文档是可选的，但如果代理建议不正确的 API，可以在以后添加。

随时运行 `/setup-engine refresh` 以填充完整的参考文档。
```

不要创建 breaking-changes.md、deprecated-apis.md 等——它们会增加上下文成本但价值很小。

### 如果超出训练数据（中或高风险）：

通过搜索网络创建完整的参考文档集：

1. **搜索官方迁移/升级指南**：
   - `"[engine] [old version] to [new version] migration guide"`
   - `"[engine] [version] breaking changes"`
   - `"[engine] [version] changelog"`
   - `"[engine] [version] deprecated API"`

2. **从官方文档获取并提取**：
   - 从训练截止到当前版本之间的每个版本的破坏性变更
   - 已弃用的 API 及其替代方案
   - 新特性和最佳实践

询问："我可以在 `docs/engine-reference/<engine>/` 下创建引擎参考文档吗？"

在写入任何文件前等待确认。

3. **创建完整的参考目录**：
   ```
   docs/engine-reference/<engine>/
   ├── VERSION.md              # 版本锁定 + 知识缺口分析
   ├── breaking-changes.md     # 逐版本的破坏性变更
   ├── deprecated-apis.md      # "不要用 X → 使用 Y" 表格
   ├── current-best-practices.md  # 训练截止后的新实践
   └── modules/                # 每个子系统的参考（按需创建）
   ```

4. **使用网络搜索的真实数据填充每个文件**，遵循现有参考文档中建立的格式。每个文件必须有"最后验证：[date]"头部。

5. **对于模块文件**：仅在发生了重大变化的子系统创建模块。不要创建空或内容最少的模块文件。

---

## 8. 更新 CLAUDE.md 导入

询问："我可以更新 `CLAUDE.md` 中的 `@` 导入以指向新的引擎参考吗？"

等待确认，然后将"引擎版本参考"下的 `@` 导入更新为指向正确的引擎：

```markdown
## Engine Version Reference

@docs/engine-reference/<engine>/VERSION.md
```

如果之前的导入指向了不同的引擎（例如从 Godot 切换到 Unity），更新它。

---

## 9. 更新代理指令

询问："我是否应该向引擎专家代理文件添加版本意识部分？"然后再做任何编辑。

对于所选引擎的专家代理，验证它们是否有"版本意识"部分。如果没有，按照现有 Godot 专家代理的模式添加一个。

该部分应指示代理：
1. 读取 `docs/engine-reference/<engine>/VERSION.md`
2. 在建议代码前检查已弃用的 API
3. 检查相关版本转换的破坏性变更
4. 使用 WebSearch 验证不确定的 API

---

## 10. 刷新子命令

如果调用为 `/setup-engine refresh`：

1. 读取现有的 `docs/engine-reference/<engine>/VERSION.md` 以获取当前引擎和版本
2. 使用 WebSearch 检查：
   - 自上次验证以来的新引擎版本
   - 更新的迁移指南
   - 新弃用的 API
3. 用新发现更新所有参考文档
4. 更新所有修改文件的"最后验证"日期
5. 报告变更内容

---

## 11. 升级子命令

如果调用为 `/setup-engine upgrade [old-version] [new-version]`：

### 步骤 1 — 读取当前版本状态

读取 `docs/engine-reference/<engine>/VERSION.md` 以确认当前锁定的版本、风险等级以及任何已记录的迁移说明 URL。如果 `old-version` 未作为参数提供，使用此文件中的锁定版本。

### 步骤 2 — 获取迁移指南

使用 WebSearch 和 WebFetch 定位 `old-version` 和 `new-version` 之间的官方迁移指南：

- 搜索：`"[engine] [old-version] to [new-version] migration guide"`
- 搜索：`"[engine] [new-version] breaking changes changelog"`
- 如果 VERSION.md 中已记录了迁移指南 URL，获取它；或使用搜索找到的 URL。

提取：重命名的 API、移除的 API、更改的默认值、行为变更以及任何"必须迁移"的项。

### 步骤 3 — 升级前审计

扫描 `src/` 中使用了目标版本中已知已弃用或已更改的 API 的代码：

- 使用 Grep 搜索从迁移指南中提取的已弃用 API 名称（例如旧的函数名、移除的节点类型、更改的属性名）
- 列出每个匹配的文件，以及找到的具体 API 引用

以表格形式呈现审计结果：

```
升级前审计：[engine] [old-version] → [new-version]
==========================================================

需要更改的文件：
  文件                                | 发现的已弃用 API       | 工作量
  --------------------------------- | -------------------------- | ------
  src/gameplay/player_movement.gd   | old_api_name               | 低
  src/ui/hud.gd                     | removed_node_type          | 中

需要注意的破坏性变更：
  - [迁移指南中的变更描述]
  - [迁移指南中的变更描述]

推荐的迁移顺序（按依赖排序）：
  1. [依赖最少的系统/层优先]
  2. [下一个系统]
  ...
```

如果在 `src/` 中未发现已弃用的 API，报告："在 src/ 中未发现已弃用的 API 使用——升级可能风险较低。"

### 步骤 4 — 在更新前确认

在进行任何更改前询问用户：

> "升级前审计完成。发现 [N] 个文件使用了已弃用的 API。
> 是否继续将 VERSION.md 升级到 [new-version]？
> （这将更新锁定的版本并添加迁移说明——它不会更改任何源文件。源文件的迁移是手动或通过 story 完成的。）"

在继续前等待明确确认。

### 步骤 5 — 更新 VERSION.md

确认后：

1. 更新 `docs/engine-reference/<engine>/VERSION.md`：
   - `Engine Version` → `[new-version]`
   - `Project Pinned` → 今天的日期
   - `Last Docs Verified` → 今天的日期
   - 如果新版本超出 LLM 知识截止日期，重新评估并更新`风险等级`和`截止后版本时间线`表
   - 添加 `## Migration Notes — [old-version] → [new-version]` 部分，包含：迁移指南 URL、关键破坏性变更、在此项目中发现的已弃用 API、以及审计中的推荐迁移顺序

2. 如果引擎参考目录中存在 `breaking-changes.md` 或 `deprecated-apis.md`，将新版本的变更追加到这些文件中。

### 步骤 6 — 升级后提醒

更新 VERSION.md 后，输出：

```
VERSION.md 已更新：[engine] [old-version] → [new-version]

后续步骤：
1. 迁移上述 [N] 个文件中已弃用的 API 用法
2. 在实际升级引擎二进制文件后运行 /setup-engine refresh，验证没有遗漏新的弃用项
3. 运行 /architecture-review — 引擎升级可能使引用特定 API 或引擎功能的 ADR 失效
4. 如果有任何 ADR 失效，运行 /propagate-design-change 更新下游 story
```

---

## 12. 输出摘要

设置完成后，输出：

```
引擎设置完成
=====================
引擎：          [name] [version]
语言：          [GDScript | C# | GDScript + C# | C# | C++ + Blueprint]
知识风险：      [低/中/高]
参考文档：      [已创建/已跳过]
CLAUDE.md：     [已更新]
技术偏好：      [已创建/已更新]
代理配置：      [已验证]

后续步骤：
1. 查看 docs/engine-reference/<engine>/VERSION.md
2. [如果来自 /brainstorm] 运行 /map-systems 将您的概念分解为各个系统
3. [如果来自 /brainstorm] 运行 /design-system 编写每个系统的 GDD（引导式，逐节）
4. [如果来自 /brainstorm] 运行 /prototype [core-mechanic] 在编写 GDD 前验证核心想法
5. [如果全新开始] 运行 /brainstorm 发现您的游戏概念
6. 创建您的第一个里程碑：/sprint-plan new
```

---

裁决：**COMPLETE** — 引擎已配置，参考文档已填充。

## 护栏

- 永远不要猜测引擎版本——始终通过 WebSearch 或用户确认验证
- 未经询问，永远不要覆盖现有的参考文档——追加或更新
- 如果不同引擎的参考文档已经存在，询问后再替换
- 在对 CLAUDE.md 进行编辑之前，始终向用户展示将更改的内容
- 如果 WebSearch 返回模糊的结果，向用户展示并让他们决定
- 当用户选择了 **GDScript**：精确复制附录 A1 中的 GDScript CLAUDE.md 模板。永远不要在语言字段中添加"通过 GDExtension 的 C++"。GDScript 项目可能使用 GDExtension，但它不是主要的项目语言。路由表中的 `godot-gdextension-specialist` 在需要原生扩展时可用——它不会使 C++ 成为项目语言。

---

## 附录 A — Godot 语言配置

所有 Godot 特定变体，用于语言相关的配置。从第 4 节和第 5 节引用——仅在 Godot 是所选引擎时相关。使用与第 4 节中选择的语言匹配的子节。

---

### A1. CLAUDE.md 技术栈模板

**GDScript：**
```markdown
- **Engine**: Godot [version]
- **Language**: GDScript
- **Build System**: SCons（引擎），Godot Export Templates
- **Asset Pipeline**: Godot Import System + custom resource pipeline
```

> **护栏**：使用此 GDScript 模板时，语言字段必须完全写为"`GDScript`"——不要添加任何内容。不要追加"通过 GDExtension 的 C++"或任何其他语言。下面的 C# 模板包含 GDExtension，因为 C# 项目通常包装原生代码；GDScript 项目不需要。

**C#：**
```markdown
- **Engine**: Godot [version]
- **Language**: C# (.NET 8+, primary), C++ via GDExtension（仅原生插件）
- **Build System**: .NET SDK + Godot Export Templates
- **Asset Pipeline**: Godot Import System + custom resource pipeline
```

**两者 — GDScript + C#：**
```markdown
- **Engine**: Godot [version]
- **Language**: GDScript（游戏玩法/UI 脚本），C#（性能关键系统），C++ via GDExtension（仅原生）
- **Build System**: .NET SDK + Godot Export Templates
- **Asset Pipeline**: Godot Import System + custom resource pipeline
```

---

### A2. 命名约定

**GDScript：**
- 类：PascalCase（例如 `PlayerController`）
- 变量/函数：snake_case（例如 `move_speed`）
- 信号：snake_case 过去式（例如 `health_changed`）
- 文件：与类匹配的 snake_case（例如 `player_controller.gd`）
- 场景：匹配根节点的 PascalCase（例如 `PlayerController.tscn`）
- 常量：UPPER_SNAKE_CASE（例如 `MAX_HEALTH`）

**C#：**
- 类：PascalCase（`PlayerController`）——也必须是 `partial`
- 公共属性/字段：PascalCase（`MoveSpeed`、`JumpVelocity`）
- 私有字段：`_camelCase`（`_currentHealth`、`_isGrounded`）
- 方法：PascalCase（`TakeDamage()`、`GetCurrentHealth()`）
- 信号委托：PascalCase + `EventHandler` 后缀（`HealthChangedEventHandler`）
- 文件：与类匹配的 PascalCase（`PlayerController.cs`）
- 场景：匹配根节点的 PascalCase（`PlayerController.tscn`）
- 常量：PascalCase（`MaxHealth`、`DefaultMoveSpeed`）

**两者 — GDScript + C#：**
对于 `.gd` 文件使用 GDScript 约定，对于 `.cs` 文件使用 C# 约定。不存在混合语言的文件——边界是按文件划分的。如果不确定新系统应该使用哪种语言，询问用户并在 `technical-preferences.md` 中记录决定。

---

### A3. 引擎专家路由

**GDScript：**
```markdown
## Engine Specialists
- **Primary**: godot-specialist
- **Language/Code Specialist**: godot-gdscript-specialist（所有 .gd 文件）
- **Shader Specialist**: godot-shader-specialist（.gdshader 文件、VisualShader 资源）
- **UI Specialist**: godot-specialist（无专门的 UI 专家——主要涵盖所有 UI）
- **Additional Specialists**: godot-gdextension-specialist（仅 GDExtension / 原生 C++ 绑定）
- **Routing Notes**: 为架构决策、ADR 验证和跨领域代码审查调用主要。为代码质量、信号架构、静态类型强制和 GDScript 惯用语法调用 GDScript 专家。为材质设计和着色器代码调用着色器专家。仅在涉及原生扩展时调用 GDExtension 专家。

### File Extension Routing

| File Extension / Type | Specialist to Spawn |
|-----------------------|---------------------|
| Game code (.gd files) | godot-gdscript-specialist |
| Shader / material files (.gdshader, VisualShader) | godot-shader-specialist |
| UI / screen files (Control nodes, CanvasLayer) | godot-specialist |
| Scene / prefab / level files (.tscn, .tres) | godot-specialist |
| Native extension / plugin files (.gdextension, C++) | godot-gdextension-specialist |
| General architecture review | godot-specialist |
```

**C#：**
```markdown
## Engine Specialists
- **Primary**: godot-specialist
- **Language/Code Specialist**: godot-csharp-specialist（所有 .cs 文件）
- **Shader Specialist**: godot-shader-specialist（.gdshader 文件、VisualShader 资源）
- **UI Specialist**: godot-specialist（无专门的 UI 专家——主要涵盖所有 UI）
- **Additional Specialists**: godot-gdextension-specialist（仅 GDExtension / 原生 C++ 绑定）
- **Routing Notes**: 为架构决策、ADR 验证和跨领域代码审查调用主要。为代码质量、[Signal] 委托模式、[Export] 属性、.csproj 管理和 C# 特定 Godot 惯用语法调用 C# 专家。为材质设计和着色器代码调用着色器专家。仅在涉及原生 C++ 插件时调用 GDExtension 专家。

### File Extension Routing

| File Extension / Type | Specialist to Spawn |
|-----------------------|---------------------|
| Game code (.cs files) | godot-csharp-specialist |
| Shader / material files (.gdshader, VisualShader) | godot-shader-specialist |
| UI / screen files (Control nodes, CanvasLayer) | godot-specialist |
| Scene / prefab / level files (.tscn, .tres) | godot-specialist |
| Project config (.csproj, NuGet) | godot-csharp-specialist |
| Native extension / plugin files (.gdextension, C++) | godot-gdextension-specialist |
| General architecture review | godot-specialist |
```

**两者 — GDScript + C#：**
```markdown
## Engine Specialists
- **Primary**: godot-specialist
- **GDScript Specialist**: godot-gdscript-specialist（.gd 文件 — 游戏玩法/UI 脚本）
- **C# Specialist**: godot-csharp-specialist（.cs 文件 — 性能关键系统）
- **Shader Specialist**: godot-shader-specialist（.gdshader 文件、VisualShader 资源）
- **UI Specialist**: godot-specialist（无专门的 UI 专家——主要涵盖所有 UI）
- **Additional Specialists**: godot-gdextension-specialist（仅 GDExtension / 原生 C++ 绑定）
- **Routing Notes**: 为跨语言架构决策以及哪些系统属于哪种语言调用主要。为 .gd 文件调用 GDScript 专家。为 .cs 文件和 .csproj 管理调用 C# 专家。在边界处优先使用信号而不是直接的跨语言方法调用。

### File Extension Routing

| File Extension / Type | Specialist to Spawn |
|-----------------------|---------------------|
| Game code (.gd files) | godot-gdscript-specialist |
| Game code (.cs files) | godot-csharp-specialist |
| Cross-language boundary decisions | godot-specialist |
| Shader / material files (.gdshader, VisualShader) | godot-shader-specialist |
| UI / screen files (Control nodes, CanvasLayer) | godot-specialist |
| Scene / prefab / level files (.tscn, .tres) | godot-specialist |
| Project config (.csproj, NuGet) | godot-csharp-specialist |
| Native extension / plugin files (.gdextension, C++) | godot-gdextension-specialist |
| General architecture review | godot-specialist |
```
