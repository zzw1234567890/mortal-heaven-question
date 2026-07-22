# 技能测试规格：/test-setup


## 技能概要

`/test-setup` 根据已配置的引擎搭建项目的测试框架。它创建 `coding-standards.md` 中定义的 `tests/` 目录结构（unit/、integration/、performance/、playtest/），并为检测到的引擎生成相应的测试运行器配置：Godot 的 GdUnit4 配置、Unity 的 Unity Test Runner asmdef，或 Unreal Engine 的 Unreal 无头运行器（headless runner）。

每个创建的文件或目录都需经过"我可以写入"的确认请求。如果测试框架已存在，技能会验证配置而非重新初始化。不适用任何主管闸门。当搭建完成后，判定结果为 COMPLETE。

---

## 静态断言（结构性）

由 `/skill-test static` 自动验证——无需测试夹具。

- [ ] 包含必需的元数据字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 包含 ≥2 个阶段标题
- [ ] 包含判定关键字：COMPLETE
- [ ] 在创建文件前包含"我可以写入"协作协议语言
- [ ] 包含下一步交接（例如，运行 `/test-helpers` 以生成辅助工具）

---

## 主管闸门检查

无。`/test-setup` 是一项搭建实用技能。不适用任何主管闸门。

---

## 测试用例

### 用例 1：快乐路径 —— Godot 项目，搭建 GdUnit4 测试结构

**测试夹具：**
- `technical-preferences.md` 的引擎设置为 Godot 4，语言为 GDScript
- `tests/` 目录尚不存在

**输入：** `/test-setup`

**预期行为：**
1. 技能从 `technical-preferences.md` 读取引擎 → Godot 4 + GDScript
2. 技能起草测试目录结构：tests/unit/、tests/integration/、tests/performance/、tests/playtest/，以及 GdUnit4 运行器配置文件
3. 技能询问"我可以写入 tests/ 目录结构吗？"
4. 批准后创建目录和 GdUnit4 运行器脚本
5. 技能确认运行器脚本与 coding-standards.md 中的 CI 命令一致：`godot --headless --script tests/gdunit4_runner.gd`
6. 判定结果为 COMPLETE

**断言：**
- [ ] 所有 4 个子目录（unit/、integration/、performance/、playtest/）均已创建
- [ ] 生成了 GdUnit4 运行器配置
- [ ] 运行器脚本路径与 coding-standards.md 的 CI 命令一致
- [ ] 在创建任何文件前询问了"我可以写入"
- [ ] 判定结果为 COMPLETE

---

### 用例 2：Unity 项目 —— 搭建含 asmdef 的 Unity Test Runner

**测试夹具：**
- `technical-preferences.md` 的引擎设置为 Unity，语言为 C#
- `tests/` 目录不存在

**输入：** `/test-setup`

**预期行为：**
1. 技能读取引擎 → Unity + C#
2. 技能以 Unity 约定创建 `Tests/` 目录（大写）
3. 技能生成 `Tests/Tests.asmdef` 和 `Tests/Editor/EditorTests.asmdef`
4. 配置 EditMode 和 PlayMode 测试运行器模式
5. 技能询问"我可以写入 Tests/ 目录结构吗？"
6. 判定结果为 COMPLETE

**断言：**
- [ ] 创建了 Unity 特定的 `Tests/` 结构（而非 Godot 结构）
- [ ] 生成了 `.asmdef` 文件
- [ ] 存在 EditMode 和 PlayMode 运行器配置
- [ ] 判定结果为 COMPLETE

---

### 用例 3：测试框架已存在 —— 验证配置，不重新初始化

**测试夹具：**
- `tests/unit/`、`tests/integration/` 存在
- GdUnit4 运行器脚本存在（Godot 项目）

**输入：** `/test-setup`

**预期行为：**
1. 技能检测到现有的 tests/ 结构
2. 技能报告："测试框架已存在——正在验证配置"
3. 技能检查：运行器脚本路径、目录完整性、CI 命令一致性
4. 如果所有检查通过：报告"配置已验证——无需更改"
5. 如果检查失败（例如，缺少 tests/performance/）：报告具体缺口并询问"我可以添加缺失的目录吗？"

**断言：**
- [ ] 框架存在时技能不会重新初始化
- [ ] 对现有结构执行验证检查
- [ ] 仅缺失部分会触发"我可以写入"的请求
- [ ] 无论一切正常还是缺口已修复，判定结果均为 COMPLETE

---

### 用例 4：未配置引擎 —— 重定向到 /setup-engine

**测试夹具：**
- `technical-preferences.md` 仅包含占位符（引擎未设置）

**输入：** `/test-setup`

**预期行为：**
1. 技能读取 `technical-preferences.md` 并发现引擎为占位符
2. 技能报告："引擎未配置——无法搭建引擎特定的测试框架"
3. 技能建议先运行 `/setup-engine`
4. 不创建任何目录或文件

**断言：**
- [ ] 错误消息明确指出引擎未配置
- [ ] 建议 `/setup-engine` 作为下一步
- [ ] 未调用写入工具
- [ ] 判定结果不为 COMPLETE（阻塞状态）

---

### 用例 5：主管闸门检查 —— 无闸门；test-setup 是搭建实用技能

**测试夹具：**
- 引擎已配置，tests/ 不存在

**输入：** `/test-setup`

**预期行为：**
1. 技能搭建并写入所有测试框架文件
2. 不生成任何主管智能体
3. 输出中不出现闸门 ID

**断言：**
- [ ] 未调用主管闸门
- [ ] 无闸门跳过消息出现
- [ ] 判定结果为 COMPLETE，无闸门检查

---

## 协议合规性

- [ ] 在生成任何搭建内容前从 `technical-preferences.md` 读取引擎
- [ ] 生成适合引擎的测试运行器配置（非通用）
- [ ] 创建 coding-standards.md 中所有 4 个子目录
- [ ] 在创建文件前询问"我可以写入"
- [ ] 检测现有框架并提供验证（而非重新初始化）
- [ ] 搭建完成后判定结果为 COMPLETE

---

## 覆盖说明

- Unreal Engine 测试搭建（使用 `-nullrhi` 的无头运行器）遵循与用例 1 和 2 相同的模式，未单独进行夹具测试。
- CI 集成文件生成（例如 `.github/workflows/test.yml`）虽被引用但在此未进行断言测试——这可能是一个单独的技能关注点。
- tests/ 存在但来自另一个引擎（例如，当前为 Godot 的项目中留有 Unity 测试）的情况未测试；技能会检测到不匹配并提供协调方案。
