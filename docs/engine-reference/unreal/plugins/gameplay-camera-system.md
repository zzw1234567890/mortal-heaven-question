
# Unreal Engine 5.7 — Gameplay Camera System

**最后验证：** 2026-02-13
**状态：** ⚠️ 实验性（UE 5.5 引入）
**插件：** `GameplayCameras`（内置，在 Plugins 中启用）

---

## 概览

**Gameplay Camera System** 是 UE 5.5 引入的模块化摄像机管理框架。它用一套灵活的、基于节点的系统替代了传统摄像机设置，用于处理摄像机模式、混合以及上下文感知的摄像机行为。

**在以下场景使用 Gameplay Cameras：**
- 动态摄像机行为（第三人称、瞄准、载具、电影式）
- 上下文感知的摄像机切换（战斗、探索、对话）
- 摄像机模式之间的平滑混合
- 程序化摄像机运动（摄像机震动、滞后、偏移）

**⚠️ 警告：** 该插件在 UE 5.5-5.7 中为实验性。未来版本的 API 可能变更。

---

## 核心概念

### 1. **Camera Rig（摄像机装置）**
- 定义摄像机配置（位置、旋转、FOV 等）
- 模块化节点图（类似材质编辑器）

### 2. **Camera Director（摄像机导演）**
- 管理当前激活的 Camera Rig
- 处理 Camera Rig 之间的混合

### 3. **Camera Nodes（摄像机节点）**
- 构建摄像机行为的积木：
  - **位置节点 (Position Nodes)**：Orbit、Follow、Fixed Position
  - **旋转节点 (Rotation Nodes)**：Look At、Match Actor Rotation
  - **修改器 (Modifiers)**：Camera Shake、Lag、Offset

---

## 设置

### 1. 启用插件

`Edit > Plugins > Gameplay Cameras > Enabled > Restart`

### 2. 添加摄像机组件

```cpp
#include "GameplayCameras/Public/GameplayCameraComponent.h"

UCLASS()
class AMyCharacter : public ACharacter {
    GENERATED_BODY()

public:
    AMyCharacter() {
        // Create camera component
        CameraComponent = CreateDefaultSubobject<UGameplayCameraComponent>(TEXT("GameplayCamera"));
        CameraComponent->SetupAttachment(RootComponent);
    }

protected:
    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Camera")
    TObjectPtr<UGameplayCameraComponent> CameraComponent;
};
```

---

## 创建 Camera Rig

### 1. 创建 Camera Rig 资源

1. Content Browser > Gameplay > Gameplay Camera Rig
2. 打开 Camera Rig Editor（基于节点的图）

### 2. 构建 Camera Rig（示例：第三人称）

**节点设置：**
```
Actor Position (Character)
  ↓
Orbit Node (Orbit around character)
  ↓
Offset Node (Shoulder offset)
  ↓
Look At Node (Look at character)
  ↓
Camera Output
```

---

## 摄像机节点

### 位置节点

#### Orbit Node（第三人称）
- 围绕目标 Actor 公转
- 配置：
  - **Orbit Distance**：与目标的距离（例如 300 单位）
  - **Pitch Range**：最小/最大俯仰角
  - **Yaw Range**：最小/最大偏航角

#### Follow Node（平滑跟随）
- 带滞后地跟随目标
- 配置：
  - **Lag Speed**：摄像机追上的速度
  - **Offset**：相对目标的固定偏移

#### Fixed Position Node
- 世界空间中的静态摄像机位置

---

### 旋转节点

#### Look At Node
- 让摄像机指向目标
- 配置：
  - **Target**：要看向的 Actor 或组件
  - **Offset**：看向偏移（例如瞄准头部而非脚部）

#### Match Actor Rotation
- 匹配目标 Actor 的旋转
- 适用于第一人称或载具摄像机

---

### 修改器节点

#### Camera Shake
- 添加程序化震动（例如脚步、爆炸）
- 配置：
  - **Shake Pattern**：柏林噪声、正弦波、自定义
  - **Amplitude**：震动强度

#### Camera Lag
- 对摄像机运动的平滑阻尼
- 配置：
  - **Lag Speed**：阻尼系数（0 = 即时，越大滞后越多）

#### Offset Node
- 相对计算位置的静态偏移
- 适用于越肩摄像机的偏移

---

## Camera Director（在 Rig 之间切换）

### 指派 Camera Rig

```cpp
#include "GameplayCameras/Public/GameplayCameraComponent.h"

void AMyCharacter::SetCameraMode(UGameplayCameraRig* NewRig) {
    if (CameraComponent) {
        CameraComponent->SetCameraRig(NewRig);
    }
}
```

### 在 Camera Rig 之间混合

```cpp
// Blend to aiming camera over 0.5 seconds
CameraComponent->BlendToCameraRig(AimingCameraRig, 0.5f);
```

---

## 示例：第三人称 + 瞄准

### 1. 创建两个 Camera Rig

**第三人称 Rig：**
```
Actor Position → Orbit (distance: 300) → Look At → Output
```

**瞄准 Rig：**
```
Actor Position → Orbit (distance: 150) → Offset (shoulder) → Look At → Output
```

### 2. 在瞄准时切换

```cpp
UPROPERTY(EditAnywhere, Category = "Camera")
TObjectPtr<UGameplayCameraRig> ThirdPersonRig;

UPROPERTY(EditAnywhere, Category = "Camera")
TObjectPtr<UGameplayCameraRig> AimingRig;

void StartAiming() {
    CameraComponent->BlendToCameraRig(AimingRig, 0.3f); // Blend over 0.3s
}

void StopAiming() {
    CameraComponent->BlendToCameraRig(ThirdPersonRig, 0.3f);
}
```

---

## 常见模式

### 越肩摄像机

```
Actor Position
  ↓
Orbit Node (distance: 250, yaw offset: 30°)
  ↓
Offset Node (X: 0, Y: 50, Z: 50) // Shoulder offset
  ↓
Look At Node (target: Character head)
  ↓
Output
```

---

### 载具摄像机

```
Vehicle Position
  ↓
Follow Node (lag: 0.2)
  ↓
Offset Node (behind vehicle: X: -400, Z: 150)
  ↓
Look At Node (target: Vehicle)
  ↓
Output
```

---

### 第一人称摄像机

```
Character Head Socket
  ↓
Match Actor Rotation
  ↓
Output
```

---

## 摄像机震动

### 触发摄像机震动

```cpp
#include "GameplayCameras/Public/GameplayCameraShake.h"

void TriggerExplosionShake() {
    if (APlayerController* PC = GetWorld()->GetFirstPlayerController()) {
        if (UGameplayCameraComponent* CameraComp = PC->FindComponentByClass<UGameplayCameraComponent>()) {
            CameraComp->PlayCameraShake(ExplosionShakeClass, 1.0f);
        }
    }
}
```

---

## 性能建议

- 限制摄像机震动频率（不要每帧触发）
- 谨慎使用摄像机滞后（高滞后值开销大）
- 缓存 Camera Rig 引用（不要每帧搜索）

---

## 调试

### 摄像机调试可视化

```cpp
// Console commands:
// GameplayCameras.Debug 1 - Show active camera rig info
// showdebug camera - Show camera debug info
```

---

## 从旧版摄像机迁移

### 旧的 Spring Arm + Camera Component

```cpp
// ❌ OLD: Spring Arm Component
USpringArmComponent* SpringArm;
UCameraComponent* Camera;

// ✅ NEW: Gameplay Camera Component
UGameplayCameraComponent* CameraComponent;
// Build orbit + look-at rig in Camera Rig asset
```

---

## 限制（实验性状态）

- **API 不稳定**：UE 5.8+ 预计会有破坏性变更
- **文档有限**：官方文档仍在完善
- **Blueprint 支持**：以 C++ 为主（Blueprint 支持在改进中）
- **生产风险**：发布前需充分测试

---

## 来源
- https://docs.unrealengine.com/5.7/en-US/gameplay-cameras-in-unreal-engine/
- UE 5.5+ Release Notes
- **注意：** 该系统为实验性。请始终查阅最新官方文档以了解 API 变更。
