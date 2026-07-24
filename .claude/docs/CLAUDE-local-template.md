
# CLAUDE.local.md 模板 (CLAUDE.local.md Template)

将此文件复制到项目根目录并命名为 `CLAUDE.local.md` 作为个人覆盖配置。
此文件已被 gitignore 忽略，不会被提交。

```markdown
# 个人偏好 (Personal Preferences)

## 模型偏好 (Model Preferences)
- 复杂设计任务偏好使用 Opus
- 快速查询和简单编辑使用 deepseek-v4-pro

## 工作流偏好 (Workflow Preferences)
- 代码变更后始终运行测试
- 在上下文使用率达到 60% 时主动压缩
- 在不相关的任务之间使用 /clear

## 本地环境 (Local Environment)
- Python 命令：python（或 py / python3）
- Shell：Windows 上的 Git Bash
- IDE：安装了 Claude Code 扩展的 VS Code

## 沟通风格 (Communication Style)
- 回复简洁
- 所有代码引用中显示文件路径
- 简要说明架构决策

## 个人快捷操作 (Personal Shortcuts)
- 当我说"review"时，对最近更改的文件运行 /code-review
- 当我说"status"时，显示 git 状态 + 冲刺进度
```

## 设置 (Setup)

1. 将此模板复制到项目根目录：`cp .claude/docs/CLAUDE-local-template.md CLAUDE.local.md`
2. 根据个人偏好编辑
3. 确认 `CLAUDE.local.md` 在 `.gitignore` 中（Claude Code 从项目根目录读取它）
