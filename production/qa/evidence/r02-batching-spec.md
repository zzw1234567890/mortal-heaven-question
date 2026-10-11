# R-02 合批实现规范（combat-ui 002-006 实现依据）

> **日期**：2026-10-11
> **Story**：combat-ui-layout 009a（合批方案定型——前置架构 spike）
> **管辖 ADR**：ADR-0031 §5 渲染预算（图集合批为 Required pattern 而非事后优化）
> **测量 API 查证**：R-02 spike（2026-10-11）——`RenderingServer.get_rendering_info(RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)` 存在，枚举值 2，结论已回写 `docs/engine-reference/godot/modules/rendering.md`
> **原型**：`prototypes/r02-batching-spike/`（benchmark.gd + spike.gd）
> **状态**：待签收（Visual/Feel——证据文档，ADVISORY 关卡）

---

## 1. TextureAtlas 结构定型

图集是**必需模式**（ADR-0031 §5），禁止角色位独立纹理逐图标渲染。图集划分与命名规范：

| 图集 | 内容 | 单图标规格 | 命名前缀 |
|------|------|-----------|---------|
| `status_icons_atlas` | 状态效果图标（增益/减益/持续） | 32×32，4px 边距 | `status_*` |
| `faction_indicator_atlas` | 阵营指示器（2 大阵营 + 12 门派 + 4 跨阵营） | 24×24 | `faction_*` |
| `card_frame_atlas` | 卡牌边框（普通/稀有/史诗/传说 + 高亮态） | 九宫格切片 | `frame_*` |
| `corner_badge_atlas` | 角标（待命/已行动/锁定/境界标记） | 20×20 | `badge_*` |

**规则**：
- 用 `AtlasTexture`（`region` 定位），**禁用**独立 `.png` 逐图标 `TextureRect`（每个独立纹理 = 至少 1 额外 DC）。
- 图集内图标间距 ≥2px 防采样渗色；padding 对齐 4 的倍数。
- 图集由技术美术生成并提交到 `assets/ui/atlas/`；命名 `[category]_atlas.png` + `.import`。
- 新增图标**追加**到对应图集（满则新建同类别第二张），不得为新图标另开独立纹理。

---

## 2. HP 条绘制方式定型：`draw_rect()` 纯色批量绘制

HP 条**禁用**纹理 ProgressBar（每格 = 背景纹理 + 前景纹理 = 2 DC）。改由单一 CanvasItem
`_draw()` 内 `draw_rect()` 纯色绘制：

```gdscript
## 角色位 HP 条——单一 _draw() 内纯色绘制（ADR-0031 §5）。
## 注（R-02 实测修正）：三个 draw_rect 是三次独立 draw command，并非一次绘制批次。
## fill 与 outline（filled=false）各为独立 DC——见 §5 实测结果。
func _draw() -> void:
    draw_rect(_bg_rect, COLOR_BG)          # 底槽
    draw_rect(_fg_rect, _color_by_ratio()) # 前景（红/黄/绿随比例）
    draw_rect(_bg_rect, COLOR_BORDER, false, 1.0)  # 边框（filled=false）
```

**规则**：
- HP 条自身是**自绘 Control**（一个 CanvasItem），不引入子节点。但**注意**（R-02 实测）：
  底槽 fill + 前景 fill + 边框 outline 三个 `draw_rect` 是 **3 次独立 draw call**，
  16 位合计 HP 条 ≈48 DC，而非预想的 16 DC。边框 outline 可裁剪（省 1 DC/条）。
- 颜色按比例分段（>50% 绿 / 20-50% 黄 / <20% 红），颜色常量集中定义（数据驱动）。
- 变化时 `queue_redraw()`（信号驱动，非 `_process()` 轮询——ADR-0031 §3）。
- 减少动态效果开启时跳过 HP 条平滑过渡动画，直接跳变。

---

## 3. 角色位 DC 分组方案：14 items → 3-4 draw call/位

| 分组 | 元素 | 合并方式 | DC 数 |
|------|------|---------|:---:|
| **头像** | 角色头像 | 独立纹理（每角色唯一，无法图集化） | 1 |
| **状态图标图集** | 状态效果 + 阵营 + 角标 + 边框 | 同一 `AtlasTexture` 图集批次 | 1 |
| **HP 条** | 底槽 + 前景 + 边框 | `_draw()` 自绘 | 1 |
| **文字** | 角色名/数值 Label | 字体图集（引擎默认合批） | 1 |

**合计（R-02 实测修正，2026-10-11）**：约 **6 DC/位**（头像 1 + 图集 1 + HP条 3 + 文字 1）。
预想的「4 DC/位」低估了 HP 条（3 个 draw_rect = 3 DC，非 1）与文字渲染开销。
16 位 × 6 = **96 DC**（角色位区实测）。按 GDD 峰值估算重算：
96（角色位）+ 50（手牌）+ 25（阵法/费用/日志）+ 30（峰值）≈ **201 DC**——紧贴 200 预算线。
→ **fallback 裁剪优先级（§4）不再是可选项，而是峰值场景的硬约束**。

**规则**：
- 角色位内部结构**不得**拆成 14 个独立子节点——状态图标全部挂同一 `AtlasTexture` 批次。
- 文字合并：同角色的名+数值合并到单一 Label（RichTextLabel 支持富文本），不拆多 Label。
- 前后排视觉区分（实线/虚线 + 100%/85% 缩放）用**同图集不同 region**，不引入额外纹理。

---

## 4. fallback 裁剪优先级（实测超预算时依次裁剪）

1. **战斗日志 → 纯文字 Label**（去背景矩形 + 去滚动条纹理）
2. **飘字数字 → 合并批量 RichTextLabel**（伤害/治疗数字并入单一下批量，去逐数字 Label）
3. **状态图标 → 减少同时显示上限**（超过 N 个仅显示最高优先级 N 个，其余折叠为「+k」角标）
4. 最后手段：头像降采样（256→128，半尺寸）+ 文字标签 50% 缩放隐藏（ADR-0031 §5 元素裁剪）

**注意**：SubViewport 渲染战斗日志**不减少 DC**（内部 draws + 1 合成纹理）——已从 GDD 移除该方案。

---

## 5. DC 测量方法

- **API**：`RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)`（R-02 查证存在，值 2）。
- **环境**：窗口模式本地运行（D3D12 默认）——**headless DC 不具代表性**。
- **采样**：连续 60 帧取稳定值（跳过前 5 帧预热）。
- **脚本**：`prototypes/r02-batching-spike/benchmark.gd`（009b 复用此测量方法）。
- **降级路径**：若 API 不可用 → Godot 内置调试器 Monitor 面板人工读数。

### 实测结果（2026-10-11，RTX 3050 Vulkan Forward+ 窗口模式）

| 测量 | 值 |
|------|-----|
| baseline（空场景） | 0 DC |
| full（16 角色卡） | 96 DC |
| 每角色位 | **6.0 DC**（目标 ≤4——**未达标**） |
| 整场景 DC 预算（GDD <200） | 96 远低于 200——**达标** |

**根因**：HP 条三个 draw_rect = 3 DC（非 1）；Label 文字渲染非单次 draw call。
**影响**：峰值场景重算 ≈201 DC（贴 200 线），§4 fallback 裁剪优先级升级为硬约束。

---

## 交付物清单

| 项 | 状态 |
|----|------|
| 图集结构定型（§1） | ✅ 本文 |
| HP 条 draw_rect 方式（§2） | ✅ 本文 |
| DC 分组方案（§3） | ✅ 本文 |
| fallback 优先级（§4） | ✅ 本文 |
| 测量方法（§5） | ✅ 本文 + rendering.md 回写 |
| 基准原型 16 角色卡实测 | ✅ 已测（2026-10-11 窗口模式）：16 卡 96 DC / 6.0 DC·位——见 §5 实测结果 |
