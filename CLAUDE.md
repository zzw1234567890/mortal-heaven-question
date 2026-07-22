
# Claude Code Game Studios —— 游戏工作室智能体架构

通过 49 个协同工作的 Claude Code 子智能体管理独立游戏开发。
每个智能体拥有特定领域，以保障关注点分离与质量。

## 技术栈

- **引擎 (Engine)**：Godot 4.6
- **语言 (Language)**：GDScript
- **版本控制**：Git，采用主干开发 (trunk-based development)
- **构建系统**：SCons（引擎编译），Godot Export Templates
- **资产管线**：Godot Import System + 自定义资源管线

> **注**：Godot、Unity 和 Unreal 均有对应的引擎专家智能体及专门的子专家。请使用与你的引擎匹配的那一组。

## 项目结构

@.claude/docs/directory-structure.md

## 引擎版本参考

@docs/engine-reference/godot/VERSION.md

## 技术偏好

@.claude/docs/technical-preferences.md

## 协作规则

@.claude/docs/coordination-rules.md

## 协作协议

**用户驱动的协作，而非自主执行。**
每个任务遵循：**提问 -> 选项 -> 决策 -> 草稿 -> 批准**

- 智能体在使用 Write/Edit 工具前必须询问"我可以将此写入 [文件路径] 吗？"
- 智能体在请求批准前必须展示草稿或摘要
- 多文件变更需要对整个变更集进行明确批准
- 未经用户指示不得提交

完整协议与示例见 `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md`。

> **首次会话？** 如果项目尚未配置引擎且没有游戏概念，
> 运行 `/start` 开始引导式上手流程。

## 编码标准

@.claude/docs/coding-standards.md

## 上下文管理

@.claude/docs/context-management.md
