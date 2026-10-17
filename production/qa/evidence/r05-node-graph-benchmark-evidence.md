# R-05 节点图基准证据（stub 版）——最坏情况缩放平移帧率 + DC 关口

> **日期**：2026-10-17
> **Story**：exploration-ui 001（节点图渲染基座与 R-05 性能基准——R-05 行为关卡）
> **原型**：`prototypes/r05-node-graph-benchmark/`（benchmark.gd 复用 R-02 测量方法）
> **测量方法**：`RenderingServer.get_rendering_info(RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)` delta 基线（空场景）+ 60 帧稳定均值；帧时间 `Time.get_ticks_usec()` 逐帧采样 + p50/p95/p99 分位
> **实测环境**：Godot 4.6.3 / **D3D12 Forward+**（RTX 3050）窗口模式 1280×720——story 指定 D3D12 实测（headless DC 不具代表性）；**VSync 关闭**（R-02 先例：VSync 锁定时 p50 恒 16.66ms 遮蔽真实帧预算）
> **结论定性**：**stub 版基线**（程序化图集近似真实美术图标）——story 010 真实元素复测时对照

---

## 1. 基准场景（stub 最坏情况）

- **DAG 规模**：6 层 × 4 节点 = 24 节点（GDD 极高难度上限，含入口/Boss）
- **连线数**：层间全连接 80 条（每节点连向下一层全部 4 节点——最坏逼近）
- **迷雾覆盖**：16/24 节点 >50%（已访问仅前 3 层）
- **图标覆盖**：全部 10 类节点类型（图集 320×32 程序化 stub）
- **渲染基座**：`NodeGraphRenderer`（单 Control `_draw()` 合批——边 + 节点 + 迷雾整体覆盖层）+ `NodeGraphViewport`（Control scale/position 变换——story 实现说明「Control 内部变换 vs Camera2D」实测裁决项）

## 2. AC-1 缩放平移帧时间（60s 驱动采样 / 600 帧）

驱动方式：每帧滚轮步进（50%↔150% 方向每 60 帧翻转，光标锚定缩放，0.2s 平滑 Tween）+ 每 120 帧中键拖拽平移脉冲（10 步 × (6,-4)px）。

| 分位 | 实测 | 目标 | 判定 |
|------|-----:|-----:|:----:|
| p50 | 1.32 ms | — | ✅ |
| p95 | **2.04 ms** | ≤16.6ms | ✅ 余量 8 倍 |
| p99 | 2.61 ms | — | ✅ |

**结论**：缩放平移全程帧时间 p95 = 2.04ms，远低于 16.6ms 预算（60fps）。
合批架构下单 Control 自绘的重绘成本（约 24 节点 × 3 笔 + 80 连线 + 迷雾 2 笔）
在缩放变换期间不构成帧预算压力。**附注**：VSync 开启时 p50 恒 16.66ms
（R-02 同现象——帧率锁定表象），关闭后实测真实合成耗时 <3ms。

## 3. AC-2 Draw Call 基准（两状态）

| 状态 | DC（净值） | 整帧 DC | 预算 | 判定 |
|------|-----------:|--------:|-----:|:----:|
| baseline（空场景） | 0 | 0 | — | — |
| 静态（stub 最坏情况全量渲染） | **90** | 90 | ≤200 | ✅ 达标 |
| 缩放中（50%-150% 变换中，终值 zoom≈0.95） | **90** | 90 | ≤200 | ✅ 达标 |

**基准值记录**（story 010 复测对照）：**stub 版 DC = 90**。分解：节点纹理
24 笔（同图集合批）+ 连线约 60 笔（draw_line/draw_dashed_line 逐条——虚线
内部分段不增 DC）+ 迷雾 2 笔（整体 fog_rect + 挖孔圆合并）+ 文字若干笔。

**结论**：静态与缩放中 DC 一致（90 = 90）——缩放平移变换不引入额外绘制
（Control scale 变换复用同一 canvas item 命令流，符合 ADR-0031 §5 预期）。

## 4. AC-3 迷雾合批验证

| 场景 | 迷雾节点数 | DC（净值） | 变化 |
|------|-----------:|-----------:|-----:|
| 已访问前 3 层 | 16 | 90 | 基准 |
| 已访问前 5 层（揭雾） | 8 | 73 | **-17** |

**结论**：迷雾覆盖节点数减半（16→8）时 DC **下降** 17（文字标签恢复
显示 + 挖孔圆增加所致），而非随迷雾节点数线性增长——**迷雾为整体覆盖层
单笔绘制**（`_draw_fog`：1 fog_rect + N 挖孔圆），非逐节点实例化。
ADR-0031「迷雾遮罩等大面积重复元素合批渲染」直接验证通过。

## 5. 实现要点与发现

- **变换策略裁决**（story 实现说明遗留项）：Control scale/position 方案
  实测通过（p95 2.04ms / DC 不变），无需 Camera2D 备选方案。
- **发现（调试期）**：renderer Control size 为 0 时，持续平移约 200 帧后
  整帧 DC 归零（canvas item 被剔除——绘制区域为 0 时 Godot 4.6 在
  D3D12/Vulkan 下均复现）。修复：renderer 设 `PRESET_FULL_RECT` 锚点
  保证非零绘制区域。此为 `NodeGraphViewport._init` 的固化实现依据。
- **引擎 API 防猜测验证**（S14-4a spike 延续）：`draw_rect_modulate` 不存在
  （迷雾灰底改 draw_rect + glyph 叠加）；`draw_dashed_line` 存在（签名
  width=-1.0, dash=2.0, aligned=true——替代手写虚线段循环）。
- **优化路径**（AC-5 前置——本基准未触发需优化条件）：预算余量充足
  （帧时间 8 倍 / DC 余量 110），图集 LOD（缩放 <75% 切换低精度图标）
  路径已预留（`NodeIconAtlas.get_atlas` 单一替换点）但无需启用。

## 6. 复现命令

```
C:/Users/Administrator/Godot/Godot_v4.6.3-stable_win64.exe \
  --path E:/mortal-heaven-question \
  --rendering-driver d3d12 \
  --script prototypes/r05-node-graph-benchmark/benchmark.gd
```

---

## 签收表

| 角色 | 结论 | 签收 |
|------|------|:----:|
| ui-programmer（实现） | AC-1 p95=2.04ms ✅；AC-2 两状态 DC=90 ✅；AC-3 迷雾合批 ✅ | [x] Approved |
| qa-lead（测试） | stub 版基准证据归档；story 010 真实元素复测义务登记 | [x] Approved |
| lead-programmer（技术） | 单 _draw 合批 + Control 变换方案成立；size=0 剔除坑已固化规避 | [x] Approved |

*独立开发者——所有角色由同一人签收。*

---

## 复测义务登记

1. **exploration-ui story 010（真实元素性能复测）**：真实美术图标替换程序化
   图集后，复跑本基准对照 stub 版基线（DC=90 / p95=2.04ms）+ 揭雾动画
   （渐变期间的 DC 与帧时间）+ 720p 自适应终验。
