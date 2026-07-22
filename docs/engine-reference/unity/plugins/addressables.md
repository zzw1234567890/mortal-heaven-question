
# Unity 6.3 — Addressables

**最后验证：** 2026-02-13
**状态：** 生产可用
**包：** `com.unity.addressables`（Package Manager）

---

## 概述

**Addressables** 是 Unity 的高级资产管理系统，用异步加载、远程内容分发和更优的内存控制替代了 `Resources.Load()`。

**适用场景：**
- 异步资产加载（非阻塞）
- DLC 和远程内容
- 内存优化（按需加载/卸载）
- 资产依赖管理
- 包含大量资产的大型项目

**不适用场景：**
- 小型项目（开销不值得）
- 启动时立即需要的资产（使用直接引用）

---

## 安装

### 通过 Package Manager 安装

1. `Window > Package Manager`
2. Unity Registry > 搜索 "Addressables"
3. 安装 `Addressables`

---

## 核心概念

### 1. **Addressable Assets**
- 被标记为 "Addressable" 的资产（分配唯一键）
- 可在运行时按键加载

### 2. **Asset Groups**
- 组织资产（例如 "UI"、"Weapons"、"Level1"）
- 分组决定构建设置（本地还是远程）

### 3. **Async Loading**
- 所有加载均为异步（非阻塞）
- 返回 `AsyncOperationHandle`

### 4. **Reference Counting**
- Addressables 跟踪资产使用情况
- 使用完毕后必须手动释放资产

---

## 设置

### 1. 将资产标记为 Addressable

1. 在 Project 窗口选中资产
2. Inspector > 勾选 "Addressable"
3. 分配键（例如 "Enemies/Goblin"）

**或通过脚本：**
```csharp
#if UNITY_EDITOR
using UnityEditor.AddressableAssets;
using UnityEditor.AddressableAssets.Settings;

AddressableAssetSettings.AddAssetEntry(guid, "MyAssetKey", "Default Local Group");
#endif
```

---

### 2. 创建分组

`Window > Asset Management > Addressables > Groups`

- **Default Local Group**：随构建打包
- **Remote Group**：托管在服务器上（CDN）

---

## 基础加载

### 异步加载资产

```csharp
using UnityEngine.AddressableAssets;
using UnityEngine.ResourceManagement.AsyncOperations;

public class AssetLoader : MonoBehaviour {
    async void Start() {
        // ✅ Load asset asynchronously
        AsyncOperationHandle<GameObject> handle = Addressables.LoadAssetAsync<GameObject>("Enemies/Goblin");
        await handle.Task;

        if (handle.Status == AsyncOperationStatus.Succeeded) {
            GameObject prefab = handle.Result;
            Instantiate(prefab);
        } else {
            Debug.LogError("Failed to load asset");
        }

        // ⚠️ IMPORTANT: Release when done
        Addressables.Release(handle);
    }
}
```

---

### 加载并实例化

```csharp
async void SpawnEnemy() {
    // ✅ Load and instantiate in one step
    AsyncOperationHandle<GameObject> handle = Addressables.InstantiateAsync("Enemies/Goblin");
    await handle.Task;

    GameObject enemy = handle.Result;
    // Use enemy...

    // ✅ Release when destroying
    Addressables.ReleaseInstance(enemy);
}
```

---

### 加载多个资产

```csharp
async void LoadAllWeapons() {
    // Load all assets with label "Weapons"
    AsyncOperationHandle<IList<GameObject>> handle = Addressables.LoadAssetsAsync<GameObject>("Weapons", null);
    await handle.Task;

    foreach (var weapon in handle.Result) {
        Debug.Log($"Loaded: {weapon.name}");
    }

    Addressables.Release(handle);
}
```

---

## 资产标签

### 分配标签

1. `Window > Asset Management > Addressables > Groups`
2. 选中资产 > Inspector > Labels > 添加标签（例如 "Level1"、"UI"）

### 按标签加载

```csharp
// Load all assets with label "Level1"
Addressables.LoadAssetsAsync<GameObject>("Level1", null);
```

---

## 远程内容（DLC）

### 设置远程分组

1. 创建新分组：`Window > Addressables > Groups > Create New Group > Packed Assets`
2. 分组设置：
   - **Build Path**：`ServerData/[BuildTarget]`
   - **Load Path**：`http://yourcdn.com/content/[BuildTarget]`

### 构建远程内容

1. `Window > Asset Management > Addressables > Build > New Build > Default Build Script`
2. 将 `ServerData/` 文件夹上传到 CDN
3. 游戏从远程服务器加载资产

---

## 预加载 / 缓存

### 下载依赖项

```csharp
async void PreloadLevel() {
    // Download all assets in group without loading into memory
    AsyncOperationHandle handle = Addressables.DownloadDependenciesAsync("Level1");
    await handle.Task;

    // Now "Level1" assets are cached, load instantly
    Addressables.Release(handle);
}
```

### 检查下载大小

```csharp
async void CheckDownloadSize() {
    AsyncOperationHandle<long> handle = Addressables.GetDownloadSizeAsync("Level1");
    await handle.Task;

    long sizeInBytes = handle.Result;
    Debug.Log($"Download size: {sizeInBytes / (1024 * 1024)} MB");

    Addressables.Release(handle);
}
```

---

## 内存管理

### 释放资产

```csharp
// ✅ Always release when done
Addressables.Release(handle);

// ✅ For instantiated objects
Addressables.ReleaseInstance(gameObject);
```

### 检查引用计数

```csharp
// Addressables uses reference counting
// Asset is unloaded when refCount == 0
```

---

## 资产引用（在 Inspector 中分配）

### 使用 AssetReference

```csharp
using UnityEngine.AddressableAssets;

public class EnemySpawner : MonoBehaviour {
    // ✅ Assign in Inspector (drag & drop)
    public AssetReference enemyPrefab;

    async void SpawnEnemy() {
        AsyncOperationHandle<GameObject> handle = enemyPrefab.InstantiateAsync();
        await handle.Task;

        GameObject enemy = handle.Result;
        // Use enemy...

        enemyPrefab.ReleaseInstance(enemy);
    }
}
```

---

## 场景

### 加载 Addressable 场景

```csharp
using UnityEngine.SceneManagement;

async void LoadScene() {
    AsyncOperationHandle<SceneInstance> handle = Addressables.LoadSceneAsync("MainMenu", LoadSceneMode.Additive);
    await handle.Task;

    SceneInstance sceneInstance = handle.Result;
    // Scene loaded

    // Unload scene
    await Addressables.UnloadSceneAsync(handle).Task;
}
```

---

## 常见模式

### 懒加载（按需加载）

```csharp
Dictionary<string, AsyncOperationHandle<GameObject>> loadedAssets = new();

async Task<GameObject> GetAsset(string key) {
    if (!loadedAssets.ContainsKey(key)) {
        var handle = Addressables.LoadAssetAsync<GameObject>(key);
        await handle.Task;
        loadedAssets[key] = handle;
    }
    return loadedAssets[key].Result;
}
```

---

### 场景卸载时清理

```csharp
void OnDestroy() {
    // Release all handles
    foreach (var handle in loadedAssets.Values) {
        Addressables.Release(handle);
    }
    loadedAssets.Clear();
}
```

---

## 内容目录更新（热更新）

### 检查目录更新

```csharp
async void CheckForUpdates() {
    AsyncOperationHandle<List<string>> handle = Addressables.CheckForCatalogUpdates();
    await handle.Task;

    if (handle.Result.Count > 0) {
        Debug.Log("Updates available");
        await Addressables.UpdateCatalogs(handle.Result).Task;
    }

    Addressables.Release(handle);
}
```

---

## 性能提示

- 在启动时**预加载**常用资产
- 不需要时立即**释放**资产
- 使用**标签**批量加载相关资产
- **缓存**远程内容以供离线使用

---

## 调试

### Addressables Event Viewer

`Window > Asset Management > Addressables > Event Viewer`

- 显示所有加载/释放操作
- 每个资产的内存使用
- 引用计数

### Addressables Profiler

`Window > Asset Management > Addressables > Profiler`

- 实时资产使用情况
- Bundle 加载统计

---

## 从 Resources 迁移

```csharp
// ❌ OLD: Resources.Load (synchronous, blocks frame)
GameObject prefab = Resources.Load<GameObject>("Enemies/Goblin");

// ✅ NEW: Addressables (async, non-blocking)
var handle = await Addressables.LoadAssetAsync<GameObject>("Enemies/Goblin").Task;
GameObject prefab = handle.Result;
```

---

## 来源
- https://docs.unity3d.com/Packages/com.unity.addressables@2.0/manual/index.html
- https://learn.unity.com/tutorial/addressables
