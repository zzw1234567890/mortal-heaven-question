
# 代理测试规格：unity-addressables-specialist

## 代理摘要
领域：可寻址资产系统 (Addressable Asset System) —— 组 (groups)、异步加载/卸载、句柄生命周期管理、内存预算、内容目录 (content catalogs) 和远程内容交付 (remote content delivery)。
不负责：渲染系统（engine-programmer）、使用已加载资产的游戏逻辑（gameplay-programmer）。
模型层级：Sonnet（默认）。
未分配门禁 ID。

---

## 静态断言（结构性）

- [ ] `description:` 字段存在且与领域相关（提及 Addressables / 资源加载 / 内容目录 / 远程交付）
- [ ] `allowed-tools:` 列表包含 Read、Write、Edit、Bash、Glob、Grep
- [ ] 模型层级为 Sonnet（专家代理默认值）
- [ ] 代理定义未宣称对渲染系统或使用已加载资产的游戏逻辑的管辖权

---

## 测试用例

### 用例 1：领域内请求 —— 合适的输出
**输入：** "异步加载一个角色纹理，并在角色销毁时释放它。"
**预期行为：**
- 产出 `Addressables.LoadAssetAsync<Texture2D>()` 调用模式
- 将返回的 `AsyncOperationHandle<Texture2D>` 存储在请求对象中
- 在角色销毁时（`OnDestroy()`），使用存储的句柄调用 `Addressables.Release(handle)`
- 不使用 `Resources.Load()` 作为加载机制
- 注明使用空值或未初始化句柄进行释放会导致错误 —— 包括有效性检查
- 说明释放句柄与释放资产之间的区别（正确做法是释放句柄）

### 用例 2：领域外重定向
**输入：** "实现将加载的纹理应用到角色网格的渲染系统。"
**预期行为：**
- 不产出渲染或网格材质分配代码
- 明确说明渲染系统实现属于 `engine-programmer`
- 将请求重定向到 `engine-programmer`
- 可以作为交接规格描述其将提供的资产类型和 API 表面（例如，句柄完成后的 `Texture2D` 引用）

### 用例 3：内存泄漏 —— 未释放的句柄
**输入：** "每次加载关卡后内存使用量不断攀升。我们使用 Addressables 加载关卡资产。"
**预期行为：**
- 诊断可能的原因：`AsyncOperationHandle` 对象在使用后未被释放
- 识别句柄泄漏模式：将资产加载到局部变量、丢失引用、从未调用 `Addressables.Release()`
- 产出审计方法：搜索所有 `LoadAssetAsync` / `LoadSceneAsync` 调用并验证对应的 `Release()` 调用
- 提供使用跟踪句柄列表（`List<AsyncOperationHandle>`）和 `ReleaseAll()` 清理方法的修正模式
- 在没有证据的情况下不假定泄漏发生在其他地方

### 用例 4：远程内容交付 —— 目录版本管理
**输入：** "我们需要支持可下载内容更新，而无需完全重新安装应用程序。"
**预期行为：**
- 产出远程目录更新模式：
  - 启动时调用 `Addressables.CheckForCatalogUpdates()`
  - 检测到更新时调用 `Addressables.UpdateCatalogs()`
  - 使用 `Addressables.DownloadDependenciesAsync()` 预加载更新后的内容
- 说明目录哈希检查用于变更检测
- 处理边缘情况：玩家在会话进行中时目录更新会发生什么 —— 定义行为（在旧目录下完成当前会话，下次启动时重新加载）
- 不设计服务器端 CDN 基础设施（交由 devops-engineer 处理）

### 用例 5：上下文传递 —— 平台内存限制
**输入：** 平台上下文：Nintendo Switch 目标，4GB RAM，实际资产内存上限 512MB。请求："为大型开放世界关卡设计 Addressables 加载策略。"
**预期行为：**
- 引用所提供的上下文中的 512MB 内存上限
- 设计流式传输策略：
  - 将世界划分为可寻址区域，根据玩家距离加载/卸载
  - 定义每个活动区域的内存预算（例如 128MB，最多 4 个区域同时活动）
  - 指定异步预加载触发距离和卸载距离（迟滞）
- 注明 Switch 特有约束：SD 卡加载时间较慢，建议预加载相邻区域
- 不产出会明显超出所述 512MB 上限且未加标记的加载策略

---

## 协议合规

- [ ] 保持在声明的领域内（Addressables 加载、句柄生命周期、内存、目录、远程交付）
- [ ] 将渲染和使用资产资源的游戏代码重定向到 engine-programmer 和 gameplay-programmer
- [ ] 返回结构化输出（加载模式、句柄生命周期代码、流式传输区域设计）
- [ ] 始终将 `LoadAssetAsync` 与对应的 `Release()` 配对 —— 将句柄泄漏标记为内存错误
- [ ] 根据所提供的内存上限设计加载策略
- [ ] 不设计 CDN/服务器基础设施 —— 服务端交由 devops-engineer 处理

---

## 覆盖说明
- 句柄生命周期（用例 1）必须包含一个测试，验证释放后内存已被回收
- 句柄泄漏诊断（用例 3）应产出适合作为 Bug 工单的发现报告
- 平台内存用例（用例 5）验证代理应用上下文中的硬约束，而非默认假设
