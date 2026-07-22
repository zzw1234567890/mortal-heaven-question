
# Unity 6.3 LTS — 已弃用的 API

**最后验证：** 2026-02-13

已弃用 API 及其替代方案的快速查找表。
格式：**不要使用 X** → **改用 Y**

---

## Input

| 已弃用 | 替代方案 | 备注 |
|------------|-------------|-------|
| `Input.GetKey()` | `Keyboard.current[Key.X].isPressed` | 新 Input System |
| `Input.GetKeyDown()` | `Keyboard.current[Key.X].wasPressedThisFrame` | 新 Input System |
| `Input.GetMouseButton()` | `Mouse.current.leftButton.isPressed` | 新 Input System |
| `Input.GetAxis()` | `InputAction` 回调 | 新 Input System |
| `Input.mousePosition` | `Mouse.current.position.ReadValue()` | 新 Input System |

**迁移：** 安装 `com.unity.inputsystem` 包。

---

## UI

| 已弃用 | 替代方案 | 备注 |
|------------|-------------|-------|
| `Canvas` (UGUI) | `UIDocument` (UI Toolkit) | UI Toolkit 现已生产就绪 |
| `Text` 组件 | `TextMeshPro` 或 UI Toolkit `Label` | 更好的渲染，更少绘制调用 |
| `Image` 组件 | UI Toolkit `VisualElement` 加背景 | 更灵活的样式 |

**迁移：** UGUI 仍然可用，但新项目推荐 UI Toolkit。

---

## DOTS/Entities

| 已弃用 | 替代方案 | 备注 |
|------------|-------------|-------|
| `ComponentSystem` | `ISystem`（非托管） | Entities 1.0+ 彻底重写 |
| `JobComponentSystem` | `ISystem` 加 `IJobEntity` | 兼容 Burst |
| `GameObjectEntity` | 纯 ECS 工作流 | 无 GameObject 转换 |
| `EntityManager.CreateEntity()`（旧签名） | `EntityManager.CreateEntity(EntityArchetype)` | 显式原型 |
| `ComponentDataFromEntity<T>` | `ComponentLookup<T>` | Entities 1.0+ 重命名 |

**迁移：** 参见 Entities 包迁移指南。需要重大重构。

---

## Rendering

| 已弃用 | 替代方案 | 备注 |
|------------|-------------|-------|
| `CommandBuffer.DrawMesh()` | RenderGraph API | URP/HDRP 渲染通道 |
| `OnPreRender()` / `OnPostRender()` | `RenderPipelineManager` 回调 | SRP 兼容 |
| `Camera.SetReplacementShader()` | 自定义渲染通道 | SRP 中不支持 |

---

## Physics

| 已弃用 | 替代方案 | 备注 |
|------------|-------------|-------|
| `Physics.RaycastAll()` | `Physics.RaycastNonAlloc()` | 避免 GC 分配 |
| `Rigidbody.velocity`（直接写入） | `Rigidbody.AddForce()` | 更好的物理稳定性 |

---

## Asset Loading

| 已弃用 | 替代方案 | 备注 |
|------------|-------------|-------|
| `Resources.Load()` | Addressables | 更好的内存控制，异步加载 |
| 同步资产加载 | `Addressables.LoadAssetAsync()` | 非阻塞 |

---

## Animation

| 已弃用 | 替代方案 | 备注 |
|------------|-------------|-------|
| Legacy Animation 组件 | Animator Controller | Mecanim 系统 |
| `Animation.Play()` | `Animator.Play()` | 状态机控制 |

---

## Particles

| 已弃用 | 替代方案 | 备注 |
|------------|-------------|-------|
| Legacy Particle System | Visual Effect Graph | GPU 加速，性能更高 |

---

## Scripting

| 已弃用 | 替代方案 | 备注 |
|------------|-------------|-------|
| `WWW` 类 | `UnityWebRequest` | 现代异步网络 |
| `Application.LoadLevel()` | `SceneManager.LoadScene()` | 场景管理 |

---

## 平台相关

### WebGL
| 已弃用 | 替代方案 | 备注 |
|------------|-------------|-------|
| WebGL 1.0 | WebGL 2.0 或 WebGPU | Unity 6+ 默认使用 WebGPU |

---

## 快速迁移模式

### Input 示例
```csharp
// ❌ 已弃用
if (Input.GetKeyDown(KeyCode.Space)) {
    Jump();
}

// ✅ 新 Input System
using UnityEngine.InputSystem;
if (Keyboard.current.spaceKey.wasPressedThisFrame) {
    Jump();
}
```

### Asset Loading 示例
```csharp
// ❌ 已弃用
var prefab = Resources.Load<GameObject>("Enemies/Goblin");

// ✅ Addressables
var handle = Addressables.LoadAssetAsync<GameObject>("Enemies/Goblin");
await handle.Task;
var prefab = handle.Result;
```

### UI 示例
```csharp
// ❌ 已弃用（UGUI）
GetComponent<Text>().text = "Score: 100";

// ✅ TextMeshPro
GetComponent<TextMeshProUGUI>().text = "Score: 100";

// ✅ UI Toolkit
rootVisualElement.Q<Label>("score-label").text = "Score: 100";
```

---

**来源：**
- https://docs.unity3d.com/6000.0/Documentation/Manual/deprecated-features.html
- https://docs.unity3d.com/Packages/com.unity.inputsystem@1.11/manual/Migration.html
