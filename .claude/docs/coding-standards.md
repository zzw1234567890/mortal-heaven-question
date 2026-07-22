
# 编码标准 (Coding Standards)

- 所有游戏代码必须包含公共 API 的文档注释
- 每个系统必须在 `docs/architecture/` 中有对应的架构决策记录 (ADR)
- 游戏数值必须是数据驱动的（外部配置），绝不硬编码
- 所有公共方法必须可进行单元测试（依赖注入优于单例）
- 提交必须引用相关的设计文档或任务 ID
- **提交信息 (Commit messages)**：使用 Conventional Commits 格式 — `feat:`、`fix:`、`chore:`、`docs:`、`test:`、`refactor:`。在正文中引用故事或任务 ID（例如 `Story: EPIC-001-S02`）。
- **验证驱动开发 (Verification-driven development)**：在添加游戏系统时先编写测试。
  对于 UI 变更，使用截图进行验证。在标记工作完成前比较预期输出与实际输出。
  每个实现都应有证明其正确性的方式。

# 设计文档标准 (Design Document Standards)

- 所有设计文档使用 Markdown
- 每个机制在 `design/gdd/` 中有专用文档
- 文档必须包含以下 8 个必需部分：
  1. **概述 (Overview)** —— 单段总结
  2. **玩家幻想 (Player Fantasy)** —— 预期感受和体验
  3. **详细规则 (Detailed Rules)** —— 明确的机制
  4. **公式 (Formulas)** —— 所有数学定义均含变量
  5. **边缘情况 (Edge Cases)** —— 处理的异常情况
  6. **依赖关系 (Dependencies)** —— 列出的其他系统
  7. **调优旋钮 (Tuning Knobs)** —— 标识的可配置值
  8. **验收标准 (Acceptance Criteria)** —— 可测试的成功条件
- 平衡数值必须链接到其来源公式或基本原理

# 测试标准 (Testing Standards)

## 按故事类型划分的测试证据 (Test Evidence by Story Type)

所有故事在标记为"完成"之前必须有适当的测试证据：

| 故事类型 (Story Type) | 所需证据 (Required Evidence) | 位置 (Location) | 关卡级别 (Gate Level) |
|---|---|---|---|
| **逻辑 (Logic)**（公式、AI、状态机） | 自动化单元测试——必须通过 | `tests/unit/[system]/` | 阻塞 (BLOCKING) |
| **集成 (Integration)**（多系统） | 集成测试或记录的试玩测试 | `tests/integration/[system]/` | 阻塞 (BLOCKING) |
| **视觉/感受 (Visual/Feel)**（动画、VFX、手感） | 截图 + 主管签字批准 | `production/qa/evidence/` | 建议 (ADVISORY) |
| **UI**（菜单、HUD、界面） | 手动演练文档或交互测试 | `production/qa/evidence/` | 建议 (ADVISORY) |
| **配置/数据 (Config/Data)**（平衡调优） | 冒烟检查通过 | `production/qa/smoke-[date].md` | 建议 (ADVISORY) |

## 自动化测试规则 (Automated Test Rules)

- **命名 (Naming)**：文件名为 `[system]_[feature]_test.[ext]`；函数名为 `test_[scenario]_[expected]`
- **确定性 (Determinism)**：每次运行必须产生相同结果——不能有随机种子，不能有时间依赖的断言
- **隔离性 (Isolation)**：每个测试自主设置和清理状态；测试不得依赖执行顺序
- **无硬编码数据 (No hardcoded data)**：测试夹具使用常量文件或工厂函数，而非内联魔数
  （例外：边界值测试中确切数字本身就是测试点的情况）
- **独立性 (Independence)**：单元测试不调用外部 API、数据库或文件 I/O——使用依赖注入

## 不应自动化的内容 (What NOT to Automate)

- 视觉保真度（着色器输出、VFX 外观、动画曲线）
- "手感"品质（输入响应性、感知重量、时机）
- 平台特定渲染（在目标硬件上测试，而非无头测试）
- 完整游戏会话（由试玩测试覆盖，非自动化）

## CI/CD 规则 (CI/CD Rules)

- 自动化测试套件在每次推送到 main 和每个 PR 时运行
- 如果测试失败则不合并——测试是 CI 中的阻塞关卡
- 绝不禁用或跳过失败的测试来使 CI 通过——修复根本问题
- 引擎特定的 CI 命令：
  - **Godot**：`godot --headless --script tests/gdunit4_runner.gd`
  - **Unity**：`game-ci/unity-test-runner@v4`（GitHub Actions）
  - **Unreal**：使用 `-nullrhi` 标志的无头运行器
