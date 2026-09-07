# 战斗UI系统 GDD 对抗性审查 —— systems-designer

> **审查日期**: 2026-09-06
> **审查者**: systems-designer
> **审查对象**: `design/gdd/combat-ui-system.md`
> **审查模式**: 对抗性（找问题，非验证设计）
> **聚焦**: 公式边界值代入、退化状态、跨公式一致性

---

## BLOCKER

### B1. `cost_color` 除零：`base_max=0` 且 `temporary=0` 时 `ratio = available / 0`

**位置**: 第 445-451 行，公式 §4 费用显示颜色

**公式**:
```
cost_color(available, base_max, temporary) → Color:
  total_max = base_max + temporary
  ratio = available / total_max
```

**变量声明**: `base_max ≥ 0`, `temporary ≥ 0`。两者均可为 0。

**边界代入**:
- `base_max=0, temporary=0`（回合初期、费用被减益清零、丹药未生效）→ `total_max=0` → `ratio = available / 0`
- 若 `available=0`（必然，因上限为 0）→ `ratio = 0/0 = NaN`
- `NaN > 0.5` 为 false，`NaN > 0.0` 为 false → 落入 `return RED`
- 结果：颜色碰巧为红色，但计算路径未定义。GDScript 中 `0.0 / 0.0` 产生 `NaN`，后续比较均 false，UI 可能渲染异常。

**为何 BLOCKER**: 该边界值在正常游戏中可达——回合 1 费用为 0、费用被清空的减益效果、丹药未购买时。GDD 验收标准（第 655 行）仅覆盖 `base_max=0 + temporary=3`，未覆盖 `base_max=0 + temporary=0`。除零是运行时错误风险。

**建议修复**: 增加守卫 `if total_max == 0: return RED`（或 `GRAY`，表示"无费用上限信息"），并将 `available` 上界约束为 `total_max`（防止 `available > total_max` 时 `ratio > 1.0`，虽不致崩溃但颜色判定语义不清）。

---

### B2. `hand_card_position` 在 `total_cards=1` 时 `rotation` 计算含义模糊但非退化；真正问题在 `screen_width` 极小、`total_cards=10` 时 `spacing` 可能为负

**位置**: 第 391-399 行，公式 §1 手牌排列弧度

**公式**:
```
spacing = min(card_width + 10px, screen_width / total_cards)
x = screen_center + (index - (total_cards - 1) / 2) × spacing
```

**边界代入（`total_cards=10, screen_width` 极小）**:
- 卡牌游戏手牌区宽度 = `screen_width × 1.0`（第 72 行"宽度100%"）
- 若 `screen_width = 1280`（最低支持分辨率 1280×720），`card_width` 假设约 150px（卡牌正常宽度）
- `spacing = min(160, 1280/10) = min(160, 128) = 128`
- 10 张卡总宽度 = `9 × 128 = 1152`，加上卡牌自身宽度 150 = 1302 > 1280，轻微溢出
- 但 `x = screen_center + (index - 4.5) × 128`，最右卡 `x = 640 + 4.5×128 = 1216`，卡牌右边缘 `1216 + 75 = 1291 > 1280`，轻微越屏

**更严重的边界**: 若 `card_width` 在低分辨率未同步缩小（GDD 未声明 `card_width` 随分辨率缩放，仅 `font_size_responsive` 处理文字），`card_width=150` 在 1280×720 下仍为固定值，则 `spacing=128` 时 10 张卡必然溢出。

**`y` 坐标退化检查**:
- `y = base_y - abs(x - screen_center) × tan(arc_angle / 2)`
- `arc_angle = min(30°, 10 × 3°) = 30°`，`tan(15°) ≈ 0.268`
- 最远卡 `abs(x - screen_center) = 4.5 × 128 = 576`，`y_offset = 576 × 0.268 = 154.4px`
- `base_y = screen_height × 0.86`。若 `screen_height=720`，`base_y = 619.2`
- 最远卡 `y = 619.2 - 154.4 = 464.8`，即最远卡向上偏移 154px
- 问题：手牌区高度声明为"屏幕的25%"（第 71 行）= 180px，但弧形抬升 154px 已接近该区域的 85%。卡牌自身高度（约 210px 缩小版）会显著超出手牌区上边界，侵入费用栏区域。

**`rotation` 在 `total_cards=1` 时**:
- `rotation = (0 - 0) × (arc_angle / 1) = 0°`，正确
- `arc_angle = min(30°, 1 × 3°) = 3°`，单张卡弧度 3°，但单张卡不应有弧度——`rotation=0` 是对的，但 `arc_angle` 本身的计算无意义（单张卡不存在"弧"）。非退化，但语义冗余。

**为何 BLOCKER**: 低分辨率下 10 张手牌必然越界且侵入费用栏，GDD 的"宽屏/超宽屏适配"边缘情况（第 497 行）未覆盖"低分辨率 + 满手牌"组合。`card_width` 未声明响应式缩放，是根本缺口。

**建议修复**:
1. 声明 `card_width` 随 `screen_height` 响应式缩放（类似 `font_size_responsive`）
2. 在 `spacing` 计算后增加守卫 `if spacing < min_spacing: trigger_stacked_layout()`，当 spacing 低于阈值时自动切换到堆叠布局（公式 §2）
3. 将弧形抬升量 `abs(x - screen_center) × tan(arc_angle/2)` 钳制在手牌区高度的 60% 以内

---

### B3. `card_overlap_offset` 在 `total_cards=10, card_width` 极小时返回负值（卡牌反向重叠）

**位置**: 第 413-418 行，公式 §2 手牌堆叠重叠量

**公式**:
```
card_overlap_offset(total_cards, card_width) → float:
  if total_cards <= 7: return card_width + 10
  excess = total_cards - 7
  overlap = (card_width × 0.3) × excess
  return card_width - overlap / total_cards
```

**边界代入（`total_cards=10, card_width=150`）**:
- `excess = 3`
- `overlap = 150 × 0.3 × 3 = 135`
- `return 150 - 135/10 = 150 - 13.5 = 136.5`
- 相邻卡偏移 136.5px，卡宽 150px → 重叠量 = `150 - 136.5 = 13.5px`（仅 9% 重叠）
- 10 张卡总宽度 = `9 × 136.5 + 150 = 1378.5px`，在 1280 宽度下仍溢出 98.5px

**更严重边界（`card_width` 未响应式缩小，但 `total_cards=10`）**:
- 若 `card_width` 在低分辨率下保持 150px，堆叠公式根本无法让 10 张卡塞进 1280px
- 需要 `spacing ≤ (1280 - 150) / 9 = 125.6px` 才能不溢出，但公式返回 136.5px

**极端边界（`card_width=100, total_cards=10`）**:
- `overlap = 100 × 0.3 × 3 = 90`
- `return 100 - 90/10 = 100 - 9 = 91`
- 相邻卡偏移 91px，卡宽 100px → 重叠 9px（9%）
- 10 张卡总宽 = `9×91 + 100 = 919px`，可塞入 1280

**退化检查（`card_width` 极小 = 50px）**:
- `overlap = 50 × 0.3 × 3 = 45`
- `return 50 - 45/10 = 50 - 4.5 = 45.5`
- 相邻卡偏移 45.5px，卡宽 50px → 重叠 4.5px（9%）
- 重叠比例恒为 9%，与 `card_width` 无关，但绝对重叠量随 `card_width` 线性缩小

**真正退化点（`card_width=30, total_cards=10`）**:
- `overlap = 30 × 0.3 × 3 = 27`
- `return 30 - 27/10 = 30 - 2.7 = 27.3`
- 相邻卡偏移 27.3px，卡宽 30px → 重叠 2.7px
- 卡牌几乎不重叠，但 30px 宽的卡牌不可读（卡名、费用、效果文字无法显示）

**为何 BLOCKER**: 公式的重叠比例（9%）远低于调优参数表第 548 行声明的"卡牌重叠比例（>7张）默认 30%"。公式实现与调优参数不一致。且 `card_width` 未声明响应式，低分辨率下 10 张卡仍溢出。

**建议修复**:
1. 统一公式与调优参数：重叠比例应为 30% 而非 9%。修正公式为 `overlap = (card_width × overlap_ratio) × excess`，其中 `overlap_ratio=0.3`，并确保相邻卡偏移 `= card_width × (1 - overlap_ratio) = card_width × 0.7`
2. 当前公式 `overlap / total_cards` 的除法语义错误——重叠量不应除以总卡数，应为固定重叠比例
3. 声明 `card_width` 响应式缩放规则

---

## HIGH

### H1. `hp_bar_color` 在 `hp_ratio > 1.0` 或 `hp_ratio < 0.0` 时未定义行为

**位置**: 第 430-434 行，公式 §3 HP条颜色阈值

**公式**:
```
hp_bar_color(hp_ratio) → Color:
  if hp_ratio > 0.6: return GREEN
  if hp_ratio > 0.3: return YELLOW
  return RED
```

**边界代入**:
- `hp_ratio = 1.5`（HP 被治疗超过最大值，若战斗系统允许溢出治疗）→ `> 0.6` → GREEN。语义上 GREEN 合理，但 GDD 未声明 HP 是否可超上限。
- `hp_ratio = -0.2`（HP 被减益打到负值，若战斗系统未在 0 处截断）→ 不 `> 0.6`，不 `> 0.3` → RED。颜色合理，但负 HP 本身是战斗系统bug，UI 静默接受。
- `hp_ratio = NaN`（最大 HP = 0 时 `current/max = 0/0`）→ RED。但最大 HP=0 是退化状态（角色不应存在）。

**为何 HIGH**: GDD 变量范围声明为 `[0.0, 1.0]`，但未声明 UI 层是否对超界输入做钳制。若战斗系统因 bug 传入 `hp_ratio = 1.5`，UI 显示满血绿色，玩家无法察觉异常——这掩盖了战斗系统 bug。建议 UI 层增加 `hp_ratio = clamp(hp_ratio, 0.0, 1.0)` 并在 `hp_ratio < 0` 时记录警告日志。

**非 BLOCKER 理由**: 颜色输出不退化（GREEN/RED 都有意义），但缺乏防御性编程。

---

### H2. `formation_row_scale` 仅返回二元值，但 GDD 描述"前后排视觉区分"还包含边框样式——缩放与边框样式耦合不清

**位置**: 第 464-466 行，公式 §5 前后排视觉缩放

**公式**:
```
formation_row_scale(is_front_row) → float:
  return 1.0 if is_front_row else 0.85
```

**问题**: 公式仅返回缩放值，但第 115-116 行描述"前排实线金色、后排虚线蓝色"——边框样式独立于缩放。公式未声明边框样式如何确定。是另一公式？是硬编码？

**边界代入**: 无退化风险（二元枚举）。但 0.85 缩放后，角色位内的文字（角色名、HP 数字）也会缩放至 85%，在低分辨率下可能低于 12pt 最小可读字号。`font_size_responsive` 未考虑缩放后的二次缩小。

**为何 HIGH**: 缩放后文字二次缩小未与 `font_size_responsive` 联动。1280×720 下 `base_font_size × 0.85` 若 `base=14` → 11.9px，低于 12pt 下限。但 `font_size_responsive` 返回 `max(base × 0.85, 12)`，若 `base=14` 则返回 12（保底）。问题在于缩放后的 12px 再被 0.85 缩放 = 10.2px，突破保底。需要"缩放后字号 = max(font_size_responsive(...) × scale, 12)"的联动公式。

---

### H3. `font_size_responsive` 仅基于 `screen_height`，未考虑 `screen_width` 和 DPI 缩放

**位置**: 第 473-477 行，公式 §6 低分辨率文字缩放

**公式**:
```
font_size_responsive(base_font_size, screen_height) → int:
  if screen_height >= 1080: return base_font_size
  if screen_height >= 720: return max(base_font_size × 0.85, 12)
  return 12
```

**边界代入**:
- `screen_height = 720, base_font_size = 14` → `max(11.9, 12) = 12` ✓
- `screen_height = 719`（略低于 720 阈值）→ `return 12`，骤降。14→12 是 14% 缩小，但 719 与 720 仅差 1px，行为突变不合理。应在 720~1080 之间平滑过渡。
- `screen_height = 1080, base_font_size = 20` → 20px。但 1080p 下 Windows 默认 DPI 缩放 125%/150% 会使有效分辨率变为 1536×864 或 1920×1080（DPI 100%）。Godot 4.6 在 D3D12 下的窗口客户区高度可能 != 屏幕高度。公式未区分"屏幕高度"与"窗口客户区高度"。
- `screen_height = 1440`（2K）→ `>= 1080` → 返回 `base_font_size`。但 2K 下 `base_font_size` 若为 14px，物理可视字号会很小（高 DPI 下像素更密）。未声明 2K/4K 下的放大规则。

**为何 HIGH**: 1280×720 阈值处行为突变（1px 差异导致字号跳变），且未处理高 DPI。Godot 4.6 在 Windows D3D12 默认下，DPI 缩放是真实场景。

**建议修复**: 在 720~1080 之间使用 `lerp(12, base, (screen_height - 720) / 360)` 平滑过渡；声明 DPI 缩放处理策略。

---

### H4. 悬停预览延迟公式（§7）与正文（第 351 行"不使用300ms延迟"）矛盾

**位置**: 第 481-485 行 公式 §7 vs 第 351 行正文

**矛盾**:
- 公式 §7: `hover_preview_delay_ms = 300`，"所有悬停目标共用"
- 第 351 行: "不使用300ms延迟——详情面板应即时响应"
- 验收标准第 695 行: "悬停手牌卡牌，超过300ms，THEN 卡牌放大120%"

**三处相互矛盾**。公式说 300ms 共用，正文说即时（0ms），验收标准说 300ms。实现时开发者无法判断以哪个为准。

**为何 HIGH**: 跨章节自相矛盾，直接影响实现一致性。虽非数值退化，但属于"规格不可执行"级别问题。

**建议修复**: 区分"触发延迟"（鼠标进入后多久触发）与"切换延迟"（从一个面板切到另一个的间隔）。统一为：触发延迟 300ms（所有元素共用，避免误触），切换延迟 0ms（即时切换，避免卡顿）。

---

### H5. `hand_card_position` 的 `arc_angle` 在 `total_cards=0` 时早返回，但 `total_cards=1` 时 `arc_angle=3°` 导致单张卡有微小旋转——虽 `rotation=0`，但弧度计算本身无意义

**位置**: 第 393 行

**公式**: `arc_angle = min(30°, total_cards × 3°)`

**边界代入**:
- `total_cards=1` → `arc_angle = min(30°, 3°) = 3°`
- `rotation = (0 - 0) × (3° / 1) = 0°` ✓
- 但 `y = base_y - abs(0) × tan(1.5°) = base_y` ✓
- 单张卡行为正确，但 `arc_angle` 的计算冗余

**真正问题**: `total_cards × 3°` 的线性增长在 `total_cards=10` 时 = 30°（命中上限），但 `total_cards=11`（若手牌上限被突破）→ `min(30°, 33°) = 30°`，仍正确。但 GDD 第 405 行声明 `total_cards` 范围 `[0, 10]`，第 491 行又说"手牌满10张抽牌→第11张进弃牌堆"——上限 10 是硬约束。若因 bug 出现 11 张，公式不会崩溃，但布局会挤压。

**为何 HIGH 而非 LOW**: 单张卡情况非退化，但暴露了 `arc_angle` 公式对 `total_cards=1` 的语义不当——应增加 `if total_cards <= 1: arc_angle = 0`。这是防御性缺口。

---

## LOW

### L1. 调优参数表"卡牌重叠比例（>7张）默认 30%"与公式 §2 实际计算的重叠比例（9%）严重不符

**位置**: 第 548 行调优参数 vs 第 413-418 行公式

**详见 B3**。调优参数表声明 30%，公式实现 9%。这是跨章节数值不一致。虽归入 B3 的根本问题，但单独标记为 LOW 是因为：若 B3 的公式修复后（采用 30% 比例），调优参数表无需改动——它本来就是 30% 的意图。问题在公式实现，不在调优参数声明。

---

### L2. `hp_bar_color` 阈值 60%/30% 与调优参数表 60%/30% 一致，但安全范围（40%~80% / 15%~50%）允许"绿→黄"阈值低于"黄→红"阈值的退化

**位置**: 第 539-540 行调优参数

**边界代入**: 若"绿→黄"调到 40%，"黄→红"调到 50% → `hp_ratio=0.45` 时：
- `> 0.6`? 否
- `> 0.3`? 是（0.45 > 0.3）→ YELLOW
- 但调优后公式应为 `if > 0.4: ...`，0.45 > 0.4 → GREEN
- 矛盾：调优参数安全范围允许两个阈值交叉，但未声明约束"绿→黄阈值必须 > 黄→红阈值"

**为何 LOW**: 调优参数表的安全范围允许交叉，但这是调参错误，非公式缺陷。建议增加约束声明。

---

### L3. 公式 §1 的 `base_y = screen_bottom × 0.86` 使用百分比，但 `screen_bottom` 未定义——是屏幕高度还是手牌区底部？

**位置**: 第 394 行

**问题**: `screen_bottom` 变量名暗示"屏幕底部"，但 `× 0.86` 暗示"屏幕高度的 86%"。若 `screen_bottom = screen_height`，则 `base_y = screen_height × 0.86`，与第 408 行"base_y 使用屏幕高度的百分比（86%）"一致。但变量名应改为 `screen_height` 以明确。

**为何 LOW**: 命名歧义，不影响计算（假设实现者按第 408 行理解）。

---

### L4. `hand_card_position` 的 `rotation` 公式 `× (arc_angle / total_cards)` 在 `total_cards=0` 时除零，但已被早返回守卫

**位置**: 第 398 行

**检查**: `if total_cards == 0: return []`（第 392 行）在除法前返回，安全。但若守卫被移除或重构时遗漏，`arc_angle / 0` 会除零。建议在 `rotation` 计算前增加次级守卫 `if total_cards <= 1: rotation = 0`。

**为何 LOW**: 已有守卫，非即时风险。

---

### L5. Draw Call 预算（235 items）超出 200 上限的缓解策略中"HP 条改用 draw_rect()"与 Godot 4.6 的 CanvasItem 体系兼容性未验证

**位置**: 第 592-596 行

**问题**: `draw_rect()` 在 `Control._draw()` 中调用，每帧重绘。16 个角色位若每个独立 `draw_rect()`，仍计为 16 个 draw call（除非合并到单一 `draw()` 调用）。GDD 未说明如何合并。Godot 4.6 的 `RenderingServer.canvas_item_add_rect` 可批量添加，但需在同一 `CanvasItem` 下。建议明确"所有 HP 条归属单一 Control 节点的 `_draw()` 批量绘制"。

**为何 LOW**: 缓解策略方向正确，但实现细节缺失，可在实现时补充。

---

## 跨公式一致性总结

| 公式 | 退化状态 | 严重度 |
|------|---------|--------|
| §1 手牌排列 | 低分辨率+10张卡：溢出屏幕、侵入费用栏 | BLOCKER (B2) |
| §2 手牌堆叠 | 重叠比例 9% vs 调优声明 30%；低分辨率仍溢出 | BLOCKER (B3) |
| §3 HP条颜色 | hp_ratio 超界（>1 或 <0）静默接受 | HIGH (H1) |
| §4 费用颜色 | base_max=0+temporary=0：除零/NaN | BLOCKER (B1) |
| §5 前后排缩放 | 缩放后文字二次缩小突破 12pt 下限 | HIGH (H2) |
| §6 文字缩放 | 720px 阈值处突变；未处理高 DPI | HIGH (H3) |
| §7 悬停延迟 | 公式与正文、验收标准三处矛盾 | HIGH (H4) |

## 整体评估

该 GDD 在公式定义上存在 **3 个 BLOCKER 级退化缺陷**，均涉及正常游戏中可达的边界值（低分辨率满手牌、费用上限为 0）。这些缺陷会在 MVP 阶段暴露为运行时错误或视觉异常，必须在交付实现前修复。

另有 **5 个 HIGH 级问题**，涉及防御性编程缺失、跨章节矛盾、以及高 DPI/低分辨率处理的覆盖空白。

**修复优先级**:
1. B1（除零）——5 分钟修复，增加守卫
2. B3（重叠公式语义错误）——重写公式，统一 30% 比例
3. B2（低分辨率溢出）——需声明 `card_width` 响应式 + 自动切换堆叠布局
4. H4（悬停延迟矛盾）——统一三处描述
5. H2/H3（缩放联动、DPI）——补充公式

审查完毕。