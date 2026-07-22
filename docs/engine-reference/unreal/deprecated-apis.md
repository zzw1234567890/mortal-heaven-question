
# Unreal Engine 5.7 — 已弃用的 API


**最后验证：** 2026-02-13

已弃用 API 及其替代方案的快速查找表。
格式：**不要使用 X** → **改用 Y**

---

## 输入

| 已弃用 | 替代方案 | 说明 |
|------------|-------------|-------|
| `InputComponent->BindAction()` | Enhanced Input `BindAction()` | 新输入系统 |
| `InputComponent->BindAxis()` | Enhanced Input `BindAxis()` | 新输入系统 |
| `PlayerController->GetInputAxisValue()` | Enhanced Input Action Values | 新输入系统 |

**迁移：** 安装 Enhanced Input 插件，创建 Input Action 与 Input Mapping Context。

---

## 渲染

| 已弃用 | 替代方案 | 说明 |
|------------|-------------|-------|
| 旧版材质节点 | Substrate 材质节点 | Substrate 在 5.7 起生产就绪 |
| Forward shading（默认） | Deferred + Lumen | Lumen 在 UE5 中为默认 |
| 旧版光照工作流 | Lumen Global Illumination | 实时 GI |

---

## 世界构建

| 已弃用 | 替代方案 | 说明 |
|------------|-------------|-------|
| UE4 World Composition | World Partition (UE5) | 大型世界流式加载 |
| Level Streaming Volumes | World Partition Data Layers | 更优的关卡流式加载 |

---

## 动画

| 已弃用 | 替代方案 | 说明 |
|------------|-------------|-------|
| 旧版动画重定向 | IK Rig + IK Retargeter | UE5 重定向系统 |
| 旧版 Control Rig | Control Rig 2.0 | 生产就绪的绑定 |

---

## 玩法

| 已弃用 | 替代方案 | 说明 |
|------------|-------------|-------|
| `UGameplayStatics::LoadStreamLevel()` | World Partition 流式加载 | 使用 Data Layers |
| 硬编码输入绑定 | Enhanced Input 系统 | 可重绑定、模块化输入 |

---

## Niagara (VFX)

| 已弃用 | 替代方案 | 说明 |
|------------|-------------|-------|
| Cascade 粒子系统 | Niagara | Cascade 已完全弃用 |

---

## 音频

| 已弃用 | 替代方案 | 说明 |
|------------|-------------|-------|
| 旧版音频混音器 | MetaSounds | 程序化音频系统 |
| Sound Cue（用于复杂逻辑） | MetaSounds | 更强大、基于节点 |

---

## 网络

| 已弃用 | 替代方案 | 说明 |
|------------|-------------|-------|
| `DOREPLIFETIME()`（基础） | `DOREPLIFETIME_CONDITION()` | 条件复制以优化 |

---

## C++ 脚本

| 已弃用 | 替代方案 | 说明 |
|------------|-------------|-------|
| 对 UObject 使用 `TSharedPtr<T>` | `TObjectPtr<T>` | UE5 类型安全指针 |
| 手动 RTTI 检查 | `Cast<T>()` / `IsA<T>()` | 类型安全转换 |

---

## 快速迁移模式

### 输入示例
```cpp
// ❌ Deprecated
void AMyCharacter::SetupPlayerInputComponent(UInputComponent* PlayerInputComponent) {
    PlayerInputComponent->BindAction("Jump", IE_Pressed, this, &ACharacter::Jump);
}

// ✅ Enhanced Input
#include "EnhancedInputComponent.h"

void AMyCharacter::SetupPlayerInputComponent(UInputComponent* PlayerInputComponent) {
    UEnhancedInputComponent* EIC = Cast<UEnhancedInputComponent>(PlayerInputComponent);
    if (EIC) {
        EIC->BindAction(JumpAction, ETriggerEvent::Started, this, &ACharacter::Jump);
    }
}
```

### 材质示例
```cpp
// ❌ Deprecated: Legacy material
// Use standard material graph (still works but not recommended)

// ✅ Substrate Material
// Enable: Project Settings > Engine > Substrate > Enable Substrate
// Use Substrate nodes in material editor
```

### World Partition 示例
```cpp
// ❌ Deprecated: Level streaming volumes
// Load/unload levels manually

// ✅ World Partition
// Enable: World Settings > Enable World Partition
// Use Data Layers for streaming
```

### 粒子系统示例
```cpp
// ❌ Deprecated: Cascade
UParticleSystemComponent* PSC = CreateDefaultSubobject<UParticleSystemComponent>(TEXT("Particles"));

// ✅ Niagara
UNiagaraComponent* NiagaraComp = CreateDefaultSubobject<UNiagaraComponent>(TEXT("Niagara"));
```

### 音频示例
```cpp
// ❌ Deprecated: Sound Cue for complex logic
// Use Sound Cue editor nodes

// ✅ MetaSounds
// Create MetaSound Source asset, use node-based audio
```

---

## 总结：UE 5.7 技术栈

| 特性 | 2026 年使用此项 | 避免使用（旧版） |
|---------|------------------|----------------------|
| **输入** | Enhanced Input | 旧版输入绑定 |
| **材质** | Substrate | 旧版材质系统 |
| **光照** | Lumen + Megalights | Lightmap + 有限光源 |
| **粒子** | Niagara | Cascade |
| **音频** | MetaSounds | Sound Cue（用于逻辑） |
| **世界流式加载** | World Partition | World Composition |
| **动画重定向** | IK Rig + Retargeter | 旧版重定向 |
| **几何体** | Nanite（高多边形） | 标准静态网格 LOD |

---

**来源：**
- https://docs.unrealengine.com/5.7/en-US/deprecated-and-removed-features/
- https://dev.epicgames.com/documentation/en-us/unreal-engine/unreal-engine-5-7-release-notes
