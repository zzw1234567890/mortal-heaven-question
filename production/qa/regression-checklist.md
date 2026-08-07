# 回归测试清单 (Regression Checklist)

本清单记录已知未覆盖的测试缺口，需在 release 候选构建中手动 QA 验证。

---

## Story 003 — CardSystem 模板注册表 + 异步加载

**日期**：2026-08-06
**来源**：Story 003 code-review（qa-tester S2）

### AC-010: THREAD_LOAD_FAILED + null 返回路径未覆盖

**缺口描述**：
`_process` 中的 `THREAD_LOAD_FAILED` 分支（[card_system.gd:69-71](file:///E:/mortal-heaven-question/src/core/card_system/card_system.gd)）与 `_validate_template` 的 null 检查（[card_system.gd:156-158](file:///E:/mortal-heaven-question/src/core/card_system/card_system.gd)）在 GUT 集成测试中无法确定性触发。Godot 的 `ResourceLoader.load_threaded_request` 在 headless GUT 模式下行为不确定——难以模拟文件损坏导致的 `THREAD_LOAD_FAILED` 状态或 `load_threaded_get` 返回 null。

**当前覆盖**：
- 非 CardTemplate 类型（普通 Resource）→ push_error ✓
- 空 card_id → push_error ✓
- 重复 card_id → push_error ✓

**未覆盖**：
- `load_threaded_get_status()` 返回 `THREAD_LOAD_FAILED` → push_error + 跳过
- `load_threaded_get()` 返回 null（文件损坏）→ push_error + 跳过
- `load_threaded_get_status()` 返回 `THREAD_LOAD_INVALID_RESOURCE` → push_error + 跳过（2026-08-06 LOW-1 修复后纳入失败分支）

**手动 QA 验证步骤**（release 候选构建）：
1. 在 `assets/cards/templates/` 中注入一个损坏的 `.tres` 文件（写入无效字节）
2. 启动游戏，观察控制台输出
3. 验证：
   - CardSystem 发射 `templates_loaded` 信号（count 不含损坏文件）
   - 控制台出现 `CardSystem: 加载失败` push_error 信息
   - 游戏不崩溃，其他模板正常加载
4. 移除损坏文件，验证恢复正常

**优先级**：MEDIUM（生产环境正确性，非 sprint 阻塞项）
