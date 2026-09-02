# QA 计划：Sprint 7 — Meta 层 + 叙事收束

**日期**：2026-09-02
**由**：手动生成（参照 Sprint 6 QA 计划模板）
**范围**：4 Epic × 14 story——Meta 层 ProgressionSystem + 3 个 Feature 层 Epic
**引擎**：Godot 4.6
**测试框架**：GUT
**Sprint 文件**：`production/sprints/sprint-7.md`
**Manifest Version**：2026-08-05

> **分类原则**：每个 story 头部 `Type:` 字段分类。14 个 story 全部为 Logic 或 Integration，无 UI/Visual/Config 类。

---

## 一、测试摘要表

| # | Story | Epic | 类型 | 测试文件路径 | 实际测试数 |
|:--:|-------|------|:----:|-------------|:----------:|
| 7-1 | 域存储 + initialize + serialize/deserialize | progression-system | Logic | `tests/unit/progression_system/test_domain_storage.gd` | 10 |
| 7-2 | achievements 领域 API | progression-system | Logic | `tests/unit/progression_system/test_achievements_api.gd` | 10 |
| 7-3 | talents 领域 API | progression-system | Logic | `tests/unit/progression_system/test_talents_api.gd` | 10 |
| 7-4 | endings + gallery + stats + meta 领域 API | progression-system | Logic | `tests/unit/progression_system/test_remaining_domains_api.gd` | 10 |
| 7-5 | progression_updated 信号 + batch_update + SaveLoad 集成 | progression-system | Integration | `tests/unit/progression_system/test_batch_and_integration.gd` | 10 |
| 7-6 | PlayerTalents 天赋树 + 查询 API | reincarnation-talent-system | Logic | `tests/unit/reincarnation_talent_system/test_talent_tree.gd` | 10 |
| 7-7 | unlock_talent / get_active_talents | reincarnation-talent-system | Logic | `tests/unit/reincarnation_talent_system/test_unlock_and_equip.gd` | 10 |
| 7-8 | settle_run 轮回结算（跨局天赋继承） | reincarnation-talent-system | Integration | `tests/unit/reincarnation_talent_system/test_settle_run.gd` | 10 |
| 7-9 | Achievement 实例 + 解锁状态管理 | achievement-system | Logic | `tests/unit/achievement_system/test_achievement_defs.gd` | 10 |
| 7-10 | check(criteria) 判定引擎 | achievement-system | Logic | `tests/unit/achievement_system/test_check_engine.gd` | 10 |
| 7-11 | get_achievements 查询 + 图鉴集成 | achievement-system | Integration | `tests/unit/achievement_system/test_query_and_gallery.gd` | 10 |
| 7-12 | DialoguePlayer + DialogueDatabase 数据结构 | dialogue-system | Logic | `tests/unit/dialogue_system/test_data_structures.gd` | 10 |
| 7-13 | start_dialogue / select_option / advance 播放编排 | dialogue-system | Logic | `tests/unit/dialogue_system/test_playback_orchestration.gd` | 10 |
| 7-14 | BarkManager + play_bark + get_bark_history | dialogue-system | Logic | `tests/unit/dialogue_system/test_bark_manager.gd` | 10 |

**实际测试总数**：**140** 个测试函数（Logic 120 + Integration 20）

### 分类统计

| 类型 | 数量 | 关卡等级 | 证据位置 |
|:----:|:----:|:--------:|---------|
| **Logic** | 12 | BLOCKING（阻塞） | `tests/unit/[system]/` |
| **Integration** | 2 | BLOCKING（阻塞） | `tests/unit/[system]/` |
| **合计** | 14 | — | — |

**Logic 分布**：progression 4、reincarnation 2、achievement 2、dialogue 3 = 11（含 dialogue-system 3）
**Integration 分布**：progression 1、reincarnation 1、achievement 1 = 3

> 修正：Logic 11 + Integration 3 = 14。

---

## 二、全量测试基线

**最终全量测试结果**（2026-09-02）：

| 指标 | 值 |
|------|----|
| Scripts | 135 |
| Tests | 2367 |
| Passing | 2366 |
| Pending | 1（既有 save_load 迁移测试） |
| Failing | 0 |
| Asserts | 8984 |
| Orphans | 1（既有） |

**零回归**——Sprint 7 新增 14 个测试脚本 / 140 个测试，全部通过。

---

## 三、按 Epic 分组的测试覆盖

### progression-system（5 Story，50 测试）

- **7-1 域存储**（10 测试）：6 域内部存储 Dictionary + initialize(data) + serialize() + deserialize(data) + has_unsaved_changes + mark_saved
- **7-2 achievements API**（10 测试）：register_achievement + unlock_achievement（去重） + get_achievement + get_achievements(category) + update_achievement_progress
- **7-3 talents API**（10 测试）：register_talent + get_talent_points + add_talent_points + purchase_talent + grant_talent + set_equipped_talents + get_active_slot_count
- **7-4 剩余 4 领域**（10 测试）：unlock_ending（total_completions 递增）+ mark_card_discovered（去重）+ increment_stat / set_stat（仅增不降）+ get_meta_value / set_meta_value（白名单 key）
- **7-5 信号+集成**（10 测试）：progression_updated 信号 + batch_update_begin/end（嵌套） + SaveLoadSystem.load_progression 被动持久化 + mark_saved 清 dirty

### reincarnation-talent-system（3 Story，30 测试）

- **7-6 天赋树**（10 测试）：20 天赋节点 const Dictionary（5 分支 × 4 层）+ get_talent_def + get_branch_talents + get_full_tree_state + ELITES_CAP / BOSSES_CAP
- **7-7 解锁装备**（10 测试）：can_unlock 前置+软解锁 + unlock_talent 委托 purchase_talent + get_active_talents + set_equipped
- **7-8 轮回结算**（10 测试）：calculate_reincarnation_points GDD §2 公式 + settle_run 编排（add_talent_points + total_reincarnations + total_completions + highest_realm_ever）

### achievement-system（3 Story，30 测试）

- **7-9 成就定义**（10 测试）：62 成就 const Dictionary（7 类别）+ get_achievement_definition + get_all_definitions + get_definitions_by_category
- **7-10 判定引擎**（10 测试）：check_achievements 扫描 event+threshold+extra + 累计型 update_achievement_progress + 即时型 unlock_achievement
- **7-11 查询图鉴**（10 测试）：get_unlocked_achievements + get_achievement_summary + get_hidden_achievements + get_achievement_progress

### dialogue-system（3 Story，30 测试）

- **7-12 数据结构**（10 测试）：DialogueDatabase 加载+缓存+查询 + DialoguePlayer start/get_current_node/advance/select_choice + 对话历史 + RefCounted 生命周期
- **7-13 播放编排**（10 测试）：start_dialogue 信号 + select_option outcomes + 条件可见性（story_flag/always） + 选项灰色 + skip + end_action + EventSystem.set_flag 委托
- **7-14 BarkManager**（10 测试）：bark 池注册 + play_bark 随机不重复 + 池耗尽重置 + bark_played 信号 + get_bark_history + 空池/未注册容错

---

## 四、Autoload 注册验证

Sprint 7 新增 1 个 Meta 层 Autoload，已注册到 `project.godot`：

| Autoload | 编号 | 脚本路径 | 依赖 |
|----------|:----:|----------|------|
| ProgressionSystem | #12 | `res://src/meta/progression_system.gd` | SaveLoadSystem, GSM |

ReincarnationTalentSystem、AchievementSystem 为 RefCounted 服务类，不注册 Autoload。DialoguePlayer/DialogueDatabase/BarkManager 为 RefCounted 服务类（ADR-0027），不注册 Autoload。

全量测试在 Autoload 注册后零回归——初始化顺序正确（ProgressionSystem 在 SaveLoadSystem #4 之后 _ready()）。

---

## 五、ProgressionSystem 取代 GSM progression.* 域

Sprint 7 的核心架构变更——ADR-0012 将跨局元进度数据所有权从 GSM progression.* 域迁移到 ProgressionSystem Autoload #12：

| 变更项 | 说明 |
|--------|------|
| 数据所有权 | ProgressionSystem 拥有 6 域存储（achievements / talents / card_gallery / endings / stats / meta） |
| 持久化 | SaveLoadSystem.load_progression() 在 ProgressionSystem._ready() 中直接调用（非信号等待） |
| 信号 | progression_updated(domain) 通知 SaveLoadSystem 被动持久化 |
| API 命名冲突修复 | get_meta() / set_meta() 与 Object 内置方法冲突 → 重命名为 get_meta_value() / set_meta_value() |
| 批量更新 | batch_update_begin/end 嵌套计数器 + _batch_pending_domains 合并去重 |

---

## 六、已知技术债务（非阻塞）

| 项 | 来源 | 影响 | 计划 |
|----|------|------|------|
| Feature 层文件超 300 行 | Sprint 4/5/6 QA 遗留 | 多个 Feature 文件超 300 行 | 后续 Sprint 重构 |
| CardSystem 掉落规则接线 | Sprint 5 桩实现遗留 | 战利品桩 | 后续 Sprint 接线 |
| RealmSystem 天劫 Boss 配置接线 | Sprint 5 桩实现遗留 | 天劫 Boss 桩 | 后续 Sprint 接线 |
| StatusEffectSystem 心魔 debuff 接线 | Sprint 5 桩实现遗留 | 心魔桩 | 后续 Sprint 接线 |
| InputManager 锁管理接线 | Sprint 5 桩实现遗留 | 输入锁桩 | 后续 Sprint 接线 |
| save_load 1 pending test | Sprint 1 既有 | 多步迁移未实现 | 首次升级时实现 |
| InputManager 1 orphan | Sprint 1 既有 | 对象清理 | 后续排查 |
| DialoguePlayer 条件评估器桩 | Sprint 7 | 8 种条件类型（realm/faction 等）返回 true | 后续 Sprint 接线游戏状态 |

---

## 七、冒烟检查清单

- [x] 全量测试通过（135 scripts / 2367 tests / 0 failing）
- [x] 1 个新 Autoload 注册且初始化顺序正确（ProgressionSystem #12）
- [x] Sprint 7 所有 14 Story 状态为 Done
- [x] ProgressionSystem serialize/deserialize 往返验证
- [x] 跨 Epic 依赖链验证（reincarnation #006 → progression #003；achievement #009 → progression #002）
- [x] 零新增回归（对比 Sprint 6 基线 121 scripts / 2227 tests）
- [x] ADR-0012 + ADR-0027 架构决策一致性验证

---

## 八、QA 签收建议

**建议**：APPROVED WITH CONDITIONS

**理由**：
- ✅ 14/14 Story 全部完成，140 个新增测试全部通过
- ✅ 零回归（全量 2367 tests / 0 failing）
- ✅ 1 个 Autoload 注册验证通过（ProgressionSystem #12）
- ✅ 跨 Epic 依赖链正确（reincarnation → progression talents API；achievement → progression achievements API）
- ✅ ProgressionSystem 取代 GSM progression.* 域无回归
- ✅ ADR-0012（ProgressionSystem Autoload）+ ADR-0027（DialogueSystem RefCounted）架构决策一致性
- ⚠️ 8 项既有技术债务非阻塞（Sprint 4/5 遗留 + Sprint 7 条件评估器桩）

**Conditions**：
1. 后续 Sprint 需接线 CardSystem 掉落规则替换战利品桩实现
2. 后续 Sprint 需接线 RealmSystem 天劫 Boss 配置替换桩默认值
3. 后续 Sprint 需接线 StatusEffectSystem 心魔 debuff 替换桩
4. 后续 Sprint 需接线 InputManager 锁管理替换桩
5. Feature 层文件超 300 行需在后续 Sprint 重构
6. DialoguePlayer 条件评估器 8 种条件类型需后续 Sprint 接线游戏状态上下文
