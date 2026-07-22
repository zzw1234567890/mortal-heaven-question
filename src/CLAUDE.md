
# 源目录 (Source Directory)

在此目录中编写或编辑游戏代码时，请遵循以下标准。

## 引擎版本警告 (Engine Version Warning)

LLM 的训练数据早于项目锁定的引擎版本。
**在使用任何引擎 API 之前，务必查阅 `docs/engine-reference/`。**
不要猜测截止日期之后的 API 签名 —— 先查询确认。

## 编码标准 (Coding Standards)

- 所有公共 API 需要文档注释
- 游戏数值必须**数据驱动**（外部配置文件），绝不硬编码
- 为便于测试，优先使用依赖注入 (dependency injection) 而非单例 (singletons)
- 每个新系统需要在 `docs/architecture/` 中有对应的架构决策记录 (ADR)
- 提交必须引用相关的故事 ID 或设计文档

## 文件路由 (File Routing)

根据正在编写的文件类型匹配对应的引擎专家智能体 (engine-specialist agent)。
参见 `CLAUDE.md` → 技术偏好 → 引擎专家 → 文件扩展名路由。

如有疑问，使用 `CLAUDE.md` 中配置的主要引擎专家。

## 测试 (Tests)

测试位于 `tests/` 中 —— 而非 `src/` 中。
如果测试框架尚不存在，运行 `/test-setup` 来搭建。
每个游戏系统都应有覆盖其公式和边缘情况的单元测试。

## 验证驱动开发 (Verification-Driven Development)

在添加游戏系统时先编写测试。
对于 UI 变更，使用截图进行验证。
在标记工作完成前，比较预期输出与实际输出。
