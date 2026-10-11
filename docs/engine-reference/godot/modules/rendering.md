
# Godot 渲染 (Rendering) — 快速参考

最近验证：2026-02-12 | 引擎：Godot 4.6

## 自 ~4.3（LLM 知识截止）以来的变化

### 4.6 变化
- **D3D12 成为 Windows 上的默认渲染后端**（原为 Vulkan）
- **Glow 在色调映射 (tonemapping) 之前处理**（原为之后）— 使用屏幕混合模式
- **AgX 色调映射器**：新增白点和对比度控制
- **SSR 重构**：更好的真实感、视觉稳定性和性能

### 4.5 变化
- **Shader Baker**：预编译着色器以减少启动时间
- **SMAA 1x**：新的抗锯齿选项（比 FXAA 更锐利，比 TAA 更便宜）
- **模板缓冲 (Stencil buffer) 支持**：启用选择性几何体遮罩/传送门效果
- **Bent normal maps**：在法线贴图纹理中编码方向性遮蔽
- **高光遮蔽 (Specular occlusion)**：环境光遮蔽现在能正确影响反射

### 4.4 变化
- **`RenderingDevice.draw_list_begin`**：移除了许多参数；新增可选的 `breadcrumb`
- **着色器纹理类型**：从 `Texture2D` 改为 `Texture` 基类型
- **粒子 `.restart()`**：新增可选的 `keep_seed` 参数

### 4.3 变化（已在训练数据中）
- **Compositor 节点**：`Compositor` + `CompositorEffect` 用于后处理链

## 当前 API 模式

### 后处理 (Post-Processing)（4.3+）
```gdscript
# Use Compositor node — NOT manual viewport shader chains
# Add Compositor as child of WorldEnvironment or Camera3D
# Create CompositorEffect resources for each post-process step
```

### 抗锯齿选项（4.6）
```
Project Settings → Rendering → Anti Aliasing:
- MSAA 2D/3D: Hardware MSAA (quality but expensive)
- Screen Space AA: FXAA (fast, blurry) or SMAA (sharp, moderate cost)  # SMAA new in 4.5
- TAA: Temporal (best quality, ghosting on fast motion)
```

### 渲染后端选择（4.6）
```
Project Settings → Rendering → Renderer:
- Forward+ (default): Full featured, desktop-focused
- Mobile: Optimized for mobile/low-end, limited features
- Compatibility: OpenGL 3.3 / WebGL 2, broadest hardware support

Windows default backend: D3D12 (was Vulkan pre-4.6)
```

## 常见错误
- 假设 Vulkan 是 Windows 上的默认后端（自 4.6 起为 D3D12）
- 使用手动 viewport 链而非 Compositor 进行后处理
- 在着色器 uniform 类型中使用 `Texture2D`（自 4.4 起应使用 `Texture`）
- 对于有着色器变体众多的项目未使用 Shader Baker

## Draw Call 测量 API（4.6 现状——R-02 spike 查证 2026-10-11）

`RenderingServer.get_rendering_info()` **存在**于 Godot 4.6.3（R-02 spike 反射查证，
原型 `prototypes/r02-batching-spike/`，实机 RTX 3050 Vulkan Forward+ 非 headless 运行）。

- **签名**：`int get_rendering_info(RenderingServer.RenderingInfo info)`——返回对应计数器值。
- **`RenderingServer.RenderingInfo` 枚举**（实测 4.6.3 反射值）：
  ```
  RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME            = 0
  RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME         = 1
  RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME         = 2   ← Draw Call 测量用此
  RENDERING_INFO_TEXTURE_MEM_USED                  = 3
  RENDERING_INFO_BUFFER_MEM_USED                   = 4
  RENDERING_INFO_VIDEO_MEM_USED                    = 5
  RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS      = 6
  RENDERING_INFO_PIPELINE_COMPILATIONS_MESH        = 7
  RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE     = 8
  RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW        = 9
  RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION = 10
  ```
- **headless DC 数不具代表性**：测量须窗口模式本地运行（Windows 默认后端为 D3D12，
  非 Vulkan）。`get_rendering_info` 在 dummy/headless 渲染器下返回 0。
- **单 Viewport 测量**：`Viewport.get_render_info(Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)`
  按 Viewport 统计（全场景预算用 RenderingServer 全局计数，单层诊断用 Viewport 计数）。
- 相关：`viewport_get_measured_render_time_cpu/gpu`、`viewport_set_measure_render_time`。
