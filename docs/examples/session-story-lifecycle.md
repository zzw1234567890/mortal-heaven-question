
# 示例会话：完整 Story 生命周期 — /story-readiness → 实现 → /story-done

**上下文：** 独立开发者，生产冲刺中期。移动系统 GDD 和架构已完成。一个用于移动核心实现的 story 已由 `/create-stories` 生成。

**起始状态：**
- `design/gdd/movement-system.md` — 完整，全部 8 节
- `docs/architecture/movement-adr-001.md` — Status: Accepted
- `production/sprints/sprint-03.md` — 待办中列出 STORY-MOV-001
- `production/stories/STORY-MOV-001.md` — 存在但尚未验证
- 尚无实现代码

**会话时长：** 约 50 分钟
**轮次：** 13
**结果：** Story 验证就绪、已实现、用 `/story-done` 验证完成

---

## 阶段 1：Story 就绪检查

### 第 1 轮：用户运行就绪检查

**User:**
> /story-readiness production/stories/STORY-MOV-001.md

### 第 2 轮：代理验证 Story

**Agent (via /story-readiness):**
> 读取 `production/stories/STORY-MOV-001.md`...
>
> **STORY-MOV-001: Implement CharacterBody2D movement with terrain modifiers**
>
> 运行 4 项验证检查：
>
> **1. 设计完整性**
> - 引用 GDD：`design/gdd/movement-system.md` ✅
> - GDD 章节覆盖：Detailed Rules ✅、Formulas ✅、Edge Cases ✅
> - 嵌入 TR-ID：TR-MOV-001 至 TR-MOV-008 ✅
>
> **2. 架构完整性**
> - 引用 ADR：`docs/architecture/movement-adr-001.md` ✅
> - ADR 状态：**Accepted** ✅ *（若为 Proposed 则会 BLOCKED）*
> - story 中的 control manifest 版本：`2026-03-10` — 当前 manifest 为 `2026-03-10` ✅
>
> **3. 范围清晰度**
> - 验收标准：9 项，全部可衡量 ✅
> - 超出范围项列出：游泳、攀爬 ✅
> - 发现的歧义：**1**
>   - ⚠️ story 说"翻滚方向跟随最后输入方向"但 GDD 说"沿移动方向翻滚"——当玩家停下并立即翻滚时两者冲突。取走前请澄清。
>
> **4. 完成定义**
> - 所需测试：公式函数的单元测试 ✅
> - 集成信号：`on_stamina_event` 必须正确触发 ✅
>
> ---
> **判定：NEEDS WORK**
>
> 一处歧义必须在实现开始前解决。你想现在解决以便我能将 story 标记为就绪吗？

### 第 3 轮：用户解决歧义

**User:**
> 翻滚使用最后移动方向。若玩家静止，翻滚使用朝向方向。

### 第 4 轮：代理更新 Story

**Agent:**
> 更新 story 的 Detailed Rules 章节：
>
> > 翻滚方向：最后移动方向。若翻滚输入时速度为零，翻滚使用当前朝向方向。
>
> 我可以写到 `production/stories/STORY-MOV-001.md` 并将 Status 设为 `ready-for-dev` 吗？

**User:**
> 是的

**代理写入更新。Story 状态：`ready-for-dev`。**

> **判定：READY**
> Story 已实现就绪。准备好构建时取走它。

---

## 阶段 2：实现

### 第 5 轮：用户开始实现

**User:**
> 让我们实现 STORY-MOV-001。我准备好开始编码。

### 第 6 轮：代理读取 Story 和 ADR

**Agent (gameplay-programmer):**
> 读取 `production/stories/STORY-MOV-001.md`、`design/gdd/movement-system.md` 和 `docs/architecture/movement-adr-001.md`...
>
> **架构（来自 ADR-001）：**
> - `MovementComponent.gd` — 附到 player 场景，非单例
> - 地形修改器查找通过 `TerrainLayer.get_modifier(tile_position)` 助手
> - Stamina 事件通过信号（非直接调用 StaminaSystem）
>
> **我提议的文件结构：**
> ```
> src/gameplay/movement/
>   movement_component.gd       # CharacterBody2D 逻辑、状态机
>   terrain_modifier_table.gd   # 常量表：terrain_type -> {speed_mod, drain_mod}
> tests/unit/
>   test_movement_formulas.gd   # 速度/消耗计算的单元测试
> ```
>
> 我可以按此结构继续吗？

**User:**
> 是的

### 第 7 轮：代理实现并展示关键代码

**Agent:**
> 实现 `movement_component.gd`。写入文件前供你审查的关键摘录：
>
> ```gdscript
> class_name MovementComponent
> extends Node
>
> signal stamina_event(type: String, amount: float)
>
> @export var base_walk_speed: float = 120.0
> @export var run_multiplier: float = 1.7
> @export var stamina_drain_walk: float = 2.0
> @export var stamina_drain_run: float = 6.0
> @export var stamina_cost_roll: float = 15.0
>
> var _is_carrying_heavy: bool = false
>
> func _physics_process(delta: float) -> void:
>     var terrain_mod := _get_terrain_modifier()
>     var effective_speed := _calculate_speed(terrain_mod)
>     # ...
> ```
>
> 所有值都是 `@export`——无硬编码。这是你想要的方向吗？

**User:**
> 看起来不错。写吧。

### 第 8-9 轮：代理写文件和测试

**代理写入：**
- `src/gameplay/movement/movement_component.gd`
- `src/gameplay/movement/terrain_modifier_table.gd`
- `tests/unit/test_movement_formulas.gd`

**Agent:**
> 文件已写入。运行可用的 lint 检查...
>
> 无错误。测试文件已创建，含 6 个单元测试覆盖：
> - 行走速度公式（3 种地形类型）
> - 奔跑速度公式
> - Stamina 消耗计算
> - 翻滚 stamina 成本（含和不带零速度边界情况）
>
> 手动测试需要：无敌帧、斜坡阻挡、地形集成（需运行场景）。

---

## 阶段 3：Story 完成

### 第 10 轮：用户手动测试并运行 /story-done

**User:**
> 我已在场景中测试——一切正常。/story-done production/stories/STORY-MOV-001.md

### 第 11 轮：代理运行完成评审

**Agent (via /story-done):**
> 读取 story、GDD、ADR...
>
> **阶段 1：Story 已定位** ✅ `production/stories/STORY-MOV-001.md`
>
> **阶段 2：验收标准验证**
>
> | # | 标准 | 验证 | 状态 |
> |---|-----------|--------------|--------|
> | 1 | 普通地面行走速度正确 | 自动：公式单元测试通过 | ✅ AUTO |
> | 2 | 奔跑速度正确 | 自动：公式单元测试通过 | ✅ AUTO |
> | 3 | stamina 到 0 时奔跑取消 | 手动：用户确认 | ✅ MANUAL |
> | 4 | 翻滚无敌帧工作 | 手动：用户确认 | ✅ MANUAL |
> | 5 | 地形修改器正确应用 | 手动：用户确认 | ✅ MANUAL |
> | 6 | 重物搬运禁用奔跑 | 自动：尚不可测（inventory 未集成） | ⏳ DEFERRED |
> | 7 | Stamina 信号正确触发 | 自动：集成测试待办 | ⏳ DEFERRED |
> | 8 | 无硬编码值 | 自动：grep magic numbers → 找到 0 | ✅ AUTO |
> | 9 | >45° 斜坡阻挡移动 | 手动：用户确认 | ✅ MANUAL |
>
> **阶段 3：GDD/ADR 偏离**
>
> 对照 TR-ID 扫描实现...
>
> - TR-MOV-001 至 TR-MOV-007：✅ 按规格实现
> - TR-MOV-008（重物搬运信号）：⚠️ ADVISORY——推迟到 inventory 集成 story。非偏离，只是现在不可验证。
>
> **阶段 4：Manifest 过时检查**
>
> Story control manifest 版本 `2026-03-10` 匹配当前 manifest `2026-03-10`。✅
>
> **阶段 5：代码评审提示**
>
> 建议在标记完成前运行 `/code-review src/gameplay/movement/`。非阻塞。
>
> ---
> **完成报告：COMPLETE WITH NOTES**
>
> Story 已完成。两条标准推迟到 inventory 集成——记为 deferred，非 blocked。
>
> 我可以将 story 状态更新为 `Status: Complete` 并添加 Completion Notes，以及更新 `production/sprint-status.yaml` 吗？

**User:**
> 是的

### 第 12 轮：代理关闭 Story

**代理写入：**
- Story `Status: Complete` + Completion Notes（推迟标准已注明）
- `production/sprint-status.yaml` — STORY-MOV-001 设为 `done`

**Agent:**
> STORY-MOV-001 已关闭。
>
> **推迟标准已记录**（将在 inventory 集成 story 中自动浮现）：
> - 重物搬运禁用奔跑（需 inventory 信号）
> - Stamina 信号集成测试（需 stamina 系统）
>
> **冲刺中下一个就绪 story：**
> - STORY-MOV-002：Stamina 系统——这是逻辑上的下一个 story（下游依赖现已解锁）
> - STORY-HUD-001：移动 HUD 指示器——也已解锁
>
> 对你接下来取走的任一个运行 `/story-readiness`。

---

## 本示例展示的内容

- **就绪闸门捕捉真实问题**：翻滚方向歧义若无 `/story-readiness` 会在实现晚期才引发决策
- **ADR 状态是硬闸门**：若 `movement-adr-001.md` 是 `Proposed` 而非 `Accepted`，story 会是 `BLOCKED`，实现不会开始
- **推迟标准**：并非每条验收标准都能在 story 关闭时验证——`/story-done` 跟踪推迟项而非阻塞完成
- **TR-ID 引用**：story 存储 `TR-MOV-001` ID，而非引用 GDD 文本——避免日后 GDD 措辞清理时的误报偏离标志
- **sprint-status.yaml**：sprint 状态的单一真相源，由 `/story-done` 更新，由 `/sprint-status` 读取
- **Manifest 版本检查**：确保 story 的实现指引未偏离当前架构决策
