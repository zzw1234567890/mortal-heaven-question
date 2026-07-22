
# 交互模式库 (Interaction Pattern Library)：[Game Title]

> **状态**：Draft | Stable | Under Revision
> **作者**：[ux-designer]
> **最后更新**：[Date]
> **版本**：[1.0]
> **引擎**：[Godot 4.6 / Unity 6 / Unreal Engine 5]
> **UI 框架**：[Godot Control nodes / Unity UI Toolkit / Unreal UMG]
> **相关文档**：
> - `design/art/art-bible.md` — 视觉标准（颜色、排版、图标）
> - `docs/accessibility-requirements.md` — 各功能的无障碍承诺
> - `docs/ux/ux-spec-[screen].md` — 引用模式的单个屏幕规格说明书

> **本文档的存在目的**：每个 UI 屏幕规格说明书应能说
> "使用按钮（主要）模式"，而非从头重新指定悬停状态、
> 按下动画、焦点行为、键盘处理以及屏幕阅读器
> 宣告。本模式库是可复用交互行为的唯一权威来源。
> 当屏幕规格说明引用某个模式名称时，
> 开发者在此查找。当行为变更时，只需在此处修改，
> 即可全局生效。
>
> 这是一份持续更新的文档。随着新屏幕的设计而添加模式 —
> 在未先查阅本文档前，请勿设计新的交互方式。如果需要新模式，
> 请在编写第一个使用该模式的屏幕规格说明书之前，将其添加至此（或向 ux-designer 提出建议）。
>
> **状态定义**：
> - **Draft（草稿）**：交互已定义但尚未实现或验证
> - **Stable（稳定）**：已在一个以上已发布屏幕中实现、测试并验证
> - **Deprecated（已弃用）**：正在逐步淘汰 — 现有使用将被迁移，新屏幕中请勿使用


---

## 如何使用本模式库

**如果你是屏幕设计师**：在构思新的交互方式之前，请先浏览下方的模式目录索引。当标准模式适用时，在屏幕规格说明中按名称引用（例如："确认按钮使用按钮（主要）模式"）。当没有现有模式适用时，请提议新模式 — 在此处记录，与引入该模式的屏幕规格说明同步或在其之前完成。

**如果你是屏幕实现者**：当屏幕规格说明中说"使用 [PatternName] 模式"，请在本文件中查找完整的规格说明。实现说明部分包含特定于引擎的指引。无障碍部分包含不可协商的要求。

**如果你是屏幕审查者**：验证所有交互元素是否引用了本模式库中的某个模式，或者包含了其自身的完整交互规格说明。"标准按钮"或"通常的方式"不是有效的引用形式。

**如果你正在更新某个模式**：更改一个 Stable（稳定）模式会影响使用它的每个屏幕。在更改之前，审计所有使用情况（在屏幕规格说明中搜索模式名称），确定影响范围，获得 ux-designer 的批准，并在任何实现变更之前或与之同步更新本文档。

---

## 模式目录索引 (Pattern Catalog Index)

> 每当你向本文档添加新模式时，请在此添加一行。
> "Used In"列为使用审计追踪 — 当新屏幕采用该模式时更新此列。

| Pattern Name | Category | Description | Used In (Screens) | Status |
|-------------|----------|-------------|------------------|--------|
| Button (Primary) | Input | 主要行动号召按钮。视觉权重高。每屏一个。 | [Main Menu, Pause Menu, Settings] | Draft |
| Button (Secondary) | Input | 备选操作或取消按钮。视觉权重低于 Primary。 | [All modal dialogs, settings screens] | Draft |
| Button (Destructive) | Input | 不可逆操作。执行前需确认。 | [Delete Save, Reset Settings] | Draft |
| Toggle | Input | 二进制开/关状态选择。 | [Accessibility settings, audio settings] | Draft |
| Slider | Input | 连续值选择。 | [Volume controls, brightness, text size] | Draft |
| Dropdown / Select | Input | 从离散选项列表中选择。 | [Resolution, language, key binding] | Draft |
| List Item | Layout / Input | 垂直可滚动列表中的可选行。 | [Achievements, quest log, settings list] | Draft |
| Grid Item | Layout / Input | 二维网格中的可选单元格。 | [Inventory, ability select, item shop] | Draft |
| Modal Dialog | Feedback / Layout | 阻止性覆盖层，需要玩家明确决策。 | [Confirmation dialogs, error prompts] | Draft |
| Confirmation Dialog | Feedback / Layout | 用于确认破坏性操作的特殊模态对话框。 | [Delete Save, Leave Match, Reset] | Draft |
| Toast / Notification | Feedback | 屏幕角落的非阻塞性临时消息。 | [Achievement unlock, autosave notification] | Draft |
| Tooltip | Feedback | 悬停或焦点上的上下文信息。 | [Inventory items, ability descriptions, settings] | Draft |
| Progress Bar | Feedback / Layout | 线性进度指示器。 | [Loading screen, XP bar, quest progress] | Draft |
| Input Field | Input | 文本输入控件。 | [Player name, search, key binding entry] | Draft |
| Tab Bar | Navigation | 单屏内的标签页式分节导航。 | [Character sheet, settings, crafting] | Draft |
| Scroll Container | Layout | 可滚动内容区域，带可见滚动指示器。 | [Inventory, lore entries, credits] | Draft |
| Inventory Slot | Game-Specific | 物品网格中的物品容器（空、已填充、已装备、已锁定）。 | [Inventory screen, equipment screen] | Draft |
| Ability / Skill Icon | Game-Specific | 具有冷却、充能和锁定状态的能力按钮。 | [HUD ability bar, skill tree] | Draft |
| Health / Resource Bar | Game-Specific | 带阈值状态和伤害闪光的数值条。 | [HUD] | Draft |
| Minimap | Game-Specific | 带有玩家标记和兴趣点的概览地图。 | [HUD] | Draft |
| Quest / Objective Tracker | Game-Specific | 显示活跃目标及其接近度和完成状态。 | [HUD] | Draft |
| Dialogue Box | Game-Specific | 带说话者标识的 NPC 对话界面。 | [All dialogue sequences] | Draft |
| Context Action Prompt | Game-Specific | 可交互物体附近显示上下文相关"按 X 进行[操作]"提示。 | [World interaction] | Draft |
| Damage Number | Game-Specific | 浮动战斗反馈数字。 | [Combat HUD] | Draft |
| Status Effect Icon | Game-Specific | 带持续时间的增益/减益指示器。 | [HUD status bar, enemy health display] | Draft |
| Notification Banner | Game-Specific | 成就、升级、获得物品通知。 | [Global overlay] | Draft |
| Screen Push | Navigation | 带有方向动画的前向导航。 | [All menu navigation] | Draft |
| Screen Pop (Back) | Navigation | 带有反向动画的后退导航。 | [All menu navigation] | Draft |
| Screen Replace | Navigation | 替换当前屏幕，不堆叠历史记录。 | [Main Menu to Loading Screen] | Draft |
| Modal Open / Close | Navigation | 使背景屏幕变暗的覆盖层。 | [All modal dialogs] | Draft |
| Tab Switch | Navigation | 标签页之间的同屏内容切换。 | [All tabbed screens] | Draft |
| Focus Management | Navigation | 屏幕打开、关闭或变化时焦点去向的规则。 | [All screens] | Draft |
| Escape / Cancel | Navigation | 跨平台和输入方式的通用返回行为。 | [All screens] | Draft |
| Loading State | Feedback | 屏幕和组件如何指示加载中。 | [All loading states] | Draft |
| Empty State | Feedback | 空列表和空网格的呈现方式。 | [Empty inventory, no quests, no saves] | Draft |
| Error State | Feedback | 错误信息的传达方式。 | [Save failed, network error, invalid input] | Draft |
| Success Confirmation | Feedback | 已完成操作的确认方式。 | [Settings saved, item crafted, quest turned in] | Draft |
| Optimistic UI | Feedback | 在系统确认前显示假定成功。 | [If online features are present] | Draft |

---

## 标准控件模式 (Standard Control Patterns)

---

#### Button (Primary)

**Category**：Input
**Status**：Draft
**何时使用**：屏幕上最重要的单一操作。"开始游戏"、"确认"、"接受"、"购买"。任何时候最多只能有一个 Primary 按钮可见。它的答案是"玩家最可能想在这里做什么？"
**何时不使用**：备选或次要操作；后果不可逆的破坏性操作需要先确认；任何不是屏幕主要意图的操作。

**交互规格说明**：

| State | Visual | Input | Response | Duration | Audio |
|-------|--------|-------|----------|----------|-------|
| Default | 全不透明度填充，使用 art-bible 中的主色。标签居中。 | — | — | — | — |
| Hovered (mouse) | 亮度 +15%，轻微缩放 1.03 倍，光标变为手型指针 | 鼠标悬停 | 从 Default 过渡 | 80ms ease-out | [UI 悬停音效 — 见声音标准] |
| Focused (keyboard/gamepad) | 焦点环可见（2px，偏移 3px，高对比色）。亮度与 Hovered 相同。 | Tab / 方向键导航 | 从 Default 过渡 | 80ms ease-out | [UI 焦点音效 — 与悬停相同] |
| Pressed | 缩放 0.97 倍，亮度 -10% | 点击 / Enter / A (Xbox) / Cross (PS) | 在释放时触发动作，而非按下时。按下时缩放。 | 按下 60ms ease-in；释放 80ms ease-out | [UI 确认音效] |
| Disabled | 40% 不透明度，无指针光标，无悬停状态 | — | 无响应 | — | — |
| Loading (post-press) | 将标签替换为旋转指示器。按钮保持按下缩放和禁用状态。 | — | 防止重复提交 | 异步操作时长 | — |

**无障碍**：
- 键盘：Tab 聚焦，Enter 或 Space 激活。必须能通过 Tab 顺序从屏幕上任何其他交互元素到达。
- 手柄：方向键或左摇杆导航焦点至按钮。A (Xbox) / Cross (PS) 激活。屏幕打开时，焦点默认放置在 Primary 按钮上。
- 屏幕阅读器：按钮必须暴露与可见标签匹配的可访问名称。角色："button"。禁用时状态："dimmed"。激活宣告："[Label] 按钮 — [操作结果，如已知]。"
- 色盲：不要仅靠颜色区分 Primary 与 Secondary。除了颜色区分外，Primary 还应使用更高视觉权重（填充 vs. 轮廓，或更大尺寸）。
- 最小触摸目标：44x44pt (iOS HIG) / 48x48dp (Android)。即使支持触摸的 PC 也应应用。

**实现说明**：
[Godot：继承 `Button` 控件。重写 `_draw()` 实现自定义状态，而非在中间修改主题。使用 `focus_mode = FOCUS_ALL` 确保键盘可聚焦性。设置 `mouse_default_cursor_shape = CURSOR_POINTING_HAND`。对于缩放动画，使用 Tween 操作按钮父级 Control 的 `scale` 属性 — 缩放 Button 本身可能导致子元素裁剪。]

---

#### Button (Secondary)

**Category**：Input
**Status**：Draft
**何时使用**：备选或取消操作。"返回"、"取消"、"跳过"、"稍后再说"。视觉权重低于 Primary — 它应在视觉上后退，而非竞争。
**何时不使用**：破坏性操作（使用 Button (Destructive)）。屏幕上最重要的操作（使用 Button (Primary)）。

**交互规格说明**：

| State | Visual | Input | Response | Duration | Audio |
|-------|--------|-------|----------|----------|-------|
| Default | 轮廓样式（仅边框，透明填充），次要色。略小于或低于 Primary 的视觉重量。 | — | — | — | — |
| Hovered | 背景填充以 15% 不透明度出现。边框变亮。缩放 1.02 倍。 | 鼠标悬停 | 从 Default 过渡 | 80ms ease-out | [UI 悬停音效 — 比 Primary 更柔和的变体] |
| Focused | 焦点环，规格与 Primary 相同。 | Tab / 方向键 | 从 Default 过渡 | 80ms ease-out | [UI 焦点音效] |
| Pressed | 缩放 0.97 倍，填充不透明度增至 30% | 点击 / Enter / B (Xbox) / Circle (PS) 在聚焦状态下 | 释放时触发动作 | 60ms ease-in | [UI 取消/返回音效] |
| Disabled | 40% 不透明度 | — | 无响应 | — | — |

**无障碍**：与 Button (Primary) 相同的要求。可访问名称必须匹配可见标签。在包含 Primary 和 Secondary 按钮的对话框中，Secondary 按钮通常映射到平台的"取消"输入（B / Circle / Escape）以及直接焦点激活。

**实现说明**：[同 Button (Primary)。当 Primary 与 Secondary 一起出现时，确保 Secondary 的位置始终一致 — 在水平布局中位于 Primary 的右侧/底部，或在垂直布局中位于 Primary 下方。跨屏幕的一致性比每个屏幕的美学偏好更重要。]

---

#### Button (Destructive)

**Category**：Input
**Status**：Draft
**何时使用**：任何不可逆且会导致玩家数据或重大进度丢失的操作："删除存档"、"重置所有设置"、"离开比赛"、"放弃更改"。视觉处理在玩家按下之前就发出危险信号。
**何时不使用**：可以撤销的操作，或者虽然重要但可逆的操作。

**交互规格说明**：

| State | Visual | Input | Response | Duration | Audio |
|-------|--------|-------|----------|----------|-------|
| Default | 轮廓或填充使用破坏性颜色（通常为降低饱和度的红色 — 在 accessibility-requirements 中确认色盲兼容性）。标签可包含警告图标。 | — | — | — | — |
| Hovered / Focused | 与 Button (Primary) 悬停/焦点行为相同，但使用破坏性颜色 | — | — | 80ms | [UI 悬停音效] |
| Pressed (first press) | 不执行操作。而是打开 Confirmation Dialog 模式（见下文）。按钮本身显示短暂的脉冲动画。 | 点击 / Enter | 触发确认对话框 | 100ms 脉冲 | [UI 警告音效 — 与标准确认音不同] |
| — | 确认对话框处理实际执行 | — | — | — | — |
| Disabled | 40% 不透明度 | — | 无响应 | — | — |

> **关键规则**：Button (Destructive) 绝不直接执行其操作。它总是触发确认对话框。没有例外。玩家如果意外按下，必须始终有再次退出机会。跳过确认步骤的破坏性操作会在所有 UX 失败类型中引发最明显的负面社区情绪。参见：每个游戏论坛上"意外删除存档"的投诉。

**无障碍**：屏幕阅读器必须宣告破坏性性质："[Label] 按钮 — 此操作不可撤销。"除可访问名称外，如果可用，使用 `description` 属性添加警告文本。

**实现说明**：[破坏性按钮触发一个单独的确认对话框场景。将操作回调传递给对话框 — 按钮本身不持有执行逻辑。这种分离防止了确认对话框出现错误时意外执行。]

---

#### Toggle

**Category**：Input
**Status**：Draft
**何时使用**：两种状态同等有效且当前状态必须一目了然的二进制开/关设置。"字幕：开/关"、"辅助瞄准：开/关"、"通知：开/关"。
**何时不使用**：超过两个选项的选择（使用 Dropdown）。一次性操作而非表示持续状态（使用 Button）。切换后果复杂到需要解释的情况（同时显示描述字段）。

**交互规格说明**：

| State | Visual | Input | Response | Duration | Audio |
|-------|--------|-------|----------|----------|-------|
| Off / Default | 轨道：暗淡填充。滑块：最左位置。标签："关"或状态标签。 | — | — | — | — |
| Hovered | 轨道亮度提升 10%。光标：手型。 | 鼠标悬停 | 过渡 | 60ms | [UI 悬停音效] |
| Focused | 整个切换元素的焦点环（轨道 + 滑块）。 | Tab / 方向键 | — | 60ms | [UI 焦点音效] |
| Pressed / Activated | 滑块滑至右侧。轨道填充变为激活色。标签变为"开"或激活状态标签。状态保持。 | 点击 / Enter / A / Cross | 切换状态变更。触发 onChange 事件。持久化值。 | 150ms ease-in-out 滑动 | [Toggle ON 音效] |
| Pressed / Deactivated | 滑块滑至左侧。轨道恢复为暗淡填充。 | 相同输入 | 切换状态变更 | 150ms ease-in-out | [Toggle OFF 音效 — 与 ON 略有不同] |
| Disabled | 40% 不透明度。无交互。当前状态仍可见。 | — | 无响应 | — | — |

**无障碍**：
- 键盘/手柄：Space 或 Enter 切换。避免使用方向输入（左/右）进行切换 — 有些用户无法预测该行为。
- 屏幕阅读器：角色："switch"。状态："on" 或 "off" — 可访问名称不应包含状态（屏幕阅读器单独宣告状态）。正确：可访问名称"字幕"，状态"on"。错误：可访问名称"字幕开启"。
- 切换标签（不仅是视觉滑块位置）必须随状态变化，为无法可靠区分左右位置的玩家显示当前状态。

**实现说明**：[Godot：使用自定义 Control 或 CheckButton。内置的 CheckButton 提供无障碍角色但使用复选框样式视觉；根据目标美术风格可能需要自定义滑动切换动画。确保在减少动态模式开启时跳过滑动动画 — 此时应直接跳至最终状态。]

---

#### Slider

**Category**：Input
**Status**：Draft
**何时使用**：从连续范围中选择一个值，近似值可接受，且范围和相对位置有意义的场景。音量（0-100%）、亮度、文字大小。位置的视觉呈现本身就是有用的信息。
**何时不使用**：精确数值输入（使用 Input Field）。从短列表中离散选择（使用 Dropdown）。二进制状态（使用 Toggle）。

**交互规格说明**：

| State | Visual | Input | Response | Duration | Audio |
|-------|--------|-------|----------|----------|-------|
| Default | 轨道（全宽）。填充（滑块左侧，显示当前值）。滑块（可拖动手柄）。当前值标签（轨道右侧或滑块上方）。 | — | — | — | — |
| Hovered | 滑块略微放大（1.2 倍）。轨道变亮。 | 鼠标悬停 | — | 60ms | — |
| Focused | 滑块上的焦点环。轨道变亮。 | Tab / 方向键 | — | 60ms | [UI 焦点音效] |
| Dragging (mouse) | 滑块跟随光标。填充实时更新。值标签实时更新。 | 点击 + 拖拽滑块 | 连续值更新。连续触发 onChange。 | 实时 | [Slider 调整音效 — 柔和，拖拽时循环] |
| Keyboard / D-pad adjust | 滑块每步移动（每次按下范围 5%，或 1 个离散单位）。 | 聚焦时左/右箭头键或左/右方向键 | 步进值变更。每步触发 onChange。 | 即时 | [Slider 步进音效 — 每步一次点击] |
| Keyboard fast adjust | 较大步进（范围的 25%）。 | 聚焦时 Page Up / Page Down | 大步值变更 | 即时 | [相同步进音效] |
| Released | 值锁定。onChange 触发最终值。 | 释放鼠标 | — | — | — |
| Disabled | 40% 不透明度。无交互。值可见。 | — | 无响应 | — | — |

**无障碍**：
- 键盘：左/右箭头键小步调整。Page Up/Page Down 大步调整。Home/End 跳至最小/最大值。
- 屏幕阅读器：角色："slider"。可访问名称：标签（例如"音乐音量"）。每次变更时宣告当前值："音乐音量，百分之八十"。首次聚焦时宣告最小/最大值。
- 所有滑块必须在视觉位置旁同时显示数值。仅依赖轨道填充位置会将无法感知相对位置的玩家排除在外。

**实现说明**：[Godot `HSlider`：将 `step` 设置为合适的增量。重写键盘输入，通过 `_input()` 添加 Page Up/Down 支持。绑定 `value_changed` 信号以更新显示的数值标签。当减少动态模式启用时，确保值标签更新是唯一的反馈 — 不要抑制它们。手柄滑块调整的震动反馈是无障碍方面不错的增强。]

---

#### Dropdown / Select

**Category**：Input
**Status**：Draft
**何时使用**：从 3-15 个选项的离散列表中选择，只需在静态时显示选中的值。显示分辨率、语言、窗口模式、输入预设。关闭状态仅显示当前选择。
**何时不使用**：二元选择（使用 Toggle）。超过约 15 个选项（使用完整的 List 模式或可滚动的 Select）。当比较选项与选择一个同样重要时（应将选项可见显示，如水平选择器或列表）。

**交互规格说明**：

| State | Visual | Input | Response | Duration | Audio |
|-------|--------|-------|----------|----------|-------|
| Closed / Default | 标签（左）。当前值（右）。向下箭头图标（最右）。 | — | — | — | — |
| Hovered | 行背景以 10% 不透明度填充 | 鼠标悬停 | — | 60ms | — |
| Focused (closed) | 整行的焦点环。 | Tab / 方向键 | — | 60ms | [UI 焦点音效] |
| Opening | 下拉列表出现在下方（如果靠近屏幕底部则在上方）。列表项可见。之前选中的项高亮显示。焦点移至列表中的选中项。 | 点击 / Enter / A / Cross | 打开列表 | 100ms ease-out (展开) | [UI 展开音效] |
| List item hovered/focused | 列表项高亮 | 鼠标 / 方向键 | — | 60ms | [UI 悬停音效] |
| List item selected | 列表关闭。关闭状态显示新值。触发 onChange 事件。 | 在项上点击 / Enter / A / Cross | 选择值，关闭列表 | 80ms ease-in (收起) | [UI 确认音效] |
| Dismissed without selecting | 列表关闭。值不变。 | Escape / B / Circle / 点击外部 | 关闭 | 80ms | [UI 取消音效] |
| Disabled | 40% 不透明度。无交互。 | — | — | — | — |

**无障碍**：
- 键盘：打开时上/下箭头键浏览列表项。Enter 选择。Escape 关闭。选项的首字母跳转焦点至第一个匹配项。
- 屏幕阅读器：角色："combobox"。可访问名称：字段标签。宣告展开/折叠状态。聚焦时宣告当前值。每个列表项宣告其值和位置："English, 第 1 项，共 12 项。"
- 下拉列表绝不能遮挡当前项或打开它的控件 — 这是小屏幕上常见的失败情况。

**实现说明**：[Godot：使用 `Button`（关闭状态）和由动画显示的 `PopupMenu` 或 `VBoxContainer` 实现自定义控件。原生 `OptionButton` 提供无障碍支持但视觉定制有限。确保弹出窗口在可能被屏幕底部裁剪时定位在控件上方。在 `_input` 检测到点击弹出窗口外部时关闭弹出窗口。]

---

#### List Item

**Category**：Layout / Input
**Status**：Draft
**何时使用**：垂直可滚动列表中的单个可选行。成就、任务日志条目、设置类别、存档槽位。列表是容器；此行是其中的行项。
**何时不使用**：物品存在于二维中的网格布局（使用 Grid Item）。不可选的内容行（移除去悬停/焦点状态和按下状态）。

**交互规格说明**：

| State | Visual | Input | Response | Duration | Audio |
|-------|--------|-------|----------|----------|-------|
| Default | 全宽行。图标（可选，左侧）。主标签。次要标签/元数据（右侧或主标签下方）。右箭头图标（右侧，如果需要更深层导航）。 | — | — | — | — |
| Hovered | 行背景 12% 不透明度高亮。 | 鼠标悬停 | — | 60ms | — |
| Focused | 行上的焦点环，或行背景 20% 不透明度（与平台惯例一致）。 | 方向键 / Tab | — | 60ms | [UI 焦点音效] |
| Selected (persistent) | 行背景 25% 不透明度。可显示选择指示器（左边框、勾选标记）。与焦点状态不同 — 行可以已选但未聚焦。 | — | 渲染状态 | — | — |
| Pressed / Activated | 短暂亮度闪动，然后导航或执行操作 | 点击 / Enter / A / Cross | 导航或操作 | 80ms 闪动 | [UI 确认音效] |
| Disabled | 40% 不透明度。无交互。 | — | — | — | — |

**无障碍**：
- 键盘/手柄：上/下箭头键或方向键在列表项间移动。列表必须处理焦点循环 — 到达底部应停止（不循环），除非明确设计了循环。
- 屏幕阅读器：角色："listitem"。父列表角色："list"。可访问名称：主标签内容。元数据（次要标签）可选地包含在描述中。位置宣告："任务日志，第 3 项，共 12 项。"
- 最小行高：触屏 44pt / 48dp。对手柄为主的平台，56px 行更舒适。

**实现说明**：[Godot：使用 `ScrollContainer` 内的 `VBoxContainer`。每行是一个自定义的 `Control` 或 `PanelContainer`，带 `_gui_input` 重写。对于滚动容器内的键盘导航，实现自定义焦点遍历 — Godot 默认的 Tab 导航不会滚动容器以保持聚焦项可见。在滚动容器上使用 `ensure_control_visible()`。]

---

#### Grid Item

**Category**：Layout / Input
**Status**：Draft
**何时使用**：二维网格中的可选单元格。物品栏槽位、能力选择、制作材料选择、角色头像选择。网格是容器；此为单元格。
**何时不使用**：单列内容（使用 List Item）。不可选的显示单元格（移除交互状态）。

**交互规格说明**：

| State | Visual | Input | Response | Duration | Audio |
|-------|--------|-------|----------|----------|-------|
| Empty | 空槽位视觉（细微边框或虚线轮廓）。与禁用不同。 | — | — | — | — |
| Populated | 物品图标填满单元格。堆叠数量（右下角，如适用）。品质指示器（边框颜色或图标覆盖层）。 | — | — | — | — |
| Hovered | 亮度 +15%。400ms 延迟后出现工具提示。 | 鼠标悬停 | — | 60ms | — |
| Focused | 焦点环（2px，偏移 2px）。亮度与悬停相同。400ms 延迟后出现工具提示，手柄则立即显示。 | 方向键导航 | — | 60ms | [UI 焦点音效] |
| Selected (persistent) | 明显边框（更粗，对比色）。可显示选择勾选标记。 | 点击 / Enter / A / Cross | 选择物品。可与不同单元格上的焦点状态共存。 | 即时 | [UI 选择音效] |
| Pressed | 短暂缩放 0.95 倍，然后执行操作 | 双击 / Enter / A / Cross | 操作（装备、使用、检视 — 由上下文定义） | 80ms | [UI 确认音效] |
| Locked | 内容上显示挂锁覆盖图标。无悬停/焦点状态。 | — | 无交互 | — | — |
| Drag source | 单元格变暗（50% 不透明度），拖拽预览出现在光标处。 | 点击 + 拖拽（仅限鼠标） | 开始拖拽操作 | 即时 | [UI 抓取音效] |
| Drop target (valid) | 单元格变亮，显示可接受的颜色指示器 | 物品拖过 | — | 60ms | — |
| Drop target (invalid) | 红色色调或抖动动画 | 物品拖过无效槽位 | — | 60ms | [UI 错误音效] |

**无障碍**：
- 键盘/手柄：方向键或箭头键导航单元格。网格必须向屏幕阅读器传达其尺寸。宣告行/列位置。
- 屏幕阅读器：角色："gridcell"。父角色："grid"。可访问名称：物品名称（空单元格则为"empty slot"）。状态：选中时为"selected"，锁定时为"dimmed"。位置："第 2 行，第 3 列。"
- 工具提示必须可通过键盘访问 — 单元格获得焦点时即应出现，而不仅限于悬停时。

**实现说明**：[Godot：使用固定列数的 `GridContainer`。每个单元格是自定义的 `Control`。通过重写 `_gui_input` 并根据索引和列数计算左/右/上/下方的单元格，实现自定义方向键导航。`GridContainer` 不原生提供此功能。]

---

#### Modal Dialog

**Category**：Feedback / Layout
**Status**：Draft
**何时使用**：玩家必须做出决定或确认后才能继续的情况。对话框是阻塞的 — 背景内容变暗且不可交互。"你确定吗？"、"你的进度将被保存。"、错误状态。
**何时不使用**：非阻塞通知（使用 Toast / Notification）。可以等玩家准备好了再查看的信息（改为添加到持久的帮助系统中）。应允许玩家在背后继续游戏的对话框。

**交互规格说明**：

| State | Visual | Input | Response | Duration | Audio |
|-------|--------|-------|----------|----------|-------|
| Opening | 背景覆盖层从 0% 动画至 60% 不透明度。对话框面板从 0.9 缩放至 1.0。对话框从中心进入（不从边缘）。 | 由代码触发 | 焦点移至对话框中的第一个交互元素（或 Primary 按钮） | 200ms ease-out | [UI 模态打开音效] |
| Active | 背景不可交互。对话框拥有所有输入焦点。玩家无法与背景交互。 | 键盘/手柄仅在对话框内导航 | — | — | — |
| Dismissing (confirmed) | 对话框面板缩放至 1.1 然后淡出。覆盖层淡出至 0%。 | Primary 按钮按下 | 执行操作，焦点返回触发元素 | 180ms | [UI 确认音效] |
| Dismissing (cancelled) | 对话框面板缩放至 0.9 然后淡出。覆盖层淡出至 0%。 | Secondary 按钮 / Escape / B / Circle | 无操作，焦点返回触发元素 | 150ms | [UI 取消音效] |
| Cannot dismiss | 如果对话框代表阻塞性错误，不提供取消路径。仅提供解决方案选项。 | — | — | — | — |

> **焦点陷阱规则**：当模态对话框打开时，Tab 和方向键导航只能在对话框的交互元素内循环。焦点绝不能导航到对话框外部的背景内容。这既是无障碍要求（WCAG 2.1 SC 2.1.2），也是 UX 完整性要求。当对话框关闭时，焦点必须返回到触发它的元素，而不是页面顶部。

**无障碍**：
- 屏幕阅读器：对话框容器角色："dialog"。可访问名称：对话框标题（必需 — 每个对话框必须有标题，即使是视觉上隐藏的）。打开时，屏幕阅读器宣告对话框标题和第一个可聚焦元素。焦点陷阱激活。
- 键盘：Escape 键始终映射到取消/关闭操作（与 Secondary 按钮或关闭按钮相同）。Enter 始终映射到主要/确认操作。
- 减少动态：缩放动画替换为即时出现/消失。覆盖层淡出保留但加速至 100ms。

**实现说明**：[Godot：实现为具有高图层值（100+）的 `CanvasLayer`，确保其渲染在所有游戏内容之上。背景覆盖层是全屏 `ColorRect`，60% 黑色不透明度。打开动画完成后，在对话框的 primary 按钮上使用 `grab_focus()`。重写 `_input()` 实现焦点陷阱 — 拦截 Tab 导航并重新路由至对话框的可聚焦元素。]

---

#### Confirmation Dialog

**Category**：Feedback / Layout
**Status**：Draft
**何时使用**：确认破坏性操作的特殊情况。总是由 Button (Destructive) 触发。总是恰好有两个选项：确认（标注具体操作，而非"OK"）和取消。
**何时不使用**：非破坏性确认。不需要做出决定的错误或通知。任何超过两个操作的对话框。

> **标签规则**：确认按钮必须标注具体操作，而非通用的"OK"或"是"。"删除存档"而非"OK"。"离开比赛"而非"是"。这减少了难以快速阅读对话框内容的玩家的失误。该模式来自 Apple HIG 并经过数十年可用性研究的验证。

**结构**：
- 标题：简短，描述操作。"删除存档？"而非"你确定吗？"
- 正文：一句话说明后果。"此操作无法撤销。"
- 确认按钮：Button (Primary) — 标注具体操作。"删除存档。"
- 取消按钮：Button (Secondary) — "取消。"
- 默认焦点：Cancel（更安全的默认 — 减少意外破坏性操作）。

**无障碍**：继承 Modal Dialog 的所有无障碍要求。此外：屏幕阅读器宣告"Alert dialog（警告对话框），[title]"以提示破坏性上下文。默认焦点在 Cancel 上是要求，而非偏好。

**实现说明**：[确认对话框是 Modal Dialog 的一个特定实例 — 将其实现为子类或参数化场景。默认焦点在 Cancel 上至关重要：在打开动画完成后，在 Cancel 按钮上设置 `grab_focus()`，而非 Confirm 按钮。]

---

#### Toast / Notification

**Category**：Feedback
**Status**：Draft
**何时使用**：简短、非阻塞的信息，不需要玩家做决定。"游戏已保存。"、"成就解锁。"、"你的物品栏已满。"玩家可以继续游戏；通知自动消失。
**何时不使用**：需要玩家做出决定的信息（使用 Modal Dialog）。需要玩家采取行动的错误。玩家绝不能错过的关键信息。

**交互规格说明**：

| State | Visual | Input | Response | Duration | Audio |
|-------|--------|-------|----------|----------|-------|
| Entering | 从屏幕边缘滑入（通常在右下角，远离主要操作区域）。从 0% 淡入至 100% 不透明度。 | 由代码触发 | — | 200ms ease-out | [与通知类型匹配的音效 — 见声音标准] |
| Displayed | 全不透明度。可选：图标（左）、标题、正文文本（可选）、关闭按钮（X，可选）。 | 指针悬停暂停自动关闭计时器 | 暂停自动关闭 | — | — |
| Auto-dismiss | 从 100% 淡出至 0% 不透明度，滑出 | 计时器到期（单行默认 5 秒；两行 8 秒） | 从队列中移除 | 200ms ease-in | — |
| Manual dismiss | 立即淡出并滑出 | 点击/轻触 X 按钮或在触屏上滑动 | 移除 | 150ms | [UI 取消音效，柔和] |
| Queue overflow | 新通知将最旧的提前挤出去 | 前一个显示时触发新通知 | FIFO 队列，最多同时显示 3 条 | — | — |

**无障碍**：
- 屏幕阅读器：Toast 必须无需焦点即可朗读。在 HTML 中使用 `role="status"` 或 `role="alert"`。在游戏 UI 中，这需要引擎的无障碍通知系统。在 engine-reference 文档中验证引擎支持。
- 减少动态：滑动动画仅替换为淡出效果。
- Toast 绝不能成为玩家需要操作的信息的唯一传达渠道。如果信息需要操作，在 toast 之外使用持久的 UI 元素。
- 自动关闭计时器：5 秒是最低要求。认知处理能力不同的玩家可能需要更多时间。考虑增加设置以延长至 10 或 15 秒。

**实现说明**：[Godot：管理一个锚定在屏幕角落的 `VBoxContainer` 中的 `PanelContainer` 场景队列。每个 toast 被实例化、添加到容器中，然后在计时器后自动移除。容器应位于高 `CanvasLayer`（50+）上，但低于模态对话框（100+）。使用 `Tween` 在 `modulate.a` 和 `position.x` 上设置动画。当减少动态模式激活时，跳过位置动画。]

---

#### Tooltip

**Category**：Feedback
**Status**：Draft
**何时使用**：补充可见标签的上下文信息。物品栏中的物品描述。角色属性面板上的状态说明。无障碍选项中的设置描述。玩家必须能访问此信息或在不查看的情况下继续。
**何时不使用**：玩家必须阅读才能完成操作的信息 — 将其放在标签或正文字体中，而非工具提示。在移动触屏上，工具提示在没有悬停状态的情况下无法发现。在仅触屏平台上，使用打开描述模态框的信息按钮代替。

**交互规格说明**：

| State | Visual | Input | Response | Duration | Audio |
|-------|--------|-------|----------|----------|-------|
| Hidden | — | — | — | — | — |
| Hover trigger | — | 鼠标进入元素 | 开始 400ms 延迟计时器 | — | — |
| Gamepad/keyboard trigger | — | 元素收到焦点 | 开始 300ms 延迟计时器（更短，因为导航是有意的） | — | — |
| Appearing | 工具提示面板淡入并从 0.95 缩放至 1.0。定位在元素附近（首选上方，靠近屏幕边缘时调整）。 | 计时器到期 | 显示工具提示 | 120ms ease-out | — |
| Displayed | 工具提示可见。标题（可选）。正文字体。最大宽度：300px。允许多行。 | — | — | — | — |
| Hiding | 工具提示淡出 | 鼠标离开元素 / 焦点移开 | 隐藏工具提示 | 80ms ease-in | — |

**无障碍**：
- 屏幕阅读器：工具提示内容必须无需悬停即可访问。父元素的可访问名称应包含最关键的提示信息。完整工具提示文本可选地放在 `description` 属性中。屏幕阅读器在元素聚焦时读取工具提示内容。
- 延迟（300-400ms）防止意外显示工具提示且是必需的 — 即时工具提示在手柄导航中具有破坏性。
- 工具提示文本必须满足与正文相同的对比度要求（最低 4.5:1）。

**实现说明**：[Godot：将自定义 `TooltipControl` 场景作为触发元素的子级附加。使用 `Timer` 节点显示/隐藏。使用 `CanvasLayer` 定位工具提示，确保其出现在所有其他 UI 之上。对于屏幕边缘，检测工具提示矩形是否超出 `get_viewport_rect()`，然后将位置翻转到相反侧。]

---

#### Progress Bar

**Category**：Feedback / Layout
**Status**：Draft
**何时使用**：朝向已定义终点的线性进度。加载屏幕（完成时间）、升下级所需的 XP 填充、具有可计数进度的任务目标（"已击败 10 个敌人中的 3 个"）、下载进度。
**何时不使用**：圆形或径向进度（如果需要，使用单独的 Radial Progress 模式）。快速上下波动的值（使用 Health/Resource Bar 模式）。没有定义终点的值。

**交互规格说明**：

| State | Visual | Input | Response | Duration | Audio |
|-------|--------|-------|----------|----------|-------|
| Default | 轨道（全宽，背景色）。填充（从左到右，值颜色）。值标签（百分比或 N/M，在填充外部或内部）。 | — | — | — | — |
| Value increasing | 填充宽度动画过渡到新值 | 值改变 | 平滑填充动画 | 300ms ease-out | [上下文相关 — XP 获得有音效；加载没有] |
| Value at maximum | 填充达到全宽。可选：完成动画（脉冲、发光）。 | 值达到 100% | 完成事件触发 | 200ms | [完成音效，如适用] |
| Value at zero | 填充隐藏（零宽度）。轨道仍然可见。 | — | — | — | — |
| Indeterminate (unknown duration) | 动画循环（填充段从左到右移动，重复）。用于未知时长的加载。 | — | — | 无限循环 | — |

**无障碍**：
- 屏幕阅读器：角色："progressbar"。可访问名称：正在推进的内容（例如"经验值"、"加载中"）。值：当前数值 AND 百分比 AND 最大值。"经验值，450 / 1000，百分之四十五。"在显著变化时更新（不是每个像素）。
- 不要仅依靠填充颜色来传达值。包含数值标签。
- 不确定进度条：宣告"加载中，进行中" — 由于值未知，不宣告变化。
- 减少动态：不确定动画替换为静态"加载"指示器。平滑填充动画替换为即时跳转到新值。

**实现说明**：[Godot：使用带自定义主题的内置 `ProgressBar`。对于不确定模式，Godot 4.x 的 `ProgressBar` 没有原生不确定状态 — 使用填充元素位置上的循环 `Tween` 实现。确保当减少动态模式激活时暂停 Tween 并显示静态指示器。]

---

#### Input Field

**Category**：Input
**Status**：Draft
**何时使用**：文本输入。新存档中的玩家名称、列表内搜索、重映射按键绑定（特殊情况 — 显示按键按下而非键入文本）、精确输入数值。
**何时不使用**：从已知选项中选择（使用 Dropdown 或 List）。在手柄为主的平台上，尽量减少文本输入 — 需要虚拟键盘，摩擦成本高。

**交互规格说明**：

| State | Visual | Input | Response | Duration | Audio |
|-------|--------|-------|----------|----------|-------|
| Default | 字段边框、占位符文本（标签样式，柔和颜色）、空输入区域。 | — | — | — | — |
| Hovered | 边框略微变亮 | 鼠标悬停 | — | 60ms | — |
| Focused | 边框完全变亮。光标（闪烁，530ms 开/530ms 关）。占位符文本隐藏。 | Tab / 点击 | 在主机/移动端打开虚拟键盘 | 即时 | [UI 焦点音效] |
| Typing | 字符出现。光标前进。 | 键盘输入 | 更新字段值 | 立即 | [细微击键音效，可选] |
| Value present | 字段显示键入的值。占位符隐藏。清除按钮出现（X，字段右侧），如果值非空。 | — | — | — | — |
| Character limit reached | 不再接受输入。可选：短暂抖动动画和限制指示器变色。 | 在限制时输入 | 拒绝更多字符 | 200ms 抖动 | [UI 错误音效，柔和] |
| Clear | 字段清空。光标返回。清除按钮消失。 | 点击 X / 手柄清除输入 | 清除值 | 即时 | [UI 取消音效，柔和] |
| Validation error | 边框变为错误颜色（红色 — 确保色盲安全）。错误信息出现在字段下方。 | 提交时或失焦时 | 显示错误 | 即时 | [UI 错误音效] |
| Validated / correct | 边框变为成功颜色（绿色 — 确保色盲安全）。可选成功图标。 | 验证通过时 | — | 即时 | — |
| Disabled | 40% 不透明度，无交互。值仍然可见。 | — | — | — | — |

**无障碍**：
- 键盘：所有标准文本编辑快捷键（Home、End、Ctrl+A、Ctrl+C、Ctrl+V、Ctrl+Z）。
- 屏幕阅读器：角色："textbox"。可访问名称：字段标签（而非占位符文本）。宣告当前值。达到字符限制时宣告。验证错误发生后立即宣告。
- 占位符文本不能作为唯一标签使用 — 必须在字段上方或旁边有一个可见标签。占位符文本在玩家输入时消失，会导致认知或记忆障碍玩家感到困惑。

**实现说明**：[Godot `LineEdit`：为提示设置 `placeholder_text`，但始终包含一个可见的 `Label` 节点作为字段的可访问名称。绑定 `text_changed` 信号进行实时验证。绑定 `text_submitted` 用于按 Enter 提交表单。在手柄上，使用 `LineEdit.call("_popup_keyboard")` 或 OS 虚拟键盘 API — 针对 Godot 4.6 主机键盘 API 细节验证 engine-reference/godot/。]

---

#### Tab Bar

**Category**：Navigation
**Status**：Draft
**何时使用**：将单个屏幕的内容划分为离散区域，一次只显示一个区域。角色属性面板标签页（属性 / 装备 / 技能）、设置标签页（游戏 / 图形 / 音频 / 无障碍）。最多 5-6 个标签页，超过后模式失效，应考虑侧边栏导航。
**何时不使用**：超过 6 个标签页。需要同时可见性的内容（使用布局模式）。不同屏幕之间的导航（使用 Screen Push）。

**交互规格说明**：

| State | Visual | Input | Response | Duration | Audio |
|-------|--------|-------|----------|----------|-------|
| Default (inactive tab) | 标签页标签。无激活指示器。 | — | — | — | — |
| Active tab | 标签页标签。激活指示器（下划线、填充或对比背景）。内容区域显示此标签页的内容。 | — | — | — | — |
| Hovered (inactive) | 标签页背景略微填充 | 鼠标悬停 | — | 60ms | — |
| Focused (keyboard/gamepad) | 标签页标签上的焦点环。 | 标签页行上的 Tab 键或左右方向键 | — | 60ms | [UI 焦点音效] |
| Activated | 激活指示器过渡至此标签页。内容区域过渡（淡出或滑动）。 | 点击 / Enter / A / Cross | 切换激活标签页。内容更新。 | 150ms ease | [UI 标签页切换音效] |
| Gamepad shoulder button | — | L1/R1 (PS) 或 LB/RB (Xbox) | 切换到上一个/下一个标签页（标准平台惯例） | 150ms | [UI 标签页切换音效] |

**无障碍**：
- 键盘：箭头键在标签栏内导航标签页（左/右）。Tab 键将焦点移入下方内容区域。这遵循 ARIA 标签面板模式。
- 屏幕阅读器：单个标签页角色："tab"。容器角色："tablist"。内容区域角色："tabpanel"。激活标签页状态："selected"。可访问名称：标签页标签。Tabpanel 由其对应的 tab 标签标识。
- 激活标签页必须通过颜色以外的视觉方式区分（除颜色外还应有下划线、填充图案或字体粗细变化）。

**实现说明**：[Godot：使用内置的 `TabContainer`。对于自定义视觉样式，使用标签按钮的 `HBoxContainer` 和用于内容的 `MarginContainer` 手动实现。肩部按钮快捷键（LB/RB）必须在屏幕的 `_input()` 重写中实现 — Godot 的标签系统中没有内置此功能。检查平台惯例：Xbox 使用 LB/RB；PlayStation 使用 L1/R1；两者是相同的物理按钮，因此一个绑定即可。]

---

#### Scroll Container

**Category**：Layout
**Status**：Draft
**何时使用**：内容超出容器可见区域的情况。物品列表、传说条目文本、演职员表、长设置列表。滚动指示器向玩家显示还有更多内容。
**何时不使用**：可以分页的内容（分页对于密集列表导航可能更清晰）。无限滚动（始终提供加载状态和结束状态）。

**交互规格说明**：

| State | Visual | Input | Response | Duration | Audio |
|-------|--------|-------|----------|----------|-------|
| Content fits | 无滚动条可见（或始终可见的滚动条处于完整高度，取决于美术方向）。 | — | — | — | — |
| Scrollable | 滚动条出现（右侧边缘）。滚动条滑块大小表示视口与内容的比例。 | — | — | — | — |
| Scrolling (mouse) | 内容移动。滚动条滑块按比例移动。 | 鼠标滚轮 | 每次滚轮刻度滚动 3 行（可在操作系统中配置） | 平滑 | — |
| Scrollbar drag | 内容移动。滑块跟随指针。 | 点击 + 拖拽滚动条滑块 | 按比例滚动 | 实时 | — |
| Keyboard scroll | 每次按键内容移动一项高度。 | 容器聚焦且无子项聚焦时的上/下箭头键 | 每次滚动一个单位 | 立即 | — |
| Gamepad scroll | 内容移动以保持聚焦项可见。 | 方向键导航至可见区域外的项目 | 自动滚动保持聚焦项可见 | 平滑 150ms | — |
| Scroll top / bottom | 内容停止。滚动条滑块到达末端。 | 达到内容边界 | 停止滚动 | — | — |
| Focus follows scroll | 当子元素获得焦点时，滚动容器确保其完全可见。 | 任意子项获得焦点 | 滚动以显示聚焦元素 | 200ms ease | — |

**无障碍**：
- 键盘/手柄：滚动容器本身不应需要显式的滚动条交互 — 在内部导航列表项应自动滚动以保持聚焦项可见。
- 屏幕阅读器：滚动容器宣告"scrollable（可滚动）"和滚动位置（"显示第 5 至第 15 项，共 30 项"）。这需要引擎的无障碍支持 — 在 engine-reference/godot/ 中验证。
- 淡出边缘（内容在滚动边界处淡出以指示存在更多内容）是有帮助的视觉提示，但不能作为内容存在于可见区域之外的唯一指示器。应包含滚动条。

**实现说明**：[Godot `ScrollContainer`：每当容器内的 `gui_focus_changed` 触发时，在聚焦的子项上调用 `ensure_control_visible()`。通过在容器的 `gui_focus_changed` 信号上递归 `connect` 来绑定此行为。对于平滑滚动动画，使用 `scroll_vertical` 上的 `Tween`，而非直接设置。]

---

## 游戏专用 UI 模式 (Game-Specific UI Patterns)

---

#### Inventory Slot

**Category**：Game-Specific
**Status**：Draft
**何时使用**：物品栏网格中的每个物品容器。空槽位、已填充槽位、已装备槽位、已锁定槽位。槽位是框架；物品图标是内容。

**状态**：

| State | Visual | Notes |
|-------|--------|-------|
| Empty | 细微的槽位边框，无内容。与禁用不同。空槽位是可交互的（接收物品）。 | 避免完全不可见的空槽位 — 玩家会失去对网格尺寸的追踪 |
| Populated | 物品图标填充槽位区域的 80%。堆叠数量右下角（如适用）。品质边框（色盲安全 — 图标 + 颜色）。已装备徽章（右上角，如已装备）。 | |
| Focused | 焦点环。300ms 后出现工具提示。 | |
| Selected | 更粗或对比色边框。用于支持多选时。 | |
| Drag source | 槽位变暗，拖拽幽灵跟随指针。 | 完整拖拽规格见 Grid Item |
| Locked | 挂锁图标覆盖。无交互。可在锁后以 50% 不透明度显示物品。 | 用于已锁定的装备槽、DLC 内容等。 |
| Highlighted | 动画边框发光（脉冲）。用于任务相关物品或新获得的物品。 | 尊重减少动态 — 用静态徽章替换脉冲 |
| Cooldown overlay | 从 12 点钟方向顺时针径向填充，随冷却结束而减少。 | 仅当槽位表示具有冷却的活跃物品时适用 |

**无障碍**：堆叠数量和质量等级必须有文本或图标替代方案，而非仅依赖颜色编码。工具提示是主要的无障碍机制 — 确保可通过键盘和屏幕阅读器访问。已锁定槽位必须向屏幕阅读器宣告"locked"。

**实现说明**：[Godot：自定义 `Control` 节点。品质边框实现为根据稀有度切换的 `StyleBoxFlat` — 避免使用 `modulate` 颜色表示品质，因为它会影响图标颜色。通过 `get_drag_data()` 和 `can_drop_data()` / `drop_data()` 重写方法实现拖放。]

---

#### Ability / Skill Icon

**Category**：Game-Specific
**Status**：Draft
**何时使用**：HUD 能力栏中的能力按钮、技能树节点以及任何需要能力显示可用状态的场景。

**状态**：

| State | Visual | Notes |
|-------|--------|-------|
| Available | 全不透明度图标。下方按键绑定标签。 | |
| On cooldown | 从 12 点钟方向顺时针减少的径向覆盖。剩余时间超过 2 秒时，在中心以数字显示。 | |
| Charges remaining | 图标下方的充能点数指示器（例如 3 个实心圆 = 3 次充能）。为屏幕阅读器提供数字替代方案。 | |
| Out of resource | 图标去饱和度至约 20%。边框变暗。按键绑定标签变暗。与冷却不同 — 受资源限制，而非时间限制。 | |
| Locked / not unlocked | 仅图标轮廓（无完整美术可见）。挂锁徽章。可在工具提示中显示解锁条件。 | |
| Active / channeling | 脉冲边框。径向填充显示引导剩余时间。 | |
| Just activated | 短暂缩放 0.9 倍，然后弹回至 1.0 倍（过冲至 1.05 倍）。 | 示例：《激战 2》和《流放之路》都在使用能力时使用按压-释放动画来确认激活。尊重减少动态。 |

**无障碍**：所有冷却/充能信息必须有数值（屏幕阅读器无法解析径向覆盖层）。冷却计时器数字满足此要求。能力名称和描述必须通过工具提示暴露给屏幕阅读器。

**实现说明**：[Godot：自定义 `TextureButton` 子类，带用于冷却径向和充能点的覆盖 `Control` 节点。冷却径向使用自定义着色器在 `ColorRect` 上旋转遮罩 — 或者如果引擎支持，使用样式化为圆形的 `ProgressBar` 实现。针对此模式，验证 engine-reference/godot/ 中 Godot 4.6 的着色器支持。]

---

#### Health / Resource Bar

**Category**：Game-Specific
**Status**：Draft
**何时使用**：HUD 中表示关键玩家资源的任何连续变化值。生命值、法力、耐力、护盾、燃料。

**状态和行为**：

| Event | Visual | Audio | Duration |
|-------|--------|-------|---------|
| Value decrease (damage) | 填充收缩。填充上短暂的"伤害闪光"（白色或红色闪光）。幽灵条停留在之前的值，并在 0.5 秒内逐渐消耗至新值（"伤害指示器"）。 | [受到伤害音效 — 根据伤害量变化] | 即时减少，500ms 幽灵条消耗 |
| Value increase (heal) | 填充增长。短暂治疗颜色闪光（绿色 — 确保色盲安全，附带图标/发光备用）。 | [治疗音效] | 300ms ease-in |
| Below 25% threshold | 填充变色为警告状态。边框脉冲（或在减少动态模式下静态徽章）。可选：心跳音频提示（如果音频是唯一信号，则与视觉配对）。 | [低血量音效 — 循环直到高于阈值] | 持续 |
| At zero | 条为空。可选：条短暂抖动。死亡/耗尽事件触发。 | [死亡/耗尽音效] | 200ms 抖动 |
| Maximum | 填充 100%，短暂发光。 | — | 200ms |
| Overflow (shield) | 护盾色的一条独立条段出现在自然填充区域之外。 | [护盾获得音效] | 200ms |

**无障碍**：当前值必须以数字形式可访问（工具提示或持久显示，或两者兼有）。颜色编码的阈值状态必须有非颜色备用方案（图标、闪烁或音频视觉警告）。25% 的警告状态必须有独立于颜色变化的视觉信号。

**实现说明**：[Godot：两个重叠的 `ProgressBar` 节点实现幽灵条效果 — 后条持有之前的值（通过 Tween 消耗），前条持有当前值（立即更新）。阈值状态触发前条上的 `StyleBoxFlat` 交换。幽灵条 Tween 时长可调，作为设计师参数。]

---

#### Dialogue Box

**Category**：Game-Specific
**Status**：Draft
**何时使用**：NPC 对话、有声叙事对话、通过角色传递的教学文本。所有有说话者的对话。

**结构**：说话者头像或名称标签（对话框顶部或左侧）。对话文本正文。继续/前进提示（右下角）。可选：全部跳过按钮、配音指示器、字幕指示器。

**状态和行为**：

| State | Visual | Input | Response | Duration |
|-------|--------|-------|----------|---------|
| Line entering | 文本逐字显示（打字机效果）。或者：如果设置了无障碍选项，文本以全速淡入。 | — | — | 速度：在无障碍设置中可配置 |
| Revealing | 文本动画显示中。继续提示隐藏或缓慢不透明度闪烁。 | [任意前进输入] | 立即跳到当前行末尾（显示完整行，停止打字机） | 立即 |
| Line complete | 完整行显示。继续提示可见并动画显示。 | — | — | — |
| Advancing to next line | 继续提示隐藏。文本淡出或擦除。新行开始。 | [任意前进输入] — Enter / A / Cross / Space / 鼠标点击 | 前进 | 100ms 过渡 |
| Choices appearing | 选择按钮出现在对话文本下方。继续提示隐藏。导航焦点移至第一个选项。 | 方向键/键盘选择，Enter / A / Cross 确认 | 选择选项 | 150ms 进入动画 |
| Closing | 对话框淡出 | 最后一行前进后 | 将控制权返回给玩家 | 200ms |
| Skipping all (if supported) | 简短确认提示："跳过对话？" | 专用跳过按钮 | 跳至对话后状态 | — |

**无障碍**：所有有声对话默认始终启用字幕。打字机动画速度是用户设置（见 accessibility-requirements.md）。对话框不得自动前进 — 玩家必须控制节奏。始终显示说话者名称。所有选择按钮必须可通过键盘和手柄导航。选择必须可供屏幕阅读器访问，并宣告位置。

**实现说明**：[Godot：使用启用了 `bbcode_enabled` 的 `RichTextLabel` 进行格式化。打字机效果通过由 `Timer` 动画化的 `visible_characters` 属性实现。将前进输入绑定到跳过打字机（设置 `visible_characters = -1`）或推进对话状态的函数。说话者名称显示在对话框上方或旁边的单独 `Label` 中。对话数据从 JSON 或专用对话格式（例如 Dialogic、Yarn Spinner for Godot）加载。]

---

#### Context Action Prompt

**Category**：Game-Specific
**Status**：Draft
**何时使用**：出现在可交互游戏对象附近，指示玩家可以做什么的提示。"按 [A] 打开宝箱。""按住 [E] 拾取。"当玩家进入交互区域时出现，离开时消失。

**状态**：

| State | Visual | Notes |
|-------|--------|-------|
| Appearing | 淡入并从物体锚点上升 8px。 | 尊重减少动态 — 仅淡出，无上升 |
| Idle | 平台正确的按钮图标 + 操作标签。图标匹配当前输入方式（玩家切换时更新）。 | 始终显示平台正确的图标 — 不要为所有平台硬编码"按 A" |
| Holding (for hold inputs) | 按钮图标上的径向填充显示按住进度。标签变为进行中动词（"打开中..."）。 | |
| Cannot interact (blocked) | 图标变暗。如果已知，标签显示原因（"太重了"、"需要钥匙"）。 | 可选 — 仅当原因对玩家有意义时才显示阻塞状态 |
| Disappearing | 淡出。 | 当玩家离开交互区域时触发 |

**无障碍**：按钮图标必须附有文本标签 — 不要仅依赖图标（有些玩家使用自定义按钮标签或带有非标准图标的自适应控制器）。提示必须定位为不与角色血量或关键 HUD 信息重叠。

**实现说明**：[Godot：作为可交互对象的 `Node3D` 子级（或 2D 中的 `Node2D` 子级）附加。对于 3D 游戏使用 `BillboardMesh` 或带有 UI 场景的 `SubViewport` — 这可使提示始终朝向摄像机而无需代码。根据 `Input.get_joy_name()` 或通过 `InputEventKey` 与 `InputEventJoypadButton` 检测键盘，更新按钮图标纹理。按住进度通过径向遮罩着色器上的 `AnimationPlayer` 或 `Tween` 实现。]

---

#### Damage Number

**Category**：Game-Specific
**Status**：Draft
**何时使用**：战斗参与者上方的浮动反馈数字。普通伤害、暴击伤害、治疗、未命中。

**变体**：

| Variant | Visual | Notes |
|---------|--------|-------|
| Normal damage | 白色数字，常规字重，中等大小。 | |
| Critical hit | 更大的尺寸（1.5 倍），粗体，橙色或黄色 — 验证色盲安全。出现时短暂缩放冲击（1.3 倍 → 1.0 倍）。 | 示例：《流放之路》和《暗黑破坏神 IV》都使用缩放弹出效果来表示暴击，使其仅凭大小而非颜色即可立刻识别。 |
| Healing | 绿色（验证色盲安全 — 使用 + 前缀和上升轨迹作为非颜色备用）。 | |
| Miss / Evade | "MISS"文本，灰色，斜体。以较小尺寸浮动。 | |
| Status damage (DoT) | 较小尺寸，与状态效果匹配的独特颜色。 | |

**行为**：数字从命中位置向上浮动 1.0 秒。数字在最后 0.4 秒内从 100% 淡出至 0%。快速命中产生的多个数字水平错开以避免重叠。屏幕上最大同时伤害数字数量：[按游戏定义 — 通常每个角色 8-12 个]。

**无障碍**：伤害数字纯粹是补充性反馈 — 绝不能是理解战斗状态的唯一途径。血量条是权威来源。提供完全禁用伤害数字的选项（有些玩家认为它们在视觉上过于杂乱）。禁用后，游戏必须仍可完全游玩。

**实现说明**：[Godot：通过对象池回收的 `Label3D`（3D 游戏）或 `Label`（2D 游戏）实例池。每个实例在生成时被赋予一个随机的小水平偏移（±20px）以减少重叠。通过 `Tween` 在 `position.y` 和 `modulate.a` 上实现浮动动画。暴击缩放弹出通过 Tween 配合 `EASE_OUT` 在缩放上实现，然后线性稳定。]

---

## 导航模式 (Navigation Patterns)

---

#### Screen Push / Pop / Replace

**Category**：Navigation
**Status**：Draft

这三种模式定义了屏幕如何进入和退出导航堆栈。

| Pattern | Trigger | Animation | Stack Behavior | Focus Behavior |
|---------|---------|-----------|---------------|----------------|
| Push | 向更深层导航（打开子菜单、打开详情视图） | 新屏幕从右侧滑入。前一个屏幕向左滑出并变暗。 | 前一个屏幕保留在堆栈中 | 焦点移至新屏幕上的第一个交互元素 |
| Pop (Back) | 返回按钮 / Escape / B / Circle | 当前屏幕向右滑出并退出。前一个屏幕从左侧滑入并变亮。 | 当前屏幕从堆栈中移除 | 焦点返回到触发 Push 的元素 |
| Replace | 导航到同级屏幕（非子级，非父级）。加载屏幕。 | 淡出当前屏幕，淡入新屏幕。无方向偏向。 | 当前屏幕移除。新屏幕添加。 | 焦点移至新屏幕上的第一个交互元素 |

**动画时长**：Push/Pop：250ms ease-in-out。Replace：200ms 淡出 + 200ms 淡入。

**减少动态**：所有滑动动画变为淡出效果。时长减少至 100ms。

**实现说明**：[Godot：实现为管理 `Control` 场景堆栈的 `ScreenManager` 单例。`push(screen_scene)` 实例化并动画进入。`pop()` 动画退出并释放。`replace(screen_scene)` 调用 pop 然后 push，跳过中间的堆栈状态。每屏使用 `CanvasLayer` 以隔离输入处理。在 push 前存储"返回焦点"元素引用，以便在 pop 时恢复。]

---

#### Focus Management

**Category**：Navigation
**Status**：Draft

> 焦点管理是游戏 UI 中最常见的键盘和手柄无障碍失败点。这些规则必须一致地执行。玩家绝不应处于无法看到哪个元素有焦点，或按 Tab/方向键无可见结果的状态。

| Rule | Description |
|------|-------------|
| Screen open | 焦点放置在最合理的交互元素上 — 典型为 Primary 按钮、第一个列表项，或如果屏幕之前被访问过则为最后聚焦的元素。绝不在非交互元素上。 |
| Screen close / pop | 焦点返回到触发导航的元素（打开屏幕的按钮、被选中的列表项）。如果该元素不再存在，焦点移至最近的先前交互元素。 |
| Modal open | 焦点被限制在模态框内。见 Modal Dialog 模式。 |
| Modal close | 焦点返回到触发模态框的元素。 |
| Element disabled | 如果聚焦的元素变为禁用，焦点移至 Tab 顺序中下一个可用的交互元素。 |
| Element destroyed | 如果聚焦的元素从场景中移除，焦点移至 Tab 顺序中最近的先前元素。 |
| Screen without interactive elements | 焦点管理为空操作。确保返回/取消输入仍然有效。 |
| Tab key (keyboard) | 按文档顺序（从左到右，从上到下）向前移动焦点到交互元素。Shift+Tab 向后移动。 |
| D-pad (gamepad) | 按按下的空间方向移动焦点。对于手柄，空间导航优先于严格的 Tab 顺序。绝不在无关区域之间循环焦点（例如，Tab bar 和内容区域应为单独的导航区域）。 |
| Focus is always visible | 当元素通过键盘或手柄聚焦时，焦点环或等效焦点指示器必须始终可见。绝不要隐藏焦点指示器。 |

---

#### Escape / Cancel

**Category**：Navigation
**Status**：Draft

> "返回"操作是所有菜单系统中使用最多的导航输入。它必须在每个屏幕上一致，没有例外。

| Platform | Input | Behavior |
|----------|-------|---------|
| PC (keyboard) | Escape | 关闭最顶层的模态框 / 在堆栈中后退一个屏幕 / 如果在根屏幕（主菜单），打开"退出？"确认 |
| PC (gamepad) | B (Xbox layout) / Circle (PS layout) | 与 Escape 相同 |
| Xbox | B button | 与 Escape 相同 |
| PlayStation | Circle button | 与 Escape 相同 |
| Nintendo Switch | B button | 与 Escape 相同（注意：任天堂在某些第一方游戏中使用 B 确认 — 检查本版本平台惯例并记录决策） |

**规则**：此输入绝不能覆盖为执行"返回/取消"以外的操作。如果某个屏幕没有返回操作（例如，游戏暂停且玩家必须做出选择），Escape 不做任何事或显示"你必须选择"消息 — 它不会导航离开。每个屏幕必须在其 UX 规格中明确定义其 Escape 行为。

---

## 反馈和加载模式 (Feedback and Loading Patterns)

---

#### Loading State

**Category**：Feedback
**Status**：Draft

| Scope | Pattern | Notes |
|-------|---------|-------|
| Full screen (initial load) | 带游戏美术的全屏加载画面、进度条（如可能使用确定型）、提示文本（可选）。 | 绝不要使用空的黑屏。给玩家一些可读或可看的内容。 |
| Full screen (level transition) | 淡出至黑色、加载屏幕、从黑色淡入至新场景。 | 淡出消除了前一个场景突然消失的突兀感。 |
| Component / inline | 旋转指示器或骨架占位符替换加载中的组件。组件在内容加载时不改变布局。 | 对于布局密集型内容，骨架占位符（近似内容形状的灰色框）比旋转指示器更优 — 它防止了加载时的布局偏移。 |
| Background / async | 除非操作超过 2 秒，否则无视觉指示。2 秒后，显示小旋转指示器或 toast。 | 对于在 2 秒内完成的操作，不要显示加载指示器 — 指示器闪动比等待更具干扰性。 |

**无障碍**：加载状态必须向屏幕阅读器宣告："[上下文] 加载中，请稍候。"完成时必须宣告"[上下文] 已加载。"对于全屏加载，确保加载屏幕本身可供屏幕阅读器导航 — 提示文本和任何 UI 元素必须暴露。

---

#### Empty State

**Category**：Feedback
**Status**：Draft

> 空状态始终是游戏 UI 中最缺乏设计的部分。它们是玩家感觉"这是我存放物品的地方"与"为什么什么都没有？是出问题了吗？"之间的区别。每个空列表和网格都必须有设计好的空状态。空状态不是错误 — 它是一个起点。

| Location | Empty State Content | Notes |
|----------|--------------------|----|
| Inventory (no items) | 图标（柔和、大、居中）。消息："你的物品栏是空的。"子消息："你在旅途中找到的物品将出现在这里。" | 不要说"未找到物品" — "找到"暗示搜索失败。 |
| Quest Log (no active quests) | 图标。消息："没有活跃的任务。"子消息："与标记有[任务标记图标]的角色交谈以开始任务。" | 给玩家一个明确的行动。 |
| Achievements (none earned) | 图标。消息："还没有成就。"提示性成就列表："尝试[行动]以获得你的首个成就。" | 游戏化激励，而不仅仅是空白。 |
| Search results (no matches) | 图标。消息："没有找到'[搜索词]'的结果。"子消息："尝试其他搜索或[浏览全部]。" | 将搜索词回显给玩家。提供替代操作。 |

**规则**：每个空状态必须包含图标、消息以及子消息或操作按钮。没有解释的空白容器是绝不可接受的。

---

#### Error State

**Category**：Feedback
**Status**：Draft

| Error Type | Pattern | Tone |
|-----------|---------|------|
| Input validation (form field) | 字段下方的内联错误消息。消息左侧的错误图标。字段上的红色边框（带图标的色盲安全）。 | 中性且具体 — "用户名必须为 3-20 个字符。"而非"无效输入。" |
| Operation failed (save error, network error) | 非关键失败使用 Toast 通知。关键失败使用 Modal Dialog（存档文件无法写入）。 | 冷静且可操作 — "保存失败。检查存储空间。"而非"致命错误。" |
| System error (crash, data corruption) | 全屏错误画面，包含错误代码、恢复选项（"重新开始游戏"、"加载最后存档"）和支持联系方式。 | 安抚 — 承认问题，给玩家主动权。绝不责怪玩家。 |
| Soft error (action cannot be performed) | Toast 或内联消息。 | 解释性 — "金币不足"而非"操作不可用。" |

**原则**：错误消息从不指向玩家的错误。它们是游戏告诉玩家发生了什么以及接下来该做什么。从所有错误消息中删除"invalid"一词 — 替换为具体解释。

---

## 动画标准 (Animation Standards)

> 这些时间值适用于本模式库中的所有模式。当某个模式说"150ms ease-out"时，缓动函数在此定义。时间上的一致性使 UI 感觉像一个统一设计的系统，而非个体决策的集合。

| Animation Type | Duration (ms) | Easing Function | Notes |
|---------------|--------------|----------------|-------|
| Button hover / focus enter | 80 | ease-out | 快速 — 干脆，不拖沓 |
| Button hover / focus exit | 60 | ease-in | 退出比进入略快 |
| Button press scale down | 60 | ease-in | 即时反馈 |
| Button press scale up (release) | 80 | ease-out | 略有弹性感 |
| Screen push (enter) | 250 | ease-in-out | 屏幕从右侧滑入 |
| Screen pop (exit) | 250 | ease-in-out | 屏幕向右侧滑出 |
| Modal open | 200 | ease-out | 从中心展开 |
| Modal close | 150 | ease-in | 比打开时收缩更快 |
| Toast enter | 200 | ease-out | 从屏幕边缘滑入 |
| Toast exit | 200 | ease-in | |
| Tab switch | 150 | ease-in-out | 内容交叉淡出或滑动 |
| Tooltip appear | 120 | ease-out | 经过 300-400ms 延迟后 |
| Tooltip disappear | 80 | ease-in | |
| Progress bar fill | 300 | ease-out | 值变更平滑动画 |
| Value flash (damage, gain) | 100ms on + 100ms off | linear | 短暂，吸引注意 |
| Dialogue text reveal (per character) | 30ms per character | linear | 可在无障碍设置中配置 |
| HUD damage flash | 80 | linear | 白色或红色覆盖，立即 |

**减少动态覆写**：当减少动态模式启用时（见 accessibility-requirements.md），所有滑动和缩放动画替换为淡出效果。淡出时长减少 50%。循环动画（不确定性旋转指示器、脉冲指示器）替换为静态等效样式。

---

## 声音标准 (Sound Standards)

> 每个交互事件都应有音频反馈。声音是主要的反馈通道，而非装饰。此处定义的声音是事件类别 — 具体的音频资产在 `docs/sound-bible.md` 中定义。此表格将交互事件映射到声音类别，以便声音设计师和 UI 程序员使用相同的词汇。

| Interaction Event | Sound Category | Notes |
|------------------|---------------|-------|
| Button hover / focus | UI Hover | 柔和、短促（< 80ms），快速导航时不产生疲劳。Hades 使用非常安静的高频点击声，在快速导航时融入背景。 |
| Button (Primary) confirm | UI Confirm — Primary | 比 secondary 确认稍突出。"是的，出发吧"的声音。 |
| Button (Secondary) cancel / back | UI Cancel | 略向下音调。"返回"的声音。Mass Effect 使用干净、独特的 swoosh 声用于返回导航。 |
| Button (Destructive) — opening confirmation | UI Warning | 与标准确认音不同。短暂吸引注意的声音。 |
| Confirmation dialog — confirm destructive | UI Confirm — Destructive | 最终、稍显沉重。正在执行操作。 |
| Toggle ON | UI Toggle On | 短暂、清脆、略亮。Celeste 的无障碍切换有一个令人满意的点击开启声。 |
| Toggle OFF | UI Toggle Off | 同一点击家族，略平。 |
| Slider adjust | UI Slider | 拖拽时柔和的连续声音。每步 D-pad 操作一次点击声。从不产生疲劳。 |
| Dropdown open | UI Expand | 短暂，有方向感（打开的感觉）。 |
| Dropdown close / select | UI Select | 确认感。 |
| Tab switch | UI Tab | 水平移动感。与垂直导航不同。 |
| Modal open | UI Modal Open | 比标准导航更突出 — 吸引注意力。 |
| Modal close (cancel) | UI Modal Close | 返回上一上下文。 |
| Toast — informational | UI Notification | 背景级别，不打扰。 |
| Toast — achievement | UI Achievement | 庆祝但不拖沓。玩家应感到被奖励，而非被打断。 |
| Toast — warning | UI Warning — Toast | 与错误不同。提醒而非警示。 |
| Error state | UI Error | 友好但清晰。不是刺耳的蜂鸣。Dark Souls 对失败操作使用微妙的沉闷重击声 — 表达"不行"而不刺耳。 |
| Success confirmation | UI Success | 干净且令人满意。 |
| Ability activate | Gameplay — Ability Activate | 世界内感受，与纯 UI 不同。属于游戏感受的一部分，而非菜单感受。 |
| Damage received | Gameplay — Damage | 完整规格见 sound-bible.md。 |
| Item pickup | Gameplay — Item Acquire | 短暂，有回报感。 |
| Level up / rank up | Gameplay — Progression | 庆祝感，适当突出。 |
| Dialogue advance | UI Dialogue | 柔和，匹配打字机节奏（如果打字机激活）。 |

---

## 开放问题 (Open Questions)

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|-----------|
| [引擎的无障碍节点系统是否支持无需焦点的 toast 通知屏幕阅读器宣告？针对 Godot 4.6 验证 engine-reference/godot/。] | [ux-designer] | [首次菜单实现之前] | [未解决] |
| [Nintendo Switch 版本平台正确的确认/取消按钮映射是什么？任天堂第一方惯例与 Xbox/PlayStation 不同。] | [producer] | [平台认证提交之前] | [未解决] |
| [伤害数字应作为 Label3D 节点池化还是在 SubViewport 中渲染？与 technical-director 协调验证性能预算。] | [lead-programmer, ux-designer] | [战斗 HUD 实现之前] | [未解决] |
| [队列变得视觉上压倒性的最大同时 toast 通知数量是多少？需要试玩测试。] | [ux-designer] | [首次试玩测试] | [未解决] |
| [添加问题] | [Owner] | [Deadline] | [Resolution] |
