
# 示例会话：使用 /design-system 编写 GDD

**上下文：** 独立开发者，项目第 3 周。`/map-systems` 已运行并产出 `design/gdd/systems-index.md`。移动系统列为 MVP 级、Foundation 优先级。

**起始状态：**
- `design/gdd/game-concept.md` 存在（生存制造游戏，2D，Godot 4.6）
- `design/gdd/systems-index.md` 存在（识别 15 个系统，移动是设计顺序第一个）
- 尚无逐系统 GDD 编写
- 移动无上游依赖（它是基础）

**会话时长：** 约 60 分钟
**轮次：** 14
**结果：** 完整的 `design/gdd/movement-system.md`，全部 8 个必需章节已写入文件，可交付 `/design-review`

---

## 第 1 轮：用户调用技能

**User:**
> /design-system movement

## 第 2 轮：代理加载上下文并呈现计划

**Agent (game-designer, via /design-system):**
> 开始前加载上下文：
>
> - 读取 `design/gdd/game-concept.md` — 生存制造、重探索、孤身幸存者滞留外星行星
> - 读取 `design/gdd/systems-index.md` — 移动是 **Foundation / MVP**，无上游依赖，下游：combat、exploration、stamina
> - 未找到既有移动 GDD — 从头开始
>
> **技术可行性预检查：**
>
> | 领域 | 信号 |
> |--------|--------|
> | 引擎 | Godot 4.6 — CharacterBody2D with move_and_slide() 受良好支持 |
> | 物理 | Jolt 在 4.6 中现为默认 — 2D 移动不受影响，但未来 3D 工作需注意 |
> | 下游风险 | Stamina 系统列为下游依赖 — 移动必须暴露一个 stamina 回调钩子 |
>
> GDD 模板有 **8 个必需章节**。我们将逐一进行：
> `Overview → Player Fantasy → Detailed Rules → Formulas → Edge Cases → Dependencies → Tuning Knobs → Acceptance Criteria`
>
> 我会向你展示每节草稿，你批准或修改，然后我写入文件再继续下一节。
>
> 现在创建带空章节头的文件骨架——我可以写 `design/gdd/movement-system.md`（含占位符）吗？

**User:**
> 是的

**代理写入** `design/gdd/movement-system.md`，含 8 个空章节头。

---

## 第 3 轮：第 1 节 — Overview

**Agent:**
> **第 1 节草稿 — Overview：**
>
> > 移动系统是玩家与世界交互的主要界面。它支配孤身幸存者如何行走、奔跑、翻滚并穿越外星地形。移动基于物理——该行星重力高于地球，幸存者身体疲惫——但仍足够响应以不挡玩家之道。系统直接馈入探索节奏、战斗定位和 stamina 系统。
>
> 这捕捉了你想要的吗？

**User:**
> 不错，但加点关于地形的内容——表面会减慢你或具有摩擦修改器。

**Agent:**
> 修订：
>
> > 移动系统是玩家与世界交互的主要界面。它支配孤身幸存者如何行走、奔跑、翻滚并穿越外星地形。移动基于物理——该行星重力高于地球，幸存者身体疲惫——但仍足够响应以不挡玩家之道。地形表面施加摩擦和速度修改器（湿滑岩石、沙地、浅水），使导航成为一项有意义的技能。系统直接馈入探索节奏、战斗定位和 stamina 系统。
>
> 我可以把这写入文件中的第 1 节吗？

**User:**
> 是的

**代理将第 1 节写入文件。**

---

## 第 4 轮：第 2 节 — Player Fantasy

**Agent:**
> **第 2 节草稿 — Player Fantasy：**
>
> > 玩家应感觉像一个疲惫但有能力的幸存者——不是超级英雄，也不是无助。游戏早期移动是有意为之且消耗大的；玩家随时间获得流畅感。穿越外星地形时，目标是谨慎导航伴随紧迫时刻（逃离威胁、跃过缺口）。幻想是"我了解这片地形"——随着玩家内化摩擦系统，每种表面类型都变得可读且可驾驭。
>
> 批准、修订，还是改变方向？

**User:**
> 很喜欢。写吧。

**代理将第 2 节写入文件。**

---

## 第 5 轮：第 3 节 — Detailed Rules

**Agent:**
> **第 3 节草稿 — Detailed Rules：**
>
> > **Base States:**
> > - **Walk**（默认）：全方向控制，中等速度，低 stamina 消耗
> > - **Run**（按住 Shift）：更快，每秒中等 stamina 消耗——stamina 到 0 时自动取消
> > - **Roll/Dodge**（点按 Space）：朝移动方向快速冲刺，短暂无敌帧，高 stamina 成本（一次性）
> > - **Idle**：零移动输入，stamina 以全速恢复
> >
> > **Terrain Modifiers:**
> > - 普通地面：1.0x 速度倍率，标准摩擦
> > - 沙地/松土：0.8x 速度，1.1x stamina 消耗（更难移动）
> > - 湿滑岩石：1.1x 速度，降低停止摩擦（玩家过冲）
> > - 浅水（齐踝）：0.7x 速度，无摩擦修改
> > - 深水：移动禁用，由游泳取代（独立系统，超出范围）
> >
> > **Collision:**
> > - CharacterBody2D + move_and_slide()；启用墙滑
> > - 高达 45° 斜坡正常行走；>45° 阻挡
> > - 支持单向平台（Down + Jump 落下穿过）
>
> 这里内容不少——你想让我精简还是扩展什么？

**User:**
> 加一条：搬运重物（如大型资源块）时禁用奔跑。

**Agent:**
> 已加到 Run 规则：
> > - **Run**（按住 Shift）：更快，每秒中等 stamina 消耗——stamina 到 0 时自动取消。**搬运重物时禁用**（信号由 inventory 系统广播）。
>
> 写入文件？

**User:**
> 是的

**代理将第 3 节写入文件。**

---

## 第 6 轮：第 4 节 — Formulas

**Agent:**
> **第 4 节草稿 — Formulas：**
>
> 先定义变量，再给公式：
>
> | 变量 | 类型 | 描述 |
> |----------|------|-------------|
> | `base_walk_speed` | float | 基础行走速度，px/s（可调） |
> | `run_multiplier` | float | 奔跑速度 = 行走 × 此值 |
> | `terrain_speed_mod` | float | 按地形的倍率 (0.7–1.1) |
> | `stamina_drain_walk` | float | 行走时每秒 stamina 单位 |
> | `stamina_drain_run` | float | 奔跑时每秒 stamina 单位 |
> | `stamina_cost_roll` | float | 每次翻滚的固定 stamina 成本 |
> | `terrain_drain_mod` | float | 按地形的 stamina 消耗倍率 |
>
> **Effective Speed:**
> ```
> effective_speed = base_walk_speed × run_multiplier (if running, else 1.0) × terrain_speed_mod
> ```
>
> **Stamina Drain (per second):**
> ```
> drain_per_sec = stamina_drain_walk (or stamina_drain_run if running) × terrain_drain_mod
> ```
>
> **Roll Stamina Cost (flat):**
> ```
> stamina_after_roll = current_stamina - stamina_cost_roll
> (clamped to 0 — roll still executes, but player lands with 0 stamina)
> ```
>
> 批准还是调整变量名/公式？

**User:**
> 看起来对。写吧。

**代理将第 4 节写入文件。**

---

## 第 7-9 轮：第 5、6、7 节

*（这些遵循相同模式——代理起草，用户批准或请求小幅调整，代理在继续前将每节写入文件。此处略写。）*

**第 5 节 — Edge Cases** 涵盖：
- 玩家翻滚撞墙（动画完成，无移动加成）
- Stamina 在奔跑中到 0（过渡到行走，无突变）
- 两种地形类型重叠（取较低倍率）
- 湿滑岩石上翻滚（仍对停止施加湿滑摩擦，而非对翻滚本身）

**第 6 节 — Dependencies** 涵盖：
- **Stamina 系统**（下游）：移动暴露 `on_stamina_event(type: String, amount: float)` 信号
- **Inventory 系统**（下游）：监听 `carrying_heavy_object_changed(is_heavy: bool)` 信号
- **Input 系统**：移动方向来自 `InputMap`——标准 Godot 动作名（`ui_left`、`ui_right` 等）
- **Terrain 层**：tile 元数据驱动地形修改器查找

**第 7 节 — Tuning Knobs** 涵盖：
- `base_walk_speed`（默认：120 px/s）
- `run_multiplier`（默认：1.7）
- 按地形的速度和消耗修改器（4 种地形类型表）
- `stamina_drain_walk`、`stamina_drain_run`、`stamina_cost_roll`

---

## 第 10 轮：第 8 节 — Acceptance Criteria

**Agent:**
> **第 8 节草稿 — Acceptance Criteria：**
>
> 这些是证明此系统完成的可测试条件：
>
> - [ ] 玩家在普通地面以 `base_walk_speed` 行走（用 debug overlay 测量）
> - [ ] 玩家在普通地面以 `base_walk_speed × run_multiplier` 奔跑
> - [ ] stamina 到 0 时奔跑自动取消，无需输入
> - [ ] 翻滚以正确无敌帧执行（通过 hitbox debug 模式验证）
> - [ ] 每种地形类型施加正确速度修改器（sprint 计划中的 QA 表）
> - [ ] 搬运重物禁用奔跑（与 inventory 集成测试）
> - [ ] Stamina 系统在行走、奔跑和翻滚期间收到 `on_stamina_event` 信号
> - [ ] 所有移动值来自 exported 变量——代码中无硬编码数字
>
> 这涵盖了你所理解的"完成"吗？

**User:**
> 加一条关于斜坡的——确保 >45 度斜坡阻挡移动。

**Agent:**
> 已加：
> - [ ] ≤45° 斜坡正常穿越；>45° 斜坡阻挡移动（玩家滑回）
>
> 写入文件？

**User:**
> 是的。写吧。

**代理将第 8 节写入文件。**

---

## 第 11 轮：完成总结

**Agent:**
> 全部 8 节已写入 `design/gdd/movement-system.md`。
>
> **GDD 状态：**
> - ✅ Overview
> - ✅ Player Fantasy
> - ✅ Detailed Rules
> - ✅ Formulas
> - ✅ Edge Cases
> - ✅ Dependencies（暴露 2 个信号：stamina_event、carrying_heavy）
> - ✅ Tuning Knobs
> - ✅ Acceptance Criteria
>
> **做出的关键决策：**
> - 地形修改器作为 tile 元数据（非代码常量）
> - 翻滚有固定 stamina 成本（非按秒）
> - 重物搬运禁用奔跑（信号驱动，非硬编码检查）
>
> **推荐的下一步：** 在进入队列中下一个系统之前运行 `/design-review design/gdd/movement-system.md`（按系统索引，stamina 是依赖顺序中的下一个）。
>
> 评审将验证完整性、内部一致性，并捕捉任何需要修订之处，以便在你基于此 GDD 构建之前解决。

---

## 本示例展示的内容

- **增量文件写入**：每节批准后立即写入磁盘——会话崩溃最多丢失一个进行中的章节
- **模板填充**：GDD 模板的 8 个章节通过对话变为具体内容，而非批量生成
- **依赖信号化**：代理在 Dependencies 章节主动浮现下游信号契约（stamina、inventory）
- **技术可行性预检查**：代理在设计开始前而非实现崩溃后 noting Jolt 物理变更
- **逐节循环**：无一次性倾倒完整草稿——每节是一个小的、可审查单元
- **恢复**：若会话崩溃，代理在重启时重新读取文件并从第一个空章节恢复
