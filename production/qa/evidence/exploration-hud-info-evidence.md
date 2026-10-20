# hud 006 探索 HUD 右下信息组证据——手动验证

> **日期**：2026-10-20
> **Story**：hud 006（探索场景右下信息组）
> **类型**：UI（含 Logic 内核）
> **自动化证据**：`tests/unit/hud/test_ap_color_threshold.gd`（13——AC-1 阈值边缘含 0/5、1/5、3/5、5/5、max_val=0 防除零、current>max 防御）+ `tests/integration/hud/test_gsm_signal_binding.gd`（15——AC-2 双路径含 batch_updated 与 `restore_action_points` 域信号）+ `tests/unit/exploration/test_get_total_layers.gd`（6——LP 条件④ 空缓存/生成后/重建后 + 公式交叉锁定）——全量 2899 tests / 2899 passing / 1 pending 存量（save_load 占位，非本次引入）
> **本文档覆盖**：AC-3 信息组完整性 + AC-4 分段格显示 手动走查（真实窗口渲染目视确认——headless 不可替代的墨字/面板可见性）

---

## 1. AC-3 手动验证步骤（信息组完整性）

**Setup**：`hud_debug.tscn` F6 窗口运行 → 按 Q（`_enter_exploration`：`es.enter_map(&"qing_yun_jian_zong", 1, 5)` + `gsm.set_exploration_position(2, 0)`）。

| # | 验证项 | 预期（story/GDD §5） | 结果 |
|---|--------|------|:----:|
| 1 | 右下信息组可见 | 米白半透明面板（`#F5F0E3` @85%）承载信息，不遮挡中央内容区 | [x] 通过（H-2 修复：面板 ColorRect + 墨黑文字——深色探索背景上肉眼可辨） |
| 2 | 地图名 | 显示「青云剑宗」（map_id→显示名常量表） | [x] 通过（MAP_NAMES 表命中 qing_yun_jian_zong） |
| 3 | AP 计数 | 显示「5/5」（当前/最大） | [x] 通过（enter_map AP 5/5） |
| 4 | 层数 | 显示「层3/5」（node_position.layer 0 基 +1 换算 + get_total_layers 总层数） | [x] 通过（set_exploration_position(2,0) → 层3） |
| 5 | 三项与状态一致 | 地图名/AP/层数三项均与 GSM exploration 域一致 | [x] 通过（真实信号驱动刷新，非轮询） |

## 2. AC-4 手动验证步骤（分段格显示）

**Setup**：AP 5/5 起，连按 W（`_consume_ap`）消耗到 3/5、再按 E（`_restore_ap`）恢复。

| # | 验证项 | 预期（story AC-4） | 结果 |
|---|--------|------|:----:|
| 1 | 分段格熄灭 | 5 格中 2 格熄灭（██░░░ 形态随 AP 递减） | [x] 通过（SEGMENT_ON █ / SEGMENT_OFF ░ 按 ApDisplayRules segments 渲染） |
| 2 | 计数同步 | 计数文本随消耗即时更新（5/5→4/5→3/5） | [x] 通过（双路径信号驱动即时刷新） |
| 3 | 颜色阈值 | 消耗到 warning（≤50%）分段格变琉璃金；连按到 critical（≤20%）变朱砂红 | [x] 通过（ApDisplayRules 共享纯函数判定 + AP_COLORS 语义色） |
| 4 | 恢复点亮 | 按 E 恢复 AP 后已消耗格重新点亮 | [x] 通过（restore_action_points 域信号路径） |

## 3. 实现说明

- **共享纯函数**：`src/ui/shared/ap_display_rules.gd` 的 `get_ap_color_threshold(current, max_val)` 是 HUD 与 exploration-ui 的唯一判定源（ADR-0031 + story Control Manifest Required——禁止内联阈值）。
- **双路径订阅**：`action_points_changed(delta, current, max_val)`（仅取 current）+ `batch_updated`（过滤 `exploration.action_points`/`exploration.max_action_points` 两条精确路径键）——story Engine Notes 逐字遵守。
- **可见性修复（H-2）**：原 LabelSettings 墨黑 `#1A1A1A` 在深色探索背景上不可见 → 根节点新增 `PanelBackground` ColorRect（米白 `#F5F0E3` @85%），normal 态文字保持墨黑——对齐美术圣经 §4.1 调色板（墨黑为文字基底、米白为纸本底色）。诊断工具 `tests/manual/_hud_screenshot.tscn/.gd` 窗口截图确认修复前后像素分布（修复前 Top 色 (76,76,76) 深灰无亮字，修复后 (220,216,204) 米白 + 墨字 (26,26,26)）。
- **总层数数据源**：`ExplorationSystem.get_total_layers()` 从 DAG 缓存推导（`max(_node_details.keys()) / 100 + 1`，ID 编码 `layer * 100 + idx`），LP 五条件全落地（空集双守卫/完整 doc 注释/禁测试桩 API/exploration 侧单测/守卫先例引用）。

## 4. 范围外确认

- 真实探索场景中央节点图 + AP 强化显示组件本体（消费本 story 的共享 helper）——exploration-ui epic
- AP 分段格真实图集图标（当前 █/░ 占位字符）与 📍/🏁 图标——美术资产管线（ADR-0031 §5）
- 战斗右下费用/牌库——combat-ui（HUD 战斗不渲染）
- 地图名完整常量表（当前仅青云剑宗，未知 map_id 回退「未知地域」+ push_warning）——exploration-ui 扩表

---

## 签收表

| 角色 | 结论 | 签收 |
|------|------|:----:|
| ui-programmer（实现） | 共享纯函数 + 双路径订阅 + 米白面板可见性修复（H-2）；13 单元 + 15 集成 + 6 exploration 全绿 | [x] Approved |
| qa-lead（测试） | AC-1/AC-2 全自动化锁定；AC-3/AC-4 手动走查 9 项归档；全量 2899 passing | [x] Approved |
| lead-programmer（技术） | H-1 容器锚点/H-2 墨字可见性/M-1 幂等守卫全闭合；get_total_layers LP 五条件落地 | [x] Approved |

*独立开发者——所有角色由同一人签收。*
