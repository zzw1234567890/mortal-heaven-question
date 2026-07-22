---
name: test-setup
description: "为项目引擎搭建测试框架和CI/CD管道。创建 tests/ 目录结构、特定于引擎的测试运行器配置和 GitHub Actions 工作流。在第一个冲刺开始前的技术设置阶段运行一次。"
argument-hint: "[force]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Bash, Write

---

# 测试设置 (Test Setup)


本技能为项目搭建自动化测试基础设施。它检测已配置的引擎，生成适当的测试运行器配置，创建标准的目录布局，并配置好 CI/CD，使测试在每次推送时运行。

在技术设置 (Technical Setup) 阶段运行此技能一次，在任何实现开始之前。在冲刺开始时安装的测试框架花费 30 分钟。在第四个冲刺时才安装的测试框架花费 3 个冲刺的代价。

**输出：** `tests/` 目录结构 + `.github/workflows/tests.yml`

---

## 阶段 1：检测引擎和现有状态 (Detect Engine and Existing State)

1. **读取引擎配置**：
   - 读取 `.claude/docs/technical-preferences.md` 并提取 `Engine:` 值。
   - 如果引擎未配置（`[TO BE CONFIGURED]`），停止：
     "引擎未配置。请先运行 `/setup-engine`，然后重新运行 `/test-setup`。"

2. **检查现有测试基础设施**：
   - 使用 Glob 搜索 `tests/` —— 目录是否存在？
   - 使用 Glob 搜索 `tests/unit/` 和 `tests/integration/` —— 子目录是否存在？
   - 使用 Glob 搜索 `.github/workflows/` —— CI 工作流文件是否存在？
   - 使用 Glob 搜索 `tests/gdunit4_runner.gd`（Godot）或 `tests/EditMode/`（Unity）或 `Source/Tests/`（Unreal）以查找引擎特定的产物。

3. **报告发现结果**：
   - "引擎： [engine]。测试目录： [found / not found]。CI 工作流： [found / not found]。"
   - 如果一切都已存在且 `force` 参数未传递：
     "测试基础设施似乎已就位。使用 `/test-setup force` 重新运行以重新生成。继续操作不会覆盖现有测试文件。"

如果传递了 `force` 参数，跳过"已存在"的提前退出并继续 —— 但仍然不覆盖已存在于给定路径的文件。仅创建缺失的文件。

---

## 阶段 2：呈现计划 (Present Plan)

根据检测到的引擎和现有状态，呈现一个计划：

```
## 测试设置计划 — [Engine]

我将创建以下内容（跳过任何已存在的）：

tests/
  unit/           — 用于公式、状态和逻辑的隔离单元测试
  integration/    — 跨系统测试和存档/读档往返测试
  smoke/          — 关键路径测试列表（15 分钟手动关卡）
  evidence/       — 截图和手动测试签核记录
  README.md       — 测试框架文档

[引擎特定的文件 — 见下方各引擎详情]

.github/workflows/tests.yml  — CI：在每次推送到 main 时运行测试

预计时间：创建所有文件约 5 分钟。
```

询问："我可以创建这些文件吗？我不会覆盖这些路径下已存在的任何测试文件。"

未经批准不得继续。

---

## 阶段 3：创建目录结构 (Create Directory Structure)

批准后，创建以下文件：

### `tests/README.md`

```markdown
# 测试基础设施 (Test Infrastructure)

**引擎 (Engine)**: [引擎名称 + 版本]
**测试框架 (Test Framework)**: [GdUnit4 | Unity Test Framework | UE Automation]
**CI**: `.github/workflows/tests.yml`
**设置日期 (Setup date)**: [date]

## 目录布局 (Directory Layout)

```
tests/
  unit/           # 隔离单元测试（公式、状态机、逻辑）
  integration/    # 跨系统和存档/读档测试
  smoke/          # /smoke-check 关卡的关键路径测试列表
  evidence/       # 截图日志和手动测试签核记录
```

## 运行测试 (Running Tests)

[引擎特定的命令 — 见下方]

## 测试命名 (Test Naming)

- **文件 (Files)**: `[system]_[feature]_test.[ext]`
- **函数 (Functions)**: `test_[scenario]_[expected]`
- **示例 (Example)**: `combat_damage_test.gd` → `test_base_attack_returns_expected_damage()`

## 故事类型 → 测试证据 (Story Type → Test Evidence)

| 故事类型 (Story Type) | 所需证据 (Required Evidence) | 位置 (Location) |
|---|---|---|
| 逻辑 (Logic) | 自动化单元测试 — 必须通过 | `tests/unit/[system]/` |
| 集成 (Integration) | 集成测试或试玩测试文档 | `tests/integration/[system]/` |
| 视觉/感受 (Visual/Feel) | 截图 + 主管签核 | `tests/evidence/` |
| UI | 手动演练或交互测试 | `tests/evidence/` |
| 配置/数据 (Config/Data) | 冒烟检查通过 | `production/qa/smoke-*.md` |

## 持续集成 (CI)

测试在每次推送到 `main` 和每个拉取请求时自动运行。失败的测试套件会阻止合并。
```

### 引擎特定的文件

#### Godot 4 (`Engine: Godot`)

创建 `tests/gdunit4_runner.gd`：

```gdscript
# GdUnit4 测试运行器 — 由 CI 和 /smoke-check 调用
# 用法：godot --headless --script tests/gdunit4_runner.gd
extends SceneTree

func _init() -> void:
    var runner := load("res://addons/gdunit4/GdUnitRunner.gd")
    if runner == null:
        push_error("GdUnit4 not found. Install via AssetLib or addons/.")
        quit(1)
        return
    var instance = runner.new()
    instance.run_tests()
    quit(0)
```

创建 `tests/unit/.gdignore_placeholder`，内容为：
`# 单元测试存放在这里 — 每个系统一个子目录（例如 tests/unit/combat/）`

创建 `tests/integration/.gdignore_placeholder`，内容为：
`# 集成测试存放在这里 — 每个系统一个子目录`

在自述文件中注明：**安装 GdUnit4**
```
1. 打开 Godot → AssetLib → 搜索"GdUnit4" → 下载并安装
2. 启用插件：项目 → 项目设置 → 插件 → GdUnit4 ✓
3. 重启编辑器
4. 验证：res://addons/gdunit4/ 存在
```

#### Unity (`Engine: Unity`)

创建 `tests/EditMode/` 占位文件 `tests/EditMode/README.md`：
```markdown
# 编辑模式测试 (Edit Mode Tests)
在不进入播放模式 (Play Mode) 的情况下运行的单元测试。
用于纯逻辑：公式、状态机、数据验证。
需要程序集定义：`tests/EditMode/EditModeTests.asmdef`
```

创建 `tests/PlayMode/README.md`：
```markdown
# 播放模式测试 (Play Mode Tests)
在真实游戏场景中运行的集成测试。
用于跨系统交互、物理和协程。
需要程序集定义：`tests/PlayMode/PlayModeTests.asmdef`
```

在自述文件中注明：**启用 Unity 测试框架**
```
Window → General → Test Runner
（Unity Test Framework 在 Unity 2019+ 中默认包含）
```

#### Unreal Engine (`Engine: Unreal` 或 `Engine: UE5`)

创建 `Source/Tests/README.md`：
```markdown
# Unreal 自动化测试 (Unreal Automation Tests)
测试使用 UE 自动化测试框架 (UE Automation Testing Framework)。
通过以下方式运行：Session Frontend → Automation → 选择"MyGame."测试
或使用无头模式：UnrealEditor -nullrhi -ExecCmds="Automation RunTests MyGame.; Quit"

测试类命名：F[SystemName]Test
测试类别命名："MyGame.[System].[Feature]"
```

---

## 阶段 4：创建 CI/CD 工作流 (Create CI/CD Workflow)

### Godot 4

创建 `.github/workflows/tests.yml`：

```yaml
name: Automated Tests

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    name: Run GdUnit4 Tests
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          lfs: true

      - name: Run GdUnit4 Tests
        uses: MikeSchulze/gdUnit4-action@v1
        with:
          godot-version: '[来自 docs/engine-reference/godot/VERSION.md 的版本]'
          paths: |
            tests/unit
            tests/integration
          report-name: test-results

      - name: Upload Test Results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: reports/
```

### Unity

创建 `.github/workflows/tests.yml`：

```yaml
name: Automated Tests

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    name: Run Unity Tests
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          lfs: true

      - name: Run Edit Mode Tests
        uses: game-ci/unity-test-runner@v4
        env:
          UNITY_LICENSE: ${{ secrets.UNITY_LICENSE }}
        with:
          testMode: editmode
          artifactsPath: test-results/editmode

      - name: Run Play Mode Tests
        uses: game-ci/unity-test-runner@v4
        env:
          UNITY_LICENSE: ${{ secrets.UNITY_LICENSE }}
        with:
          testMode: playmode
          artifactsPath: test-results/playmode

      - name: Upload Test Results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: test-results/
```

注意：Unity CI 需要 `UNITY_LICENSE` 密钥。在首次 CI 运行前将其添加到 GitHub 仓库密钥中。

### Unreal Engine

创建 `.github/workflows/tests.yml`：

```yaml
name: Automated Tests

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    name: Run UE Automation Tests
    runs-on: self-hosted  # UE 需要安装了编辑器的本地运行器

    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          lfs: true

      - name: Run Automation Tests
        run: |
          "$UE_EDITOR_PATH" "${{ github.workspace }}/[ProjectName].uproject" \
            -nullrhi -nosound \
            -ExecCmds="Automation RunTests MyGame.; Quit" \
            -log -unattended
        shell: bash

      - name: Upload Logs
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: test-logs
          path: Saved/Logs/
```

注意：UE CI 需要安装了 Unreal 编辑器的自托管运行器。在运行器上设置 `UE_EDITOR_PATH` 环境变量。

---

## 阶段 5：创建冒烟测试种子 (Create Smoke Test Seed)

创建 `tests/smoke/critical-paths.md`：

```markdown
# 冒烟测试：关键路径 (Smoke Test: Critical Paths)

**目的**：在任何质量保证交接前，在 15 分钟内运行这 10-15 项检查。
**运行方式**：`/smoke-check`（读取此文件）
**更新**：当新的核心系统实现时，添加新条目。

## 核心稳定性（始终运行）

1. 游戏启动到主菜单无崩溃
2. 可以从主菜单开始新游戏/会话
3. 主菜单对所有输入均有响应，无冻结

## 核心机制（每个冲刺更新）

<!-- 随着每个冲刺的实施，在此添加主要机制 -->
<!-- 例如："玩家可以移动、跳跃，并且摄像机正确跟随" -->
4. [主要机制 — 当第一个核心系统实现时更新]

## 数据完整性

5. 存档完成无错误（一旦存档系统实现）
6. 读档恢复正确状态（一旦读档系统实现）

## 性能

7. 在目标硬件上没有可见的帧率下降（目标 60fps）
8. 5 分钟游戏过程中无内存增长（一旦核心循环实现）
```

---

## 阶段 6：设置后总结 (Post-Setup Summary)

写入所有文件后，报告：

```
为 [engine] 创建的测试基础设施。

已创建的文件：
- tests/README.md
- tests/unit/（目录）
- tests/integration/（目录）
- tests/smoke/critical-paths.md
- tests/evidence/（目录）
[引擎特定的文件]
- .github/workflows/tests.yml

后续步骤：
1. [引擎特定的安装步骤，例如"通过 AssetLib 安装 GdUnit4"]
2. 编写您的第一个测试：创建 tests/unit/[first-system]/[system]_test.[ext]
3. 在您的第一个冲刺前运行 `/qa-plan sprint` 以分类故事并设置测试证据要求
4. 每次质量保证交接前运行 `/smoke-check`

关卡备注：/gate-check 技术设置 (Technical Setup) → 预制作 (Pre-Production) 现在需要：
- 带有 unit/ 和 integration/ 子目录的 tests/ 目录
- .github/workflows/tests.yml
- 至少一个示例测试文件
在推进之前运行 /test-setup 并编写一个示例测试。

裁定：**完成 (COMPLETE)** — 测试框架已搭建，CI/CD 已配置。
```

---

## 协作协议 (Collaborative Protocol)

- **绝不要覆盖现有的测试文件** — 仅创建缺失的文件。如果测试运行器文件已存在，保持原样。
- **始终在创建文件前询问** — 阶段 2 需要明确批准。
- **引擎检测不可协商** — 如果引擎未配置，停止并重定向到 `/setup-engine`。不要猜测。
- **`force` 标志跳过"已存在"的提前退出，但绝不要覆盖。** 它的意思是"即使目录已存在，也创建任何缺失的文件"。
- 对于 Unity CI，注意 `UNITY_LICENSE` 密钥必须手动配置。不要尝试自动化许可证管理。
