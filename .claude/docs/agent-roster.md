
# 代理花名册 (Agent Roster)

以下代理可用。每个代理在 `.claude/agents/` 中都有专用的定义文件。请选择最适合当前任务的代理。当任务跨多个领域时，协调代理（通常为 `producer` 或领域主管）应委派给专业人员。

## 第 1 层——领导层代理（Opus 模型）(Tier 1 -- Leadership Agents (Opus))
| 代理 (Agent) | 领域 (Domain) | 使用时机 (When to Use) |
|-------|--------|-------------|
| `creative-director` | 高层愿景 (High-level vision) | 重大创意决策、核心支柱冲突、基调/方向 |
| `technical-director` | 技术愿景 (Technical vision) | 架构决策、技术栈选择、性能策略 |
| `producer` | 制作管理 (Production management) | 冲刺规划、里程碑跟踪、风险管理、协调 |

## 第 2 层——部门主管代理（deepseek-v4-pro 模型）(Tier 2 -- Department Lead Agents (deepseek-v4-pro))
| 代理 (Agent) | 领域 (Domain) | 使用时机 (When to Use) |
|-------|--------|-------------|
| `game-designer` | 游戏设计 (Game design) | 机制、系统、成长、经济、平衡 |
| `lead-programmer` | 代码架构 (Code architecture) | 系统设计、代码审查、API 设计、重构 |
| `art-director` | 视觉方向 (Visual direction) | 风格指南、美术圣经、资源标准、UI/UX 方向 |
| `audio-director` | 音频方向 (Audio direction) | 音乐方向、音色调色板、音频实现策略 |
| `narrative-director` | 故事与写作 (Story and writing) | 故事弧线、世界构建、角色设计、对话策略 |
| `qa-lead` | 质量保证 (Quality assurance) | 测试策略、Bug 分类、发布就绪度、回归规划 |
| `release-manager` | 发布管线 (Release pipeline) | 构建管理、版本控制、变更日志、部署、回滚 |
| `localization-lead` | 国际化 (Internationalization) | 字符串外部化、翻译管线、语言环境测试 |

## 第 3 层——专业代理（deepseek-v4-pro 或 deepseek-v4-pro 模型）(Tier 3 -- Specialist Agents (deepseek-v4-pro or deepseek-v4-pro))
| 代理 (Agent) | 领域 (Domain) | 模型 (Model) | 使用时机 (When to Use) |
|-------|--------|-------|-------------|
| `systems-designer` | 系统设计 (Systems design) | deepseek-v4-pro | 特定机制实现、公式设计、循环 |
| `level-designer` | 关卡设计 (Level design) | deepseek-v4-pro | 关卡布局、节奏、遭遇设计、流程 |
| `economy-designer` | 经济/平衡 (Economy/balance) | deepseek-v4-pro | 资源经济、战利品表、成长曲线 |
| `gameplay-programmer` | 玩法代码 (Gameplay code) | deepseek-v4-pro | 功能实现、游戏系统代码 |
| `engine-programmer` | 引擎系统 (Engine systems) | deepseek-v4-pro | 核心引擎、渲染、物理、内存管理 |
| `ai-programmer` | AI 系统 (AI systems) | deepseek-v4-pro | 行为树、寻路、NPC 逻辑、状态机 |
| `network-programmer` | 网络 (Networking) | deepseek-v4-pro | 网络代码、复制、延迟补偿、匹配 |
| `tools-programmer` | 开发工具 (Dev tools) | deepseek-v4-pro | 编辑器扩展、管线工具、调试工具 |
| `ui-programmer` | UI 实现 (UI implementation) | deepseek-v4-pro | UI 框架、界面、控件、数据绑定 |
| `technical-artist` | 技术美术 (Tech art) | deepseek-v4-pro | 着色器、VFX、优化、美术管线工具 |
| `sound-designer` | 音效设计 (Sound design) | deepseek-v4-pro | SFX 设计文档、音频事件列表、混音说明 |
| `writer` | 对话/传说 (Dialogue/lore) | deepseek-v4-pro | 对话编写、传说条目、物品描述 |
| `world-builder` | 世界/传说设计 (World/lore design) | deepseek-v4-pro | 世界规则、阵营设计、历史、地理 |
| `qa-tester` | 测试执行 (Test execution) | deepseek-v4-pro | 编写测试用例、Bug 报告、测试清单 |
| `performance-analyst` | 性能 (Performance) | deepseek-v4-pro | 性能分析、优化建议、内存分析 |
| `devops-engineer` | 构建/部署 (Build/deploy) | deepseek-v4-pro | CI/CD、构建脚本、版本控制工作流 |
| `analytics-engineer` | 遥测 (Telemetry) | deepseek-v4-pro | 事件跟踪、仪表板、A/B 测试设计 |
| `ux-designer` | UX 流程 (UX flows) | deepseek-v4-pro | 用户流程、线框图、可访问性、输入处理 |
| `prototyper` | 快速原型 (Rapid prototyping) | deepseek-v4-pro | 可抛弃原型、机制测试、可行性验证 |
| `security-engineer` | 安全 (Security) | deepseek-v4-pro | 反作弊、漏洞预防、存档加密、网络安全 |
| `accessibility-specialist` | 可访问性 (Accessibility) | deepseek-v4-pro | WCAG 合规、色盲模式、重映射、文本缩放 |
| `live-ops-designer` | 运营 (Live operations) | deepseek-v4-pro | 赛季、活动、战斗通行证、留存、运营经济 |
| `community-manager` | 社区 (Community) | deepseek-v4-pro | 补丁说明、玩家反馈、危机沟通、社区健康 |

## 引擎特定代理（使用与你引擎匹配的集合）(Engine-Specific Agents (use the set matching your engine))

### 引擎主管 (Engine Leads)

| 代理 (Agent) | 引擎 (Engine) | 模型 (Model) | 使用时机 (When to Use) |
| ---- | ---- | ---- | ---- |
| `unreal-specialist` | Unreal Engine 5 | deepseek-v4-pro | Blueprint 与 C++、GAS 概览、UE 子系统、Unreal 优化 |
| `unity-specialist` | Unity | deepseek-v4-pro | MonoBehaviour 与 DOTS、Addressables、URP/HDRP、Unity 优化 |
| `godot-specialist` | Godot 4 | deepseek-v4-pro | GDScript 模式、节点/场景架构、信号、Godot 优化 |

### Unreal Engine 子专家 (Unreal Engine Sub-Specialists)

| 代理 (Agent) | 子系统 (Subsystem) | 模型 (Model) | 使用时机 (When to Use) |
| ---- | ---- | ---- | ---- |
| `ue-gas-specialist` | 游戏能力系统 (Gameplay Ability System) | deepseek-v4-pro | 能力、游戏效果、属性集、标签、预测 |
| `ue-blueprint-specialist` | Blueprint 架构 (Blueprint Architecture) | deepseek-v4-pro | BP/C++ 边界、图形标准、命名、BP 优化 |
| `ue-replication-specialist` | 网络/复制 (Networking/Replication) | deepseek-v4-pro | 属性复制、RPC、预测、相关性、带宽 |
| `ue-umg-specialist` | UMG/CommonUI | deepseek-v4-pro | 控件层级、数据绑定、CommonUI 输入、UI 性能 |

### Unity 子专家 (Unity Sub-Specialists)

| 代理 (Agent) | 子系统 (Subsystem) | 模型 (Model) | 使用时机 (When to Use) |
| ---- | ---- | ---- | ---- |
| `unity-dots-specialist` | DOTS/ECS | deepseek-v4-pro | 实体组件系统、Jobs、Burst 编译器、混合渲染器 |
| `unity-shader-specialist` | 着色器/VFX (Shaders/VFX) | deepseek-v4-pro | Shader Graph、VFX Graph、URP/HDRP 定制、后处理 |
| `unity-addressables-specialist` | 资产管理 (Asset Management) | deepseek-v4-pro | Addressable 组、异步加载、内存、内容分发 |
| `unity-ui-specialist` | UI Toolkit/UGUI | deepseek-v4-pro | UI Toolkit、UXML/USS、UGUI Canvas、数据绑定、跨平台输入 |

### Godot 子专家 (Godot Sub-Specialists)

| 代理 (Agent) | 子系统 (Subsystem) | 模型 (Model) | 使用时机 (When to Use) |
| ---- | ---- | ---- | ---- |
| `godot-gdscript-specialist` | GDScript | deepseek-v4-pro | 静态类型、设计模式、信号、协程、GDScript 性能 |
| `godot-csharp-specialist` | C# / .NET | deepseek-v4-pro | .NET 模式、[Signal] 委托、async、可空类型、类型安全节点访问 |
| `godot-shader-specialist` | 着色器/渲染 (Shaders/Rendering) | deepseek-v4-pro | Godot 着色语言、可视化着色器、粒子、后处理 |
| `godot-gdextension-specialist` | GDExtension | deepseek-v4-pro | C++/Rust 绑定、原生性能、自定义节点、构建系统 |
