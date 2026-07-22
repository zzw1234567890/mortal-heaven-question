
# 文档目录


在本文档目录中创作或编辑文件时，请遵循以下标准。

## 架构决策记录 (`docs/architecture/`)

使用 ADR 模板：`.claude/docs/templates/architecture-decision-record.md`

**必填章节：** 标题 (Title)、状态 (Status)、背景 (Context)、决策 (Decision)、后果 (Consequences)、ADR 依赖 (ADR Dependencies)、引擎兼容性 (Engine Compatibility)、所应对的 GDD 需求 (GDD Requirements Addressed)

**状态生命周期 (Status lifecycle)：** `Proposed` → `Accepted` → `Superseded`
- 永不跳过 `Accepted` —— 引用处于 `Proposed` 状态 ADR 的故事将被自动阻断
- 使用 `/architecture-decision` 通过引导式流程创建 ADR

**TR 注册表 (TR Registry)：** `docs/architecture/tr-registry.yaml`
- 稳定的需求 ID（例如 `TR-MOV-001`），用于将 GDD 需求与故事关联
- 永不重新编号已存在的 ID —— 只能追加新 ID
- 由 `/architecture-review` 第 8 阶段更新

**控制清单 (Control Manifest)：** `docs/architecture/control-manifest.md`
- 面向程序员的扁平规则表：按层级列出 必须做 (Required) / 禁止做 (Forbidden) / 护栏 (Guardrails)
- 头部带有日期戳的 `Manifest Version:`
- 故事会嵌入此版本号；`/story-done` 会检查其是否过期

**验证：** 在完成一组 ADR 后运行 `/architecture-review`。

## 引擎参考 (`docs/engine-reference/`)

版本锁定的引擎 API 快照。**在使用任何引擎 API 之前，务必先查阅此处** —— LLM 的训练数据早于所锁定的引擎版本。

当前引擎：见 `docs/engine-reference/godot/VERSION.md`
