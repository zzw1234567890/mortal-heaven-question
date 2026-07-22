
# 引擎参考文档

本目录包含本项目所用游戏引擎的精选、版本锁定的文档快照。这些文件存在的原因是 **LLM 知识有截止日期**，而游戏引擎更新频繁。

## 为什么需要这些文件

Claude 的训练数据有一个知识截止日期（当前为 2025 年 5 月）。Godot、Unity、Unreal 等游戏引擎发布的更新会引入破坏性 API 变更、新特性以及被弃用的模式。如果没有这些参考文件，agent 会建议过时的代码。

## 结构

每个引擎有自己的目录：

```
<engine>/
├── VERSION.md              # 锁定的版本、验证日期、知识空白窗口
├── breaking-changes.md     # 各版本间的 API 变更，按风险等级组织
├── deprecated-apis.md      # "不要用 X → 改用 Y" 查找表
├── current-best-practices.md  # 模型训练数据中未包含的新实践
└── modules/                # 各子系统快速参考（每个不超过约 150 行）
    ├── rendering.md
    ├── physics.md
    └── ...
```

## Agent 如何使用这些文件

引擎专家 agent 被指示：

1. 阅读 `VERSION.md` 以确认当前引擎版本
2. 在建议任何引擎 API 之前先查阅 `deprecated-apis.md`
3. 针对版本相关的问题查阅 `breaking-changes.md`
4. 针对子系统相关工作阅读相关 `modules/*.md`

## 维护

### 何时更新

- 升级引擎版本之后
- LLM 模型更新时（新的知识截止日期）
- 运行 `/refresh-docs` 之后（如果可用）
- 当你发现某个 API 模型会搞错时

### 如何更新

1. 用新的引擎版本和日期更新 `VERSION.md`
2. 为该版本过渡向 `breaking-changes.md` 添加新条目
3. 将新弃用的 API 移入 `deprecated-apis.md`
4. 用新模式更新 `current-best-practices.md`
5. 用 API 变更更新相关 `modules/*.md`
6. 在所有修改过的文件上设置 "Last verified" 日期

### 质量规则

- 每个文件必须有一个 "Last verified: YYYY-MM-DD" 日期
- 模块文件保持在 150 行以内（上下文预算）
- 包含展示正确/错误模式的代码示例
- 链接到官方文档 URL 以供验证
- 只记录与模型训练数据不同的内容
