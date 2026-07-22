
# Unreal Engine 5.7 — PCG (Procedural Content Generation，程序化内容生成)

**最后验证：** 2026-02-13
**状态：** 生产可用（自 UE 5.7 起）
**插件：** `PCG`（内置，在 Plugins 中启用）

---

## 概览

**Procedural Content Generation (PCG)** 是 Unreal 的基于节点的框架，用于大规模生成程序化内容。它面向用植被、岩石、道具、建筑和其他环境细节填充大型开放世界。

**在以下场景使用 PCG：**
- 程序化植被放置（树木、草、岩石）
- 基于生物群落 (Biome) 的环境生成
- 道路/路径生成
- 建筑/结构放置
- 世界细节填充（道具、杂物）

**在以下场景不要使用 PCG：**
- 玩法逻辑（使用 Blueprint/C++）
- 一次性手动放置（使用编辑器工具）

**⚠️ 注意：** PCG 在 UE 5.0-5.6 中为实验性，在 UE 5.7 中成为生产可用。

---

## 核心概念

### 1. **PCG Graph**
- 基于节点的图（类似材质编辑器）
- 定义生成规则

### 2. **PCG Component**
- 放置在关卡中，执行 PCG Graph
- 在定义的体积内生成内容

### 3. **PCG Data**
- 点数据（位置、旋转、缩放）
- 样条数据（路径、道路、河流）
- 体积数据（密度、生物群落遮罩）

### 4. **节点 (Nodes)**
- **Samplers（采样器）**：生成点（Grid、Poisson、Surface）
- **Filters（过滤器）**：按规则移除点（Density、Tag、Bounds）
- **Modifiers（修改器）**：变换点（Offset、Rotate、Scale）
- **Spawners（生成器）**：在点处实例化网格体/Actor

---

## 设置

### 1. 启用插件

`Edit > Plugins > PCG > Enabled > Restart`

### 2. 创建 PCG Volume

1. Place Actors > Volumes > PCG Volume
2. 将体积缩放到所需的生成区域

### 3. 创建 PCG Graph

1. Content Browser > PCG > PCG Graph
2. 打开 PCG Graph Editor

---

## 基础工作流

### 示例：森林生成

#### 1. 创建 PCG Graph

**节点设置：**
```
Input (Volume)
  ↓
Surface Sampler (sample volume surface, points per m²: 0.5)
  ↓
Density Filter (use texture mask or noise)
  ↓
Static Mesh Spawner (tree meshes)
  ↓
Output
```

#### 2. 将 Graph 指派给 Volume

1. 选中 PCG Volume
2. Details Panel > PCG Component > Graph = 你的 PCG Graph
3. 点击“Generate”按钮

---

## 关键节点类型

### Samplers（点生成）

#### Grid Sampler
- 规则的点网格
- 配置：
  - **Grid Size**：点间距
  - **Offset**：每个点的随机偏移

#### Poisson Disk Sampler
- 具有最小间距的随机点
- 配置：
  - **Points Per m²**：密度
  - **Min Distance**：点之间的间距

#### Surface Sampler
- 在网格体表面或地形上生成点
- 配置：
  - **Points Per m²**：密度
  - **Surface Only**：仅表面，不含体积

---

### Filters（点移除）

#### Density Filter
- 根据密度值移除点
- 输入：纹理或噪声
- 用途：生物群落遮罩、空地、路径

#### Tag Filter
- 按标签过滤点
- 用途：条件化生成

#### Bounds Filter
- 仅保留边界内的点
- 用途：将生成限制在特定区域

---

### Modifiers（点变换）

#### Rotate
- 随机化点旋转
- 配置：
  - **Min/Max Rotation**：每轴旋转范围

#### Scale
- 随机化点缩放
- 配置：
  - **Min/Max Scale**：缩放范围

#### Project to Ground
- 将点吸附到地形表面

---

### Spawners（网格体/Actor 实例化）

#### Static Mesh Spawner
- 在点处生成静态网格体
- 配置：
  - **Mesh List**：网格体数组（随机选择）
  - **Culling Distance**：LOD/剔除设置

#### Actor Spawner
- 在点处生成 Blueprint Actor
- 用途：玩法 Actor、可交互对象

---

## 数据源

### Landscape（地形）
- 使用地形作为采样输入
- 自动投影到地形高度

### Splines（样条）
- 沿样条生成内容（道路、河流、路径）
- 示例：沿路径的树木

### Textures（纹理）
- 使用纹理作为密度遮罩
- 绘制生物群落、空地、区域

---

## 生物群落示例（混合森林）

### Graph 设置

```
Input (Landscape)
  ↓
Surface Sampler (density: 1.0)
  ↓
┌─────────────────┬─────────────────┐
│ Tree Biome      │ Rock Biome      │
│ (density > 0.5) │ (density < 0.5) │
├─────────────────┼─────────────────┤
│ Tree Spawner    │ Rock Spawner    │
└─────────────────┴─────────────────┘
  ↓
Merge
  ↓
Output
```

---

## 基于样条的生成（带树木的道路）

### 1. 创建 PCG Graph

```
Spline Input
  ↓
Spline Sampler (sample along spline)
  ↓
Offset (offset from spline path)
  ↓
Tree Spawner
  ↓
Output
```

### 2. 向 PCG Volume 添加 Spline Component

1. PCG Volume > Add Component > Spline
2. 绘制样条路径
3. PCG Graph 读取样条数据

---

## 运行时生成

### 从 C++ 触发生成

```cpp
#include "PCGComponent.h"

UPCGComponent* PCGComp = /* Get PCG Component */;
PCGComp->Generate(); // Execute PCG graph
```

### 流式生成（大型世界）

- PCG 自动与 World Partition 一起流式加载
- 仅在已加载的单元格中生成内容

---

## 性能

### 优化建议

- 对生成的网格体使用 **culling distance**（LOD）
- 限制 **density**（点越少性能越好）
- 对重复网格体使用 **Hierarchical Instanced Static Meshes (HISM)**
- 为大型世界启用 **streaming**

### 调试性能

```cpp
// Console commands:
// pcg.graph.debug 1 - Show PCG debug info
// stat pcg - Show PCG performance stats
```

---

## 常见模式

### 带空地的森林

```
Surface Sampler
  ↓
Density Filter (noise texture with clearings)
  ↓
Tree Spawner (pine, oak, birch)
```

---

### 陡坡上的岩石

```
Landscape Input
  ↓
Surface Sampler
  ↓
Slope Filter (angle > 30°)
  ↓
Rock Spawner
```

---

### 沿道路的道具

```
Spline Input (road spline)
  ↓
Spline Sampler
  ↓
Offset (side of road)
  ↓
Street Light Spawner
```

---

## 调试

### PCG 调试可视化

```cpp
// Console commands:
// pcg.debug.display 1 - Show points and generation bounds
// pcg.debug.colormode points - Color-code points
```

### Graph 调试

- PCG Graph Editor > Debug > Show Debug Points
- 在图中每个节点处可视化点

---

## 从 UE 5.6（实验性）迁移到 5.7（生产）

### API 变更

```cpp
// ❌ OLD (5.6 experimental API):
// Some nodes renamed, API unstable

// ✅ NEW (5.7 production API):
// Stable node types, documented API
```

**迁移：** 使用稳定的 5.7 节点重建 PCG Graph。充分测试。

---

## 限制

- **不用于玩法逻辑**：游戏规则请使用 Blueprint/C++
- **大型图可能较慢**：通过过滤器和降低密度优化
- **运行时生成开销**：尽可能预先生成

---

## 来源
- https://docs.unrealengine.com/5.7/en-US/procedural-content-generation-in-unreal-engine/
- https://docs.unrealengine.com/5.7/en-US/pcg-quick-start-in-unreal-engine/
- UE 5.7 Release Notes（PCG 生产可用公告）
