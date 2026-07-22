
# Unreal Engine 5.7 — 渲染模块参考

**最后验证：** 2026-02-13
**知识缺口：** UE 5.7 引入 Megalights、生产可用的 Substrate 以及 Lumen 改进

---

## 概览

UE 5.7 渲染栈：
- **Lumen**：实时全局光照（默认）
- **Nanite**：虚拟化几何体，支持数百万三角形
- **Megalights**：支持数百万动态光源（5.5+ 新增）
- **Substrate**：生产可用的模块化材质系统（5.7 新增）

---

## Lumen（全局光照）

### 启用 Lumen

```cpp
// Project Settings > Engine > Rendering > Dynamic Global Illumination Method = Lumen
// Real-time GI, no lightmap baking needed
```

### Lumen 质量设置

```ini
; DefaultEngine.ini
[/Script/Engine.RendererSettings]
r.Lumen.DiffuseColorBoost=1.0
r.Lumen.ScreenProbeGather.RadianceCache.NumFramesToKeepCached=2
```

### 在 C++ 中使用 Lumen

```cpp
// Check if Lumen is enabled
bool bIsLumenEnabled = IConsoleManager::Get().FindConsoleVariable(TEXT("r.DynamicGlobalIlluminationMethod"))->GetInt() == 1;
```

---

## Nanite（虚拟化几何体）

### 在 Static Mesh 上启用 Nanite

1. Static Mesh Editor
2. Details > Nanite Settings > Enable Nanite Support
3. 保存网格（自动构建 Nanite 数据）

### 在 C++ 中使用 Nanite

```cpp
// Spawn Nanite mesh
UStaticMeshComponent* MeshComp = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Mesh"));
MeshComp->SetStaticMesh(NaniteMesh); // Automatically uses Nanite if enabled
```

### Nanite 限制
- 不支持顶点动画（骨骼网格体）
- 材质中不支持世界位置偏移 (World Position Offset, WPO)
- 最适合静态、高面数几何体

---

## Megalights（UE 5.5+）

### 启用 Megalights

```cpp
// Project Settings > Engine > Rendering > Megalights = Enabled
// Supports millions of dynamic lights with minimal performance cost
```

### Megalights 用法

```cpp
// Add point lights as usual
UPointLightComponent* Light = CreateDefaultSubobject<UPointLightComponent>(TEXT("Light"));
Light->SetIntensity(5000.0f);
Light->SetAttenuationRadius(500.0f);

// Megalights automatically handles thousands/millions of these
```

---

## Substrate 材质（5.7 生产可用）

### 启用 Substrate

```cpp
// Project Settings > Engine > Substrate > Enable Substrate
// Restart editor
```

### Substrate 材质节点
- **Substrate Slab**：物理材质层（漫反射、高光等）
- **Substrate Blend**：混合多个层
- **Substrate Thin Film**：虹彩、肥皂泡
- **Substrate Hair**：毛发专用着色

### Substrate 材质图示例

```
Substrate Slab (Diffuse)
  └─ Base Color: Texture Sample
  └─ Roughness: Constant (0.5)
  └─ Metallic: Constant (0.0)
  └─ Connect to Material Output
```

---

## 材质（C++ API）

### 动态材质实例

```cpp
// Create dynamic material instance
UMaterialInstanceDynamic* DynMat = UMaterialInstanceDynamic::Create(BaseMaterial, this);

// Set parameters
DynMat->SetVectorParameterValue(TEXT("BaseColor"), FLinearColor::Red);
DynMat->SetScalarParameterValue(TEXT("Metallic"), 0.8f);
DynMat->SetTextureParameterValue(TEXT("DiffuseTexture"), MyTexture);

// Apply to mesh
MeshComp->SetMaterial(0, DynMat);
```

---

## 后处理

### Post-Process Volume

```cpp
// Add to level
APostProcessVolume* PPV = GetWorld()->SpawnActor<APostProcessVolume>();
PPV->bUnbound = true; // Affect entire world

// Configure settings
PPV->Settings.bOverride_MotionBlurAmount = true;
PPV->Settings.MotionBlurAmount = 0.5f;

PPV->Settings.bOverride_BloomIntensity = true;
PPV->Settings.BloomIntensity = 1.0f;
```

### 在 C++ 中使用后处理

```cpp
// Access camera post-process settings
APlayerController* PC = GetWorld()->GetFirstPlayerController();
if (APlayerCameraManager* CamManager = PC->PlayerCameraManager) {
    CamManager->PostProcessBlendWeight = 1.0f;
    CamManager->PostProcessSettings.BloomIntensity = 2.0f;
}
```

---

## 光照

### Directional Light（方向光/太阳）

```cpp
ADirectionalLight* Sun = GetWorld()->SpawnActor<ADirectionalLight>();
Sun->SetActorRotation(FRotator(-45.f, 0.f, 0.f));
Sun->GetLightComponent()->SetIntensity(10.0f);
Sun->GetLightComponent()->bCastShadows = true;
```

### Point Light（点光源）

```cpp
APointLight* Light = GetWorld()->SpawnActor<APointLight>();
Light->SetActorLocation(FVector(0, 0, 200));
Light->GetPointLightComponent()->SetIntensity(5000.0f);
Light->GetPointLightComponent()->SetAttenuationRadius(1000.0f);
Light->GetPointLightComponent()->SetLightColor(FLinearColor::Red);
```

### Spot Light（聚光灯）

```cpp
ASpotLight* Spotlight = GetWorld()->SpawnActor<ASpotLight>();
Spotlight->GetSpotLightComponent()->SetInnerConeAngle(20.0f);
Spotlight->GetSpotLightComponent()->SetOuterConeAngle(40.0f);
```

---

## Render Target（渲染到纹理）

### 创建 Render Target

```cpp
// Create render target asset (2D texture)
UTextureRenderTarget2D* RenderTarget = NewObject<UTextureRenderTarget2D>();
RenderTarget->InitAutoFormat(512, 512); // 512x512 resolution
RenderTarget->UpdateResourceImmediate();

// Render scene to texture
UKismetRenderingLibrary::DrawMaterialToRenderTarget(
    GetWorld(),
    RenderTarget,
    MaterialToDraw
);
```

---

## 自定义渲染通道（高级）

### Render Dependency Graph (RDG)

```cpp
// UE5 uses Render Dependency Graph for custom rendering
// Example: Custom post-process pass

#include "RenderGraphBuilder.h"

void RenderCustomPass(FRDGBuilder& GraphBuilder, const FViewInfo& View) {
    FRDGTextureRef SceneColor = /* Get scene color texture */;

    // Define pass parameters
    struct FPassParameters {
        FRDGTextureRef InputTexture;
    };

    FPassParameters* PassParams = GraphBuilder.AllocParameters<FPassParameters>();
    PassParams->InputTexture = SceneColor;

    // Add render pass
    GraphBuilder.AddPass(
        RDG_EVENT_NAME("CustomPass"),
        PassParams,
        ERDGPassFlags::Raster,
        [](FRHICommandList& RHICmdList, const FPassParameters* Params) {
            // Render commands
        }
    );
}
```

---

## 性能

### 渲染统计

```cpp
// Console commands for profiling:
// stat fps - Show FPS
// stat unit - Show frame time breakdown
// stat gpu - Show GPU timings
// profilegpu - Detailed GPU profile
```

### 可扩展性设置

```cpp
// Get current scalability settings
UGameUserSettings* Settings = UGameUserSettings::GetGameUserSettings();
int32 ViewDistanceQuality = Settings->GetViewDistanceQuality(); // 0-4

// Set scalability
Settings->SetViewDistanceQuality(3); // High
Settings->SetShadowQuality(2); // Medium
Settings->ApplySettings(false);
```

---

## 调试

### 可视化渲染特性

```
Console commands:
- r.Lumen.Visualize 1 - Show Lumen debug
- r.Nanite.Visualize 1 - Show Nanite triangles
- viewmode wireframe - Wireframe mode
- viewmode unlit - Disable lighting
- show collision - Show collision meshes
```

---

## 来源
- https://docs.unrealengine.com/5.7/en-US/lumen-global-illumination-and-reflections-in-unreal-engine/
- https://docs.unrealengine.com/5.7/en-US/nanite-virtualized-geometry-in-unreal-engine/
- https://docs.unrealengine.com/5.7/en-US/substrate-materials-in-unreal-engine/
