
# Godot — 当前最佳实践

Last verified: 2026-02-12 | 引擎：Godot 4.6

自模型训练数据（~4.3）以来**新增或变更**的实践。本文件是对 agent 内置知识的补充，而非替代。

## GDScript（4.5+）

- **可变参数**：函数可接受任意数量的参数
  ```gdscript
  func log_values(prefix: String, values: Variant...) -> void:
      for v in values:
          print(prefix, ": ", v)
  ```

- **抽象类与方法**：使用 `@abstract` 强制继承
  ```gdscript
  @abstract
  class_name BaseEnemy extends CharacterBody3D

  @abstract
  func get_attack_pattern() -> Array[Attack]:
      pass  # 子类必须重写
  ```

- **脚本回溯**：即使在 Release 构建中也可获得详细调用栈

## Physics（4.6）

- **Jolt Physics 是新项目的默认 3D 引擎**
  - 比 GodotPhysics3D 有更好的确定性和稳定性
  - 某些 HingeJoint3D 属性（`damp`）只在 GodotPhysics 下有效
  - 切换方式：Project Settings → Physics → 3D → Physics Engine
  - 2D 物理不变（仍为 Godot Physics 2D）

## Rendering（4.6）

- **D3D12 是 Windows 上的默认后端**（以前是 Vulkan）— 为了更好的驱动兼容性
- **Glow 现在在 tonemapping 之前处理**，采用屏幕混合模式 — 现有的 glow 配置可能呈现不同效果
- **SSR 全面翻新** — 在真实感、稳定性和性能上有显著提升
- **AgX tonemapper** — 新的白点和对比度控件

## Rendering（4.5）

- **Shader Baker**：预编译 shader 以消除启动时的卡顿
- **SMAA 1x**：新的抗锯齿选项 — 比 FXAA 更锐利，比 TAA 更便宜
- **模板缓冲**：可用于高级遮罩/门户效果
- **Bent normal maps**：法线贴图纹理中的方向性遮挡
- **Specular occlusion**：环境光遮蔽现在会影响反射

## Accessibility（4.5+）

- **屏幕阅读器支持**：Control 节点通过 AccessKit 与无障碍工具集成
- **实时翻译预览**：直接在编辑器内以不同语言测试 GUI 布局
- **FoldableContainer**：新的手风琴式 UI 节点，用于可折叠区段
- **递归 Control 禁用**：用单个属性禁用整个节点层级的鼠标/焦点交互

## Animation（4.5+）

- **BoneConstraint3D**：通过修饰器将骨骼绑定到其他骨骼
  - AimModifier3D、CopyTransformModifier3D、ConvertTransformModifier3D

## Animation（4.6）

- **IK 系统完全恢复**：3D 完整逆向运动学重新引入
  - 可用修饰器：CCDIK、FABRIK、Jacobian IK、Spline IK、TwoBoneIK
  - 通过 `SkeletonModifier3D` 节点应用

## Resources（4.5+）

- **`duplicate_deep()`**：用于嵌套资源树的显式深复制
  - 旧的 `duplicate()` 行为保留以向后兼容
  - 当你需要嵌套资源的逐实例副本时使用 `duplicate_deep()`

## 资源 UID 边车（4.4+）

- **`.uid` 边车文件由编辑器生成**，每个 `.gd` / `.gdshader` 旁各一个，内容一行
  `uid://xxxxx`。它们是 `uid://` 引用的解析表：`.tscn` / `.tres` 用
  `[ext_resource uid="uid://..."]` 引用资源时，靠它找到文件。
- **同一个 `res://` 路径生成的 UID 是确定的**——UID 由路径哈希得出，不随机。实测：
  删掉 `src/ui/main_menu/world_seam.gd.uid` 后重跑编辑器，生成的仍是
  `uid://c5gkxtx7smlog`（与删除前逐字相同）。因此「谁在哪台机器上补的」不影响结果。
- **生成方式**（无需开图形界面）：

  ```powershell
  godot --headless --editor --quit
  ```

  缺边车时编辑器启动会补齐；不打开编辑器则永远不生成。
- **本仓库的策略是提交 `.uid`**（`git ls-files "*.uid"` 可核对）。理由：路径哈希确定 ⇒
  提交它零成本；而「一半提交一半不提交」会让新克隆的机器在[b]首次打开编辑器之前[/b]
  对 `uid://` 引用解析失败。新增脚本提交时请一并 `git add` 其 `.uid`。

> 截至 2026-11-23，`src/` 下的 `.tscn` / `.tres` 全部用 `path="res://..."` 引用、
> 尚未使用 `uid://`——所以缺边车[b]当下[/b]不会立刻报错；但 `prototypes/` 与
> `resources/audio/` 已经用上了 `uid://`，那条路上缺边车就是硬失败。

## Navigation（4.5+）

- **专用 2D 导航服务器**：不再通过 3D NavigationServer 代理
  - 减少 2D 专用游戏的导出二进制体积

## UI（4.6）

- **双焦点系统**：鼠标/触摸焦点现在与键盘/手柄焦点分离
  - 视觉反馈因输入方式而异
  - 设计自定义焦点行为时需考虑这一点

## Editor Workflow（4.6）

- 灵活的停靠面板拖放，带蓝色轮廓预览（包括底部面板）
- 大多数面板支持浮动窗口（Debugger 除外）
- 新快捷键：Alt+O（Output）、Alt+S（Shader）
- 导出变量自动生成：从 FileSystem 拖动资源到脚本编辑器
- 启用 "Live Preview" 后在 Quick Open 对话框中实时预览
- 新的 "Select Mode"（v 键）防止误操作变换；旧模式更名为 "Transform Mode"（q 键）

## Tooling

- **ripgrep 没有 `gdscript` 类型**：`*.gd` 注册在 `gap`（GAP 编程语言）下。
  `rg --type gdscript` 是硬错误 — 搜索永远不会执行。
  请始终使用 `rg --glob "*.gd"`（shell）或 `glob: "*.gd"`（Grep 工具）来筛选 GDScript 文件。

## Platform（4.5+）

- **visionOS 导出**：自开源以来首个新平台（窗口应用模式）
- **SDL3 手柄驱动**：更好的跨平台手柄支持
- **Android**：Edge-to-edge 显示、摄像头画面访问、16KB 页支持（Android 15+）
- **Linux**：Wayland 子窗口支持，实现多窗口能力
