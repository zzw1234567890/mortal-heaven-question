
# Unreal Engine 5.7 — 动画模块参考


**最后验证：** 2026-02-13
**知识空白：** UE 5.7 动画创作改进、Control Rig 2.0

---

## 概述

UE 5.7 动画系统：
- **Animation Blueprint**：基于状态机的动画逻辑
- **Control Rig**：运行时程序化动画（UE5 起生产就绪）
- **IK Rig + Retargeter**：现代重定向系统
- **Sequencer**：电影级动画

---

## Animation Blueprint

### 创建 Animation Blueprint

1. Content Browser > Right Click > Animation > Animation Blueprint
2. 选择父类：`AnimInstance`
3. 选择骨架

### 动画状态机

```cpp
// In Animation Blueprint Event Graph:
// - State Machine drives animation states (Idle, Walk, Run, Jump)
// - Blend Spaces for directional movement

// Access in C++:
UAnimInstance* AnimInstance = Mesh->GetAnimInstance();
AnimInstance->Montage_Play(AttackMontage);
```

---

## 播放动画 Montage

### Animation Montage

```cpp
// Play montage
UAnimInstance* AnimInstance = GetMesh()->GetAnimInstance();
AnimInstance->Montage_Play(AttackMontage, 1.0f);

// Stop montage
AnimInstance->Montage_Stop(0.2f, AttackMontage);

// Check if montage is playing
bool bIsPlaying = AnimInstance->Montage_IsPlaying(AttackMontage);
```

### Montage Notify 事件

```cpp
// Add notify event in Animation Montage (right-click timeline > Add Notify > New Notify)
// Implement in C++:

UCLASS()
class UMyAnimInstance : public UAnimInstance {
    GENERATED_BODY()

public:
    UFUNCTION()
    void AnimNotify_AttackHit() {
        // Called when notify is reached
        DealDamage();
    }
};
```

---

## Blend Space

### 1D Blend Space（速度混合）

```cpp
// Create: Content Browser > Animation > Blend Space 1D
// Horizontal Axis: Speed (0 = Idle, 1 = Walk, 2 = Run)
// Add animations at key points

// Use in Anim Blueprint:
// - Get speed from character
// - Feed into Blend Space
```

### 2D Blend Space（方向移动）

```cpp
// Create: Content Browser > Animation > Blend Space
// Horizontal Axis: Direction X (-1 to 1)
// Vertical Axis: Direction Y (-1 to 1)
// Place animations (Fwd, Back, Left, Right, diagonal)
```

---

## Control Rig（程序化动画）

### 创建 Control Rig

1. Content Browser > Animation > Control Rig
2. 选择骨架
3. 构建绑定层级（骨骼、控制器、IK）

### 在 Animation Blueprint 中使用 Control Rig

```cpp
// Add "Control Rig" node to Anim Blueprint
// Assign Control Rig asset
// Procedurally modify bones at runtime
```

### 在 C++ 中使用 Control Rig

```cpp
// Get control rig component
UControlRig* ControlRig = /* Get from animation instance */;

// Set control value
ControlRig->SetControlValue<FVector>(TEXT("IK_Hand_R"), TargetLocation);
```

---

## IK Rig 与重定向（UE5）

### 创建 IK Rig

1. Content Browser > Animation > IK Rig
2. 选择骨架
3. 添加 IK goal（手、脚）
4. 设置 solver chain

### 重定向动画

1. 为源骨架创建 IK Rig
2. 为目标骨架创建 IK Rig
3. 创建 IK Retargeter 资产
4. 指定源与目标 IK Rig
5. 批量重定向动画

### 在 C++ 中重定向

```cpp
// Retargeting is primarily editor-based
// Animations are retargeted once, then used normally
```

---

## Animation Notify State

### 自定义 Notify State（基于时长的事件）

```cpp
UCLASS()
class UAnimNotifyState_Invulnerable : public UAnimNotifyState {
    GENERATED_BODY()

public:
    virtual void NotifyBegin(USkeletalMeshComponent* MeshComp, UAnimSequenceBase* Animation, float TotalDuration, const FAnimNotifyEventReference& EventReference) override {
        // Start invulnerability
        AMyCharacter* Character = Cast<AMyCharacter>(MeshComp->GetOwner());
        Character->bIsInvulnerable = true;
    }

    virtual void NotifyEnd(USkeletalMeshComponent* MeshComp, UAnimSequenceBase* Animation, const FAnimNotifyEventReference& EventReference) override {
        // End invulnerability
        AMyCharacter* Character = Cast<AMyCharacter>(MeshComp->GetOwner());
        Character->bIsInvulnerable = false;
    }
};
```

---

## 骨骼网格与 Socket

### 将对象附加到 Socket

```cpp
// Create socket in Skeletal Mesh Editor (Skeleton Tree > Add Socket)

// Attach component to socket
UStaticMeshComponent* Weapon = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Weapon"));
Weapon->SetupAttachment(GetMesh(), TEXT("hand_r_socket"));
```

---

## 动画曲线

### 使用动画曲线

```cpp
// Add curve to animation:
// Animation Editor > Curves > Add Curve

// Read curve value in Anim Blueprint or C++:
UAnimInstance* AnimInstance = GetMesh()->GetAnimInstance();
float CurveValue = AnimInstance->GetCurveValue(TEXT("MyCurve"));
```

---

## 根运动

### 启用根运动

```cpp
// In Animation Sequence: Asset Details > Root Motion > Enable Root Motion

// In Character class:
GetCharacterMovement()->bAllowPhysicsRotationDuringAnimRootMotion = true;
```

---

## 动画层（Linked Anim Graph）

### 使用 Linked Anim Layer

```cpp
// Create separate Anim Blueprints for layers (e.g., upper body, lower body)
// Link in main Anim Blueprint: Add "Linked Anim Graph" node

// Dynamically switch layers:
UAnimInstance* AnimInstance = GetMesh()->GetAnimInstance();
AnimInstance->LinkAnimClassLayers(NewLayerClass);
```

---

## Sequencer（电影级动画）

### 创建 Sequence

1. Content Browser > Cinematics > Level Sequence
2. 添加轨道：Camera、Character、Animation 等

### 从 C++ 播放 Sequence

```cpp
#include "LevelSequenceActor.h"
#include "LevelSequencePlayer.h"

ALevelSequenceActor* SequenceActor = /* Spawn or find in level */;
SequenceActor->GetSequencePlayer()->Play();
```

---

## 性能提示

### 动画优化

```cpp
// LOD (Level of Detail) for skeletal meshes
// Reduce bone count for distant characters

// Anim Blueprint optimization:
// - Use "Anim Node Relevancy" (skip updates when not visible)
// - Disable updates when off-screen:
GetMesh()->VisibilityBasedAnimTickOption = EVisibilityBasedAnimTickOption::OnlyTickPoseWhenRendered;
```

---

## 调试

### 动画调试可视化

```cpp
// Console commands:
// showdebug animation - Show animation state info
// a.VisualizeSkeletalMeshBones 1 - Show skeleton bones

// Draw debug bones:
DrawDebugCoordinateSystem(GetWorld(), BoneLocation, BoneRotation, 50.0f, false, -1.0f, 0, 2.0f);
```

---

## 来源
- https://docs.unrealengine.com/5.7/en-US/animation-in-unreal-engine/
- https://docs.unrealengine.com/5.7/en-US/control-rig-in-unreal-engine/
- https://docs.unrealengine.com/5.7/en-US/ik-rig-in-unreal-engine/
