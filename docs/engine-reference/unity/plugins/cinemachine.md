
# Unity 6.3 — Cinemachine

**最后验证：** 2026-02-13
**状态：** 生产可用
**包：** `com.unity.cinemachine` v3.0+（Package Manager）

---

## 概述

**Cinemachine** 是 Unity 的虚拟相机系统，无需手动脚本即可实现专业、动态的相机行为。它是 Unity 相机工作的行业标准。

**适用场景：**
- 第三人称跟随相机
- 过场动画和电影式镜头
- 相机混合与过渡
- 动态相机构图
- 屏幕震动和相机效果

**⚠️ 知识缺口：** Cinemachine 3.0（Unity 6）相较 2.x 是一次重大重写。
许多 API 名称和组件已变更。

---

## 安装

### 通过 Package Manager 安装

1. `Window > Package Manager`
2. Unity Registry > 搜索 "Cinemachine"
3. 安装 `Cinemachine`（版本 3.0+）

---

## 核心概念

### 1. **Virtual Cameras**
- 定义相机行为（位置、旋转、镜头）
- 可存在多个虚拟相机；同一时间只有一个处于"活动"状态

### 2. **Cinemachine Brain**
- 主相机上的组件
- 在虚拟相机之间进行混合
- 将虚拟相机设置应用到 Unity Camera

### 3. **优先级**
- 虚拟相机具有优先级值
- 优先级最高的相机处于活动状态
- 优先级变化时平滑混合

---

## 基础设置

### 1. 为主相机添加 Cinemachine Brain

```csharp
// Automatically added when creating first virtual camera
// Or manually: Add Component > Cinemachine Brain
```

### 2. 创建虚拟相机

`GameObject > Cinemachine > Cinemachine Camera`

这会创建一个带有默认设置的 **CinemachineCamera** GameObject。

---

## 虚拟相机组件

### CinemachineCamera（Unity 6 / Cinemachine 3.0+）

```csharp
using Unity.Cinemachine;

public class CameraController : MonoBehaviour {
    public CinemachineCamera virtualCamera;

    void Start() {
        // Set priority (higher = active)
        virtualCamera.Priority = 10;

        // Set follow target
        virtualCamera.Follow = playerTransform;

        // Set look-at target
        virtualCamera.LookAt = playerTransform;
    }
}
```

---

## 跟随模式（Body 组件）

### 3rd Person Follow（Orbital Follow）

```csharp
// In Inspector:
// CinemachineCamera > Body > 3rd Person Follow

// Configure:
// - Shoulder Offset: (0.5, 0, 0) for over-shoulder
// - Camera Distance: 5.0
// - Vertical Damping: 0.5 (smooth up/down)
```

### Framing Transposer（平滑跟随）

```csharp
// CinemachineCamera > Body > Position Composer

// Configure:
// - Screen Position: Center (0.5, 0.5)
// - Dead Zone: Don't move camera if target within zone
// - Damping: Smooth following
```

### Hard Lock（精确跟随）

```csharp
// CinemachineCamera > Body > Hard Lock to Target
// Camera exactly matches target position (no offset or damping)
```

---

## 瞄准模式（Aim 组件）

### Composer（构图目标）

```csharp
// CinemachineCamera > Aim > Composer

// Configure:
// - Tracked Object Offset: Aim at target's head instead of feet
// - Screen Position: Where target appears on screen
// - Dead Zone: Don't rotate if target within zone
```

### Look At Target

```csharp
// CinemachineCamera > Aim > Rotate With Follow Target
// Camera rotation matches target rotation (e.g., first-person)
```

---

## 相机之间的混合

### 基于优先级的混合

```csharp
public CinemachineCamera normalCamera; // Priority: 10
public CinemachineCamera aimCamera;    // Priority: 5

void StartAiming() {
    // Set aim camera to higher priority
    aimCamera.Priority = 15; // Now active
    // Brain automatically blends from normalCamera to aimCamera
}

void StopAiming() {
    aimCamera.Priority = 5; // Back to normal
}
```

### 自定义混合时长

```csharp
// Create Custom Blends Asset:
// Assets > Create > Cinemachine > Cinemachine Blender Settings

// In Cinemachine Brain:
// - Custom Blends = your asset
// - Configure blend times per camera pair
```

---

## 相机震动

### Impulse Source（触发震动）

```csharp
using Unity.Cinemachine;

public class ExplosionShake : MonoBehaviour {
    public CinemachineImpulseSource impulseSource;

    void Explode() {
        // Trigger camera shake
        impulseSource.GenerateImpulse();
    }
}
```

### Impulse Listener（接收震动）

```csharp
// Add to CinemachineCamera:
// Add Component > CinemachineImpulseListener

// Impulse listener automatically receives shake from nearby Impulse Sources
```

---

## Freelook 相机（带鼠标视角的第三人称）

### Cinemachine Free Look

```csharp
// GameObject > Cinemachine > Cinemachine Free Look

// Creates 3 rigs (Top, Middle, Bottom) that blend based on vertical input
// Configure:
// - Orbit Radius: Distance from target
// - Height Offset: Camera height at each rig
// - X/Y Axis: Mouse or joystick input
```

---

## 状态驱动相机（基于 Animator）

### Cinemachine State-Driven Camera

```csharp
// GameObject > Cinemachine > Cinemachine State-Driven Camera

// Configure:
// - Animated Target: Character with Animator
// - Layer: Animator layer to track
// - State: Assign camera per animation state (Idle, Run, Jump, etc.)

// Camera automatically switches based on animation state
```

---

## Dolly 轨道（过场动画）

### Cinemachine Dolly Track

```csharp
// 1. Create Spline: GameObject > Cinemachine > Cinemachine Spline

// 2. Create Dolly Camera:
//    GameObject > Cinemachine > Cinemachine Camera
//    Body > Spline Dolly
//    Assign Spline

// 3. Animate dolly position on spline (Timeline or script)
```

---

## 常见模式

### 第三人称跟随相机

```csharp
// CinemachineCamera
// - Follow: Player Transform
// - Body: 3rd Person Follow (shoulder offset, distance: 5)
// - Aim: Composer (frame player at center)
```

---

### 瞄准相机（拉近）

```csharp
// Normal Camera (Priority 10):
//   - Distance: 5.0

// Aim Camera (Priority 5):
//   - Distance: 2.0
//   - FOV: Narrower

// Script:
void StartAiming() {
    aimCamera.Priority = 15; // Blend to aim camera
}
```

---

### 过场动画相机序列

```csharp
// Use Timeline:
// 1. Create Timeline (Assets > Create > Timeline)
// 2. Add Cinemachine Track
// 3. Add virtual cameras as clips
// 4. Timeline automatically blends between cameras
```

---

## 从 Cinemachine 2.x 迁移（Unity 2021）

### API 变更（Unity 6 / Cinemachine 3.0）

```csharp
// ❌ OLD (Cinemachine 2.x):
CinemachineVirtualCamera vcam;
vcam.m_Follow = target;

// ✅ NEW (Cinemachine 3.0+):
CinemachineCamera vcam;
vcam.Follow = target; // Cleaner API
```

**主要变更：**
- `CinemachineVirtualCamera` → `CinemachineCamera`
- `m_Follow`、`m_LookAt` → `Follow`、`LookAt`（无 "m_" 前缀）
- 组件重命名以提升清晰度
- 性能提升

---

## 性能提示

- 限制活动虚拟相机数量（仅在需要时激活）
- 使用较低优先级的相机，而非销毁/创建
- 当虚拟相机远离玩家时禁用

---

## 调试

### Cinemachine Debug

```csharp
// Window > Analysis > Cinemachine Debugger
// Shows active camera, blend info, shot quality
```

---

## 来源
- https://docs.unity3d.com/Packages/com.unity.cinemachine@3.0/manual/index.html
- https://learn.unity.com/tutorial/cinemachine
