# R-05 节点图基准 spike（prototypes/r05-node-graph-benchmark）

## 测试假设

节点图渲染基座（单 Control `_draw()` 合批：图集 region + 边框 + 文字、
内置虚线连线、迷雾整体覆盖层）在 stub 最坏情况（6 层×4 节点 = 24 节点 +
层间全连接 80 连线 + 迷雾覆盖 16 节点 + 10 类图标）下，于 D3D12 窗口模式
达成 R-05 风险关闭标准：

- AC-1: 缩放平移 60s 帧时间 p95 ≤16.6ms（60fps）
- AC-2: 静态 + 缩放中两状态 DC ≤200
- AC-3: 迷雾增减时 DC 变化与迷雾节点数无强线性关系（合批验证——
  逐节点实例化会导致 DC 随节点数线性增长）

## 运行方式

窗口模式（headless DC 不具代表性——RenderingServer 帧统计需真实渲染后端）：

```
C:/Users/Administrator/Godot/Godot_v4.6.3-stable_win64.exe \
  --path E:/mortal-heaven-question \
  --script prototypes/r05-node-graph-benchmark/benchmark.gd
```

## 当前状态

已结束（2026-10-17）。

## 发现

- **三组数据全部通过**（D3D12 窗口模式 + VSync 关闭，RTX 3050，1280×720）：
  - AC-1 缩放平移帧时间 p95 = **2.04ms**（预算 16.6ms，余量 8 倍）
  - AC-2 静态 / 缩放中 DC = **90 / 90**（预算 200，stub 版基线值）
  - AC-3 迷雾 16→8 节点时 DC 90→73（**下降**非线性增长——整体覆盖层合批成立）
- **关键坑**：renderer Control size=0 时持续平移约 200 帧后整帧 DC 归零
  （canvas item 剔除——D3D12/Vulkan 均复现）。修复 = renderer 设
  `PRESET_FULL_RECT` 锚点。已固化到 `NodeGraphViewport._init`。
- **变换策略裁决**：Control scale/position 实测通过，无需 Camera2D 备选。
- 完整数据与签收：`production/qa/evidence/r05-node-graph-benchmark-evidence.md`
  （R-05 已关闭，story 010 真实元素复测义务登记在案）
