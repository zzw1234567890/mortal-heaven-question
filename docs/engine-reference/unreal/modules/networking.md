
# Unreal Engine 5.7 — 网络模块参考

**最后验证：** 2026-02-13
**知识缺口：** UE 5.7 网络改进

---

## 概览

UE 5.7 网络：
- **客户端-服务器架构 (Client-Server Architecture)**：服务器权威（推荐）
- **复制 (Replication)**：自动状态同步
- **RPC (Remote Procedure Calls，远程过程调用)**：跨网络调用函数
- **相关性 (Relevancy)**：仅复制相关 Actor 以优化带宽

---

## 基础多人设置

### 在 Actor 上启用复制

```cpp
UCLASS()
class AMyActor : public AActor {
    GENERATED_BODY()

public:
    AMyActor() {
        // ✅ Enable replication
        bReplicates = true;
        bAlwaysRelevant = true; // Always replicate to all clients
    }
};
```

### 网络角色检查

```cpp
// Check role
if (HasAuthority()) {
    // Running on server
}

if (GetLocalRole() == ROLE_AutonomousProxy) {
    // This is the owning client (local player)
}

if (GetRemoteRole() == ROLE_SimulatedProxy) {
    // This is a remote client (other players)
}
```

---

## 复制变量

### 基础复制

```cpp
UPROPERTY(Replicated)
int32 Health;

UPROPERTY(Replicated)
FVector Position;

// ✅ Implement GetLifetimeReplicatedProps
void AMyActor::GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const {
    Super::GetLifetimeReplicatedProps(OutLifetimeProps);

    DOREPLIFETIME(AMyActor, Health);
    DOREPLIFETIME(AMyActor, Position);
}
```

### 条件复制

```cpp
// Only replicate to owner
DOREPLIFETIME_CONDITION(AMyCharacter, Ammo, COND_OwnerOnly);

// Skip owner (replicate to everyone else)
DOREPLIFETIME_CONDITION(AMyCharacter, TeamID, COND_SkipOwner);

// Only when changed
DOREPLIFETIME_CONDITION(AMyCharacter, Score, COND_InitialOnly);
```

### RepNotify（复制时回调）

```cpp
UPROPERTY(ReplicatedUsing=OnRep_Health)
int32 Health;

UFUNCTION()
void OnRep_Health() {
    // Called on clients when Health changes
    UpdateHealthUI();
}

// Implement GetLifetimeReplicatedProps (same as above)
```

---

## RPC (Remote Procedure Calls，远程过程调用)

### Server RPC（客户端 → 服务器）

```cpp
// Client calls, server executes
UFUNCTION(Server, Reliable)
void Server_TakeDamage(int32 Damage);

void AMyCharacter::Server_TakeDamage_Implementation(int32 Damage) {
    // Runs on server only
    Health -= Damage;

    if (Health <= 0) {
        Server_Die();
    }
}

bool AMyCharacter::Server_TakeDamage_Validate(int32 Damage) {
    // Validate input (anti-cheat)
    return Damage >= 0 && Damage <= 100;
}
```

### Client RPC（服务器 → 客户端）

```cpp
// Server calls, client executes
UFUNCTION(Client, Reliable)
void Client_ShowDeathScreen();

void AMyCharacter::Client_ShowDeathScreen_Implementation() {
    // Runs on client only
    ShowDeathUI();
}
```

### Multicast RPC（服务器 → 所有客户端）

```cpp
// Server calls, all clients execute
UFUNCTION(NetMulticast, Reliable)
void Multicast_PlayExplosion(FVector Location);

void AMyActor::Multicast_PlayExplosion_Implementation(FVector Location) {
    // Runs on server and all clients
    UGameplayStatics::SpawnEmitterAtLocation(GetWorld(), ExplosionEffect, Location);
}
```

### RPC 可靠性

```cpp
// Reliable: Guaranteed delivery (important events)
UFUNCTION(Server, Reliable)
void Server_FireWeapon();

// Unreliable: Best-effort delivery (frequent updates, position sync)
UFUNCTION(Server, Unreliable)
void Server_UpdateAim(FRotator AimRotation);
```

---

## 服务器权威模式（推荐）

### 移动示例

```cpp
class AMyCharacter : public ACharacter {
    UPROPERTY(Replicated)
    FVector ServerPosition;

    void Tick(float DeltaTime) override {
        Super::Tick(DeltaTime);

        if (GetLocalRole() == ROLE_AutonomousProxy) {
            // Client: Send input to server
            FVector Input = GetMovementInput();
            Server_Move(Input);

            // Client-side prediction (move locally)
            AddMovementInput(Input);
        }

        if (HasAuthority()) {
            // Server: Authoritative position
            ServerPosition = GetActorLocation();
        } else {
            // Client: Interpolate toward server position
            FVector NewPos = FMath::VInterpTo(GetActorLocation(), ServerPosition, DeltaTime, 5.0f);
            SetActorLocation(NewPos);
        }
    }

    UFUNCTION(Server, Unreliable)
    void Server_Move(FVector Input);

    void Server_Move_Implementation(FVector Input) {
        // Server validates and applies movement
        AddMovementInput(Input);
    }
};
```

---

## 网络相关性（带宽优化）

### 自定义相关性

```cpp
bool AMyActor::IsNetRelevantFor(const AActor* RealViewer, const AActor* ViewTarget, const FVector& SrcLocation) const {
    // Only replicate if within range
    float Distance = FVector::Dist(SrcLocation, GetActorLocation());
    return Distance < 5000.0f;
}
```

### 始终相关 Actor

```cpp
AMyActor() {
    bAlwaysRelevant = true; // Replicate to all clients (e.g., GameState, PlayerController)
    bOnlyRelevantToOwner = true; // Only replicate to owner (e.g., PlayerController)
}
```

---

## 所有权

### 设置 Owner

```cpp
// Assign owner (important for RPCs and relevancy)
MyActor->SetOwner(OwningPlayerController);
```

### 检查 Owner

```cpp
if (GetOwner() == PlayerController) {
    // This actor is owned by this player
}
```

---

## Game Mode 与 Game State

### Game Mode（仅服务器）

```cpp
UCLASS()
class AMyGameMode : public AGameMode {
    GENERATED_BODY()

public:
    // Game mode only exists on server
    // Use for server-side logic (spawning, scoring, rules)
};
```

### Game State（复制到所有客户端）

```cpp
UCLASS()
class AMyGameState : public AGameState {
    GENERATED_BODY()

public:
    // ✅ Replicate game state to all clients
    UPROPERTY(Replicated)
    int32 RedTeamScore;

    UPROPERTY(Replicated)
    int32 BlueTeamScore;

    virtual void GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const override {
        Super::GetLifetimeReplicatedProps(OutLifetimeProps);
        DOREPLIFETIME(AMyGameState, RedTeamScore);
        DOREPLIFETIME(AMyGameState, BlueTeamScore);
    }
};
```

---

## Player Controller 与 Player State

### Player Controller（每名玩家一个）

```cpp
UCLASS()
class AMyPlayerController : public APlayerController {
    GENERATED_BODY()

public:
    // Exists on server and owning client
    // Use for player-specific logic, input handling
};
```

### Player State（复制的玩家信息）

```cpp
UCLASS()
class AMyPlayerState : public APlayerState {
    GENERATED_BODY()

public:
    UPROPERTY(Replicated)
    int32 Kills;

    UPROPERTY(Replicated)
    int32 Deaths;

    virtual void GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const override {
        Super::GetLifetimeReplicatedProps(OutLifetimeProps);
        DOREPLIFETIME(AMyPlayerState, Kills);
        DOREPLIFETIME(AMyPlayerState, Deaths);
    }
};
```

---

## 会话与匹配

### 创建会话

```cpp
#include "OnlineSubsystem.h"
#include "OnlineSessionSettings.h"

void CreateSession() {
    IOnlineSubsystem* OnlineSub = IOnlineSubsystem::Get();
    IOnlineSessionPtr Sessions = OnlineSub->GetSessionInterface();

    TSharedPtr<FOnlineSessionSettings> SessionSettings = MakeShareable(new FOnlineSessionSettings());
    SessionSettings->bIsLANMatch = false;
    SessionSettings->NumPublicConnections = 4;
    SessionSettings->bShouldAdvertise = true;

    Sessions->CreateSession(0, FName("MySession"), *SessionSettings);
}
```

### 查找会话

```cpp
void FindSessions() {
    IOnlineSubsystem* OnlineSub = IOnlineSubsystem::Get();
    IOnlineSessionPtr Sessions = OnlineSub->GetSessionInterface();

    TSharedRef<FOnlineSessionSearch> SearchSettings = MakeShareable(new FOnlineSessionSearch());
    SearchSettings->bIsLanQuery = false;
    SearchSettings->MaxSearchResults = 20;

    Sessions->FindSessions(0, SearchSettings);
}
```

---

## 性能建议

### 降低带宽

```cpp
// Use unreliable RPCs for frequent updates
UFUNCTION(Server, Unreliable)
void Server_UpdatePosition(FVector Pos);

// Conditional replication (only replicate to relevant clients)
DOREPLIFETIME_CONDITION(AMyActor, Health, COND_OwnerOnly);

// Limit replication frequency
SetReplicationFrequency(10.0f); // Update 10 times per second (default 100)
```

---

## 调试

### 网络调试

```cpp
// Console commands:
// stat net - Show network stats
// stat netplayerupdate - Show player update stats
// NetEmulation PktLoss=10 - Simulate 10% packet loss
// NetEmulation PktLag=100 - Simulate 100ms latency

// Draw debug for replication:
UE_LOG(LogNet, Warning, TEXT("Replicating Health: %d"), Health);
```

---

## 来源
- https://docs.unrealengine.com/5.7/en-US/networking-and-multiplayer-in-unreal-engine/
- https://docs.unrealengine.com/5.7/en-US/actor-replication-in-unreal-engine/
- https://docs.unrealengine.com/5.7/en-US/rpcs-in-unreal-engine/
