
# Unreal Engine 5.7 — 输入模块参考


**最后验证：** 2026-02-13
**知识空白：** UE 5.7 默认使用 Enhanced Input（旧版输入已弃用）

---

## 概述

UE 5.7 输入系统：
- **Enhanced Input**（推荐，UE5 起为默认）：模块化、可重绑定、基于上下文
- **旧版输入 (Legacy Input)**：已弃用，新项目避免使用

---

## Enhanced Input 系统

### 设置 Enhanced Input

1. **启用插件**：`Edit > Plugins > Enhanced Input`（UE5 默认启用）
2. **项目设置**：`Engine > Input > Default Classes > Default Player Input Class = EnhancedPlayerInput`

---

### 创建 Input Action

1. Content Browser > Input > Input Action
2. 命名（例如 `IA_Jump`、`IA_Move`）
3. 配置：
   - **值类型**：Digital (bool)、Axis1D (float)、Axis2D (Vector2D)、Axis3D (Vector)

示例 Input Action：
- `IA_Jump`：Digital (bool)
- `IA_Move`：Axis2D (Vector2D)
- `IA_Look`：Axis2D (Vector2D)
- `IA_Fire`：Digital (bool)

---

### 创建 Input Mapping Context

1. Content Browser > Input > Input Mapping Context
2. 命名（例如 `IMC_Default`）
3. 添加映射：
   - `IA_Jump` → 空格键
   - `IA_Move` → W/A/S/D 键（合并 X/Y）
   - `IA_Look` → 鼠标 XY
   - `IA_Fire` → 鼠标左键

---

### 在 C++ 中绑定输入

```cpp
#include "EnhancedInputComponent.h"
#include "EnhancedInputSubsystems.h"
#include "InputActionValue.h"

class AMyCharacter : public ACharacter {
public:
    // Input Actions (assign in Blueprint)
    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Input")
    TObjectPtr<UInputAction> MoveAction;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Input")
    TObjectPtr<UInputAction> LookAction;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Input")
    TObjectPtr<UInputAction> JumpAction;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Input")
    TObjectPtr<UInputMappingContext> DefaultMappingContext;

protected:
    virtual void BeginPlay() override {
        Super::BeginPlay();

        // Add Input Mapping Context
        if (APlayerController* PC = Cast<APlayerController>(Controller)) {
            if (UEnhancedInputLocalPlayerSubsystem* Subsystem =
                ULocalPlayer::GetSubsystem<UEnhancedInputLocalPlayerSubsystem>(PC->GetLocalPlayer())) {
                Subsystem->AddMappingContext(DefaultMappingContext, 0);
            }
        }
    }

    virtual void SetupPlayerInputComponent(UInputComponent* PlayerInputComponent) override {
        Super::SetupPlayerInputComponent(PlayerInputComponent);

        UEnhancedInputComponent* EIC = Cast<UEnhancedInputComponent>(PlayerInputComponent);
        if (EIC) {
            // Bind actions
            EIC->BindAction(JumpAction, ETriggerEvent::Started, this, &ACharacter::Jump);
            EIC->BindAction(JumpAction, ETriggerEvent::Completed, this, &ACharacter::StopJumping);

            EIC->BindAction(MoveAction, ETriggerEvent::Triggered, this, &AMyCharacter::Move);
            EIC->BindAction(LookAction, ETriggerEvent::Triggered, this, &AMyCharacter::Look);
        }
    }

    void Move(const FInputActionValue& Value) {
        FVector2D MoveVector = Value.Get<FVector2D>();

        if (Controller) {
            AddMovementInput(GetActorForwardVector(), MoveVector.Y);
            AddMovementInput(GetActorRightVector(), MoveVector.X);
        }
    }

    void Look(const FInputActionValue& Value) {
        FVector2D LookVector = Value.Get<FVector2D>();

        if (Controller) {
            AddControllerYawInput(LookVector.X);
            AddControllerPitchInput(LookVector.Y);
        }
    }
};
```

---

## 输入触发器

### 触发器类型

Input Action 可附加触发器以控制何时触发：
- **Pressed**：输入开始时
- **Released**：输入结束时
- **Hold**：按住一段时长
- **Tap**：快速按下
- **Pulse**：按住期间重复触发

### 在编辑器中添加触发器

1. 打开 Input Action 资产
2. Triggers > Add > 选择触发器类型（例如 `Hold`）
3. 配置（例如 Hold Time = 0.5s）

---

## 输入修饰器

### 修饰器类型

修饰器用于变换输入值：
- **Negate**：翻转符号（-1 ↔ 1）
- **Dead Zone**：忽略小幅输入
- **Scalar**：乘以某值
- **Smooth**：随时间平滑

### 在编辑器中添加修饰器

1. 打开 Input Action 资产
2. Modifiers > Add > 选择修饰器（例如 `Negate`）
3. 配置

---

## Input Mapping Context（上下文切换）

### 多上下文

```cpp
// Define contexts
UPROPERTY(EditAnywhere, Category = "Input")
TObjectPtr<UInputMappingContext> DefaultContext;

UPROPERTY(EditAnywhere, Category = "Input")
TObjectPtr<UInputMappingContext> VehicleContext;

// Switch context
void EnterVehicle() {
    if (APlayerController* PC = Cast<APlayerController>(Controller)) {
        if (UEnhancedInputLocalPlayerSubsystem* Subsystem =
            ULocalPlayer::GetSubsystem<UEnhancedInputLocalPlayerSubsystem>(PC->GetLocalPlayer())) {
            Subsystem->RemoveMappingContext(DefaultContext);
            Subsystem->AddMappingContext(VehicleContext, 0);
        }
    }
}
```

---

## 旧版输入（已弃用）

### 旧版输入绑定

```cpp
// ❌ DEPRECATED: Do not use for new projects

void AMyCharacter::SetupPlayerInputComponent(UInputComponent* PlayerInputComponent) {
    // Legacy action binding
    PlayerInputComponent->BindAction("Jump", IE_Pressed, this, &ACharacter::Jump);

    // Legacy axis binding
    PlayerInputComponent->BindAxis("MoveForward", this, &AMyCharacter::MoveForward);
}

void MoveForward(float Value) {
    AddMovementInput(GetActorForwardVector(), Value);
}
```

**迁移：** 改用 Enhanced Input。

---

## 手柄输入

### 使用 Enhanced Input 的手柄输入

```cpp
// Input Mapping Context:
// - IA_Move → Gamepad Left Thumbstick
// - IA_Look → Gamepad Right Thumbstick
// - IA_Jump → Gamepad Face Button Bottom (A/Cross)

// No code changes needed, just add gamepad mappings to Input Mapping Context
```

---

## 触摸输入（移动端）

### 使用 Enhanced Input 的触摸输入

```cpp
// Input Mapping Context:
// - IA_Move → Touch (virtual thumbstick)
// - IA_Look → Touch (swipe)

// Use Touch Interface asset for virtual controls
```

---

## 运行时重绑定输入

### 更改按键映射

```cpp
#include "PlayerMappableInputConfig.h"

// Get subsystem
UEnhancedInputLocalPlayerSubsystem* Subsystem = /* Get subsystem */;

// Get player mappable keys
FPlayerMappableKeySlot KeySlot = FPlayerMappableKeySlot(/*..*/);
FKey NewKey = EKeys::F; // Rebind to F key

// Apply new mapping
Subsystem->AddPlayerMappedKey(/*..*/);
```

---

## 输入调试

### 调试输入

```cpp
// Console commands:
// showdebug input - Show input debug info

// Log input values:
UE_LOG(LogTemp, Warning, TEXT("Move Input: %s"), *MoveVector.ToString());
```

---

## 常见模式

### 检查按键是否按下（快速但粗糙）

```cpp
// For debugging only (not recommended for gameplay)
if (GetWorld()->GetFirstPlayerController()->IsInputKeyDown(EKeys::SpaceBar)) {
    // Space bar is down
}
```

---

## 来源
- https://docs.unrealengine.com/5.7/en-US/enhanced-input-in-unreal-engine/
- https://docs.unrealengine.com/5.7/en-US/enhanced-input-action-and-input-mapping-context-in-unreal-engine/
