# HUD Story 005 暂停菜单——视觉手动验证证据

> **故事**：production/epics/hud/story-005-pause-menu.md（AC-4 / AC-5）
> **验证日期**：2026-09-11
> **验证方式**：编辑器 F6 运行 HUD.tscn 手动观察（独立开发者——所有角色由同一人签收）
> **判定**：通过

## 验证环境

- Godot 4.6.3.stable，Forward+ 渲染器，编辑器 F6 运行 HUD.tscn
- Autoload 全部在场景树中（InputManager/GameStateManager/SaveLoadSystem）——ESC 拦截与进度行读 GSM 真实生效
- 经 InputManager ESC 拦截路径触发暂停（`_ready` 接线，不依赖 setup 调用）
- 注：F6 下 scene_manager 未注入（HUD setup 由游戏启动流程调用）——转场路径由集成测试 mock 覆盖

## AC-4：菜单项完整性与导航

| # | 验证项 | 预期 | 结果 |
|---|--------|------|------|
| 1 | 菜单项数量 | 继续游戏 / 查看卡组 / 系统设置 / 保存并退出 / 返回主菜单（5 项） | [x] 通过 |
| 2 | 探索进度行 | 降级格式「层 N」（node_position.layer + 1，0 基转 1 基） | [x] 通过 |
| 3 | 继续游戏 | 点击关闭暂停菜单，恢复游戏 | [x] 通过 |
| 4 | 查看卡组 | 发 deck_view_requested 信号（界面本体归 deck-editing-ui epic） | [x] 通过（留桩信号，无界面——预期） |
| 5 | 系统设置 | 发 settings_requested 信号（界面本体归 main-menu epic） | [x] 通过（留桩信号，无界面——预期） |
| 6 | 保存并退出 | SaveLoadSystem 存档后返主菜单；存档失败保持菜单打开 | [x] 通过（集成测试覆盖转场；F6 下走关闭逆序） |
| 7 | 返回主菜单 | 不存档直接转场（无二次确认——GAP-5 裁决） | [x] 通过（F6 下菜单关闭+锁释放正确；转场由 test_return_to_main_menu_releases_pause_and_lock mock 覆盖） |
| 8 | 遮罩点击 | 点击模糊遮罩等效「继续游戏」关闭菜单 | [x] 通过 |
| 9 | ESC 打开 | 探索场景按 ESC 打开暂停菜单 | [x] 通过 |
| 10 | ESC 关闭 | 菜单打开时再按 ESC 关闭菜单（PauseMenu _unhandled_input 兜底） | [x] 通过 |

## AC-5：背景模糊与计时冻结

| # | 验证项 | 预期 | 结果 |
|---|--------|------|------|
| 1 | 背景模糊 | 0.3s 模糊过渡（blur shader hint_screen_texture + BackBufferCopy） | [x] 通过 |
| 2 | 模糊遮罩 | 半透明黑色遮罩（dim_color.a = 0.6）叠加在模糊之上 | [x] 通过 |
| 3 | 计时冻结 | 暂停期间游戏内计时（AP 恢复等如有）不推进 | [x] 通过 |
| 4 | 恢复计时 | 恢复后计时从暂停点继续 | [x] 通过 |
| 5 | 分辨率适配 | 1920×1080 与 1152×648 下面板均居中可见 | [x] 通过 |

## 签收

| 角色 | 签收 | 日期 |
|------|------|------|
| 独立开发者（全部角色） | [x] Approved | 2026-09-11 |