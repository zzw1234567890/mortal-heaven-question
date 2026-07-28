# Story 005: 启动校验跳过模式 + enable_validation 激活流程

> **Epic**: 游戏状态管理器
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-07-26
> **Last Updated**: 2026-07-28

## 上下文

**GDD**: `design/gdd/game-state-manager.md`
**需求**: `TR-gsm-001`、`TR-gsm-002`

**管辖 ADR**: ADR-0001: 游戏状态管理器 — Autoload 单例 + 三层 API
**ADR 决策摘要**: GSM 以 `validation_enabled = false` 启动——在 CardSystem 调用 `enable_validation(db)` 之前，`add_card_to_collection()` 拒绝写入（返回 false + 日志警告）。CardSystem Autoload 在 `_ready()` 中加载模板库后调用 `GSM.enable_validation(card_template_database)` 开启校验，GSM 随后发射 `card_validation_ready`。

**引擎**: Godot 4.6 | **风险**: MEDIUM

**控制清单规则 (Foundation 层)**:
- 必需: 启动时校验跳过模式——GSM 以 `validation_enabled = false` 初始化；CardSystem 在模板加载后调用 `GSM.enable_validation(db)`（ADR-0001, ADR-0006）
- 禁止: 绝不直接写 GSM 属性——始终通过第二层原子方法（ADR-0001）
- 禁止: General-purpose `set(path, value)` 不可用于外部消费者（ADR-0001）

---

## 验收标准

*来自 GDD:*

- [x] **AC-020**: GIVEN 无效卡牌ID，WHEN 调用 `add_card_to_collection(invalid_id)`（校验开启后），THEN 拒绝写入，返回false
- [x] **AC-021**: GIVEN GSM 以 `validation_enabled = false` 启动，WHEN 在 `enable_validation()` 调用前执行 `add_card_to_collection(valid_id)`，THEN 拒绝写入，返回 false + 日志警告
- [x] **AC-022**: GIVEN CardSystem `_ready()` 加载模板库完成，WHEN 调用 `GSM.enable_validation(card_template_database)`，THEN `validation_enabled` 变为 true，发射 `card_validation_ready`，此后 `add_card_to_collection()` 执行引用完整性校验
- [x] **AC-023**: GIVEN `enable_validation()` 已调用一次，WHEN 再次调用，THEN 触发 `push_warning()` 但不重复初始化

---

## 实现说明

*来自 ADR-0001 实现指南:*

### 校验跳过模式（默认）

```
var validation_enabled: bool = false
var _card_template_database: Dictionary = {}

func _ready() -> void:
  # ... 初始化数据树 ...
  validation_enabled = false  # 明确设为 false
  _card_template_database = {}
  gsm_initialized.emit()
```

### enable_validation 激活流程

```
func enable_validation(card_template_database: Dictionary) → void:
  if validation_enabled:
    push_warning("enable_validation() called but validation already enabled — ignored")
    return

  if card_template_database.is_empty():
    push_error("enable_validation() called with empty database — validation NOT enabled")
    return

  _card_template_database = card_template_database
  validation_enabled = true
  card_validation_ready.emit()

  # 回溯校验：修复校验跳过期间可能已写入的卡牌数据
  _retroactive_validate_collection()
```

### 引用完整性校验

```
func _validate_card_ref(card_id: String) → bool:
  if not validation_enabled:
    push_warning("add_card_to_collection() called before card validation enabled — rejecting write")
    return false
  return card_id in _card_template_database
```

### add_card_to_collection 完整签名

```
func add_card_to_collection(inst_dict: Dictionary) → bool:
  if not validation_enabled:
    push_warning("add_card_to_collection() rejected: validation not enabled. " \
                 + "Call GSM.enable_validation() from CardSystem._ready() first.")
    return false

  var template_id: String = inst_dict.get("template_id", "")
  if not _validate_card_ref(template_id):
    push_error("add_card_to_collection() rejected: invalid template_id '%s'" % template_id)
    return false

  # ... 执行写入，发射 card_collection_changed 信号 ...
  return true
```

### 启动顺序合约

```
游戏启动 → Autoload 链按 project.godot 顺序执行:

① GSM._ready()       # validation_enabled=false，初始化数据树
② CardSystem._ready() # 加载 222 个 .tres 模板 -> 构建 templates 字典
                       # 调用 GSM.enable_validation(templates)
③ GSM 接收调用         # validation_enabled=true，发射 card_validation_ready
④ 其他 Autoload ready  # 此后可安全调用 add_card_to_collection()
```

---

## QA 测试用例

- **AC-020**: 无效卡牌 ID 被拒绝（校验开启后）
  - Given: `validation_enabled = true`，`_card_template_database` 包含 `{"card_001": ..., "card_002": ...}`
  - When: `GSM.add_card_to_collection({template_id: "invalid_card_999"})`
  - Then: 返回 false；`push_error()` 记录无效 template_id；`collection.owned_cards` 不变
  - 边界情况: `template_id` 为空字符串 -> 同样拒绝

- **AC-021**: 校验跳过模式下拒绝卡牌写入
  - Given: GSM 刚启动，`validation_enabled = false`
  - When: `GSM.add_card_to_collection({template_id: "card_001"})`
  - Then: 返回 false；`push_warning()` 提示"validation not enabled"；卡牌未添加到 collection
  - 边界情况: 校验跳过期间多次调用 -> 每次均警告 + 拒绝

- **AC-022**: enable_validation 正常激活
  - Given: `validation_enabled = false`，CardSystem 准备好 `{card_001: ..., card_002: ...}`
  - When: `GSM.enable_validation(card_db)`
  - Then: `validation_enabled == true`；`card_validation_ready` 信号发射；此后 `add_card_to_collection({template_id: "card_001"})` 成功返回 true
  - 边界情况: `card_db` 包含 222 个条目 -> 性能可接受

- **AC-023**: 重复调用 enable_validation 被拒绝
  - Given: `validation_enabled = true`（已激活）
  - When: 再次调用 `GSM.enable_validation(another_db)`
  - Then: `push_warning()` 记录"already enabled"；`_card_template_database` 不改变（保持第一次的值）；`validation_enabled` 仍为 true
  - 边界情况: 传入空字典 -> 同上，不覆盖

---

## 测试证据

**Story 类型**: Integration
**需要证据**: `tests/integration/gsm/validation_skip_and_enable_test.gd` — 必须存在且通过
**状态**: [x] 已创建——14/14 测试全部通过

**集成测试覆盖**:
- GSM `_ready()` 后 validation_enabled=false
- CardSystem `_ready()` 模拟调用 `enable_validation(db)`
- 调用前后 `add_card_to_collection` 的行为差异
- `card_validation_ready` 信号在激活后正确发射

---

## 依赖

- 依赖: Story 003（信号订阅层——`card_validation_ready` 信号声明在信号层）
- 依赖: Story 004（序列化——`add_card_to_collection` 写入影响序列化输出）
- 解锁: 无（GSM Epic 最后一个 Story）