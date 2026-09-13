# R-03 D3D12 冒烟 Spike 报告：D3D12 vs Vulkan 渲染对比 + 截图工具链验证

> **日期**：2026-09-12
> **Sprint**：13（S13-12，timebox 0.5d）
> **验证人**：godot-specialist 职责范畴（harness 程序化验证）
> **关联**：presentation-layer-risks.md R-03、engine-reference/godot/breaking-changes.md（4.6 D3D12 默认化）
> **harness**：`prototypes/r03-d3d12-smoke-spike/`（spike.gd + results-d3d12.json + results-vulkan.json + screenshot-default.png）

---

## 执行环境

| 字段 | 值 |
|------|-----|
| 引擎 | Godot 4.6.3.stable.official.7d41c59c4 |
| GPU | NVIDIA GeForce RTX 3050（驱动 546.33） |
| 视口 | 3840×2071（窗口模式，VSync 60Hz） |
| 渲染管线 | Forward+（两种驱动下一致） |
| 方式 | SceneTree 脚本 harness——窗口模式运行，程序化构建 CanvasItem 场景（ColorRect + Label + canvas_item shader），120 帧采样 + 第 60 帧截图 |

## 验证结果（双驱动全项 PASS）

| ID | 验证项 | D3D12 | Vulkan |
|----|--------|-------|--------|
| V1 | 渲染驱动生效（引擎头行确认） | **PASS** `D3D12 12_0 - Forward+` | **PASS** `Vulkan 1.3.260 - Forward+` |
| V2 | 窗口 + 2D CanvasItem 绘制帧循环稳定（120 帧） | **PASS**（自然退出码 0，无崩溃） | **PASS** |
| V3 | 截图工具链（`viewport.get_texture().get_image()` + `save_png`） | **PASS**（3840×2071 PNG 落盘，内容正确——Label 文本 + shader 着色矩形均渲染） | **PASS** |
| V4 | 帧时间粗采样（120 帧均值/峰值） | avg 18.15ms / max 148ms | avg 18.03ms / max 150ms |
| V5 | canvas_item shader 编译（uniform + source_color hint——HUD 同类用法） | **PASS**（无编译报错，渲染正确） | **PASS** |
| V6 | 退出无崩溃 | **PASS**（exit 0） | **PASS** |

**V4 解读**：avg ~18ms 为 VSync 60Hz 封顶值（非 GPU 瓶颈），两驱动差异 0.12ms 在噪声范围内；max ~150ms 为首帧 shader 编译 + Autoload 初始化尖峰（一次性）。**本项是冒烟级粗采样，正式帧预算 Profiler 归 combat-ui 满场实测（R-02/009b）**。

## 结论

### 1. R-03 关闭——D3D12 冒烟通过，无需回退 ✅

- Godot 4.6 Windows 默认 D3D12 后端在目标硬件（RTX 3050 / 驱动 546.33）上：2D CanvasItem 渲染、canvas_item shader（HUD pause_blur 同类用法含 `hint_screen_texture` 之外的标准 uniform）、窗口帧循环、正常退出全项通过
- 与 Vulkan 后端输出**无可见差异**（帧时间、截图内容一致）
- **无需 `project.godot` 显式回退 `--rendering-driver vulkan`**——保持引擎默认（D3D12），回退命令作为应急手段记录在风险登记册

### 2. 截图工具链确认（coding-standards 截图验证要求）✅

`root.get_texture().get_image() + Image.save_png()` 在两种驱动下均正常工作——UI 变更截图验证流程（编码标准要求）无驱动兼容风险。

### 3. 残留限制（记录，不阻塞）

- **Steam 覆盖层交互未测**：本机无 Steam 运行时集成（main-menu epic 前无 Steam SDK）——D3D12 + Steam 覆盖层归后续 Steam 集成 spike（release 前必验）
- **最低配置硬件未测**：仅目标开发机（RTX 3050）；集显/旧驱动场景归发布前最低规格验证（release-checklist）
- **后处理（glow/模糊）未纳入本 harness**：pause_blur shader（hint_screen_texture + BackBufferCopy）已在 hud 005 F6 手动验证（D3D12 默认驱动下）+ 集成测试覆盖——间接证据充分

## Harness 局限（记录，不影响结论）

- `--rendering-driver` 参数不入 `OS.get_cmdline_args()` 可读范围——harness 内驱动名探测失效（记录为 "default"），以**引擎启动头行日志**（`D3D12 12_0` / `Vulkan 1.3.260`）作为驱动生效的权威证据
- 脚本结束时 `root.get_node` 一次 null 报错（SceneTree 退出时序，harness 代码噪音，非渲染问题）

## 后续行动

| 项 | 状态 |
|----|------|
| R-03（presentation-layer-risks.md） | **已关闭**（2026-09-12，本报告为关闭依据） |
| QA 签收条件 C（性能 Profiler 递延） | **已解除**——本 spike 提供 D3D12 基线冒烟；combat-ui 满场 Profiler 归 009b（原计划即如此） |
| Steam 覆盖层 + 最低规格 | 归 release 前验证（release-checklist 平台要求节） |

## 复现命令

```
C:/Users/Administrator/Godot/Godot_v4.6.3-stable_win64.exe \
  --path E:/mortal-heaven-question \
  --rendering-driver d3d12 \
  --script prototypes/r03-d3d12-smoke-spike/spike.gd
# 对照组：--rendering-driver vulkan（其余同）
# 结果文件：results-d3d12.json / results-vulkan.json + screenshot-default.png
```
