---
name: hud-story006-ql-test-coverage
description: hud Story 006 QL-TEST-COVERAGE 2026-10-20——ADEQUATE；AC-1 全 6 edge/AC-2 双路径/LP④三例逐项核实 COVERED，域信号用例不可区分（batch 恒伴随发射遮蔽域处理器失效）等 3 ADVISORY
metadata:
  type: project
---

hud Story 006（探索 HUD 右下信息组）QL-TEST-COVERAGE full 模式审查，2026-10-20。判定：**ADEQUATE**——QA 规格 AC-1 全部 6 个 edge case、AC-2 双路径含 2 edge、LP 条件④三例均有直接对应测试函数且断言核实为真（ap_display_rules 边界 ≤20%/≤50% 语义、get_total_layers 守卫链 max/100+1、_apply_ap/_apply_map_name 消费路径逐行比对一致）。AC-5 组合成立（story 001 可见性矩阵 12 值 + ExplorationInfoArea 容器存在断言 + 隐藏期间变更用例）。

**3 条 ADVISORY**：
1. 域信号用例（test_ac002_domain_signal_path_restore_updates_display）不可区分：GSM `_flush_pending_changes` 恒发射 batch_updated（gsm_signal_router.gd L61），restore 单写虽走域信号但 batch 伴随携带同路径键——`_on_action_points_changed` 断连时测试仍经 batch 路径通过。属 GSM 恒伴随发射的系统性属性（story 002 先例同病），非本 story 实现缺陷。
2. 「未知地域」map_id 回退 + 层数 0→1 基换算零自动化覆盖：QA 规格未列为自动化用例（AC-3 手动走查仅覆盖青云剑宗——回退路径双零覆盖，GAP-3 裁决行为实际无任何证据）。
3. 用例名 test_hud_ap_color_three_of_five_returns_warning 断言实为 normal（规格正确、命名误导）；story 证据路径写 `tests/unit/exploration/` 实际落 `tests/unit/exploration_system/test_get_total_layers.gd`（新文件非追加现有）。

**Why**：AC-3/AC-4 手动证据 `production/qa/evidence/exploration-hud-info-evidence.md` 未建（ADVISORY 级，UI 故事可签批后补）。全量 2900/2899 passing/1 pending（save_load 存量）。

**How to apply**：story 006 逻辑/集成 BLOCKING 关卡可放行；若 dev 要求域信号路径严格归因，建议手动 emit `action_points_changed` 或连接断言。相关：[[hud-story006-ql-review]]（三处 GAP 修订均已承接核实）。
