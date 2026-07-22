
# Unreal Engine 5.7 — 破坏性变更


**最后验证：** 2026-02-13

本文档跟踪 Unreal Engine 5.3（可能在模型训练数据中）与 Unreal Engine 5.7（当前版本）之间的破坏性 API 变更与行为差异。按风险等级组织。

## HIGH 风险 — 会破坏现有代码

### Substrate 材质系统（5.7 起生产就绪）
**版本：** UE 5.5+（实验性），5.7（生产就绪）

Substrate 以模块化、物理准确的框架取代旧版材质系统。

```cpp
// ❌ OLD: Legacy material nodes (still work but deprecated)
// Standard material graph with Base Color, Metallic, Roughness, etc.

// ✅ NEW: Substrate material layers
// Use Substrate nodes: Substrate Slab, Substrate Blend, etc.
// Modular material authoring with true physical accuracy
```

**迁移：** 在 `Project Settings > Engine > Substrate` 中启用 Substrate，并使用 Substrate 节点重建材质。

---

### PCG (Procedural Content Generation) API 改版
**版本：** UE 5.7（生产就绪）

PCG 框架达到生产就绪状态，API 有重大变更。

```cpp
// ❌ OLD: Experimental PCG API (pre-5.7)
// Old node types, unstable API

// ✅ NEW: Production PCG API (5.7+)
// Use FPCGContext, IPCGElement, new node types
// Stable API, production-ready workflow
```

**迁移：** 遵循 5.7 文档中的 PCG 迁移指南。实验性 PCG 代码预计需要重大重构。

---

### Megalights 渲染系统
**版本：** UE 5.5+

新光照系统支持百万级动态光源。

```cpp
// ❌ OLD: Limited dynamic lights (clustered forward shading)
// Max ~100-200 dynamic lights before performance degrades

// ✅ NEW: Megalights (5.5+)
// Millions of dynamic lights with minimal performance cost
// Enable: Project Settings > Engine > Rendering > Megalights
```

**迁移：** 无需代码变更，但光照行为可能有所不同。启用后请测试场景。

---

## MEDIUM 风险 — 行为变更

### Enhanced Input 系统（现为默认）
**版本：** UE 5.1+（推荐），5.7（默认）

Enhanced Input 现为默认输入系统。

```cpp
// ❌ OLD: Legacy input bindings (deprecated)
InputComponent->BindAction("Jump", IE_Pressed, this, &ACharacter::Jump);

// ✅ NEW: Enhanced Input
SetupPlayerInputComponent(UInputComponent* PlayerInputComponent) {
    UEnhancedInputComponent* EIC = Cast<UEnhancedInputComponent>(PlayerInputComponent);
    EIC->BindAction(JumpAction, ETriggerEvent::Started, this, &ACharacter::Jump);
}
```

**迁移：** 将旧版输入绑定替换为 Enhanced Input action。

---

### Nanite 默认启用
**版本：** UE 5.0+（可选），5.7（鼓励）

Nanite 虚拟化几何体现在是静态网格体的推荐工作流。

```cpp
// Enable Nanite on static mesh:
// Static Mesh Editor > Details > Nanite Settings > Enable Nanite Support
```

**迁移：** 将高多边形网格转换为 Nanite。在目标平台上测试性能。

---

## LOW 风险 — 弃用（仍可用）

### 旧版材质系统
**状态：** 已弃用但仍支持
**替代：** Substrate 材质系统

旧版材质仍可工作，但新项目推荐使用 Substrate。

---

### 旧版 World Partition（UE4 风格）
**状态：** 已弃用
**替代：** World Partition（UE5+）

大型世界请使用 UE5 的 World Partition 系统。

---

## 平台相关的破坏性变更

### Windows
- **UE 5.7**：DirectX 12 现为默认（旧版本中为 DX11）
- 更新 shader 以兼容 DX12

### macOS
- **UE 5.5+**：需要 Metal 3（最低 macOS 13）

### 移动端
- **UE 5.7**：最低 Android API level 提升至 26（Android 8.0）
- 最低 iOS 部署目标提升至 iOS 14

---

## 迁移检查清单

从 UE 5.3 升级到 UE 5.7 时：

- [ ] 审查 Substrate 材质（如准备好使用新系统则转换）
- [ ] 审计 PCG 使用（如使用实验性版本则更新至生产 API）
- [ ] 测试 Megalights 性能（启用并基准测试）
- [ ] 将旧版输入迁移至 Enhanced Input
- [ ] 将高多边形网格转换为 Nanite
- [ ] 更新 shader 以适配 DX12（Windows）或 Metal 3（macOS）
- [ ] 验证最低平台版本（Android 8.0、iOS 14）
- [ ] 在目标硬件上测试 Lumen 与 Nanite 性能

---

**来源：**
- https://dev.epicgames.com/documentation/en-us/unreal-engine/unreal-engine-5-7-release-notes
- https://dev.epicgames.com/documentation/en-us/unreal-engine/upgrading-projects-to-newer-versions-of-unreal-engine
