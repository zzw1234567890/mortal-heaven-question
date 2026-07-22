
# Unreal Engine 5.7 — 当前最佳实践


**最后验证：** 2026-02-13

LLM 训练数据中可能尚未包含的现代 UE5 模式。
以下为 UE 5.7 起的生产就绪建议。

---

## 项目设置

### 新项目使用 UE 5.7
- 最新特性：Megalights、生产就绪的 Substrate 与 PCG
- 更好的性能与稳定性

### 选择正确的渲染特性
- **Lumen**：实时全局光照（推荐用于大多数项目）
- **Nanite**：用于高多边形网格的虚拟化几何体（推荐用于细节丰富的环境）
- **Megalights**：百万级动态光源（推荐用于复杂光照）
- **Substrate**：模块化材质系统（推荐用于新项目）

---

## C++ 编码

### 使用现代 C++ 特性（UE5.7 中的 C++20）

```cpp
// ✅ Use TObjectPtr<T> (UE5 type-safe pointers)
UPROPERTY()
TObjectPtr<UStaticMeshComponent> MeshComp;

// ✅ Structured bindings
if (auto [bSuccess, Value] = TryGetValue(); bSuccess) {
    // Use Value
}

// ✅ Concepts and constraints (C++20)
template<typename T>
concept Damageable = requires(T t, float damage) {
    { t.TakeDamage(damage) } -> std::same_as<void>;
};
```

### 使用 UPROPERTY() 进行垃圾回收

```cpp
// ✅ UPROPERTY ensures GC doesn't delete this
UPROPERTY()
TObjectPtr<AActor> MyActor;

// ❌ Raw pointers can become dangling
AActor* MyActor; // Dangerous! May be garbage collected
```

### 使用 UFUNCTION() 暴露给 Blueprint

```cpp
// ✅ Callable from Blueprint
UFUNCTION(BlueprintCallable, Category="Combat")
void TakeDamage(float Damage);

// ✅ Implementable in Blueprint
UFUNCTION(BlueprintImplementableEvent, Category="Combat")
void OnDeath();
```

---

## Blueprint 最佳实践

### Blueprint 与 C++ 的取舍

- **C++**：核心玩法系统、性能关键代码、底层引擎交互
- **Blueprint**：快速原型、内容创作、数据驱动逻辑、设计师工作流

### Blueprint 性能提示

```cpp
// ✅ Use Event Tick sparingly (expensive)
// Prefer timers or events

// ✅ Use Blueprint Nativization (Blueprints → C++)
// Project Settings > Packaging > Blueprint Nativization

// ✅ Cache frequently accessed components
// Don't call GetComponent every tick
```

---

## 渲染（UE 5.7）

### 使用 Lumen 实现全局光照

```cpp
// Enable: Project Settings > Engine > Rendering > Dynamic Global Illumination Method = Lumen
// Real-time GI, no lightmap baking needed (RECOMMENDED)
```

### 使用 Nanite 处理高多边形网格

```cpp
// Enable on Static Mesh: Details > Nanite Settings > Enable Nanite Support
// Automatically LODs millions of triangles (RECOMMENDED for detailed meshes)
```

### 使用 Megalights 处理复杂光照（UE 5.5+）

```cpp
// Enable: Project Settings > Engine > Rendering > Megalights = Enabled
// Supports millions of dynamic lights with minimal cost
```

### 使用 Substrate 材质（5.7 起生产就绪）

```cpp
// Enable: Project Settings > Engine > Substrate > Enable Substrate
// Modular, physically accurate materials (RECOMMENDED for new projects)
```

---

## Enhanced Input 系统

### 设置 Enhanced Input

```cpp
// 1. Create Input Action (IA_Jump)
// 2. Create Input Mapping Context (IMC_Default)
// 3. Add mapping: IA_Jump → Space Bar

// C++ Setup:
#include "EnhancedInputComponent.h"
#include "EnhancedInputSubsystems.h"

void AMyCharacter::BeginPlay() {
    Super::BeginPlay();

    if (APlayerController* PC = Cast<APlayerController>(GetController())) {
        if (UEnhancedInputLocalPlayerSubsystem* Subsystem =
            ULocalPlayer::GetSubsystem<UEnhancedInputLocalPlayerSubsystem>(PC->GetLocalPlayer())) {
            Subsystem->AddMappingContext(DefaultMappingContext, 0);
        }
    }
}

void AMyCharacter::SetupPlayerInputComponent(UInputComponent* PlayerInputComponent) {
    UEnhancedInputComponent* EIC = Cast<UEnhancedInputComponent>(PlayerInputComponent);
    EIC->BindAction(JumpAction, ETriggerEvent::Started, this, &ACharacter::Jump);
    EIC->BindAction(MoveAction, ETriggerEvent::Triggered, this, &AMyCharacter::Move);
}

void AMyCharacter::Move(const FInputActionValue& Value) {
    FVector2D MoveVector = Value.Get<FVector2D>();
    AddMovementInput(GetActorForwardVector(), MoveVector.Y);
    AddMovementInput(GetActorRightVector(), MoveVector.X);
}
```

---

## Gameplay Ability System (GAS)

### 复杂玩法使用 GAS

```cpp
// ✅ Use GAS for: Abilities, buffs, damage calculation, cooldowns
// Modular, scalable, multiplayer-ready

// Install: Enable "Gameplay Abilities" plugin

// Example Ability:
UCLASS()
class UGA_Fireball : public UGameplayAbility {
    GENERATED_BODY()

public:
    virtual void ActivateAbility(...) override {
        // Ability logic
        SpawnFireball();
        CommitAbility(); // Commit cost/cooldown
    }
};
```

---

## World Partition（大型世界）

### 开放世界使用 World Partition

```cpp
// Enable: World Settings > Enable World Partition
// Automatically streams world cells based on player location

// Data Layers: Organize content (e.g., "Gameplay", "Audio", "Lighting")
// Runtime Data Layers: Load/unload at runtime
```

---

## Niagara (VFX)

### 使用 Niagara（而非 Cascade）

```cpp
// Create: Content Browser > Right Click > FX > Niagara System
// GPU-accelerated, node-based particle system (RECOMMENDED)

// Spawn particles:
UNiagaraComponent* NiagaraComp = UNiagaraFunctionLibrary::SpawnSystemAtLocation(
    GetWorld(),
    ExplosionSystem,
    GetActorLocation()
);
```

---

## MetaSounds（音频）

### 使用 MetaSounds 实现程序化音频

```cpp
// Create: Content Browser > Right Click > Sounds > MetaSound Source
// Node-based audio, replaces Sound Cue for complex logic (RECOMMENDED)

// Play MetaSound:
UAudioComponent* AudioComp = UGameplayStatics::SpawnSound2D(
    GetWorld(),
    MetaSoundSource
);
```

---

## 复制（多人游戏）

### 服务器权威模式

```cpp
// ✅ Client sends input, server validates and replicates
UFUNCTION(Server, Reliable)
void Server_Move(FVector Direction);

void AMyCharacter::Server_Move_Implementation(FVector Direction) {
    // Server validates and applies movement
    AddMovementInput(Direction);
}

// ✅ Replicate important state
UPROPERTY(Replicated)
int32 Health;

void AMyCharacter::GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const {
    Super::GetLifetimeReplicatedProps(OutLifetimeProps);
    DOREPLIFETIME(AMyCharacter, Health);
}
```

---

## 性能优化

### 使用对象池

```cpp
// ✅ Reuse objects instead of Spawn/Destroy
TArray<AActor*> ProjectilePool;

AActor* GetPooledProjectile() {
    for (AActor* Proj : ProjectilePool) {
        if (!Proj->IsActive()) {
            Proj->SetActive(true);
            return Proj;
        }
    }
    // Pool exhausted, spawn new
    return SpawnNewProjectile();
}
```

### 使用实例化静态网格

```cpp
// ✅ Hierarchical Instanced Static Mesh Component (HISM)
// Render thousands of identical meshes in one draw call
UHierarchicalInstancedStaticMeshComponent* HISM = CreateDefaultSubobject<UHierarchicalInstancedStaticMeshComponent>(TEXT("Trees"));
for (int i = 0; i < 1000; i++) {
    HISM->AddInstance(FTransform(RandomLocation));
}
```

---

## 调试

### 使用日志

```cpp
// ✅ Structured logging
UE_LOG(LogTemp, Warning, TEXT("Player health: %d"), Health);

// Custom log category
DECLARE_LOG_CATEGORY_EXTERN(LogMyGame, Log, All);
DEFINE_LOG_CATEGORY(LogMyGame);
UE_LOG(LogMyGame, Error, TEXT("Critical error!"));
```

### 使用可视化日志

```cpp
// ✅ Visual debugging
#include "VisualLogger/VisualLogger.h"

UE_VLOG_SEGMENT(this, LogTemp, Log, StartPos, EndPos, FColor::Red, TEXT("Raycast"));
UE_VLOG_LOCATION(this, LogTemp, Log, TargetLocation, 50.f, FColor::Green, TEXT("Target"));
```

---

## 总结：UE 5.7 推荐技术栈

| 特性 | 2026 年使用此项 | 说明 |
|---------|------------------|-------|
| **光照** | Lumen + Megalights | 实时 GI、百万级光源 |
| **几何体** | Nanite | 高多边形网格、自动 LOD |
| **材质** | Substrate | 模块化、物理准确 |
| **输入** | Enhanced Input | 可重绑定、模块化 |
| **VFX** | Niagara | GPU 加速 |
| **音频** | MetaSounds | 程序化音频 |
| **世界流式加载** | World Partition | 大型开放世界 |
| **玩法** | Gameplay Ability System | 复杂技能、buff |

---

**来源：**
- https://docs.unrealengine.com/5.7/en-US/
- https://dev.epicgames.com/documentation/en-us/unreal-engine/unreal-engine-5-7-release-notes
