# 跨 GDD 审查报告 (Cross-GDD Review Report)

> **日期**：2026-07-23
> **审查的 GDD 数量**：36（全部系统 GDD）
> **覆盖的系统**：5 层级、36 个系统
> **引擎**：Godot 4.6 | **类型**：Roguelike 卡牌对战（修仙题材）
> **支柱**：组牌(1) > 成长(2) > 机缘(3) > 问道(4)
> **审查模式**：完整（一致性 + 设计理论 + 场景演练）

---

## 综合裁决：✅ 通过（3 个阻塞项已解决）

**3 个阻塞项** 已在 2026-07-23 的设计审查会话中全部解决。**40 个警告** 中的 8 个已解决，**32 个信息项** 保持。

| 类别 | 阻塞项 | 警告 | 信息 |
|------|:-----:|:----:|:----:|
| **一致性（阶段 2）** | 3 | 9 | 8 |
| **设计理论（阶段 3）** | 0 | 29 | 23 |
| **场景演练（阶段 4）** | 0 | 2 | 1 |
| **合计** | **3** | **40** | **32** |

---

## 阻塞项（全部已解决 ✅ — 2026-07-23）

### ✅ B1：卡组上限被三个 GDD 重复定义且数值冲突

**状态**：已解决。`game-state-manager.md §调优参数` 中的全局卡组上限已移除，替换为对 `realm-system.md §2` 的交叉引用。GSM 中所有卡组边界检查现在从 `realm-system.get_realm_property(L, "deck_limit")` 动态读取。卡组最低保护 5 已与 deck-editing-system 对齐。

---

### ✅ B2：探索系统与境界系统的地图名称不一致

**状态**：已解决。`exploration-system.md` 已同步为"西域古林"和"西域边境"，与 `realm-system.md §8` 地图列表一致。所有出现位置均已更新：§1 重入费用表、§8 地图列表。

---

### ✅ B3：角色阵亡时 status-system 暂挂/恢复 vs binding-system 永久移除——互不兼容

**状态**：已解决。作用域拆分已双向实现——status-system 的暂挂/恢复仅处理非绑定来源的状态（敌方 debuff、丹药 buff）；绑定来源的效果遵循 binding-system 的永久移除规则。两处 GDD 均已明确记录此作用域拆分（status-system.md §5/§边界情况，binding-system.md §7/§依赖关系）。

---

## 一致性警告（阶段 2）

⚠️ **W-C1**：~~`realm-system.md` 苍玄正道盟难度为"低"，`exploration-system.md` 重入费用表列为"中难度"——需统一~~ **✅ 已解决 (2026-07-23)**：exploration-system.md §1 重入费用表已将苍玄正道盟列为低难度基价 30 灵石，与 realm-system.md §8 的"低"难度定义一致。

⚠️ **W-C2**：~~`game-state-manager.md §待解决问题` #1（BASE_MAX 待确认）现已确认——应移除或标记为已解决~~ **✅ 已解决 (2026-07-23)**：BASE_MAX=1000 已在 GSM 中标记为已解决，所有消费端数值一致。

⚠️ **W-C3**：~~`game-state-manager.md` 与 `cultivation-system.md` 均定义了 CONVERSION_RATE 修为溢出转化率——应引用单一来源~~ **✅ 已解决 (2026-07-23)**：GSM 中 `overflow_pool` 添加了交叉引用至 cultivation-system.md。单一权威来源为 cultivation-system.md。

⚠️ **W-C4**：~~行动力/费用表在 `action-point-system.md`、`cost-system.md`、`realm-system.md` 三处重复——realm-system 应引用而非复制~~ **✅ 已解决 (2026-07-23)**：realm-system.md §2 属性表声明为 action_points 和 cost_per_turn 的唯一权威来源。action-point-system.md 和 cost-system.md 添加了交叉引用注释。运行时通过 `get_realm_property(L, key)` 查询。

⚠️ **W-C5**：`resource-system.md` 初始灵石 AC（灵石=15）需与 `identity-selection-system.md` 起始资源交叉验证

⚠️ **W-C6**：`deck-editing-system.md` 的"卡组最低 5 张保护"规则在事件/战斗系统验收标准中无覆盖

⚠️ **W-C7**：`exploration-system.md` 地图重入费用公式在 §1 和 §11 重复定义——应合并

⚠️ **W-C8**：回旧地图双倍惩罚——`realm-system.md` 压制境界属性 + `ai-system.md` 独立提升敌人属性 30%/级——两者是否应同时生效？

⚠️ **W-C9**：~~`status-system.md` 数据结构字段拼写错误 `is_hiden` → 应为 `is_hidden`~~ **✅ 已解决 (2026-07-23)**：拼写已修正为 `is_hidden`。

## 设计理论警告（阶段 3 —— 高优先级 10 项）

⚠️ **W-D1**：**缺少跨系统战力预算**——境界、流派、铭刻、天赋、属性丹的累积效果未在任何文档中汇总。终局（化神）玩家可能在所有加成叠加后达到远超预期的战力，使敌人属性增幅（最大 ×2.2）严重不足

⚠️ **W-D2**：**叠加倍率指数增长**——stack_multiplier=2.0、stack_count=5 时效果达 16×。需在卡牌模板加载时实现硬上限验证，防止指数失控

⚠️ **W-D3**：**战斗回合中 9 个并发信息通道**——远超 3-4 的认知负荷阈值。建议为战斗 UI 定义视觉优先级层级（主要/次要/第三级）

⚠️ **W-D4**：**灵石"万能溶剂"**——可购买卡牌、丹药，间接购买材料。青云剑宗（+15% 灵石）+ 灵脉感应（+10%）= +25%，无克制手段。建议限制灵石购买暗金卡牌或新增竞争性消耗渠道

⚠️ **W-D5**：**渡劫实质上无风险**——失败仅损失 10% 修为，连续失败保护让该关卡失去意义。建议渡劫失败同时消耗地图节点（每节点限尝试一次）

⚠️ **W-D6**：**溢出修为→属性丹无限农场**——无消耗上限，玩家可停留在满修为并反复刷战斗积累 100+ 属性丹。建议按境界限制消耗上限或引入递减收益

⚠️ **W-D7**：**阵道双杰+万象阵典组合**——可绕过所有阵法阵营要求（formation_master 天赋 -1 条件 + 万象阵典计为 2 人）

⚠️ **W-D8**：**第 2 章境界下跌难度断崖**——高费筑基卡组在炼气期无法使用（费用从 5 降至 2）。建议下跌后为前 3 场战斗新增临时增益

⚠️ **W-D9**：**铭刻系统纯随机老虎机**——与支柱 1"策略为王"矛盾。建议新增有向随机或属性锁定选项

⚠️ **W-D10**：**音频资源预算严重不足**——各 GDD 需求（约 8-10 首 BGM + 60-80 个音效）约为音频 GDD 预估的 2 倍

**全部 29 项设计理论警告详见阶段 3 子代理详细输出。**

## 场景演练警告（阶段 4）

⚠️ **W-S1**：卡组满时购买卡牌行为——多个系统均未定义（阻止购买 vs 触发弃牌流程？）

⚠️ **W-S2**：渡劫战中阵亡角色→突破后 realm_up 与角色状态恢复的时序未明确记录

---

## 标记需要修订的 GDD

| GDD | 原因 | 类型 | 优先级 |
|-----|--------|------|----------|
| `game-state-manager.md` | 卡组上限冲突 + BASE_MAX 问题未关闭 | OWNERSHIP + STALE | 🔴 阻塞 |
| `exploration-system.md` | 地图名称不一致 + 重入费用重复定义 | RULE + DUPLICATE | 🔴 阻塞 |
| `status-system.md` | 阵亡暂挂与绑定移除不兼容 + 拼写错误 | RULE | 🔴 阻塞 |
| `binding-system.md` | 阵亡时对状态系统的职责边界未声明 | RULE | 🔴 阻塞 |
| `realm-system.md` | 苍玄正道盟难度不一致 | RULE | ⚠️ 警告 |
| `card-system.md` | 旧卡组构建规则已过期 | STALE | ⚠️ 警告 |
| `inscription-system.md` | 纯随机老虎机——与支柱 1 矛盾 | PILLAR_DRIFT | ⚠️ 警告 |
| `achievement-system.md` | 支柱声明缺失 P4 + 命名使用通用术语 | PILLAR + FANTASY | ⚠️ 警告 |
| `audio-system.md` | 资源预估不足 + 无支柱声明 | ECONOMY + PILLAR | ⚠️ 警告 |
| `tribulation-system.md` | 渡劫无风险 + 事件路由边界模糊 | STRATEGY + RULE | ⚠️ 警告 |
| `reincarnation-talent-system.md` | "因果不断"携带卡牌破坏 Roguelike 幻想 | FANTASY | ⚠️ 警告 |
| `combat-ui-system.md` | 缺少视觉优先级层级定义 | COGNITIVE | ⚠️ 警告 |
| `alchemy-crafting-system.md` | 灵材收入 vs 消耗差距（金丹期缺口约 1-2 材料） | ECONOMY | ⚠️ 警告 |
| `resource-system.md` | 灵石购买力无限 + 正反馈滚雪球 | ECONOMY | ⚠️ 警告 |

---

## 架构阶段的建议前置条件

1. **3 个阻塞项**（B1-B3）—— 必须解决
2. **高优先级警告**（W-D1 战力预算、W-D2 叠加限制、W-D3 认知负荷、W-D4 灵石经济）—— 强烈建议解决
3. 其余警告可推迟至架构阶段中后期处理，但在阶段结束前应全部给出答复