# 里程碑：Core Layer Complete

> **目标日期**：2026-08-19
> **状态**：Completed（2026-08-09）
> **依赖里程碑**：foundation-layer-complete（已 Completed，2026-08-05）
> **完成冲刺**：Sprint 2（2026-08-06 至 2026-08-19）

## 交付物

- [x] CardSystem（Autoload #6）实现并通过测试——卡牌模板/实例/注册表/工厂/序列化 5 Story
- [x] RealmSystem（Autoload #11）实现并通过测试——境界数据表/压制计算/realm_up 编排 3 Story
- [x] ResourceSystem（Autoload #16）实现并通过测试——读写 API + GSM 第二层 + 6 公式纯函数 2 Story
- [x] FactionSystem（Autoload #15）实现并通过测试——标签库查询 + 场上统计判定 2 Story
- [x] Autoload #15/#16 初始化顺序验证（CardSystem #6 先于 FactionSystem/ResourceSystem）
- [x] event_system.gd 拆分（558→≤300 行）——提取条件判定引擎到独立文件
- [x] 所有 Core 层 Logic/Integration Story 有通过的单元/集成测试
- [x] 回顾行动项 #1（拆分 event_system.gd）已完成

## 完成标准

4 个 Core 层 Autoload 系统全部实现，单元/集成测试通过，Autoload 初始化顺序验证无误。Core 层基础设施就绪，Feature 层（战斗、效果引擎、流派等）可开始构建。

## 风险登记

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| faction-system/002 依赖 card-system get_field_characters（跨 Epic） | 高 | 中 | Sprint 排序 card-system 优先；faction/002 排在 card/004 之后 |
| AC 密集 Story 预估偏低（retro 发现 AC>15 偏差 +30%） | 中 | 中 | resource/faction Story AC 19-22，预估已上调 +4h |
| Autoload #15/#16 初始化顺序 | 中 | 中 | Sprint 第 1 天前置验证（0.5h 任务） |
| event_system.gd 拆分可能引入回归 | 中 | 高 | 拆分后重跑全部 520 测试，零回归才合并 |
