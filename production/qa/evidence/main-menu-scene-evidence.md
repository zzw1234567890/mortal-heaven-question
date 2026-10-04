# main-menu Story 001 主菜单场景——UI 手动验证证据

> **故事**：production/epics/main-menu/story-001-main-menu-scene.md（AC-5 / AC-6）
> **验证日期**：2026-10-04
> **验证方式**：运行项目主场景（project.godot run/main_scene → src/ui/main_menu/MainMenu.tscn，F5）手动观察（独立开发者——所有角色由同一人签收）
> **判定**：通过

## 验证环境

- Godot 4.6.3.stable，Forward+ 渲染器（D3D12——Windows 默认），F5 运行项目
- 主场景即 MainMenu.tscn（code-review BLOCKER-1 修复后：run/main_scene 由旧原型 uid 改为 path 引用）
- Autoload 全部在场景树中（GameStateManager/InputManager/SceneManager/SaveLoadSystem）——存档判定读 SaveLoadSystem 真实生效

## AC-5：主菜单完整性

| # | 验证项 | 预期 | 结果 |
|---|--------|------|------|
| 1 | 入场动画 | 0.8s 淡入 + 标题从上方滑落（GDD §视觉/音频需求） | [x] 通过 |
| 2 | 标题+按钮组+版本号 | 「仙途问道」标题 + 新游戏/继续游戏/设置/退出 4 按钮 + 左下角版本号 v0.1.0-dev（ProjectSettings 读取） | [x] 通过 |
| 3 | 初始焦点（无存档） | 焦点环落「新游戏」（继续游戏灰色禁用回退——story Implementation Notes） | [x] 通过 |
| 4 | 键盘可达 | Tab / ↑↓ 在 新游戏→继续→设置→退出 间循环移动（VBox 树序即焦点序） | [x] 通过 |
| 5 | 鼠标可达 | 悬停高亮 + 点击响应（4.6 双焦点模型——grab_focus 不影响鼠标 hover） | [x] 通过 |
| 6 | 无存档摘要行 | 摘要行隐藏（visible=false 占位保留） | [x] 通过 |
| 7 | 设置按钮 | 灰色禁用不可点（Story 002 留桩——预期） | [x] 通过 |
| 8 | 新游戏按钮 | 静默回退主菜单（identity_select.tscn 相邻 story 留桩——Completion Notes 已声明，预期非缺陷） | [x] 通过（预期留桩） |
| 9 | 退出按钮 | 真正关闭进程（quit 真语义——自动化仅验证接线契约，此处补全） | [x] 通过 |

## AC-6：性能（D3D12）

| # | 验证项 | 预期 | 结果 |
|---|--------|------|------|
| 1 | 帧率 | 主菜单动画运行下 60fps（AC-main-menu-020） | [x] 通过（监控器稳定 60） |
| 2 | 帧时间 | ≤16.6ms（引擎监控器实测） | [x] 通过 |
| 3 | Draw Call | ≤50（get_rendering_info / 监控器采样，AC-main-menu-022——主菜单专项预算，严于全局 <200） | [x] 通过 |
| 4 | 分辨率下限 | 1280×720 布局无溢出（AC-main-menu-021，支持下限；LayoutAnchor 内容底界 608px——code-review S-6 修正后） | [x] 通过 |

## 备注

- 背景动画为骨架纯色背景（动态背景场景归后续视觉 story——story Context「布局/交互骨架」范围）；本证据的 60fps/Draw Call 针对骨架态实测，视觉 story 落地后需复测。
- 损坏对话框路径（AC-3）与导航（AC-4）由自动化集成测试覆盖（tests/integration/main_menu/ 20/20），不在本手动证据范围。

## 签收

| 角色 | 签收 | 日期 |
|------|------|------|
| 独立开发者（全部角色） | [x] Approved | 2026-10-04 |
