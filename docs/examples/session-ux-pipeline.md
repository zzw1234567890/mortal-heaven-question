
# 示例会话：UX 流水线 — /ux-design → /ux-review → /team-ui

**上下文：** 独立开发者，Pre-Production 阶段。HUD 和 inventory 界面是首批要设计的 UI。游戏有玩家旅程文档和 inventory、combat 的 GDD。

**起始状态：**
- `design/gdd/inventory-system.md` — 完整
- `design/gdd/combat-system.md` — 完整
- `design/player-journey.md` — 完整（定义了 6 阶段弧）
- 尚无 UX 规格
- `design/ux/` 目录不存在

**会话时长：** 约 90 分钟，跨两个会话（HUD 设计，然后 inventory 界面）
**轮次：** 16
**结果：** 创建并评审了 `design/ux/hud.md` 和 `design/ux/screens/inventory.md`；交接给 team-ui 进行视觉实现

---

## 第 1 部分：用 /ux-design 进行 HUD 设计

### 第 1 轮：用户开始 HUD 设计

**User:**
> /ux-design hud

### 第 2 轮：代理加载上下文并呈现方法

**Agent (ux-designer, via /ux-design):**
> 开始 HUD 设计。加载上下文...
>
> - `design/player-journey.md` 已读——关键状态：Calm Exploration、Tension（威胁检测）、Crisis（低 HP/stamina）、Combat
> - `design/gdd/combat-system.md` — HUD 需要：HP 条、stamina 条、主动能力冷却（最多 3 个）、伤害数字
> - `design/gdd/inventory-system.md` — HUD 需要：快捷栏（4 个槽位）、活动物品指示器
>
> **HUD 哲学问题：** 游玩时玩家的主要注意力焦点是什么？
>
> 这决定 HUD 应多激进：
> - **选项 A：Diegetic（低存在感）** — HP 仅在受损时显示，stamina 仅在消耗时显示。世界优先，HUD 除非紧急否则隐退。
> - **选项 B：Persistent minimal** — HP 和 stamina 总可见，小而不显眼。快速参考无需切换模式。
> - **选项 C：Full tactical** — 所有信息总可见（HP、stamina、冷却、地图、inventory 槽）。玩家总有完整感知。
>
> 鉴于你的生存游戏和"孤身幸存者"幻想，A 或 B 最符合类型惯例。

**User:**
> B——我希望它总在那但最小化。玩家总是在管理资源。

### 第 3 轮：代理起草 HUD 哲学章节

**Agent:**
> **HUD 哲学草稿：**
>
> > **方法：Persistent Minimal**
> > HUD 总可见但占用最小屏幕空间。玩家是资源管理型幸存者——拒绝 HP/stamina 可见性制造的是挫败而非紧张。所有关键属性可一眼读出而不打断探索焦点。元素在变紧急时增加视觉权重（HP 低于 30% 脉动，stamina 到 0 闪烁），然后回到最小状态。
>
> 我可以写到 `design/ux/hud.md` 作为 Philosophy 章节吗？

**User:**
> 是的

**代理创建 `design/ux/hud.md` 并写入 Philosophy 章节。**

*（第 4-7 轮继续逐节 HUD 编写：Info Architecture、Zones、Element Specs、State Machine、Visual Budget、Platform Adaptation——每节起草、批准并写入文件。）*

---

**所有章节后的最终 HUD 结构：**

```
design/ux/hud.md
  - Philosophy: Persistent Minimal
  - Info Architecture: HP (top-left), Stamina (top-left below HP), Quick Slots (bottom-center),
    Ability Cooldowns (bottom-right), Damage Numbers (world-space)
  - Zones: 4 defined (top-left vitals, bottom-center interaction, bottom-right abilities, world-space)
  - Element Specs: 6 elements with dimensions, font sizes, opacity rules
  - State Machine: Calm / Tension / Crisis / Combat (4 states, transition triggers)
  - Visual Budget: Max 8% screen coverage, 3 simultaneous animations
  - Platform Adaptation: Controller (aim reticle added), Mobile (out of scope v1)
```

---

## 第 2 部分：用 /ux-design 进行 Inventory 界面

### 第 8 轮：用户开始 Inventory 界面

**User:**
> /ux-design screen inventory

### 第 9 轮：代理扫描 GDD 和玩家旅程

**Agent:**
> 为 inventory 界面加载上下文...
>
> 来自 `design/gdd/inventory-system.md`：
> - 网格 inventory，6×8 槽位
> - 物品有重量（影响移动）和堆叠大小
> - 玩家可装备、丢弃、检视、拆分堆叠
>
> 来自 `design/player-journey.md`：
> - Inventory 在 Calm Exploration 期间频繁打开
> - 玩家打开 inventory 时应感到"井然有序且掌控之中"
> - 焦虑时刻："我需要决定丢什么"——应清晰，不慌乱
>
> **玩家需求（来自旅程）：** *我需要快速评估我携带了什么、决定保留或丢弃什么，然后回到世界。*
>
> **关键设计问题：** 玩家如何导航到 inventory 操作？
> - **选项 A：右键上下文菜单** — 悬停物品 → 右键 → 菜单出现（Escape/常见）
> - **选项 B：基于拖拽** — 拖到丢弃区丢弃；拖到装备槽装备（Stardew Valley）
> - **选项 C：检视面板** — 点击物品 → 右侧出现详情面板附操作按钮

**User:**
> B——基于拖拽。我想要触觉感。

*（第 10-12 轮继续逐节进行 inventory 界面规格：Player Need、Layout Zones、States、Interaction Map、Data Requirements、Events Fired、Accessibility、Localization。）*

---

## 第 3 部分：/ux-review

### 第 13 轮：用户运行评审

**User:**
> /ux-review design/ux/

### 第 14 轮：代理评审两份文档

**Agent (via /ux-review):**
> 评审 `design/ux/` 中所有 UX 规格...
>
> ---
> **HUD 评审 (`hud.md`)：**
>
> | 检查 | 状态 | 备注 |
> |-------|--------|-------|
> | GDD 对齐——所有必需元素在场 | ✅ | HP、stamina、快捷栏、冷却全部规格化 |
> | 状态机覆盖 | ✅ | 全部 4 种玩法状态覆盖 |
> | 可访问性层级 | ⚠️ | 未为 HP/stamina 条指定色盲模式（红/黄惯例） |
> | 视觉预算 | ✅ | 8% 屏幕覆盖，预算内 |
> | 平台备注 | ✅ | 控制器变体已记录 |
>
> **Inventory 界面评审 (`screens/inventory.md`)：**
>
> | 检查 | 状态 | 备注 |
> |-------|--------|-------|
> | 玩家需求已陈述 | ✅ | |
> | 所有 GDD 操作覆盖 | ✅ | 装备、丢弃、检视、拆分全在交互图中 |
> | 拖拽交互完整规格化 | ⚠️ | inventory 满时的丢弃目标行为未定义——怎么办？ |
> | 可访问性：拖拽的键盘替代 | ❌ | 缺失——仅拖拽无键盘路径不符合运动可访问性 |
> | 本地化：所有字符串已标记 | ✅ | |
> | 数据事件已触发 | ✅ | `item_equipped`、`item_dropped`、`stack_split` 全部映射 |
>
> ---
> **判定：NEEDS REVISION**
>
> 交接给 /team-ui 之前必须解决两个问题：
>
> 1. **BLOCKING（可访问性）：** Inventory 界面无拖拽的键盘替代。运动可访问性要求非拖拽交互路径。添加"按 X 拾取 / 再按 X 放置"切换，或带键盘可访问操作按钮的详情面板。
>
> 2. **ADVISORY（HUD）：** HP/stamina 条仅用颜色传达状态。为色盲用户添加次级指示器（形状、图标或图案）。可在视觉阶段解决。
> 3. **ADVISORY（Inventory）：** 满 inventory 丢弃行为未指定。在实现前于 GDD 解决，或记录为超出范围。

### 第 15 轮：用户解决阻塞问题

**User:**
> 键盘：按 F 拾取光标处物品，再按 F 于目标槽位放置。加到 inventory 规格。

**Agent:**
> 添加到 Interaction Map 的"Keyboard / Controller Path"下：
>
> > 按 F（或 South 按钮）拾取光标处物品。物品进入"held"状态并附视觉指示器。再按 F 于目标槽位放置。按 Escape 取消并归还物品。
>
> 我可以写到 `design/ux/screens/inventory.md` 并重跑可访问性检查吗？

**User:**
> 是的

**代理写入更新。重查可访问性——现通过。**

---

## 第 4 部分：交接给 /team-ui

### 第 16 轮：用户启动 Team UI

**User:**
> /team-ui

**Agent (via /team-ui):**
> 运行 UX 流水线上下文检查...
>
> - `design/ux/hud.md` — 已评审 ✅
> - `design/ux/screens/inventory.md` — 已评审 ✅
> - `/ux-review` 判定：NEEDS REVISION 已解决——当前状态：APPROVED ✅
>
> 进入 **阶段 2：视觉设计**
>
> 交接给 `art-director` 进行视觉规格（调色板、字体、图标体系对齐 art bible）...
>
> *（team-ui 继续通过视觉设计 → 布局实现 → 可访问性审计 → 最终评审）*

---

## 本示例展示的内容

- **上下文驱动设计**：代理读取 player-journey.md 将 HUD 决策建立在玩家情绪状态之上，而非仅功能清单
- **UX 评审是硬闸门**：`/team-ui` 在进入视觉设计前检查是否有通过的 `/ux-review`
- **可访问性早期捕捉**：缺失的键盘替代由评审标记，而非由 QA 测试员在最后一周发现
- **阻塞 vs. 建议**：缺失的键盘路径是 BLOCKING（阻止交接）；色盲颜色是 ADVISORY（可在视觉阶段修复）
- **逐节 UX 编写**：与 `/design-system` 相同的增量模式——每节在继续前写入文件
- **分离的 HUD 和界面文件**：`design/ux/hud.md` 是整局游戏的 HUD；逐屏规格位于 `design/ux/screens/`
- **由 /team-ui 强制的模式库**：此会话后，inventory 拖拽成为 `design/ux/interaction-patterns.md` 中的文档化模式，供所有未来界面引用
