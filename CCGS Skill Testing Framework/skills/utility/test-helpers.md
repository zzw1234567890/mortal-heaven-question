# 技能测试规格：/test-helpers


## 技能概要

`/test-helpers` 为项目的测试套件生成引擎特定的测试辅助工具。辅助工具包括工厂函数（用于创建具有已知状态的测试实体）、测试夹具加载器、断言辅助工具以及外部依赖的模拟存根。生成的辅助工具遵循 `coding-standards.md` 中的命名和结构约定，并写入到 `tests/helpers/`。

每个辅助工具文件都需经过"我可以写入"的确认请求。如果辅助工具文件已存在，技能会提供扩展而非替换的选项。不适用任何主管闸门。当辅助工具文件写入完成后，判定结果为 COMPLETE。

---

## 静态断言（结构性）

由 `/skill-test static` 自动验证——无需测试夹具。

- [ ] 包含必需的元数据字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 包含 ≥2 个阶段标题
- [ ] 包含判定关键字：COMPLETE
- [ ] 在写入辅助工具前包含"我可以写入"协作协议语言
- [ ] 包含下一步交接（例如，使用生成的辅助工具编写测试）

---

## 主管闸门检查

无。`/test-helpers` 是一项搭建（scaffolding）实用技能。不适用任何主管闸门。

---

## 测试用例

### 用例 1：快乐路径 —— 为 Godot/GDScript 生成玩家工厂辅助工具

**测试夹具：**
- `technical-preferences.md` 的引擎为 Godot 4，语言为 GDScript
- `tests/` 目录存在（test-setup 已运行）
- `design/gdd/player.md` 存在，定义了玩家属性
- `tests/helpers/` 中无现有辅助工具

**输入：** `/test-helpers player-factory`

**预期行为：**
1. 技能读取引擎（Godot 4 / GDScript）和玩家 GDD 以获取属性上下文
2. 技能在 GDScript 中生成确定性的 `PlayerFactory` 辅助工具：
   - `create_player(health: int = 100, speed: float = 200.0)` 函数
   - 返回一个预先配置为已知状态的玩家节点
   - 使用依赖注入（无单例）
3. 技能询问"我可以写入 `tests/helpers/player_factory.gd` 吗？"
4. 批准后写入文件；判定结果为 COMPLETE

**断言：**
- [ ] 生成的辅助工具使用 GDScript（非 C# 或 Blueprint）
- [ ] 工厂函数参数使用与 GDD 值匹配的默认参数
- [ ] 辅助工具使用依赖注入（无 Autoload/单例引用）
- [ ] 文件名遵循 GDScript 的 snake_case 约定
- [ ] 判定结果为 COMPLETE

---

### 用例 2：无测试设置 —— 重定向到 /test-setup

**测试夹具：**
- `tests/` 目录不存在

**输入：** `/test-helpers player-factory`

**预期行为：**
1. 技能检查 `tests/` 目录——未找到
2. 技能报告："未找到测试目录——必须先设置测试框架"
3. 技能建议在生成辅助工具前运行 `/test-setup`
4. 不创建辅助工具文件

**断言：**
- [ ] 错误消息指明缺失的 tests/ 目录
- [ ] 建议 `/test-setup` 作为先决步骤
- [ ] 未调用写入工具
- [ ] 判定结果不为 COMPLETE（阻塞状态）

---

### 用例 3：辅助工具已存在 —— 提供扩展而非替换的选项

**测试夹具：**
- `tests/helpers/player_factory.gd` 已存在，包含 `create_player()` 函数
- 用户请求向工厂添加新的 `create_enemy()` 函数

**输入：** `/test-helpers enemy-factory`

**预期行为：**
1. 技能找到现有的 `player_factory.gd` 并检查它是否是应扩展的正确文件（或者是否应创建单独的 `enemy_factory.gd`）
2. 技能提供选项：将 `create_enemy()` 添加到现有工厂，或创建 `tests/helpers/enemy_factory.gd`
3. 用户选择扩展；技能起草 `create_enemy()` 函数
4. 技能询问"我可以扩展 `tests/helpers/player_factory.gd` 吗？"
5. 批准后添加函数；判定结果为 COMPLETE

**断言：**
- [ ] 检测到现有辅助工具并呈现给用户
- [ ] 用户被提供扩展 vs. 新建文件的选择
- [ ] 使用"我可以扩展"措辞（而非用于替换的"我可以写入"）
- [ ] 现有 `create_player()` 在扩展后的文件中得到保留
- [ ] 判定结果为 COMPLETE

---

### 用例 4：系统无 GDD —— 在辅助工具中注明缺失的设计上下文

**测试夹具：**
- `technical-preferences.md` 为 Godot 4 / GDScript
- `tests/` 存在
- 用户请求"库存系统"的辅助工具，但 `design/gdd/inventory.md` 不存在

**输入：** `/test-helpers inventory-factory`

**预期行为：**
1. 技能查找 `design/gdd/inventory.md`——未找到
2. 技能注明："未找到 inventory 的 GDD——使用占位符默认值生成辅助工具"
3. 技能生成 `inventory_factory.gd`，使用通用占位符值（item_count = 0, max_capacity = 20）和注释：`# TODO: align defaults with inventory GDD when written`（# 待办：编写库存 GDD 后对齐默认值）
4. 技能询问"我可以写入 `tests/helpers/inventory_factory.gd` 吗？"
5. 写入文件；判定结果为 COMPLETE，附带建议性说明

**断言：**
- [ ] 技能在没有 GDD 的情况下继续执行（不会阻塞）
- [ ] 生成的辅助工具具有占位符默认值和 TODO 注释
- [ ] 缺失 GDD 在输出中被注明（建议性警告）
- [ ] 判定结果为 COMPLETE

---

### 用例 5：主管闸门检查 —— 无闸门；test-helpers 是搭建实用技能

**测试夹具：**
- 引擎已配置，tests/ 存在

**输入：** `/test-helpers player-factory`

**预期行为：**
1. 技能生成并写入辅助工具文件
2. 不生成任何主管智能体
3. 输出中不出现闸门 ID

**断言：**
- [ ] 未调用主管闸门
- [ ] 无闸门跳过消息出现
- [ ] 判定结果为 COMPLETE，无闸门检查

---

## 协议合规性

- [ ] 在生成任何辅助工具前读取引擎（辅助工具是引擎特定的）
- [ ] 在有可用时读取 GDD 以获取默认值
- [ ] 注明缺失的 GDD 上下文而不是阻塞
- [ ] 检测现有辅助工具文件并提供扩展而非替换
- [ ] 在任何文件操作前询问"我可以写入"（或"我可以扩展"）
- [ ] 辅助工具写入后判定结果为 COMPLETE

---

## 覆盖说明

- 模拟/存根辅助工具生成（用于依赖项，如保存系统或音频总线）遵循与工厂辅助工具相同的模式，未单独测试。
- Unity C# 辅助工具生成（使用 NSubstitute 或自定义模拟）遵循与用例 1 相同的逻辑，输出适用于该语言。
- 请求的辅助工具类型无法识别的情况未测试；技能会要求用户澄清辅助工具类型。
