# 技术偏好设定

<!-- 由 /setup-engine 填充。随着用户在开发过程中做出决策而更新。 -->
<!-- 所有代理都引用此文件以了解项目特定的标准和约定。 -->

## 引擎与语言

- **引擎 (Engine)**：Godot 4.6
- **语言 (Language)**：GDScript
- **渲染 (Rendering)**：Godot Forward+（默认渲染器，卡牌游戏 2D UI 为主要场景）
- **物理 (Physics)**：Godot Physics 2D

## 输入与平台

<!-- 由 /setup-engine 编写。由 /ux-design、/ux-review、/test-setup、/team-ui 和 /dev-story 读取 -->
<!-- 以将交互规格、测试辅助工具和实现限定在正确的输入方法范围内。 -->

- **目标平台 (Target Platforms)**：PC（Steam）
- **输入方式 (Input Methods)**：键盘/鼠标
- **主要输入 (Primary Input)**：鼠标（卡牌点击拖拽）
- **手柄支持 (Gamepad Support)**：部分（可选，非 MVP 需求）
- **触屏支持 (Touch Support)**：无
- **平台说明 (Platform Notes)**：卡牌交互以鼠标点击和拖拽为主，UI 设计需考虑 Steam 覆盖层兼容

## 命名规范

- **类 (Classes)**：PascalCase（如 `PlayerController`）
- **变量 (Variables)**：snake_case（如 `move_speed`）
- **信号/事件 (Signals/Events)**：snake_case 过去式（如 `health_changed`）
- **文件 (Files)**：snake_case 匹配类名（如 `player_controller.gd`）
- **场景/预制体 (Scenes/Prefabs)**：PascalCase 匹配根节点（如 `PlayerController.tscn`）
- **常量 (Constants)**：UPPER_SNAKE_CASE（如 `MAX_HEALTH`）

## 性能预算

- **目标帧率 (Target Framerate)**：60fps
- **帧预算 (Frame Budget)**：16.6ms
- **绘制调用 (Draw Calls)**：200 以下（2D 卡牌游戏）
- **内存上限 (Memory Ceiling)**：2GB

## 测试

- **框架 (Framework)**：GUT（Godot Unit Test，GDScript 原生测试框架）
- **最低覆盖率 (Minimum Coverage)**：[暂未设定 — 首个 sprint 前设置]
- **必需测试 (Required Tests)**：平衡公式、卡牌效果解析、战斗流程

## 禁止模式

<!-- 添加不应出现在本项目代码库中的模式 -->
- [尚未配置 — 随着架构决策的做出而添加]

## 允许的库/插件

<!-- 在此添加已批准的第三方依赖 -->
- [尚未配置 — 随着依赖项的获批而添加]

## 架构决策日志

<!-- 快速参考，链接至 docs/architecture/ 中的完整 ADR -->
- [尚无 ADR — 使用 /architecture-decision 创建]

## 引擎专家

<!-- 在引擎配置完成后由 /setup-engine 编写。 -->
<!-- 由 /code-review、/architecture-decision、/architecture-review 和团队技能读取 -->
<!-- 以了解在引擎特定验证时应调起哪个专家。 -->

- **主要 (Primary)**：godot-specialist
- **语言/代码专家 (Language/Code Specialist)**：godot-gdscript-specialist（所有 .gd 文件）
- **着色器专家 (Shader Specialist)**：godot-shader-specialist（.gdshader 文件、VisualShader 资源）
- **UI 专家 (UI Specialist)**：godot-specialist（无专门的 UI 专家——主要涵盖所有 UI）
- **附加专家 (Additional Specialists)**：godot-gdextension-specialist（仅原生 C++ 扩展绑定）
- **路由说明 (Routing Notes)**：为架构决策、ADR 验证和跨领域代码审查调用主要。为代码质量、信号架构、静态类型强制和 GDScript 惯用语法调用 GDScript 专家。为材质设计和着色器代码调用着色器专家。仅在涉及原生扩展时调用 GDExtension 专家。

### 文件扩展名路由

<!-- 技能使用此表按文件类型选择正确的专家。 -->
<!-- 如果某行显示 [待配置]，则该文件类型回退到主要 (Primary) 专家。 -->

| 文件扩展名 / 类型 | 需调起的专家 |
|-----------------------|---------------------|
| 游戏代码（.gd 文件） | godot-gdscript-specialist |
| 着色器 / 材质文件（.gdshader, VisualShader） | godot-shader-specialist |
| UI / 屏幕文件（Control 节点, CanvasLayer） | godot-specialist |
| 场景 / 预制体 / 关卡文件（.tscn, .tres） | godot-specialist |
| 原生扩展 / 插件文件（.gdextension, C++） | godot-gdextension-specialist |
| 通用架构审查 | godot-specialist |
