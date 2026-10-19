# keybind 004 按键绑定界面（含启动加载）证据——手动验证

> **日期**：2026-10-18
> **Story**：main-menu 004（按键绑定界面含启动加载）
> **类型**：UI（含 Logic 内核）
> **自动化证据**：`tests/unit/main_menu/test_keybind_conflict.gd`（13——AC-1 冲突检测全场景含 ESC/混绑/修饰键/序列化往返）+ `tests/integration/main_menu/test_keybind_roundtrip.gd`（19——AC-2 往返 + AC-4 注册机制 + UI 状态机 + H-1/H-2/H-3 真实接线回归 + 方案 B 同类替换 4 例）——main_menu 套件单元 79/79 + 集成 48/48；全量 2875 tests / 2874 passing / 1 pending 存量（CI success，提交 9b2bc07）
> **本文档覆盖**：AC-3 重绑定交互流手动走查（headless 无法自动化的真人按键/鼠标交互路径——基于渲染序列与信号接线审读，同 combat-ui 003 证据口径）

---

## 1. AC-3 手动验证步骤（重绑定交互流）

**Setup**：主菜单 → 设置 → 按键绑定 tab（AC-015 点击按键格进入等待输入）。

| # | 验证项 | 预期（story/GDD） | 结果 |
|---|--------|------|:----:|
| 1 | 点击按键格进入等待 | 按键格文字变「等待输入...」，0.5s 周期闪烁（modulate:a 0.3↔1.0 循环 Tween——非忙等） | [x] 通过（`begin_capture` 置 TEXT_WAITING + `_play_blink` set_loops Tween——`test_capture_esc_cancels_waiting` 锁定文案态） |
| 2 | 按新键完成绑定 | 0.15s 弹出新键名（POPUP_DURATION 延迟 callback 置文本）+ 即时持久化写设置文件 | [x] 通过（`_show_new_key` set_delay(0.15) + `test_capture_new_key_unoccupied_binds_immediately` 断言文件侧可加载回 F1） |
| 3 | 冲突提示 | 新键已被占用 → 弹「该键已绑定 [功能名]，是否覆盖？」ConfirmationDialog 覆盖/取消两分支 | [x] 通过（`_ask_overwrite` 弹窗 + confirmed→`_overwrite_conflicts`、canceled→`_on_overwrite_cancelled` 真实信号接线——`test_conflict_dialog_real_signal_paths` 双信号路径断言） |
| 4 | 覆盖分支 | 被占用 action 移除该事件（空则清空），新 action 抢占槽位 | [x] 通过（`test_capture_conflict_overwrite_takes_slot` + 方案 B 组合 `test_conflict_overwrite_keeps_target_other_device_binding`——键盘槽换键、鼠标槽保留） |
| 5 | 取消分支 | 弹窗取消 → 等待态复位、按键格恢复键名、InputMap 不变 | [x] 通过（`_on_overwrite_cancelled` → `_cancel_capture` 恢复 `_current_key_text` + `_kill_blink`——`test_conflict_dialog_real_signal_paths` ①段断言） |
| 6 | ESC 取消等待 | 等待输入中按 ESC → 取消返回列表（不作为可绑定键；消费事件防冒泡关面板） | [x] 通过（`_handle_capture_event` ESC 分支 `set_input_as_handled`——`test_capture_esc_cancels_waiting`） |
| 7 | 重启不失效 | 自定义键写入设置文件后，启动时从文件加载应用 InputMap | [x] 通过（`MainMenu._load_keybinds` 先快照后加载——`test_roundtrip_single_binding_survives_inputmap_reset` 文件侧往返锁定） |
| 8 | 多绑定同类替换 | 重绑「确认」类跨设备动作 → 键盘槽替换、鼠标槽保留；按键格多事件「 / 」显示 | [x] 通过（方案 B——`test_rebind_same_device_class_keeps_other_device` + `_current_key_text` TEXT_KEY_SEP 连接，GDD L110 线框既有约定） |
| 9 | 纯鼠标 action 键盘拒绝 | 「布阵移动」等待中按键盘 → 提示「该功能仅支持鼠标输入」继续等待 | [x] 通过（设备类准入分支 + `test_rebind_pure_mouse_action_rejects_keyboard`——拒绝后保持等待态、绑定集不变） |
| 10 | 恢复默认 | 全局恢复默认 → InputMap 归位快照 + 写设置文件 + 界面刷新；注册表含 keybinds 分类 | [x] 通过（`test_reset_all_includes_keybind_category_and_restores_inputmap` + H-3 产品路径 `test_reset_all_product_path_without_manual_snapshot`——共享快照实例注入） |
| 11 | 按键绑定页可见 | 设置→按键绑定 tab 内容显示（非隐藏占位） | [x] 通过（H-1 修复挂载点 + `test_keybind_tab_visible_under_keybinds_tab` 祖先链断言） |
| 12 | 冲突警告音 | 音频事件触发（AudioManager 14-7 未落地降级日志占位） | [x] 降级路径（`push_warning` 占位——story AC 明文允许；AudioManager 契约落地 story 接线） |

## 2. 实现说明

- **三层拆分**：KeybindLogic（纯静态函数——冲突检测/同类互换/序列化）+ KeybindStore（快照法/InputMap 应用 erase+add 组合/settings.json keybinds 键 merge 持久化）+ KeybindTab（等待输入状态机 UI）。
- **可测入口分离**：`_handle_capture_event` 返回结果字典（bound/conflict/cancelled/ignored）——headless 集成测试驱动全状态机。
- **即时持久化**：按键绑定每格独立生效（GDD AC-016 无应用按钮语义——与画面类「点应用」差异已注释）。
- **InputMap API 偏离**：`action_set_event` 在 4.6.3 不存在（R-05 spike 实测 has_method=false）——`apply_bindings` 用 `action_erase_events + action_add_event` 组合（语义等价，注释+story 已同步）。
- **多绑定语义**：QL 裁定 2026-10-18 方案 B（同类替换、异类保留）——GDD 边界澄清已落规格文本。

## 3. 范围外确认

- 冲突警告音本体——audio-manager epic（本 story 仅触发事件，当前日志占位）
- Story 005 语言分类注册——落地时各自注册
- 动作显示名完整映射（当前 ACTION_LABELS 仅 2 条 + 原名回退）——随 project.godot 动作演进补
- DEBT-MM-004（settings_panel/main_menu 超 300 行 + KeybindStore 文件读写重复）——main-menu epic 收尾前拆分 story

---

## 签收表

| 角色 | 结论 | 签收 |
|------|------|:----:|
| ui-programmer（实现） | 三层拆分 + 状态机 + 同类替换全链；48 集成 + 13 单元全绿；LP-CODE-REVIEW H-1/H-2/H-3 + M-1/M-2 修复（提交 7ed1076 + 9b2bc07 CI success） | [x] Approved |
| qa-lead（测试） | AC-1/2/4 全自动化锁定；AC-3 手动走查 12 项归档；真实接线回归（H-1 挂载/H-2 双信号/H-3 产品路径快照）补齐自动化盲区 | [x] Approved |
| lead-programmer（技术） | 三项 Required Changes（H-1 挂载点/H-2 弹窗信号/H-3 快照共享）闭合并定向复审；M-1 方案 B 经 game-designer 裁定落地；M-2/M-3/L 项处理（DEBT-MM-004 登记） | [x] Approved |

*独立开发者——所有角色由同一人签收。录屏证据可后续补挂（当前以测试+走查审读覆盖——与 combat-ui 003 证据同口径）。*
