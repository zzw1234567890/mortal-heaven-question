
# 代理测试规格：unity-ui-specialist

## 代理摘要
领域：Unity UI Toolkit（UXML/USS）、UGUI（Canvas）、数据绑定、运行时 UI 性能以及 UI 输入事件处理 (UI input event handling)。
不负责：用户体验流程设计（ux-designer）、视觉美术风格（art-director）。
模型层级：Sonnet（默认）。
未分配门禁 ID。

---

## 静态断言（结构性）

- [ ] `description:` 字段存在且与领域相关（提及 UI Toolkit / UGUI / Canvas / 数据绑定）
- [ ] `allowed-tools:` 列表包含 Read、Write、Edit、Bash、Glob、Grep
- [ ] 模型层级为 Sonnet（专家代理默认值）
- [ ] 代理定义未宣称对用户体验流程设计或视觉美术方向的管辖权

---

## 测试用例

### 用例 1：领域内请求 —— 合适的输出
**输入：** "使用 Unity UI Toolkit 实现一个背包 UI 界面。"
**预期行为：**
- 产出定义背包面板结构的 UXML 文档（ListView、物品模板、详情面板）
- 产出背包布局和物品状态（默认、悬停、选中）的 USS 样式
- 提供通过 `INotifyValueChanged` 或 `IBindable` 将背包数据模型绑定到 UI 的 C# 代码
- 使用带有 `makeItem` / `bindItem` 回调的 `ListView` 实现可滚动物品列表
- 不产出用户体验流程设计 —— 根据提供的规格实现

### 用例 2：领域外重定向
**输入：** "设计背包的用户体验流程 —— 玩家装备与丢弃物品时分别会发生什么。"
**预期行为：**
- 不产出用户体验流程设计
- 明确说明交互流程设计属于 `ux-designer`
- 将请求重定向到 `ux-designer`
- 注明将按照 ux-designer 指定的任何流程进行实现

### 用例 3：用于动态列表的 UI Toolkit 数据绑定
**输入：** "当物品从玩家背包中添加或移除时，背包列表需要实时更新。"
**预期行为：**
- 产出带有绑定 `ObservableList<T>` 或事件驱动刷新方法的 `ListView` 模式
- 在后备集合变更事件上使用 `ListView.Rebuild()` 或 `ListView.RefreshItems()`
- 说明大型列表的性能考量（通过 `makeItem`/`bindItem` 模式实现虚拟化）
- 不使用 `QuerySelector` 循环逐个更新元素作为列表刷新策略 —— 将其标记为性能反模式

### 用例 4：Canvas 性能 —— 过度绘制
**输入：** "主菜单 Canvas 引起了 GPU 过度绘制警告；有许多重叠的面板。"
**预期行为：**
- 识别过度绘制原因：多个堆叠的 Canvas、全屏叠加面板在非活跃时未被裁剪
- 建议：
  - 分别为世界空间、屏幕空间叠加和屏幕空间摄像机层使用独立的 Canvas
  - 禁用/停用面板，而非将 alpha 设为 0（不可见的 alpha-0 面板仍然会绘制）
  - 使用 Canvas Group + alpha 实现淡入淡出效果，而非单独调整 Image 的 alpha
- 如果项目处于迁移阶段，注明 UI Toolkit 作为替代方案

### 用例 5：上下文传递 —— Unity 版本
**输入：** 项目上下文：Unity 2022.3 LTS。请求："使用数据绑定实现设置面板。"
**预期行为：**
- 使用 2022.3 LTS 版本运行时绑定系统的 UI Toolkit
- 注明 Unity 2022.3 引入了运行时数据绑定（相较于早期版本仅限编辑器的绑定）
- 不使用 Unity 6 增强绑定 API 中在 2022.3 中不可用的功能
- 产出与所述 Unity 版本兼容的代码，并附有版本特定的 API 说明

---

## 协议合规

- [ ] 保持在声明的领域内（UI Toolkit、UGUI、数据绑定、UI 性能）
- [ ] 将用户体验流程设计重定向到 ux-designer
- [ ] 返回结构化输出（UXML、USS、C# 绑定代码）
- [ ] 使用与项目 Unity 版本匹配的正确 Unity UI 框架版本
- [ ] 将 Canvas 过度绘制标记为性能反模式并提供具体的修复建议
- [ ] 不使用 alpha-0 作为显示/隐藏模式 —— 使用 SetActive() 或 VisualElement.style.display

---

## 覆盖说明
- 背包 UI（用例 1）应在 `production/qa/evidence/` 中备有手动演练文档
- 动态列表绑定（用例 3）应有集成测试或自动化交互测试
- Canvas 过度绘制（用例 4）验证代理了解正确的 Unity UI 性能模式
