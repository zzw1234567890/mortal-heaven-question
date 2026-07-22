
# 代理测试规格：unity-dots-specialist

## 代理摘要
领域：ECS 架构（IComponentData、ISystem、SystemAPI）、Jobs 系统（IJob、IJobEntity、Burst）、Burst 编译器约束、DOTS 玩法系统以及混合渲染器 (hybrid renderer)。
不负责：MonoBehaviour 玩法代码（gameplay-programmer）、UI 实现（unity-ui-specialist）。
模型层级：Sonnet（默认）。
未分配门禁 ID。

---

## 静态断言（结构性）

- [ ] `description:` 字段存在且与领域相关（提及 ECS / Jobs / Burst / IComponentData）
- [ ] `allowed-tools:` 列表包含 Read、Write、Edit、Bash、Glob、Grep
- [ ] 模型层级为 Sonnet（专家代理默认值）
- [ ] 代理定义未宣称对 MonoBehaviour 玩法或 UI 系统的管辖权

---

## 测试用例

### 用例 1：领域内请求 —— 合适的输出
**输入：** "将玩家移动系统转换为 ECS。"
**预期行为：**
- 产出：
  - 包含速度、移动速度和输入向量字段的 `PlayerMovementData : IComponentData` 结构体
  - 使用 `SystemAPI.Query<>` 或 `IJobEntity` 实现 `OnUpdate()` 的 `PlayerMovementSystem : ISystem`
  - 通过 `IBaker` 从创作 MonoBehaviour 烘焙玩家的初始状态
- 使用 `RefRW<LocalTransform>` 进行位置更新（而非已弃用的 `Translation`）
- 标记作业为 `[BurstCompile]`，并注明为实现 Burst 兼容性，哪些内容必须为非托管类型
- 不修改输入轮询系统 —— 从现有的 `PlayerInputData` 组件读取

### 用例 2：MonoBehaviour 回推
**输入：** "直接用 MonoBehaviour 做玩家移动就行了 —— 更简单。"
**预期行为：**
- 承认简单性的论点
- 解释 DOTS 的权衡：前期设置更多，但 ECS/Burst 方法能提供项目 ADR 或需求中记录的性能特性
- 如果项目已承诺使用 DOTS，则不实现 MonoBehaviour 版本
- 如果尚无承诺，将架构决策标记给 `lead-programmer` / `technical-director` 决定
- 不单方面做出 MonoBehaviour 与 DOTS 的决策

### 用例 3：Burst 不兼容的托管内存
**输入：** "这个 Burst 作业访问了一个 `List<EnemyData>` 来寻找最近的敌人。"
**预期行为：**
- 标记 `List<T>` 为与 Burst 编译不兼容的托管类型
- 不批准带有托管内存访问的 Burst 作业
- 提供正确的替代方案：根据用例使用 `NativeArray<EnemyData>`、`NativeList<EnemyData>` 或 `NativeHashMap<>`
- 注明 `NativeArray` 必须显式释放，或通过 `[DeallocateOnJobCompletion]` 自动释放
- 产出使用非托管原生容器的修正后作业

### 用例 4：混合访问 —— DOTS 系统需要 MonoBehaviour 数据
**输入：** "DOTS 移动系统需要读取由 MonoBehaviour CameraController 管理的摄像机变换。"
**预期行为：**
- 识别此为混合访问场景
- 提供正确的混合模式：将摄像机变换存储在单例 `IComponentData` 中（每帧从 MonoBehaviour 侧通过 `EntityManager.SetComponentData` 更新）
- 或者建议使用 `CompanionComponent` / 托管组件方法
- 不直接从 Burst 作业内部访问 MonoBehaviour —— 将其标记为不安全
- 在 MonoBehaviour 侧（写入 ECS）和 DOTS 系统侧（从 ECS 读取）都提供桥接代码

### 用例 5：上下文传递 —— 性能目标
**输入：** 来自上下文的技术偏好：60fps 目标，每帧最大 2ms CPU 脚本预算。请求："为 10,000 个敌人实体设计 ECS 块布局。"
**预期行为：**
- 在设计理由中明确引用 2ms CPU 预算
- 为缓存效率设计 `IComponentData` 块布局：
  - 将经常一起查询的组件分组在同一个原型 (archetype) 中
  - 将不常用的数据分离到单独的组件中，以保持热数据紧凑
  - 针对 2ms 预算估算实体迭代时间
- 提供内存布局分析（每实体字节数，16KB 块大小下每块实体数）
- 不设计会明显超出所述 2ms 预算且未加标记的布局

---

## 协议合规

- [ ] 保持在声明的领域内（ECS、Jobs、Burst、DOTS 玩法系统）
- [ ] 将仅涉及 MonoBehaviour 的玩法内容重定向到 gameplay-programmer
- [ ] 返回结构化输出（IComponentData 结构体、ISystem 实现、IBaker 创作类）
- [ ] 将 Burst 作业中的托管内存访问标记为编译错误，并提供非托管替代方案
- [ ] 在 DOTS 系统需要与 MonoBehaviour 系统交互时提供混合访问模式
- [ ] 根据提供的性能预算设计块布局

---

## 覆盖说明
- ECS 转换（用例 1）必须包含使用 ECS 测试框架（`World`、`EntityManager`）的单元测试
- Burst 不兼容（用例 3）关乎安全关键 —— 代理必须在代码写出之前发现此问题
- 块布局（用例 5）验证代理将定量性能推理应用于架构决策
