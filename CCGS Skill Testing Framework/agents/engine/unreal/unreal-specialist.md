
# 智能体测试规格：unreal-specialist（Unreal 引擎专家）

## 智能体概述
- **领域 (Domain)**：Unreal 引擎模式与架构 —— Blueprint vs C++ 决策、UE 子系统（GAS、Enhanced Input、Niagara）、UE 项目结构、插件集成及引擎级配置
- **不负责**：美术风格和视觉方向 (art-director)、服务器基础设施和部署 (devops-engineer)、UI/UX 流程设计 (ux-designer)
- **模型层级 (Model tier)**：Sonnet
- **关卡 ID**：无；关卡裁决交由 technical-director

---

## 静态断言（结构）

- [ ] `description:` 字段存在且具有领域针对性（涉及 Unreal 引擎）
- [ ] `allowed-tools:` 列表与智能体角色匹配（支持读取、写入 UE 项目文件；无部署工具）
- [ ] 模型层级为 Sonnet（专家角色的默认值）
- [ ] 智能体定义未声称在其声明领域之外具有权威（无美术、无服务器基础设施）

---

## 测试用例

### 用例 1：领域内请求 —— Blueprint vs C++ 决策标准
**输入**："我应该用 Blueprint 还是 C++ 实现我们的连击攻击系统？"
**预期行为**：
- 提供结构化决策标准：复杂度、复用频率、团队技能和性能要求
- 对于每帧调用或跨 5 种以上能力类型共享的系统，建议使用 C++
- 对于设计师可调值和一次性逻辑，建议使用 Blueprint
- 在不知道项目上下文的情况下不做最终裁决 —— 在缺少上下文时提出澄清性问题
- 输出结构化（标准表格或项目符号列表），而非自由格式意见

### 用例 2：领域外请求 —— Unity C# 代码
**输入**："请编写处理玩家生命值并在死亡时触发 Unity 事件的 C# MonoBehaviour。"
**预期行为**：
- 不生成 Unity C# 代码
- 明确说明："此项目使用 Unreal 引擎；Unity 的等效实现是 UE C++ 中的 Actor Component 或 Blueprint Actor Component"
- 可选地，在请求时提供 UE 等效方案
- 不重定向给 Unity 专家（框架中不存在这样的专家）

### 用例 3：领域边界 —— UE5.4 API 要求
**输入**："我需要使用 UE5.4 中引入的新 Motion Matching API。"
**预期行为**：
- 指出 UE5.4 是一个特定版本，LLM 训练覆盖范围可能有限
- 建议在信任任何 API 建议之前，交叉参考官方 Unreal 文档或项目的 engine-reference 目录
- 提供尽力而为的 API 指导，并带有明确的不确定性标记（例如"请对照 UE5.4 发布说明进行验证"）
- 不静默生成过时或不正确的 API 签名而不加警示

### 用例 4：冲突 —— 核心系统中的蓝图面条式代码
**输入**："我们的复制逻辑完全位于深度嵌套的蓝图事件图中，有 300 多个节点且无函数封装。它变得难以维护了。"
**预期行为**：
- 将其识别为蓝图架构问题，而非小风格问题
- 建议将核心复制逻辑迁移到 C++ ActorComponent 或 GameplayAbility 系统
- 说明所需的协调：对复制架构的更改必须涉及 lead-programmer
- 不在不向用户揭示重构范围的情况下单方面宣布"迁移到 C++"
- 生成具体的迁移建议，而非模糊的建议

### 用例 5：上下文传递 —— 版本适配的 API 建议
**输入上下文**：项目的 engine-reference 文件声明使用 Unreal Engine 5.3。
**输入**："如何为新角色设置 Enhanced Input 动作？"
**预期行为**：
- 使用 UE5.3 时代的 Enhanced Input API（InputMappingContext、UEnhancedInputComponent::BindAction）
- 不引用 UE5.3 之后引入的 API，除非标记为可能不可用
- 在回复中引用项目声明的引擎版本
- 提供具体的、锚定版本号的代码或蓝图节点名称

---

## 协议合规

- [ ] 保持在声明的领域内（Unreal 模式、Blueprint/C++、UE 子系统）
- [ ] 将 Unity 或其他引擎的请求重定向，不生成错误引擎的代码
- [ ] 返回结构化发现（标准表、决策树、迁移计划），而非自由格式意见
- [ ] 在生成 API 建议前明确标记版本不确定性
- [ ] 对于架构层面的重构，与 lead-programmer 协调而非单方面决策

---

## 覆盖范围说明
- 无用于智能体行为测试的自动运行器 —— 这些通过手动审查或 `/skill-test` 进行
- 版本感知（用例 3、用例 5）是此智能体风险最高的失效模式；引擎版本变更时定期测试
- 用例 4 与 lead-programmer 的集成是协调测试，而非技术正确性测试
