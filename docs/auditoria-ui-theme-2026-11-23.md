# 审计：四屏 UI 配色与统一主题落点

> **Data**: 2026-11-23
> **Validade**: ~90 dias（重新验证日期 2027-02-21）
> **Itens voláteis**: 主题 token 的具体色值（以 `theme/main.tres` 与生成器为真理来源）、
> 各屏幕节点路径、字号档位（下一轮排版收敛可能改变）

## 背景

承接 `d64814d`（战斗 / 渡劫补深色背板 + 主菜单文字色阶）之后的 UI 走查发现：
**项目没有 Theme 资源**，`project.godot` 无 `gui/theme/custom`。后果有两层：

1. **背板色散落**：六个 `.tscn` 各写一份 `ColorRect` 字面量，其中节点图那份漂成了
   另一个值——同一支「项目深色」在屏幕上呈三支。
2. **未覆写的文字全落到引擎内置默认主题**：标题纯白、按钮冷灰，与 art-bible 的暖色
   四级色阶毫无关系（上一轮已单独修掉主菜单这一处，本轮的修法是把它收进主题）。

本文件是「先审计再动手」的那份审计——色值表与结论。**实施落点在
`theme/main.tres`（生成器 `tools/gen_theme.gd`）**，本文件不重复其内容，只记录
「改之前长什么样」。

## 一、四屏底色的实际值（审计表）

取自各 `.tscn` 的 `Background` 节点（`ColorRect.color` 字面量）：

| 屏幕 | 场景文件 | 行的位置 | 实测色值 | 十六进制 | 与最深值的偏差 |
|------|----------|----------|----------|----------|----------------|
| 主菜单 | `src/ui/main_menu/MainMenu.tscn` | `Background.color` | `Color(0.071, 0.071, 0.086, 1)` | ≈`#121216` | 偏亮 |
| 地图选择 | `src/ui/exploration/map_select_screen.tscn` | 同上 | `Color(0.071, 0.071, 0.086, 1)` | ≈`#121216` | 偏亮 |
| **节点图** | `src/ui/exploration/node_graph_screen.tscn` | 同上 | `Color(0.055, 0.06, 0.086, 1)` | ≈`#0E0F16` | **最深（基准）** |
| 战斗 | `src/feature/combat/combat_scene.tscn` | 同上 | `Color(0.071, 0.071, 0.086, 1)` | ≈`#121216` | 偏亮 |
| 渡劫 | `src/feature/tribulation/tribulation_scene.tscn` | 同上 | `Color(0.071, 0.071, 0.086, 1)` | ≈`#121216` | 偏亮 |
| 身份选择 | `src/ui/identity_select/identity_select.tscn` | 同上 | `Color(0.071, 0.071, 0.086, 1)` | ≈`#121216` | 偏亮 |

**走查的第三支**：`d64814d` 之前战斗与渡劫连 `Background` 节点都没有，玩家看到的是
Godot 默认清屏色 `Color(0.3, 0.3, 0.3)`（实测战斗屏 93.3% 像素 RGB(76,76,76)）。
该轮已补上 `Color(0.071, 0.071, 0.086)`，所以**审计时点是「两支」**，
但「三支」是这一串改动的起点，一并记在这里。

**结论**：以**节点图那一支（最深）**为基准——`#0E0F16`。它同时是「屏幕基底」应该
比 BG-0（`#141414`，留给对话框遮罩这类更深的层）更暗的合理取值。

## 二、主菜单文字色阶的实际值（审计表）

`d64814d` 之前 `MainMenu.tscn` **没有任何 `theme_override_colors`**，全部落到引擎内置
默认主题。该轮补上了下面的值（**本节数值本轮未变**，只是载体从节点覆写换成主题变体）：

| 档位 | 用途 | 实测色值 | 十六进制 | art-bible |
|------|------|----------|----------|-----------|
| T-0 | 标题 / 高亮 / 悬停·按下·聚焦态 | `Color(0.941176, 0.921569, 0.878431, 1)` | `#F0EBE0` | §4.7.2 一致 |
| T-1 | 正文 / 按钮默认态 | `Color(0.784314, 0.768627, 0.737255, 1)` | `#C8C4BC` | §4.7.2 一致 |
| T-2 | 次要说明（存档摘要 / 无存档提示 / 版本号） | `Color(0.596078, 0.580392, 0.54902, 1)` | `#98948C` | §4.7.2 一致 |
| T-3 | 禁用态 | `Color(0.407843, 0.392157, 0.360784, 1)` | `#68645C` | §4.7.2 一致 |

**对照**：修之前实测的是引擎默认——标题 9.30% 像素为**纯白 RGB(255,255,255)**、
按钮文字 4.33% 为**冷灰 RGB(204,204,204)**。冷灰与 `#C8C4BC`（暖灰）在数值上很接近，
但暖冷之差正是 art-bible 要表达的东西，所以这不算「本来就差不多」。

主菜单字号档位（审计值，本轮保留）：标题 48 / 按钮 18 / 说明标签 13。

**旁支发现（本轮只记录不动）**：地图选择与节点图各有一个警示标签写的是
`Color(0.9, 0.75, 0.3, 1)` 的字面量金色——与 art-bible §4.1 的琉璃金 `#C8A84E` 不符。
本轮把它收进 `GamePalette/accent_warning`（`WarningText` 变体），于是这两处自动改成了
**符合 §4.1 的金色**——这是「收敛重复值」的副作用，不是有意的配色重新设计，故在此登记。

## 三、`theme/main.tres` 定义了哪些 token

| 类别 | token | 取值来源 | 用途 |
|------|-------|----------|------|
| 调色板 | `GamePalette/backdrop` | `#0E0F16`（审计表最深值） | 六块全屏背板 |
| | `GamePalette/panel` / `panel_border` | BG-2 `#282826` / BG-4 `#4A4A46` | `Panel` / `PanelContainer` |
| | `GamePalette/control` / `control_border` | BG-3 `#363634` / BG-4 | `Button` 各状态底 |
| | `GamePalette/disabled_fill` | BG-0 `#141414` | 禁用按钮底 |
| | `GamePalette/text_primary` … `text_disabled` | T-0 … T-3 | 四级文字色阶 |
| | `GamePalette/accent_success` / `accent_warning` / `accent_danger` | 松石青 / 琉璃金 / 朱砂红 | 语义色 |
| | `GamePalette/accent_danger_soft` | `#B3424A` | 大面积文字用的软变体（项目既有警报编码） |
| 文字变体 | `DisplayText`(48) / `TitleText`(32) / `SubtitleText`(22) / `BodyText`(16) / `CaptionText`(13) / `DisabledText`(13) | 各屏既有字号 | 标题 / 正文 / 说明三档以上 |
| | `WarningText` / `DangerText`(16) | accent_warning / accent_danger_soft | 语义色文字 |
| 控件变体 | `NavButton`（挂 `Button`，18） | 主菜单既有按钮字号 | 导航按钮 |
| 基础样式 | `Label`（T-1 / 16） | §4.7.2 | 兜底正文 |
| | `Button`（5 色 + 4 状态样式盒，16） | §4.7.3 | 默认 T-1 / 悬停·按下·聚焦 T-0 / 禁用 T-3 |
| | `Panel` / `PanelContainer`（面板样式盒） | §4.7.1 | 面板底 + 1px 描边 |
| | `RichTextLabel`（default_color T-1 / 16） | §4.7.2 | 富文本兜底 |

**刻意留空**：`Button/styles/focus`。项目既有的焦点环唯一来源是
`shop_panel_layout.apply_focus_ring`（松石青 3px），主题里再定义一套会让「焦点长什么样」
出现两个来源。

## 四、四屏各自怎么接的

| 屏幕 | 底色接线 | 文字接线 |
|------|----------|----------|
| 主菜单 | `Background` 挂 `AppBackdrop` 脚本（颜色由主题提供，`.tscn` 里不再有 `color`） | 标题 → `DisplayText`；7 按钮 → `NavButton`；3 说明标签 → `CaptionText` |
| 地图选择 | 同上 | 标题 → `TitleText`；余额 → `SubtitleText`；警示 → `WarningText`（保留局部 13px 字号，注释说明原因） |
| 节点图 | 同上 | 状态标签 → `WarningText` |
| 战斗 | 同上 | 本轮不动（该屏文字无硬编码配色） |
| 渡劫 | 同上 | 本轮不动 |
| 身份选择 | 同上（**额外收编**，不在任务点名的四屏内） | 本轮不动 |

**为什么背板要一个脚本**：`ColorRect.color` 是普通属性，没有主题槽——`.tscn` 只能写
字面量。`AppBackdrop` 在 `_init` 从主题读 `GamePalette/backdrop` 写进 `color`，
于是「底色是什么」只有一处。全局默认主题通过 `project.godot` 的
`gui/theme/custom` 设置，四个根节点都不自挂 `theme`。

## 五、本轮未动的既有边界（登记）

**背板色的接线口径是「`.tscn` 里声明了 `Background` 节点」**——全库共七处，本轮接了六处，
另有三处是**代码里 new 出来的**背板，按同一口径属于另一类构造路径，未接：

| 位置 | 现状 | 为什么不接 / 何时接 |
|------|------|---------------------|
| `src/ui/cultivation/cultivation_scene_layout.gd:29` | `BG_COLOR = Color(0.055, 0.06, 0.086)`（**正是节点图那一支**） | 背板由 `_add_background()` 运行时 `ColorRect.new()` 建。接线要改成用挂了 `AppBackdrop` 的脚本实例，动的是**运行时构建路径**而不是场景声明——本轮范围是「四屏接线」，这属于同一类漂移但不同的改法，留给下一轮统一 |
| `src/ui/deck_editing/deck_editing_layout.gd:42` | `Color(0.071, 0.071, 0.086)` | 同上（`build()` 里 new） |
| `src/ui/shared/placeholder_scene.gd:46` | `Color(0.071, 0.071, 0.086)` | 同上（`_build()` 里 new） |
| `src/ui/loading/loading_screen.tscn` | `Color(0, 0, 0, 1)` 纯黑 | 是一闪而过的过渡屏；纯黑与 `backdrop` 的差在看片上分不出来，且纯黑在这里是**有意**的（转场遮罩语义），不是漂移 |

**结论（拍板）**：上面三处代码里的 `BG_COLOR` 与六个场景背板**是同一支「项目深色」的四份拷贝**，
本轮只收敛了 `.tscn` 那一路；代码那一路仍是字面量。它不构成本轮结论的反例（`theme/main.tres`
是唯一落点，这三处是**还没接的消费者**），但必须记在这里，否则下一个人会以为「配色已经收干净了」。
判断依据是三条：① 三处的值互不相同（`0.055` vs `0.071`）——正是本轮要消灭的漂移；
② 它们的容器类都持有 `_add_background` 之类的私有辅助，改法一样（换成 `AppBackdrop` 实例）；
③ 会一起动到 cultivation / deck-editing / placeholder 三屏的既有用例，
量级与本轮相当，值得单独一轮。

其余未动项：

1. **`identity_select.tscn` 的 `HintLabel`**：留着 `Color(0.42, 0.4, 0.37, 1)`
   ——比 T-3（`#68645C`）还暗。语义像是「比正文更弱的提示」，但它比禁用色还暗，
   属于设计判断（该用 T-2 还是 T-3？）而不是收敛重复值，留待下一轮定夺。
   （该屏的**背板**已接——它与四屏同值、同 `Background` 节点形态。）
2. **地图选择 / 主菜单 / 身份选择弹窗内的 `theme_override_font_sizes`**：是排版
   （密集弹窗要更小的字号），本轮只收敛配色，不动。地图选择那处已在场景里写了注释说明。
3. **引擎默认主题里的 `Window` / `AcceptDialog` / `PopupMenu` 等槽位**：主题未定义，
   弹窗仍走引擎默认外观。改之前也是默认，不算回归；要不要收进主题是下一轮的事。

## 来源

- `design/art/art-bible.md` §4.1（主色调色板）、§4.7.1（背景层级）、§4.7.2（文字色阶）、
  §4.7.3（交互态色阶）、§3.3.1（微圆角 2px）
- `docs/decisions/ADR-0031-presentation-layer-architecture-baseline.md`
- `theme/main.tres`（生成器 `tools/gen_theme.gd`——改配色要重跑它）
- 本文件结论的可执行形式：
  - `tests/integration/ui_theme/test_theme_resource.gd`——主题里有什么、值对不对
  - `tests/integration/ui_theme/test_theme_wiring.gd`——六屏有没有真的接上、四屏底色同色系
  - `tests/integration/scene_manager/test_scene_backdrop_present.gd`——战斗 / 渡劫背板仍在
  - `tests/integration/main_menu/test_menu_text_style.gd`——主菜单四级色阶仍在
