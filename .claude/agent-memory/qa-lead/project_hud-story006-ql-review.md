---
name: hud-story006-ql-review
description: hud Story 006 QL-STORY-READY 对抗性复核 2026-10-20——GAPS；主审 layers 差距方向成立但修复方案有误（_map_config 扁平+读档清空），新发现域信号路径零测试覆盖
metadata:
  type: project
---

hud Story 006（探索 HUD 右下信息组）QL-STORY-READY 对抗性复核，2026-10-20。判定：**GAPS**（维持主审 NEEDS WORK）。

**主审唯一差距的复核**：`map_states[map_id].layers` 不可行成立（`update_exploration_map_state` 是 map_states 唯一写入方，`enter_map` 只写 entry_count/graph/nodes，layers 键从未写入；`_ready` L396 读端期望该键——读写脱节）。但主审建议的 `get_total_layers()` 读 `_map_config[map_id].layers` **有两处错误**：

1. `_map_config` 是**扁平配置字典**（`{"layers": 5, ...}`，int 非数组），无 map_id 键——`exploration_dag_builder.gd` L101 写入 `config.duplicate(true)`。
2. `rebuild_dag_cache` L415 执行 `_map_config = {}`——**读档恢复路径 _map_config 为空**，走它会返回垃圾。

**Why**：正确修复 = get_total_layers() 从 **DAG 缓存推导**（`_node_details` max(node_id)/100 + 1，节点 ID 编码 layer*100+idx），并遵守 R7 `_dag_ready` 守卫。map_states 快照含 nodes，重建后 DAG 缓存可用。

**新发现差距**：
- GAP-2（BLOCKING）：AC-2 测试规格只覆盖 batch_updated 路径（`set_exploration_ap` 恒双写→batch）；域信号 `action_points_changed` 有真实触发者 `restore_action_points`（单写，event_resolver L152 行动力恢复节点）但**零测试覆盖**。story 002 LingshiDeckBar 先例对两路径各有独立用例，本 story 缺对偶。
- GAP-3（ADVISORY）：未知 map_id 回退显示未定义。炼气章共 4 张地图（青云剑宗/血渊秘境/云澜城/丹霞谷），最小表只含青云剑宗；exploration-ui 扩表前进入其余地图显示行为未指定。建议占位符「未知地域」+ push_warning（同通知系统 2026-09-10 裁决模式）。

**How to apply**：story 006 修订 L48/L50/AC-2 后方可翻 Ready；实现时若 dev 提议 get_total_layers 走 _map_config，按上述错误驳回。相关：[[hud-story002-ql-review]]（G6 双路径先例）、[[project_qa_conventions]]。
