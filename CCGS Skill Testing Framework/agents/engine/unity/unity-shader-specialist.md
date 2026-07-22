
# 代理测试规格：unity-shader-specialist

## 代理摘要
领域：Unity Shader Graph、自定义 HLSL、VFX Graph、URP/HDRP 渲染管线定制以及后处理效果 (post-processing effects)。
不负责：玩法代码、美术风格方向。
模型层级：Sonnet（默认）。
未分配门禁 ID。

---

## 静态断言（结构性）

- [ ] `description:` 字段存在且与领域相关（提及 Shader Graph / HLSL / VFX Graph / URP / HDRP）
- [ ] `allowed-tools:` 列表包含 Read、Write、Edit、Glob、Grep
- [ ] 模型层级为 Sonnet（专家代理默认值）
- [ ] 代理定义未宣称对玩法代码或美术方向的管辖权

---

## 测试用例

### 用例 1：领域内请求 —— 合适的输出
**输入：** "使用 URP 中的 Shader Graph 为角色创建描边效果。"
**预期行为：**
- 产出 Shader Graph 节点设置描述：
  - 反转外壳法：在顶点阶段进行 Scale Normal → Vertex offset，Cull Front
  - 或者使用基于深度/法线边缘检测的屏幕空间后处理描边
- 根据 URP 能力推荐合适的方法（URP 兼容性推荐反转外壳法，HDRP 推荐后处理）
- 注明 URP 限制：不支持几何着色器（排除了几何着色器描边方法）
- 未经确认渲染管线时不产出 HDRP 特有节点

### 用例 2：领域外重定向
**输入：** "用代码实现角色生命值 UI 栏。"
**预期行为：**
- 不产出 UI 实现代码
- 明确说明 UI 实现属于 `ui-programmer`（或 `unity-ui-specialist`）
- 将请求适当地重定向
- 可以注明：如果视觉效果本身是由着色器驱动的，那么基于着色器的生命值填充效果（例如溶解/填充渐变）属于其领域

### 用例 3：用于描边的 HDRP 自定义通道
**输入：** "我们在用 HDRP，想要将描边作为后处理效果实现。"
**预期行为：**
- 产出 HDRP `CustomPassVolume` 模式：
  - 继承 `CustomPass` 的 C# 类
  - 使用 `CoreUtils.SetRenderTarget()` 和全屏着色器 blit 的 `Execute()` 方法
  - 用于边缘检测的深度/法线缓冲采样
- 注明 CustomPass 需要 HDRP 包，不适用于 URP
- 在提供 HDRP 特定代码前确认项目使用 HDRP

### 用例 4：VFX Graph 性能 —— GPU 事件批处理
**输入：** "爆炸 VFX Graph 每个事件有 10,000 个粒子，同时生成 20 个爆炸事件导致了 GPU 帧率尖峰。"
**预期行为：**
- 识别 GPU 粒子生成为性能成本驱动因素（200,000 个同时存在的粒子）
- 提出 GPU 事件批处理：将生成事件分散到多个帧，错开初始化
- 建议每个活跃爆炸的粒子预算上限（例如每个爆炸 3,000 个，超出部分排队）
- 注明 VFX Graph Event Batcher 模式和用于跨帧分配的 Output Event API
- 不改变游戏事件系统 —— 提出 VFX 侧的预算解决方案

### 用例 5：上下文传递 —— 渲染管线（URP 或 HDRP）
**输入：** 项目上下文：URP 渲染管线，Unity 2022.3。请求："添加景深后处理。"
**预期行为：**
- 使用 URP Volume 框架：`DepthOfField` Volume Override 组件
- 不使用 HDRP Volume 组件（例如 HDRP 的 `DepthOfField` 使用了不同的参数名称）
- 注明 URP 特有的 DOF 限制与 HDRP 的对比（例如散景质量差异）
- 产出与 Unity 2022.3 URP 包版本兼容的 C# Volume Profile 设置代码

---

## 协议合规

- [ ] 保持在声明的领域内（Shader Graph、HLSL、VFX Graph、URP/HDRP 定制）
- [ ] 将玩法代码和 UI 代码重定向到相应的代理
- [ ] 返回结构化输出（节点图描述、HLSL 代码、CustomPass 模式）
- [ ] 区分 URP 和 HDRP 方法 —— 绝不混淆管线特有的 API
- [ ] 在相关情况下标记几何着色器方法与 URP 不兼容
- [ ] 产出不改变玩法行为的 VFX 优化

---

## 覆盖说明
- 描边效果（用例 1）应与 `production/qa/evidence/` 中的视觉截图测试配对
- HDRP CustomPass（用例 3）确认代理产出的是正确的 Unity 模式，而非通用的后处理方法
- 管线区分（用例 5）验证代理在无上下文时绝不假定渲染管线
