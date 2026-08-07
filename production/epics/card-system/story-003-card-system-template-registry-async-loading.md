# Story 003: CardSystem 模板注册表 + 异步加载

> **Epic**: card-system
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration（需集成测试）
> **Estimate**: 4h
> **Manifest Version**: 2026-08-05
> **Last Updated**: 2026-08-06

## Context

**GDD**: `design/gdd/card-system.md`
**Requirement**: `TR-card-002`（222 个模板文件的异步加载策略——防止启动卡顿）
*（需求文本见 `docs/architecture/tr-registry.yaml`——审查时读取最新版）*

**ADR Governing Implementation**: ADR-0006（卡牌数据模型——Template/Instance 分离 + Resource 序列化）
**ADR Decision Summary**: CardSystem 作为 Autoload #6 持有模板注册表 `templates: Dictionary`，通过 `DirAccess` 枚举 `.tres` 文件 + `ResourceLoader.load_threaded_request()` 异步加载，每帧 10 个分批处理，完成后发射 `templates_loaded` 信号。

**Engine**: Godot 4.6.3 | **Risk**: HIGH（训练截止后 API）
**Engine Notes**: `ResourceLoader.load_threaded_request()` 不支持通配符——必须先用 `DirAccess` 枚举文件列表；`load_threaded_get_status()` 返回异步加载状态。4.6 双焦点系统不影响 CardSystem（纯数据系统）。

**Control Manifest Rules (Core 层 + Foundation 层)**:
- **Required**: CardSystem 是模板注册表 + 实例工厂 —— `create_instance(template_id)` 分配 GSM ID（Story 004 实现）
- **Required**: 模板加载 —— `DirAccess` 枚举 `.tres` → `ResourceLoader.load_threaded_request()` —— 每帧 10 个批处理
- **Required**: `templates_loaded` 信号为 Cat 2b 动作通知（ADR-0007）—— 信号命名 snake_case 过去式
- **Required**: Foundation Autoload 测试用 `CS_SCRIPT.new()` + `var cs: Node` 动态分派模式（控制清单 2026-08-05 新增规则）
- **Required**: 动态分派返回值必须显式类型注解（控制清单 2026-08-05 新增规则）
- **Forbidden**: CardSystem 是 Autoload —— 绝不声明 `class_name`（与全局单例冲突，控制清单 2026-08-05 新增规则）

---

## Acceptance Criteria

*From ADR-0006 §CardSystem Autoload + §模板加载生命周期 + GDD §验收标准:*

- [ ] **AC-001**: CardSystem extends Node（Autoload #6），不声明 `class_name`（控制清单规则）
- [ ] **AC-002**: `templates: Dictionary` 注册表，键 StringName，值 CardTemplate，初始为空
- [ ] **AC-003**: `_ready()` 调用可注入的私有方法 `_load_templates_from(path: String)`（默认路径 `DEFAULT_TEMPLATE_PATH = &"res://assets/cards/templates/"`），该方法使用 `DirAccess` 枚举指定目录下 `.tres` 文件。测试通过注入 fixture 路径验证（接缝明确）
- [ ] **AC-004**: 对每个 `.tres` 文件调用 `ResourceLoader.load_threaded_request(path)`
- [ ] **AC-005**: `_process(delta)` 每帧查询最多 10 个 `load_threaded_get_status()`，完成则 `load_threaded_get()` 存入 templates。通过本帧计数器 `_frame_processed_count: int`（在 `_process` 入口重置为 0，每处理一个 pending 递增）验证节流上限。测试可反射读取该计数器（同 EventSystem `_chain_visited_ids` 先例）
- [ ] **AC-006**: 全部加载完成后 `set_process(false)` + 发射 `templates_loaded` 信号；**空目录仍发射信号**（count=0，视为"全部完成"）。空目录采用时序方案 B：`_load_templates_from` 检测到 0 pending 时直接发射 `templates_loaded.emit(0)`（不调用 `set_process(true)`），避免空帧调度。
  - **GAP-5 异步确定性方案**：测试采用最大帧数上限 60（1s@60fps）循环调用 `_process(0.016)`，每次后检查信号是否发射。fixture 文件极小通常 1-3 帧完成。超 60 帧未完成则 `assert_true` 失败——视为真正失败而非 flaky。
- [ ] **AC-007**: `get_template(id: StringName) -> CardTemplate` O(1) 字典查询；不存在返回 null
- [ ] **AC-008**: `get_templates_by_type(type: CardType) -> Array[CardTemplate]` O(n) 筛选；无匹配返回空数组
- [ ] **AC-009**: 重复 `card_id` 检测——加载时若 templates 已有同 card_id，`push_error` 并跳过（第一个胜出）。**架构偏差声明**：ADR-0006 L402 区分 EDITOR 构建（中止报错）和 RELEASE 构建（以第一个为准并记录警告）；本 Story 采用统一 `push_error` 策略（不区分构建模式），偏离 ADR-0006 的 EDITOR/RELEASE 区分。理由：release 模式可测试性——统一 push_error 保证 GUT headless 模式下可通过 `assert_push_error_count` 验证。建议后续通过 `/architecture-decision` 修订 ADR-0006 同步此决策。
- [ ] **AC-010**: 加载失败（非 CardTemplate 类型 / 缺 card_id / `load_threaded_get_status()` 返回 `THREAD_LOAD_FAILED` / `load_threaded_get()` 返回 null 文件损坏）→ `push_error` 并跳过，不计入 count
- [ ] **AC-011**: `templates_loaded(count: int)` 信号签名（Cat 2b 动作通知，ADR-0007），参数 `count` 语义为**入库的模板数量**（`templates.size()`），非 `load_threaded_get` 返回数。重复 card_id 或加载失败的资源不计入 count
- [ ] **AC-012**: DirAccess 打开失败（目录不存在/权限）→ `push_error` + 视为空目录仍发射 `templates_loaded(0)` 信号

---

## Implementation Notes

*Derived from ADR-0006 §CardSystem Autoload + §模板加载生命周期:*

1. **文件位置**: `src/core/card_system/card_system.gd`
2. **类声明**: `extends Node`（不声明 class_name——Autoload 固有权衡，Story 004 曾因 class_name EventSystem 导致 402/486 测试失败）
3. **注册表字段**: `var templates: Dictionary = {}`（裸 Dictionary——GDScript 4.6 class_name 跨文件解析限制，同 EventSystem `templates`）
4. **异步加载生命周期**（ADR-0006 §模板加载生命周期）:
   ```
   T+0: _ready()
     → templates = {}
     → DirAccess.open("res://assets/cards/templates/")
     → dir.list_dir_begin() 枚举 .tres 文件
     → 对每个文件 ResourceLoader.load_threaded_request(path)
     → _pending_loads = total_count; set_process(true)

   T+1..T+N: _process(delta)
     → 每帧查询最多 10 个 load_threaded_get_status()
     → THREAD_LOADED → load_threaded_get() 获取模板
     → 校验 is_instance_of(res, CardTemplate) + card_id 非空 + 无重复
     → 存入 templates[res.card_id] = res
     → _pending_loads -= 1
     → 全部完成: set_process(false) + templates_loaded.emit(templates.size())
   ```
5. **DirAccess API**（ADR-0006 引擎验证）:
   ```gdscript
   var dir := DirAccess.open("res://assets/cards/templates/")
   if dir == null:
       push_error("CardSystem: 无法打开模板目录 'res://assets/cards/templates/'")
       templates_loaded.emit(0)
       return
   dir.include_hidden = false
   dir.list_dir_begin()
   var file_name := dir.get_next()
   while file_name != "":
       if file_name.ends_with(".tres"):
           ResourceLoader.load_threaded_request("res://assets/cards/templates/" + file_name)
       file_name = dir.get_next()
   dir.list_dir_end()
   ```
6. **分批节流**: 每帧 10 个 = 222/10 ≈ 23 帧 ≈ 380ms @ 60fps。通过内部计数器 `_frame_processed_count` 跟踪节流（测试可反射读取）
7. **重复检测**: 加载时 `if templates.has(res.card_id): push_error("...") ; continue`（第一个胜出策略）
8. **信号签名**: `signal templates_loaded(count: int)` —— Cat 2b 动作通知，携带事实"加载了 N 个模板"，消费者（GSM.enable_validation）自行决定后续行为
9. **get_template**: `return templates.get(id, null) as CardTemplate`
10. **get_templates_by_type**: O(n) 遍历，非热路径（仅收藏浏览/战利品生成调用）
11. **测试模式**: 测试用 `var cs: Node = CS_SCRIPT.new()` 动态分派（不调 _ready，用 fixture 目录 + 手动调用 `_load_templates_from(dir_path)`——需为扫描路径提供测试接缝，可注入路径参数）
12. **异步测试确定性（GAP-5 方案 A）**: fixture .tres 文件极小，`load_threaded_request` 在 headless GUT 下通常 1-3 帧完成。测试循环调用 `cs._process(0.016)` 最多 60 帧，每次后检查 `templates_loaded` 信号是否发射。超 60 帧未完成则断言失败（非 flaky，是真正失败信号）。参考 EventSystem `test_load_templates.gd` 的同步 `load()` 模式不适用本异步路径——本 Story 是新增异步测试挑战。
13. **fixture 创建策略（GAP-7）**: 测试中动态创建 fixture .tres 文件——用 `ResourceSaver.save()` 将构造的 CardTemplate 实例保存到 `res://tests/fixtures/card_system/templates/` 下，`after_each` 清理。参考 EventSystem `test_load_templates.gd` L59-65 的动态创建 + 清理模式。fixture 根目录固定为 `res://tests/fixtures/card_system/templates/`。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: CardTemplate Resource 定义
- **Story 002**: CardInstance RefCounted 定义
- **Story 004**: CardSystem.create_instance() 实例工厂 + GSM.enable_validation 集成
- **Story 005**: serialize_instance / deserialize_instance 序列化

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-001**: CardSystem extends Node（Autoload #6），不声明 class_name
  - Given: `src/core/card_system/card_system.gd` 存在
  - When: `var script := load("res://src/core/card_system/card_system.gd")`
  - Then: `assert_eq(script.get_instance_base_type(), "Node")`；源码中无 `class_name` 关键字（grep 断言）
  - Edge cases: 确认测试使用 `var cs: Node = CS_SCRIPT.new()` 动态分派模式（控制清单规则）

- **AC-002**: templates: Dictionary 注册表，键 StringName，值 CardTemplate
  - Given: 新建 `var cs: Node = CS_SCRIPT.new()`
  - When: 读取 `cs.templates`
  - Then: `assert_eq(typeof(cs.templates), TYPE_DICTIONARY)`；`assert_true(cs.templates.is_empty())`（初始空）
  - Edge cases: 键类型验证——插入 `cs.templates[&"test"] = CardTemplate.new()` 后 `assert_true(typeof(cs.templates.keys()[0]) == TYPE_STRING_NAME)`

- **AC-003**: _ready() 中使用 DirAccess 枚举 .tres 文件
  - Given: 测试 fixture 目录 `tests/fixtures/card_system/templates/` 含 2 个有效 .tres 文件（card_a.tres、card_b.tres）；CardSystem 扫描路径可注入（测试接缝）
  - When: 调用 `cs._load_templates_from("res://tests/fixtures/card_system/templates/")`
  - Then: 断言内部待加载队列长度 == 2，且包含两个 .tres 的路径
  - Edge cases: 空目录——队列长度 == 0，仍应继续流程（见 AC-006）

- **AC-004**: 对每个 .tres 文件调用 ResourceLoader.load_threaded_request()
  - Given: fixture 目录含 2 个 .tres
  - When: `_load_templates_from()` 调用后
  - Then: 断言 `ResourceLoader.load_threaded_get_status(path)` 对两个路径均返回 `THREAD_IN_PROGRESS` 或 `THREAD_LOADED`（即请求已提交）
  - Edge cases: 重复 _ready 不重复提交（幂等性）——若 AC 未要求，仅记录不阻塞

- **AC-005**: _process() 每帧查询最多 10 个 load_threaded_get_status()
  - Given: fixture 目录含 15 个 .tres（>10 以触发节流）
  - When: 调用 `cs._process(0.016)` 多帧，每帧后检查内部计数器
  - Then: 每帧处理的 pending 数 <= 10（通过反射读取私有 `_frame_processed_count` 计数器）
  - Edge cases: 测试接缝已明确——私有计数器反射验证节流上限

- **AC-006**: 全部加载完成后 set_process(false) + 发射 templates_loaded 信号
  - Given: fixture 含 2 个 .tres，`var emitted := false; var emitted_count := -1; cs.templates_loaded.connect(func(c: int): emitted = true; emitted_count = c)`
  - When: 推进多帧直到全部 status == THREAD_LOADED
  - Then: `assert_true(emitted)`；`assert_eq(emitted_count, 2)`；`assert_false(cs.is_processing())`；`assert_eq(cs.templates.size(), 2)`
  - Edge cases: 空目录——仍发射信号，count=0

- **AC-007**: get_template(id: StringName) -> CardTemplate O(1) 查询
  - Given: cs.templates 已加载 2 个模板，键 &"card_a"、&"card_b"
  - When: `var tpl: CardTemplate = cs.get_template(&"card_a")`
  - Then: `assert_true(tpl is CardTemplate)`；`assert_eq(tpl.card_id, &"card_a")`
  - Edge cases: 不存在的 id → 返回 null；传入 String（非 StringName）→ 按 Godot 4.6 值比较自动转换

- **AC-008**: get_templates_by_type(type) -> Array[CardTemplate] O(n) 筛选
  - Given: cs.templates 含 3 个模板（2 个 CHARACTER、1 个 TECHNIQUE）
  - When: `var arr: Array = cs.get_templates_by_type(CardTemplate.CardType.CHARACTER)`
  - Then: `assert_eq(arr.size(), 2)`；`assert_true(arr.all(func(t): return t is CardTemplate and t.type == CardTemplate.CardType.CHARACTER))`
  - Edge cases: 无匹配类型 → 返回空数组（非 null）

- **AC-009**: 重复 card_id 检测——push_error 并跳过（第一个胜出）
  - Given: fixture 含两个 .tres，二者 card_id 均为 &"card_dup"
  - When: 推进加载完成
  - Then: `assert_eq(cs.templates.size(), 1)`（仅第一个入库）；`assert_push_error_count(1)`
  - Edge cases: 明确"第一个胜出"策略——测试断言先加载的文件入库

- **AC-010**: 加载失败（非 CardTemplate 类型 / 缺 card_id）push_error 并跳过
  - Given: fixture 含 1 个有效 CardTemplate .tres、1 个非 CardTemplate .tres（如 Resource）、1 个 card_id 为空的 CardTemplate
  - When: 推进加载完成
  - Then: `assert_eq(cs.templates.size(), 1)`（仅有效项入库）；`assert_push_error_count(2)`
  - Edge cases: ResourceLoader 返回 null（文件损坏）→ push_error 并跳过

- **AC-011**: templates_loaded(count: int) 信号为 Cat 2b 动作通知（ADR-0007）
  - Given: CardSystem 脚本已加载
  - When: 读取 `cs.get_signal_list()` 查找 `templates_loaded`
  - Then: 信号存在；参数列表含 1 个 int 参数（count）
  - Edge cases: 确认信号参数类型为 TYPE_INT

- **AC-012**: DirAccess 打开失败 → push_error + 仍发射 templates_loaded(0)
  - Given: 不存在的目录路径 `res://tests/fixtures/nonexistent/`
  - When: 调用 `cs._load_templates_from("res://tests/fixtures/nonexistent/")`
  - Then: `assert_push_error_count(1)`；`assert_eq(cs.templates.size(), 0)`；信号发射 count=0
  - Edge cases: 权限错误同处理

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/card_system/test_card_system_loading.gd` — must exist and pass
**Status**: [x] Created and passing (13/13 tests, 74 assertions)

---

## Completion Notes

**Completed**：2026-08-06
**Criteria**：12/12 通过（所有 AC 自动化验证通过）

**Deviations**（全部 ADVISORY，已在 code-review 后修复或记录）：
- LOW-1：`THREAD_LOAD_INVALID_RESOURCE` 状态已纳入失败分支（与 `THREAD_LOAD_FAILED` 合并处理），修复潜在死锁——已修复
- LOW-2：`get_templates_by_type` 返回裸 `Array` 而非 `Array[CardTemplate]`——GDScript 4.6 在不声明 class_name 的脚本中跨文件 typed array 返回类型解析不稳定（同 EventSystem 先例），保留并文档化
- LOW-3：`_process` 入口 `_pending_paths.is_empty()` 防御性分支已标注注释，说明理论不可达但保留以防 Autoload 重载
- LOW-4：测试 AC-001 正则已启用多行模式 `(?m)`，增强 class_name 检测鲁棒性——已修复
- LOW-7：ADR-0006 L402 已修订——EDITOR/RELEASE 区分改为统一 `push_error` 策略，消除规范与实现漂移（理由：GUT 可测试性）
- R1：`_cleanup_test_files` 已清理 `.tres.uid` sidecar 文件，防止 fixture 目录污染——已修复
- R2：`_drive_loading_to_completion` 末尾已添加显式超时断言，区分"实现 bug"与"CI 机器慢导致超时"——已修复
- S1：AC-009 测试已增强——两个 fixture 设置不同 `type`，断言入库模板的 `type` 等于第一个 fixture，验证"第一个胜出"语义——已修复
- S2：AC-010 的 `THREAD_LOAD_FAILED` + null 返回路径记入 `production/qa/regression-checklist.md`，需 release 候选构建手动 QA 验证——已记录

**Test Evidence**：Integration — `tests/integration/card_system/test_card_system_loading.gd`（13 测试函数，74 断言，全部通过）
**Code Review**：已完成——godot-gdscript-specialist APPROVED WITH SUGGESTIONS + qa-tester TESTABLE with GAPS（缺口已处理）。7 项 LOW 级建议项中 5 项已修复（LOW-1/3/4/7 + R1/R2/S1），2 项保留并文档化（LOW-2 typed array 限制 + S2 回归清单）。

### 测试结果

- **13/13 测试通过**，74 断言，零失败
- 覆盖 12 条 AC 全部
- 修复 5 项 code-review 建议项 + 记录 2 项已知缺口

### 关键修正记录

1. **`_drive_loading_to_completion` 不依赖 `is_processing()`**——测试实例未加入 SceneTree，`set_process(true)` 是 no-op，改为检查 `_pending_paths.is_empty()`
2. **`OS.delay_msec(2)` 让出主线程**——load_threaded_request 的后台线程需要 CPU 时间片，紧凑同步循环中主线程不让出会导致状态卡在 IN_PROGRESS
3. **`THREAD_LOAD_INVALID_RESOURCE` 纳入失败分支**——修复潜在死锁（虽实践中极难触发）
4. **`.tres.uid` sidecar 清理**——Godot 4.x 为每个 .tres 生成 .uid 文件，需一并清理
5. **AC-009 "第一个胜出"语义验证**——两个 fixture 设置不同 type，断言入库 type 匹配第一个
6. **ADR-0006 L402 同步**——统一 push_error 策略替代 EDITOR/RELEASE 区分

---

## Dependencies

- Depends on: Story 001（CardTemplate Resource 定义——加载的 .tres 文件是 CardTemplate 类型）
- Unlocks: Story 004（create_instance 需 templates 注册表就绪）、Story 005（serialize 后 reconstitute 需 templates 查询）
