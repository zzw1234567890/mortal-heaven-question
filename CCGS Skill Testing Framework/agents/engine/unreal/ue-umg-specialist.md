
# 智能体测试规格：ue-umg-specialist（UMG/UI 专家）

## 智能体概述
- **领域 (Domain)**：UMG 微件层级设计 (UMG widget hierarchy design)、数据绑定模式 (data binding patterns)、CommonUI 输入路由和动作标签、微件样式 (WidgetStyle 资源)、UI 优化（微件池化、ListView、无效化）
- **不负责**：UX 流程和屏幕导航设计 (ux-designer)、游戏逻辑 (gameplay-programmer)、后端数据源（游戏代码）、服务器通信
- **模型层级 (Model tier)**：Sonnet
- **关卡 ID**：无；UX 流程决策交由 ux-designer

---

## 静态断言（结构）

- [ ] `description:` 字段存在且具有领域针对性（涉及 UMG、微件层级、CommonUI）
- [ ] `allowed-tools:` 列表与智能体角色匹配（支持读取/写入 UI 资源和蓝图文件；无服务器或游戏源代码工具）
- [ ] 模型层级为 Sonnet（专家角色的默认值）
- [ ] 智能体定义未声称对 UX 流程、导航架构或游戏数据逻辑具有权威

---

## 测试用例

### 用例 1：领域内请求 —— 带数据绑定的库存微件
**输入**："创建一个库存微件，显示物品网格。每个格子应显示物品图标、数量和稀有度颜色。它需要在库存变化时更新。"
**预期行为**：
- 生成 UMG 微件结构：包含 UniformGridPanel 或 TileView 的父级 WBP_Inventory，每个物品对应一个子级 WBP_InventorySlot 微件
- 描述数据绑定方式：要么在 Inventory 组件上通过事件分发器 (Event Dispatchers) 触发刷新，要么使用 ListView 配合实现 IUserObjectListEntry 的 UObject 物品数据类
- 说明稀有度颜色如何驱动：使用 WidgetStyle 资源或数据表查找，而非硬编码的颜色值
- 输出包括微件层级、绑定模式和刷新触发机制

### 用例 2：领域外请求 —— UX 流程设计
**输入**："为我们的库存系统设计完整的导航流程 —— 玩家如何打开它、如何切换到角色属性界面、以及如何退出到暂停菜单。"
**预期行为**：
- 不生成导航流程或屏幕跳转架构
- 明确说明："导航流程和屏幕跳转设计由 ux-designer 负责；我可以在流程确定后实现 UMG 微件结构"
- 在没有 UX 规格的情况下，不做出 UX 决策（返回按钮行为、转场动画、模态 vs. 全屏）

### 用例 3：领域边界 —— CommonUI 输入动作不匹配
**输入**："我们的库存微件对控制器的返回按钮无响应。我们正在使用 CommonUI。"
**预期行为**：
- 确定可能的原因：微件的 Back 输入动作标签与项目注册的 CommonUI InputAction 数据资源不匹配
- 解释 CommonUI 输入路由模型：微件通过 `CommonUI_InputAction` 标签声明输入动作；CommonActivatableWidget 处理路由
- 提供修复方案：验证微件的 Back 动作标签是否与项目 CommonUI 输入动作数据表中注册的标签匹配
- 将其与硬件输入绑定问题（属于 Enhanced Input 范畴）区分开

### 用例 4：微件性能问题 —— 单帧大量微件实例化
**输入**："我们的排行榜微件一次性创建了 500 个独立的 WBP_LeaderboardRow 实例。打开排行榜时游戏卡顿了 300 毫秒。"
**预期行为**：
- 识别根本原因：单帧内 500 个微件实例化导致构建卡顿
- 建议切换到 ListView 或 TileView 并启用虚拟化 —— 仅构建可见行
- 解释 ListView 数据对象所需的 IUserObjectListEntry 接口要求
- 如果 ListView 不合适，建议使用对象池：预先实例化固定数量的行并用新数据重复使用
- 输出为具体的建议（应使用的具体 UMG 组件），而非模糊的"优化它"

### 用例 5：上下文传递 —— CommonUI 已配置完成
**输入上下文**：项目使用 CommonUI，已注册的 InputAction 标签为：UI.Action.Confirm、UI.Action.Back、UI.Action.Pause、UI.Action.Secondary。
**输入**："向库存微件添加一个 'Sort Inventory' 按钮，使其兼容 CommonUI。"
**预期行为**：
- 使用 UI.Action.Secondary（或建议注册一个如 UI.Action.Sort 的新标签，如果 Secondary 已被占用）
- 不发明新 InputAction 标签而不说明它必须在 CommonUI 数据表中注册
- 在 CommonUI 已是既定模式的情况下，不使用非 CommonUI 输入绑定方式（例如事件图中的原始按键）
- 在建议中明确引用所提供的标签列表

---

## 协议合规

- [ ] 保持在声明的领域内（UMG 结构、数据绑定、CommonUI、微件性能）
- [ ] 将 UX 流程和导航设计请求重定向给 ux-designer
- [ ] 返回结构化发现（微件层级 + 绑定模式），而非自由格式意见
- [ ] 使用上下文中现有的 CommonUI InputAction 标签；不发明新标签而不指出需要注册
- [ ] 对于大型集合，推荐虚拟化列表（ListView/TileView）优先于微件池化

---

## 覆盖范围说明
- 用例 3（CommonUI 输入路由）要求项目已配置 CommonUI；如果项目不使用 CommonUI 则跳过此测试
- 用例 4（性能）是高影响失效模式 —— 300ms 卡顿会阻碍发布；优先处理此用例
- 用例 5 是 UI 管线一致性方面最重要的上下文感知测试
- 无自动运行器；手动审查或通过 `/skill-test` 进行
