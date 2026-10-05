# 设置面板 UI 手动验证证据

> **Story**: main-menu 002（设置面板框架与音量控制）
> **测试日期**: 2026-10-05
> **测试者**: 开发者（手动编辑器 F5 运行验证）
> **引擎环境**: Godot 4.6.3, Windows 11, D3D12 渲染

---

## AC 手动验证项

| # | 验收标准 | 验证方式 | 结果 |
|---|---------|---------|------|
| AC-1 | 点击设置打开设置界面，含音效/画面/按键/语言 4 个分类 | 主菜单点击「设置」按钮，目视 TabContainer 4 标签页 | ✅ 通过 |
| AC-4-可听 | 拖动音量滑条时实时可听变化 | **降级路径**（audio 002 BGM 未交付）：以 `AudioServer.get_bus_volume_db()` 表读数实时变化代证——自动化测试 `test_volume_bus_apply.gd` 5 条参数化 + `test_settings_rollback.gd` 6 条全部通过（main_menu 域 51 单元 + 25 集成零失败） | ✅ 通过（降级） |
| AC-6 | 打开 0.3s 滑入 / 关闭 0.2s 滑出 | 目视面板出场动画：自右侧滑入（ease-out ~0.3s）；ESC/关闭按钮滑出（ease-in ~0.2s） | ✅ 通过 |
| 键盘路径 | 键盘 ← → 调节滑条同样实时生效 | 点击总音量滑条聚焦 → 按 ←/→ 调节，目视滑条移动 + 值变化 | ✅ 通过 |
| 4 分类 | TabContainer 标签页切换 | 依次点击音效/画面/按键绑定/语言标签页，后三个显示占位文案 | ✅ 通过 |
| 持久化 | 应用→关闭→重开显示已保存值 | 拖动 BGM→30%→点应用→关闭→重开→BGM 显示 30% | ✅ 通过 |
| 回滚 | 未保存关闭→回滚已保存值 | 拖动 Master→30%→ESC 关闭→重开→Master 显示上次保存值 | ✅ 通过 |

---

## 降级说明

- **可听验证**：audio-manager 002（BGM 播放）尚未交付，无 BGM/SFX 音源供实时听觉验证。「可听变化」降级为总线 dB 表读数验证，由以下自动化测试钉死：
  - `test_volume_bus_apply_parametrized`（9 组参数化：[BGM,SFX,Master]×[0%,50%,100%]，容差 ±0.01dB）
  - `test_volume_bus_master_zero_is_mute_db`（0% → -80dB）
  - `test_volume_bus_master_full_is_zero_db`（100% → 0.0dB）
  - `test_volume_bus_keyboard_step_changes_volume`（键盘步进信号路径）
- 可听确认推迟至 audio-manager 002 交付后补做（本证据文件已注明）

---

## 签收

| 角色 | 签收人 | 日期 | 签收 |
|------|--------|------|------|
| 开发者 | zwzhang | 2026-10-05 | [x] Approved |

---

> **下次复测条件**：audio-manager 002（BGM 播放）交付后，F5 运行主场景 → 开设置面板 → 拖动 BGM 滑条确认音量实时变化可听 → 在此文件追加签收行