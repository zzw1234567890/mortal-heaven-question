
# Unreal Engine 5.7 — UI 模块参考

**最后验证：** 2026-02-13
**知识缺口：** UE 5.7 UMG 与 CommonUI 改进

---

## 概览

UE 5.7 UI 系统：
- **UMG (Unreal Motion Graphics)**：基于可视化控件的 UI（推荐）
- **CommonUI**：跨平台、输入感知的 UI 框架（主机/PC）
- **Slate**：底层 C++ UI（引擎/编辑器 UI）

---

## UMG (Unreal Motion Graphics)

### 创建 Widget Blueprint

1. Content Browser > User Interface > Widget Blueprint
2. 打开 Widget Designer
3. 从 Palette 拖入控件：Button、Text、Image、ProgressBar 等

---

## 在 C++ 中进行基础 UMG 设置

### 创建并显示控件

```cpp
#include "Blueprint/UserWidget.h"

UPROPERTY(EditAnywhere, Category = "UI")
TSubclassOf<UUserWidget> HealthBarWidgetClass;

void AMyCharacter::BeginPlay() {
    Super::BeginPlay();

    // Create widget
    UUserWidget* HealthBarWidget = CreateWidget<UUserWidget>(GetWorld(), HealthBarWidgetClass);

    // Add to viewport
    HealthBarWidget->AddToViewport();
}
```

### 移除控件

```cpp
HealthBarWidget->RemoveFromParent();
```

---

## 从 C++ 访问控件元素

### 绑定到控件元素

```cpp
UCLASS()
class UMyHealthWidget : public UUserWidget {
    GENERATED_BODY()

public:
    // ✅ Bind to widget elements (must match names in Widget Blueprint)
    UPROPERTY(meta = (BindWidget))
    TObjectPtr<UTextBlock> HealthText;

    UPROPERTY(meta = (BindWidget))
    TObjectPtr<UProgressBar> HealthBar;

    void UpdateHealth(int32 CurrentHealth, int32 MaxHealth) {
        HealthText->SetText(FText::FromString(FString::Printf(TEXT("%d / %d"), CurrentHealth, MaxHealth)));
        HealthBar->SetPercent((float)CurrentHealth / MaxHealth);
    }
};
```

---

## 常用 UMG 控件

### Text Block

```cpp
UPROPERTY(meta = (BindWidget))
TObjectPtr<UTextBlock> ScoreText;

ScoreText->SetText(FText::FromString(TEXT("Score: 100")));
ScoreText->SetColorAndOpacity(FLinearColor::Green);
```

### Button

```cpp
UPROPERTY(meta = (BindWidget))
TObjectPtr<UButton> PlayButton;

void NativeConstruct() override {
    Super::NativeConstruct();

    // Bind button click
    PlayButton->OnClicked.AddDynamic(this, &UMyMenuWidget::OnPlayClicked);
}

UFUNCTION()
void OnPlayClicked() {
    UE_LOG(LogTemp, Warning, TEXT("Play clicked"));
}
```

### Image

```cpp
UPROPERTY(meta = (BindWidget))
TObjectPtr<UImage> PlayerAvatar;

PlayerAvatar->SetBrushFromTexture(AvatarTexture);
PlayerAvatar->SetColorAndOpacity(FLinearColor::White);
```

### Progress Bar

```cpp
UPROPERTY(meta = (BindWidget))
TObjectPtr<UProgressBar> HealthBar;

HealthBar->SetPercent(0.75f); // 75%
HealthBar->SetFillColorAndOpacity(FLinearColor::Red);
```

### Slider

```cpp
UPROPERTY(meta = (BindWidget))
TObjectPtr<USlider> VolumeSlider;

void NativeConstruct() override {
    Super::NativeConstruct();
    VolumeSlider->OnValueChanged.AddDynamic(this, &UMyWidget::OnVolumeChanged);
}

UFUNCTION()
void OnVolumeChanged(float Value) {
    // Value is 0.0 - 1.0
    UE_LOG(LogTemp, Warning, TEXT("Volume: %f"), Value);
}
```

### EditableTextBox（输入框）

```cpp
UPROPERTY(meta = (BindWidget))
TObjectPtr<UEditableTextBox> PlayerNameInput;

void NativeConstruct() override {
    Super::NativeConstruct();
    PlayerNameInput->OnTextChanged.AddDynamic(this, &UMyWidget::OnNameChanged);
}

UFUNCTION()
void OnNameChanged(const FText& Text) {
    FString PlayerName = Text.ToString();
}
```

---

## UMG 动画

### 播放动画

```cpp
UPROPERTY(Transient, meta = (BindWidgetAnim))
TObjectPtr<UWidgetAnimation> FadeInAnimation;

void ShowUI() {
    PlayAnimation(FadeInAnimation);
}
```

### 停止动画

```cpp
StopAnimation(FadeInAnimation);
```

---

## Canvas Panel（布局）

### Canvas Panel（绝对定位）

```cpp
// Use in Widget Blueprint for absolute positioning
// Anchor widgets to corners/edges for responsive UI
```

### Vertical Box（垂直堆叠）

```cpp
// Auto-stacks children vertically
```

### Horizontal Box（水平堆叠）

```cpp
// Auto-stacks children horizontally
```

### Grid Panel（网格布局）

```cpp
// Arranges children in a grid
```

---

## 世界空间 UI（3D UI）

### Widget Component（世界中的 3D UI）

```cpp
#include "Components/WidgetComponent.h"

UWidgetComponent* HealthBarWidget = CreateDefaultSubobject<UWidgetComponent>(TEXT("HealthBar"));
HealthBarWidget->SetupAttachment(RootComponent);
HealthBarWidget->SetWidgetClass(HealthBarWidgetClass);
HealthBarWidget->SetWidgetSpace(EWidgetSpace::World); // 3D world space
HealthBarWidget->SetDrawSize(FVector2D(200, 50));
```

---

## UMG 中的输入处理

### 重写键盘输入

```cpp
UCLASS()
class UMyWidget : public UUserWidget {
    GENERATED_BODY()

public:
    virtual FReply NativeOnKeyDown(const FGeometry& InGeometry, const FKeyEvent& InKeyEvent) override {
        if (InKeyEvent.GetKey() == EKeys::Escape) {
            // Handle Escape key
            CloseMenu();
            return FReply::Handled();
        }
        return Super::NativeOnKeyDown(InGeometry, InKeyEvent);
    }
};
```

---

## CommonUI（跨平台输入）

### 启用 CommonUI 插件

```cpp
// Enable: Edit > Plugins > CommonUI
// Restart editor
```

### 使用 CommonUI 控件

```cpp
// CommonUI widgets:
// - CommonActivatableWidget: Base for screens/menus
// - CommonButtonBase: Input-aware button (gamepad + mouse)
// - CommonTextBlock: Text with styling
```

### CommonActivatableWidget 示例

```cpp
UCLASS()
class UMyMenuWidget : public UCommonActivatableWidget {
    GENERATED_BODY()

public:
    virtual void NativeOnActivated() override {
        Super::NativeOnActivated();
        // Menu activated (shown)
    }

    virtual void NativeOnDeactivated() override {
        Super::NativeOnDeactivated();
        // Menu deactivated (hidden)
    }
};
```

---

## HUD 类（UMG 的替代方案）

### 创建 HUD

```cpp
UCLASS()
class AMyHUD : public AHUD {
    GENERATED_BODY()

public:
    virtual void DrawHUD() override {
        Super::DrawHUD();

        // Draw text
        DrawText(TEXT("Score: 100"), FLinearColor::White, 50, 50);

        // Draw texture
        DrawTexture(CrosshairTexture, Canvas->SizeX / 2, Canvas->SizeY / 2, 32, 32);
    }
};
```

---

## 性能建议

### 优化 UMG

```cpp
// Invalidation boxes: Only redraw when content changes
// Add "Invalidation Box" widget to Widget Blueprint

// Disable tick if not needed
bIsFocusable = false;
SetVisibility(ESlateVisibility::Collapsed); // Collapsed = not rendered
```

---

## 调试

### UI 调试命令

```cpp
// Console commands:
// widget.debug - Show widget hierarchy
// Slate.ShowDebugOutlines 1 - Show widget bounds
// stat slate - Show Slate performance
```

---

## 来源
- https://docs.unrealengine.com/5.7/en-US/umg-ui-designer-for-unreal-engine/
- https://docs.unrealengine.com/5.7/en-US/commonui-plugin-for-advanced-user-interfaces-in-unreal-engine/
