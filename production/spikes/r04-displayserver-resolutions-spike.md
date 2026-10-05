# R-04 分辨率枚举 API Spike 报告

> **日期**：2026-10-05
> **Sprint**：14（S14-4a，timebox 0.5d）
> **验证人**：spike.gd 自动化探针（Godot 4.6.3 headless Vulkan Forward+）
> **关联**：main-menu 003 前置（QL-STORY-READY 2026-09-19 裁决）、ADR-0031 §2.1
> **探针**：`prototypes/r04-displayserver-resolutions-spike/spike.gd`

---

## 执行环境

| 字段 | 值 |
|------|-----|
| 引擎 | Godot 4.6.3.stable.official.7d41c59c4 |
| 渲染 | Vulkan 1.3.260 Forward+ / D3D12（Windows 默认） |
| GPU | NVIDIA GeForce RTX 3050 |
| 显示器 | 双屏（Screen 0: 3840×2160, Screen 1: 1920×1080 推测） |
| 方式 | `ClassDB.class_get_method_list("DisplayServer")` 反射查证 + 关键 API 实际调用 |

---

## 核心发现

### 1. `screen_get_resolutions()` **不存在**于 Godot 4.6 DisplayServer ❌

反射扫描 DisplayServer 全部 ~80 个方法中**无 `screen_get_resolutions`**，实际调用亦确认为 `[缺失]`。该方法不是 4.6 新增 API——是 LLM 训练数据中的误记/幻觉。

### 2. 分辨率枚举替代方案：`screen_get_size(screen_index)` + `get_screen_count()`

| API | 存在性 | 实测值 | 用途 |
|-----|:--:|------|------|
| `get_screen_count()` | ✅ | 2 | 枚举多显示器 |
| `screen_get_size(screen_index)` | ✅ | Screen 0 = (3840, 2160) | 取各显示器当前分辨率 |
| `get_primary_screen()` | ✅ | 0 | 确定主显示器 |
| `screen_get_dpi(screen_index)` | ✅ | — | 可选过滤低 DPI 显示 |

**结论**：可用分辨率枚举必须用 `get_screen_count()` + `screen_get_size(screen_index)` 手动组合——不是单次 API 调用返回列表。

### 3. 全屏/窗口切换 API

| API | 存在性 | 值 | 备注 |
|-----|:--:|------|------|
| `window_get_mode()` | ✅ | 2 (WINDOW_MODE_MAXIMIZED) | 当前窗口模式 |
| `window_set_mode(mode)` | ✅ | — | 设置窗口模式 |
| `window_get_size()` | ✅ | (1920, 1080) | 当前窗口尺寸 |
| `window_set_size(Vector2i)` | ✅ | — | 设置窗口尺寸 |

**`window_set_fullscreen()` 和 `is_window_fullscreen()` 均不存在**——全屏切换必须走 `window_set_mode(WINDOW_MODE_FULLSCREEN / WINDOW_MODE_WINDOWED)` 路径。

### 4. WindowMode 枚举（完整）

```
WINDOW_MODE_WINDOWED          = 0
WINDOW_MODE_MINIMIZED         = 1
WINDOW_MODE_MAXIMIZED         = 2
WINDOW_MODE_FULLSCREEN        = 3
WINDOW_MODE_EXCLUSIVE_FULLSCREEN = 4  （4.6 新增——LLM 知识截止后）
```

### 5. Engine 层帧率控制

`Engine.max_fps = 0`（当前取值为 0 = 不限帧）。支持任意正整数——story 003 的 30/60/120/不限(→0) 实现无 API 障碍。

---

## 对 main-menu 003 的影响

| 原假设 | Spike 结论 | 003 调整 |
|--------|-----------|---------|
| `screen_get_resolutions()` 可能是 4.6 新增 API | ❌ 不存在 | 003 须用 `get_screen_count()` + `screen_get_size()` 手动枚举 |
| 全屏切换用 `window_set_fullscreen(bool)` | ❌ 不存在 | 003 须用 `window_set_mode(WINDOW_MODE_*)` |
| 分辨率列表格式为 `Array[Vector2i]` | ✅ 可行 | `screen_get_size()` 返回 `Vector2i`——直接泛用 |

**003 实现建议**：
1. 分辨率枚举函数：遍历 `get_screen_count()` → `screen_get_size(i)` → 去重 + 过滤低于 1280×720 的条目 → 宽高比过滤（保持桌面宽高比）→ 返回排序列表
2. 全屏切换：`window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)` / `WINDOW_MODE_WINDOWED`
3. 窗口分辨率变更：`window_set_size(Vector2i(width, height))`
4. 头注释标注：「分辨率枚举不使用 `screen_get_resolutions()`——该方法在 Godot 4.6.3 DisplayServer 中不存在（R-04 spike 查证 2026-10-05）」

---

## 引擎参考回填

本 spike 产出应回写到 `docs/engine-reference/godot/modules/rendering.md`（或新建 `modules/display-server.md`），新增 DisplayServer 分辨率/窗口 API 小节。建议条目：

```markdown
## DisplayServer 分辨率/窗口 API（4.6 现状——R-04 spike 查证 2026-10-05）

- `screen_get_resolutions()`: **不存在**（非 4.6 新增 API——LLM 训练数据误记）
- 分辨率枚举替代: `get_screen_count()` + `screen_get_size(screen_index)`
- 全屏切换: `window_set_mode(WINDOW_MODE_FULLSCREEN / WINDOW_MODE_WINDOWED / WINDOW_MODE_EXCLUSIVE_FULLSCREEN)`
- `window_set_fullscreen()` / `is_window_fullscreen()`: **不存在**
- `window_get_size()` / `window_set_size(Vector2i)`: 存在
```

---

## 后续行动

| 项 | 状态 |
|----|------|
| R-04 spike S14-4a | **已关闭**（本报告为关闭依据） |
| 引擎参考回填 | 待写入 `docs/engine-reference/godot/modules/` |
| main-menu 003 解锁 | ✅ S14-4 可开工（API 查证完成——无阻塞） |
| sprint-status 14-4a → done | 待更新 |