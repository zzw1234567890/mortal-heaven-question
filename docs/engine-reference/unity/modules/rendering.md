
# Unity 6.3 — 渲染模块参考

**最后验证：** 2026-02-13
**知识缺口：** LLM 基于 Unity 2022 LTS 训练；Unity 6 在渲染方面有重大变更

---

## 概述

Unity 6.3 LTS 使用 **Scriptable Render Pipelines (SRP)** 作为现代渲染架构：
- **URP (Universal Render Pipeline)**：跨平台、对移动端友好（推荐）
- **HDRP (High Definition Render Pipeline)**：面向高端 PC/主机，照片级真实感
- **Built-in Pipeline**：已弃用，新项目应避免使用

---

## 相较 2022 LTS 的关键变更

### RenderGraph API（Unity 6+）
自定义渲染通道现在使用 RenderGraph 而非 CommandBuffer：

```csharp
// ✅ Unity 6+ (RenderGraph)
public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData) {
    using var builder = renderGraph.AddRasterRenderPass<PassData>("MyPass", out var passData);
    builder.SetRenderFunc((PassData data, RasterGraphContext ctx) => {
        // Rendering commands
    });
}

// ❌ Old (CommandBuffer - still works but deprecated)
public override void Execute(ScriptableRenderContext context, ref RenderingData data) { }
```

### GPU Resident Drawer（Unity 6+）
自动合批，大幅减少 draw call：

```csharp
// Enable in URP Asset settings:
// Rendering > GPU Resident Drawer = Enabled
// Automatically batches thousands of objects with minimal CPU overhead
```

---

## URP 快速参考

### 创建 URP Asset
1. `Assets > Create > Rendering > URP Asset (with Universal Renderer)`
2. 分配到 `Project Settings > Graphics > Scriptable Render Pipeline Settings`

### URP Renderer Feature
添加自定义渲染通道：

```csharp
using UnityEngine.Rendering.Universal;

public class OutlineRendererFeature : ScriptableRendererFeature {
    OutlineRenderPass pass;

    public override void Create() {
        pass = new OutlineRenderPass();
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData data) {
        renderer.EnqueuePass(pass);
    }
}
```

---

## 材质与着色器

### Shader Graph（可视化着色器编辑器）
Unity 6 的 Shader Graph 已达到生产可用，适用于所有着色器类型：

```csharp
// Create: Assets > Create > Shader Graph > URP > Lit Shader Graph
// No code needed, visual node-based editing
```

### HLSL 自定义着色器（URP）

```hlsl
// URP Lit shader template
Shader "Custom/URPLit" {
    Properties {
        _BaseColor ("Base Color", Color) = (1,1,1,1)
    }
    SubShader {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }

        Pass {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes {
                float4 positionOS : POSITION;
            };

            struct Varyings {
                float4 positionCS : SV_POSITION;
            };

            Varyings vert(Attributes input) {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                return output;
            }

            half4 frag(Varyings input) : SV_Target {
                return half4(1, 0, 0, 1); // Red
            }
            ENDHLSL
        }
    }
}
```

---

## 光照

### 烘焙光照（Unity 6 Progressive Lightmapper）

```csharp
// Mark objects as static: Inspector > Static > Contribute GI
// Bake: Window > Rendering > Lighting > Generate Lighting
```

### 实时光照（URP）

```csharp
// Main Light (Directional): Auto-handled by URP
// Additional Lights: Limited by "Additional Lights" setting in URP Asset

// Check light count in shader:
int lightCount = GetAdditionalLightsCount();
```

---

## 后处理

### Volume 系统（Unity 6+）

```csharp
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

// Add Volume component to GameObject
// Add Volume Profile asset
// Configure effects: Bloom, Color Grading, Depth of Field, etc.

// Script access:
Volume volume = GetComponent<Volume>();
if (volume.profile.TryGet<Bloom>(out var bloom)) {
    bloom.intensity.value = 2.5f;
}
```

---

## 性能

### SRP Batcher（自动合批）

```csharp
// Enable: URP Asset > Advanced > SRP Batcher = Enabled
// Batches draws with same shader variant (minimal CPU overhead)
```

### GPU Instancing

```csharp
// Material: Enable "Enable GPU Instancing" checkbox
// Batches identical meshes (same material + mesh)

Graphics.RenderMeshInstanced(
    new RenderParams(material),
    mesh,
    0,
    matrices // NativeArray<Matrix4x4>
);
```

### 遮挡剔除

```csharp
// Window > Rendering > Occlusion Culling
// Bake occlusion data for static geometry
```

---

## 常见模式

### 自定义相机渲染

```csharp
// Get URP camera data
var cameraData = frameData.Get<UniversalCameraData>();
var camera = cameraData.camera;

// Access render targets
var colorTarget = cameraData.renderer.cameraColorTargetHandle;
```

### 屏幕空间效果

```csharp
// Create ScriptableRendererFeature
// Inject pass at specific point: AfterRenderingOpaques, AfterRenderingTransparents, etc.
```

---

## 调试

### Frame Debugger
- `Window > Analysis > Frame Debugger`
- 逐步查看 draw call，检查状态

### Rendering Debugger（Unity 6+）
- `Window > Analysis > Rendering Debugger`
- 实时查看 URP 设置、过度绘制、光照

---

## 来源
- https://docs.unity3d.com/Packages/com.unity.render-pipelines.universal@17.0/manual/index.html
- https://docs.unity3d.com/6000.0/Documentation/Manual/render-pipelines.html
