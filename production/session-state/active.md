# 活跃会话状态

## Session Extract — /story-done 2026-08-02 (Story 005 save-load)
- Verdict：✅ COMPLETE WITH NOTES
- Story：`production/epics/save-load/story-005-migration-chain-version-mismatch.md` — schema_version 迁移链 + VERSION_MISMATCH 拒绝
- Code Review：LP-CODE-REVIEW ISSUES FOUND（0 BLOCKER / 2 HIGH / 3 LOW）——H1（文件 796 行超标 265%）、H2（_validate_version 与 _migrate_if_needed 重复检查——纵深防御设计）、L1/L3 已修复
- QA Review：QL-TEST-COVERAGE ADEQUATE（3 建议项记录为 ADVISORY）
- Changes：`src/foundation/save_load_system.gd`（缩进修复 + 交叉引用注释）+ `tests/unit/save_load/test_migration_chain.gd`（L1 死代码删除 + L3 补充断言）
- 测试结果：344/344 通过（含 save_load 全部 5 个测试文件），1342 断言，1 pending（多步迁移——CURRENT=1 合理推迟），零失败
- Tech debt logged：3 ADVISORY（H1 行数超标、H2 重复检查、QA 3 项改善建议）
- Next recommended：`production/epics/event-system/story-001-event-template-resource-model.md`（EventTemplate Resource 数据模型，3h）——Event System Epic 启动

<!-- STATUS -->
Epic: event-system
Feature: Sprint 1 - Foundation 层
Task: Story 005 完成——save-load Epic ✅ 全部 5/5 完成
<!-- /STATUS -->

## Session Extract — /story-done 2026-08-01 (Story 004 save-load)
- Verdict：✅ COMPLETE WITH NOTES
- Story：`production/epics/save-load/story-004-public-api-gsm-integration.md` — GSM 状态序列化/反序列化 + 公共 API 整合
- Code Review：LP-CODE-REVIEW APPROVED WITH HIGH FINDINGS（R1+R2+R3+QA GAP 2/3/4 全部修复）
- QA Review：QL-TEST-COVERAGE ADEQUATE（6 缺口已补充，新增 4 测试）
- Changes：`src/foundation/save_load_system.gd`（+~190 行——5 信号 + DI + meta.json 管理 + _migrate_if_needed 桩 + 9 公共 API）+ `tests/unit/save_load/test_public_api.gd`（新建，20 测试）
- 测试结果：55/55 通过，175 断言，零失败
- Tech debt logged：4 ADVISORY（返回类型 int vs enum、duplicate 浅拷贝、测试目录位置、文件行数超标）
- Next recommended：`production/epics/save-load/story-005-migration-chain-version-mismatch.md`（迁移链 + VERSION_MISMATCH，3h）

<!-- STATUS -->
Epic: save-load
Feature: Sprint 1 - Foundation 层
Task: Story 004 完成——公共 API + GSM 集成
<!-- /STATUS -->

## Session Extract — /story-done 2026-07-31 (Story 003 save-load)
- Verdict：✅ COMPLETE
- Story：`production/epics/save-load/story-003-container-schema-validation.md` — 存档容器 schema + "complete" 标记 + 完整性校验
- Code Review：APPROVED WITH SUGGESTIONS——1 HIGH DRY 已修复，4/5 LOW 已修复
- QA Review：QL-TEST-COVERAGE ADEQUATE
- Changes：`src/foundation/save_load_system.gd`（追加 ~100 行——4 方法 + 1 常量）+ `tests/unit/save_load/test_container_schema.gd`（新建，19 测试）
- 测试结果：35/35 通过，110 断言，零失败（save_load 全部测试：35/35）
- Tech debt logged：None（1 LOW——测试目录 `tests/unit/` vs `tests/integration/` 留待后续 Sprint 调整）
- Next recommended：`production/epics/save-load/story-004-public-api-gsm-integration.md`（公共 API + GSM 集成，4h）

<!-- STATUS -->
Epic: save-load
Feature: Sprint 1 - Foundation 层
Task: Story 003 完成——容器 schema + 完整性校验
<!-- /STATUS -->

## Session Extract — /story-done 2026-07-31 (Story 002 save-load)
- Verdict：✅ COMPLETE WITH NOTES
- Story：`production/epics/save-load/story-002-atomic-write-retry.md` — 原子写入策略 + 重入防护 + Windows 重试
- Code Review：LP-CODE-REVIEW APPROVED WITH SUGGESTIONS（4 项建议已修复）
- QA Review：QL-TEST-COVERAGE ADEQUATE（2 ADVISORY）
- Changes：`src/foundation/save_load_system.gd`（追加 ~150 行——5 方法 + 2 常量 + 2 字段）+ `tests/unit/save_load/test_atomic_write.gd`（新建，16 测试）
- 测试结果：289/289 通过，1172 断言，零失败
- Tech debt logged：None
- Next recommended：`production/epics/save-load/story-003-container-schema-validation.md`（容器 schema + 完整性校验）

<!-- STATUS -->
Epic: save-load
Feature: Sprint 1 - Foundation 层
Task: Story 002 完成——原子写入 + Windows 重试 + 重入防护
<!-- /STATUS -->

## Session Extract — /story-done 2026-07-31 (Story 001 save-load)
- Verdict：✅ COMPLETE WITH NOTES
- Story：`production/epics/save-load/story-001-json-engine-enums.md` — JSON 序列化引擎 + SaveResult/LoadResult 枚举
- Code Review：LP-CODE-REVIEW APPROVED（H1/H2 已修复，M1 为 Autoload 架构固有限制）
- QA Review：QL-TEST-COVERAGE ADEQUATE（2 ADVISORY）
- Changes：`src/foundation/save_load_system.gd`（重写，86 行）+ `tests/integration/save_load/test_json_engine.gd`（新建，31 测试）
- 测试结果：304/304 通过，1209 断言，零失败
- Tech debt logged：None
- Next recommended：`production/epics/save-load/story-002-atomic-write-retry.md`（原子双写 + Windows 重试）

<!-- STATUS -->
Epic: save-load
Feature: Sprint 1 - Foundation 层
Task: Story 001 完成——JSON 引擎 + 枚举定义
<!-- /STATUS -->

## Session Extract — /story-done 2026-07-30 (Story 002 关闭)
- Verdict：✅ COMPLETE
- Story：`production/epics/scene-manager/story-002-transition-type-audio-matrix.md` — TransitionType + 音频过渡矩阵
- Next recommended：Story #12 — 转场前自动存档 + 输入锁集成

## Session Extract — /story-done 2026-07-30 (Story 001)
- Verdict：✅ COMPLETE WITH NOTES
- Story：`production/epics/scene-manager/story-001-five-phase-pipeline-core.md` — 5 阶段转换管线核心
- Fixes applied：STATIC_CALLED_ON_INSTANCE 警告 ×2（get_script() 静态调用）、AC-2 文本 "13"→"12"、测试列表 test_scene_paths_contains_all_13_entries→test_scene_paths_has_12_entries
- Tech debt logged：None（2 项 ADVISORY 记录在 Completion Notes）
- Next recommended：Story #11 — scene-manager TransitionType + 音频过渡矩阵 (`production/epics/scene-manager/story-002-transition-type-audio-matrix.md`)

## 本会话成果

### gate-check Pre-Production→Production：🟡 CONCERNS（2026-07-28）

**审查日期**：2026-07-28（复查）
**审查模式**：full
**裁决**：🟡 CONCERNS——可以进入 Production，10 项关切需在前 2 个 Sprint 内解决

**原始审查日期**：2026-07-27
**复查日期**：2026-07-28
**审查模式**：full

#### 原主管小组

| 主管 | 原始裁决 | 最新评估 |
|------|:--:|------|
| 创意总监 | 🔴 NOT READY | 🟡——B1 已解决（PROCEED），B2 部分缓解（1 次自测），B3 已解决 |
| 技术总监 | 🔴 NOT READY | 🔴——B4/B6 未在垂直切片中覆盖，B5 部分缓解 |
| 制作人 | 🟡 CONCERNS | 🟡——速度数据充分，B2 试玩不足 |
| 美术总监 | 🟡 CONCERNS | 🟡——无变化（垂直切片无美术资产） |

#### 阻塞项状态（复查）

| # | 阻塞项 | 原始严重度 | 当前状态 |
|---|--------|:--:|------|
| B1 | 无可玩原型/垂直切片 | 致命 | ✅ **已解决**——REPORT.md 已写入，PROCEED 裁决，D1-D7 全部完成 |
| B2 | 零试玩数据 | 致命 | ⚠️ **部分缓解**——1 次开发者自测（~3 分钟），`production/playtests/` 仍为空，无外部测试者 |
| B3 | 缺少 `/review-all-gdds` | 高 | ✅ **已解决**——`gdd-cross-review-2026-07-23.md` 已存在，综合裁决 ✅ 通过，3 阻塞项已解决 |
| B4 | Godot 4.6 双焦点行为未验证 | 高 | ⬜ **未解决**——REPORT 未涉及双焦点验证 |
| B5 | 性能预算全为纸面估算 | 高 | ⚠️ **部分缓解**——RTX 3050 验证通过，低端 GPU 未测 |
| B6 | 25 Autoload 初始化顺序未运行 | 高 | ⬜ **未解决**——垂直切片未使用 Autoload 链 |

#### 更新后的最小 PASS 路径

1. ✅ `/vertical-slice` 已完成（覆盖 B1，部分覆盖 B5）
2. ⚠️ 试玩记录——需正式写入 `production/playtests/`（覆盖 B2）
3. ⬜ 运行 `/review-all-gdds`（覆盖 B3）
4. ⬜ 重新提交 `/gate-check`（含 B4/B6 评估）

### Foundation 层 ADR 全部 Accepted ✅

| ADR | 系统 | 审查结果 | 修复项 | 最终状态 |
|-----|------|:--:|:--:|:--:|
| ADR-0001 | GSM 三层 API | 7 HIGH | 交叉引用 ×3、缺 6 章节、GDD 路径 | **Accepted** |
| ADR-0002 | 存档/读档 | 3 HIGH | meta + current_scene、event_resolved 连接 | **Accepted** |
| ADR-0003 | 事件系统 | ✅ PASS | 仅 ADR-0001 L112 引用修正 | **Accepted** |
| ADR-0004 | 输入管理器 | 3 CONCERNS | 白名单语义修正、MODAL 覆盖机制 | **Accepted** |
| ADR-0005 | 场景管理器 | ✅ PASS | assert→if、注释修正 | **Accepted** |

### 法宝铭刻 ADR 创建 ✅

| ADR | 系统 | 模式 | 状态 |
|-----|------|------|:--:|
| ADR-0030 | 法宝铭刻系统 | RefCounted + class_name（零 Autoload） | **Proposed** |

### Feature 层 ADR 第四批 Accepted ✅

| ADR | 系统 | 审查结果 | 修复项 | 最终状态 |
|-----|------|:--:|:--:|:--:|
| ADR-0022 | 开局身份选择 | Foundation 计数 7→5 | `§排序说明` Foundation 层 "7 个 ADR"→"5 个" | **Accepted** |
| ADR-0023 | 卡组编辑 | EventSystem 层归属修正 | `§排序说明` EventSystem 标注 "Foundation" 层→已在 ADR-0003 确认 | **Accepted** |
| ADR-0024 | 阵法系统 | InputManager 引用 ADR-0005→0004、拼写 Formaton→Formation | InputManager 编号偏移 + 类名拼写修正 | **Accepted** |
| ADR-0026 | 剧情系统 | ✅ PASS | 编号引用正确，Autoload 链完整 | **Accepted** |

### 跨 ADR 修复

- architecture.md v1.9→v2.0：Feature 层 12/12 全部 Accepted ✅
- active.md 统计更新：Feature 8→12，总计 22→26

| ADR | 系统 | 审查结果 | 修复项 | 最终状态 |
|-----|------|:--:|:--:|:--:|
| ADR-0008 | 战斗系统 | 11 项 | Foundation 编号偏移 ×6、Deployment/AI ADR 编号修正、Foundation 计数 7→5、InputManager ADR-0005→0004、markdown 表格结构 | **Accepted** |
| ADR-0009 | 卡牌效果引擎 | 10 项 | Foundation 编号偏移 ×4、ADN0008 拼写→ADR-0008、ADR-0010→0016/ADR-0011→0017、CostSystem "待 ADR"→ADR-0015、StatusSystem 风险更新、ADR-0005→0004/ADR-0006→0005 | **Accepted** |

### 跨 ADR 修复

- ADR-0008 战斗系统 Phase 3 ATTACK_DECLARATION 锁冲突修复（pop/push ANIMATION）
- architecture.md ADR-0005→ADR-0004 输入管理器编号引用修正
- architecture.md v1.3→v1.4：30 ADR + Foundation Accepted 标注

## Autoload 全链（25 个）

```
#1  GSM                 (FOUNDATION)
#2  InputManager         (FOUNDATION)
#3  SceneManager         (FOUNDATION)
#4  SaveLoadSystem       (FOUNDATION)
#5  EventSystem          (FOUNDATION)
#6  CardSystem           (CORE)
#7  CostSystem           (CORE)      ← ADR-0015
#8  StatusEffectSystem   (CORE)
#9  CombatSystem         (FEATURE)
#10 CardEffectEngine     (FEATURE)
#11 RealmSystem           (CORE)
#12 ProgressionSystem     (META)
#13 BindingManager        (FEATURE)
#14 ExplorationSystem     (FEATURE)
#15 FactionSystem         (CORE)      ← ADR-0018
#16 ResourceSystem        (CORE)      ← ADR-0019
#17 DeploymentSystem      (FEATURE)   ← ADR-0016
#18 AISystem              (FEATURE)   ← ADR-0017
#19 SchoolSystem          (CORE)      ← ADR-0025
#20 CultivationSystem     (FEATURE)   ← ADR-0020
#21 IdentitySelectionSystem (FEATURE) ← ADR-0022
#22 DeckEditingSystem     (FEATURE)   ← ADR-0023
#23 FormationSystem       (FEATURE)   ← ADR-0024
#24 TribulationSystem     (FEATURE)   ← ADR-0021
#25 StorySystem           (FEATURE)   ← ADR-0026
```

## 非 Autoload 系统（3 个——均为第三批）

| 系统 | 模式 | ADR |
|------|------|-----|
| 对话系统 | RefCounted 服务类（DialoguePlayer + DialogueDatabase + BarkManager）+ JSON 按需加载 | ADR-0027 |
| 炼丹炼器系统 | RefCounted + class_name 工具类 + PRD 独立 RNG 实例 | ADR-0028 |
| 结局分支系统 | EndingEvaluator 纯函数工具类嵌入 StorySystem | ADR-0029 |

<!-- STATUS -->
Epic: Production
Feature: Sprint 1 - Foundation 层
Task: GSM Epic 全部完成——Story 001-005，98/98 测试通过
<!-- /STATUS -->

## 垂直切片：仙途问道——扩展战斗原型

> **启动**：2026-07-27
> **验证问题**：玩家能否在 4 分钟内无需引导完成「炼气战斗→修为满→渡劫→突破筑基→再战」？
> **审查模式**：full
> **硬时间限制**：7 个工作日（D1=2026-07-27）
> **原型目录**：`prototypes/cultivation-card-battle-vertical-slice/`

### 逐日进度

| 日 | 计划 | 状态 |
|:--:|------|:--:|
| D1 | 项目框架 + 角色选择 + 基础战斗 + 卡牌 | ✅ 完成 |
| D2 | 修为系统 + 灵石系统 + 渡劫战 + 战斗日志 | ✅ 完成 |
| D3 | 绑定卡牌系统 + 4 张绑定卡 | ✅ 完成 |
| D4 | 新卡牌 + 敌方差异化 AI + 日志优化 + 文件拆分 | ✅ 完成 |
| D5 | 完整循环穿线 + Godot 4.6 语法修复 + 警告清零 | ✅ 完成 |
| D6 | 打磨（卡牌颜色/按钮状态/hud 重置） | ✅ 完成 |
| D7 | 试玩验证 + REPORT.md | ✅ 完成 |

### D1 产出

| 文件 | 行数 | 说明 |
|------|:--:|------|
| `scripts/realm_data.gd` | 65 | 炼气/筑基属性表 + 压制系数表 + get_realm_property()/get_suppression() |
| `scripts/cost_system.gd` | 86 | 灵力费用：can_afford()/spend()/reset_for_turn()/temp_bonus |
| `scripts/cultivation_system.gd` | 100 | 修为获取统一入口 + 溢出池 + 突破就绪检测 |
| `scripts/player_state.gd` | 147 | 重写——委托给 CostSystem/CultivationSystem + 信号转发 |
| `scripts/battle_controller.gd` | 251 | 接入三系统 + 境界压制 + 突破流程（简化为直接突破） |
| `scripts/battle_hud.gd` | 389 | 新增修为进度条 + 境界标签 + 突破按钮 + 突破成功动画 |
| `scripts/enemy_ai.gd` | 155 | 新增按境界缩放 + get_enemy_name() + reset_all() |
| `scripts/reward_screen.gd` | 125 | 新增修为奖励显示 |
| **总计** | **1,318 行** | 3 新文件 + 5 修改

### 范围外
探索地图、卡组自由编辑、阵法、炼丹炼器、剧情对话、音频

## 会话摘录——/dev-story 2026-07-28
- 故事：production/epics/input-manager/story-001-lock-stack-core.md —— 四级锁栈核心实现
- 更改的文件：src/foundation/input_manager.gd（覆盖 stub，183 行）、tests/unit/input/test_lock_stack.gd（新建，37 测试函数）
- 编写的测试：tests/unit/input/test_lock_stack.gd — 14 AC 全覆盖 + 边界测试
- 阻塞项：无
- 下一步：/code-review src/foundation/input_manager.gd tests/unit/input/test_lock_stack.gd 然后 /story-done

- 2026-07-28：**5 项高优先级关切全部解决：**
  - **C1** Presentation Spike 规划 → `production/spikes/presentation-spike-plan.md`（5-7 天，Sprint 2-3 执行）
  - **C2** 铭刻系统已有向随机——无需修订（定向铭刻+三择+替换选择已提供策略代理权）
  - **C3** 渡劫 GDD 已修订——`design/gdd/tribulation-system.md`（修为损失 10→15% + 心魔 debuff + 复活途径）
  - **C4** 双焦点测试场景 → `tests/integration/input-manager/dual_focus_manual_verify.gd`（5 个验证问题 + 信号日志）
  - **C5** Autoload 初始化计时测试 → `tests/integration/autoload/autoload_init_timing_test.gd`（Foundation 5 合计<50ms + 25 外推<200ms）
- 2026-07-28：🎉 垂直切片「仙途问道」完成——D1-D7 全部完成，REPORT.md 已写入：
  - 裁决：**PROCEED**——完整循环已验证，4 天构建 + 1 天试玩，约 3000 行 GDScript
  - 验证问题通过：玩家可独立完成炼气战斗→渡劫→突破→再战（无引导完成率 100%）
  - 修仙爽感未通过（预期内——纯程序化 UI 无资产/音频/动画），生产需 UI 大幅投入
  - 试玩次数不足：仅 1 次开发者自测 → gate-check B2（零试玩数据）仅部分缓解
- 2026-07-27：垂直切片启动——阶段 1-3 完成，扩展战斗原型进入 D1
- 2026-07-27：Story 001 实现完成——GSM Autoload 基础结构与第一层属性读取：
  - `src/foundation/game_state_manager.gd` —— 178 行，8 个数据域（progression 已按 ADR-0012 移除），RealmLevel 枚举，get(path) 通用路径读取，gsm_initialized 信号
  - `tests/unit/gsm/autoload_and_tier1_read_test.gd` —— 18 条测试，覆盖 AC-001/AC-002/AC-003 + 补充测试（全域初始化、progression 缺席、默认值正确性）
  - `_get_domain()` 私有方法使用 match + String 分支，兼容 Godot 4.6
  - 所有代码：静态类型、## 文档注释、snake_case 信号命名

- 2026-07-27：AD-PHASE-GATE 审查完成——CONCERNS（1 CONCERN + 2 ADVISORY，无 BLOCKER）：
  - C-1: `design/assets/entity-inventory.md` 缺失——需在 Production 第一周内（不晚于 2026-08-04）创建敌方/Boss/NPC 实体视觉清单
  - A-1: UI 图标 (~48) 和 VFX (12) 规范待 UI 实现后补充
  - A-2: LOD-0 角色立绘数量（38 vs 表格中的 15）导致 LOD 金字塔内存估算偏低——建议更新

- 2026-07-27：QA 计划写入——Sprint 1 Foundation 层：
  - 21 个预期 story（14 逻辑 + 7 集成）
  - 预估 ~110 单元测试 + ~48 集成测试
  - 3 项手动 QA 检查（双焦点验证、grep 扫描、Windows 原子写入复现）
  - 无试玩要求（Foundation 层无面向玩家 UI）

- 2026-07-27：UX 规范审查完成——3/3 APPROVED：
  - `design/ux/hud.md`——APPROVED（0 BLOCKING / 2 ADVISORY）
  - `design/ux/main-menu.md`——APPROVED（修复后：制作人员界面移出 MVP + 加载/错误状态补充）
  - `design/ux/pause-menu.md`——APPROVED（修复后：保存失败错误状态 + 战败结算流程）
  - 审查发现共 7 项问题（2 BLOCKING + 5 ADVISORY），全部已修复写入文件

- 2026-07-26：全部卡牌资产规范完成——5 个新规范文件写入：
  - `design/assets/specs/card-system-techniques-assets.md`——52 张功法卡运功图（ASSET-016~063）
  - `design/assets/specs/card-system-artifacts-assets.md`——48 张法宝卡器物图（ASSET-064~108）
  - `design/assets/specs/card-system-pills-assets.md`——24 张丹药卡丹丸图（ASSET-109~133）
  - `design/assets/specs/card-system-talismans-assets.md`——30 张符箓卡符文图（ASSET-134~163）
  - `design/assets/specs/card-system-formations-assets.md`——16 张阵法卡阵盘图（ASSET-164~179）
  - `design/assets/asset-manifest.md`——更新——200/200 资产已规范
  - 6 个并行代理全部因 Haiku API 503 失败——所有规范由主会话以 Solo 模式直接编写

- 2026-07-26：补全卡牌图片规范——三个文件修改：
  - `ADR-0006` L91：CardTemplate 新增 `illustration_path: String` 字段
  - `art-bible.md` L1482-L1722：新增第 5.X 部分「卡牌插画类型规范」——6 种卡牌类型 × 185 张 LOD-1 插画规格，含角色(15)/功法(52)/法宝(48)/丹药(24)/符箓(30)/阵法(16) 的视觉语法、构图规则、色彩预算、外包标准
  - `card-system-design.md` L309：新增插画规范引用注释
- 2026-07-26：完成美术圣经第 7/8/9 部分的撰写并写入 `design/art/art-bible.md`
  - 第 7 部分「UI/HUD 视觉方向」：排版系统(4 字体+7 字号层级)、图标系统(5 类别 + 3 状态)、4 屏幕 ASCII 布局图(战斗/探索/卡组编辑/主菜单)、5 种动画规范、4.6 双焦点视觉策略、语义色使用预算(≤12 处)
  - 第 8 部分「资产标准」：文件格式与命名约定(完整目录结构)、LOD 金字塔内存估算(~119MB 纹理峰值)、Godot 导入预设(可直接复制)、绘制调用预算(≤200)、色彩管理与墨阶校准(7 级)、外包 8 项验收清单
  - 第 9 部分「参考方向」：5 个参考(汪达与巨像/上美影水墨动画/Slay the Spire/胧村正/Sable)——每个含「汲取」+「明确避免」双向约束 + 参考可区分性测试
- 美术圣经已完整：9 部分 + 卡牌插画类型规范(5.X) = 2,889 行。状态已更新为「全部完成」

## 关键架构决策

1. **ADR 覆盖 30/36 GDD 系统**：剩余 6 个为 UI 层（6 个）——编码阶段直接决策。法宝铭刻已由 ADR-0030 覆盖
2. **Autoload 链 25 个**：超出 Godot 20 软上限 ⚠️——第三批后新增系统（对话/炼丹炼器/结局分支/法宝铭刻）全部采用 RefCounted 阻止进一步膨胀
3. **Foundation 层 5 个 ADR 全部 Accepted ✅**：编码阶段可开始实现 Foundation 系统
4. **Core 层"静态数据表三剑客"**：RealmSystem(#11) + FactionSystem(#15) + SchoolSystem(#19)——均采用 const Dictionary + 纯查询接口
5. **GSM 例外清单四条目**：StatusEffectSystem + BindingManager + DeploymentSystem + FormationSystem——战斗热路径内部管理 + 战斗结束 GSM 快照
6. **ADR-0001 第二层原子方法**：24 个方法（8 个明确签名 + 3 个图表中存在 + 12 个其他 ADR 定义 + 1 个最终状态变更）——需汇总回 ADR-0001（见遗留问题 #3）

## ADR 总数统计

| 层 | 数量 | Autoload | 非 Autoload | Accepted |
|-----|------|:--:|:--:|:--:|
| Foundation | 5 | 5 | 0 | 5 ✅ |
| Core | 9 | 8 | 0 | 8 ✅ |
| Feature | 11 | 11 | 0 | 12 ✅ |
| Meta | 1 | 1 | 0 | 1 ✅ |
| Narrative | 2 | 0 | 2 | 2 ✅ |
| Economy | 2 | 0 | 2 | 2 ✅ |
| **总计** | **30** | **25** | **4** | **30 ✅** |

## 已知遗留问题

1. **行数超标**：多个 ADR 超出 ≤250 行目标
2. **ADR-0015 双重信号路径**：cost_changed (Cat 2b) + batch_updated (Cat 1)
3. **GSM 第二层方法碎片化**：24 个原子方法分布在 ADR-0001（8+3）、ADR-0014（6）、ADR-0020/0021（1）、ADR-0022（1）、ADR-0026（5）——需汇总回 ADR-0001
4. **Autoload 25 超 20 软上限**：已在所有相关 ADR 中明确记录风险
5. **Core/Feature/Narrative/Economy/Meta 层 ADR 仍为 Proposed**：25 个非 Foundation 层 ADR 等待实现前审查

## Session Extract — /story-done 2026-07-29

- **Verdict**：✅ COMPLETE WITH NOTES
- **Story**：`production/epics/input-manager/story-001-lock-stack-core.md` — 四级锁栈核心实现
- **Code Review**：首席程序员 APPROVED WITH SUGGESTIONS — `_sync_to_gsm()` 空桩 + 路径修正已应用
- **QA Review**：QA Lead ADEQUATE — 14/14 AC 覆盖，37 测试函数
- **Changes**：
  - `src/foundation/input_manager.gd` — 新增 `_sync_to_gsm()` 空桩（为 Story 003 预留）
  - `production/epics/input-manager/story-001-lock-stack-core.md` — 路径修正 + Status: Complete + Completion Notes
  - `production/sprints/sprint-1.md` — Story #1 和 #6 标记 Done
- **Tech debt logged**：None
- **Next recommended**：`production/epics/input-manager/story-002-dual-focus-judgment.md`（双焦点输入判定）

## Session Extract — /story-done 2026-07-29 (Story 002)

- **Verdict**：✅ COMPLETE WITH NOTES
- **Story**：`production/epics/input-manager/story-002-dual-focus-judgment.md` — 双焦点输入判定
- **Code Review**：LP-CODE-REVIEW APPROVED with CONCERNS (2 LOW)，QL-TEST-COVERAGE ADEQUATE
- **Changes**：
  - `src/foundation/input_manager.gd` — 新增 ActionType/DeviceType 枚举、`is_input_allowed()`、`is_action_blocked()`、`_check_device_allowed()`、`_get_highest_lock()` assert 守卫（334 行）
  - `tests/unit/input/test_input_judgment.gd` — 37 测试函数（24 AC + 11 边界 + 2 GAP 修复），性能注释已文档化
  - `production/epics/input-manager/story-002-dual-focus-judgment.md` — Status: Complete + Completion Notes
  - `production/sprints/sprint-1.md` — Story #7 标记 ✅ Done
- **Tech debt logged**：None（5 项 ADVISORY 记录在 Completion Notes 中）
- **LP Concerns 修复**：C1 (行数) 推迟至 Story 003/004，C2 (_get_highest_lock assert) 已修复
- **Next recommended**：`production/epics/input-manager/story-003-gsm-sync-signal-routing.md`（GSM 同步与信号传播）或 `production/epics/gsm/story-002-atomic-write-methods.md`（GSM 第二层）

## Session Extract — /story-done 2026-07-29 (Story 003)

- **Verdict**：✅ COMPLETE WITH NOTES
- **Story**：`production/epics/input-manager/story-003-gsm-sync-signal-routing.md` — GSM 同步、信号传播与输入分发
- **Changes**：
  - `src/foundation/input_manager.gd` — `_sync_to_gsm()` 替换空桩（序列化→`GameStateManager.set_input_locks()`）、`_on_tree_changed()` 连接、`_ready()` 场景树 guard、`_process()` 路径A、`_input()` 路径B
  - `src/foundation/game_state_manager.gd` — 新增 `set_input_locks()` Tier 2 原子方法（通过 `_buffer_change` 管线 + `batch_updated` 发射）
  - `tests/unit/input/test_gsm_sync.gd` — 新增 10 个测试函数（AC-001→008 + 补充测试）
  - `tests/unit/input/test_input_judgment.gd` — 3 个旧测试白名单语义修正（AC-017/AC-019/GAP-2-2：`assert_true`→`assert_false`）
  - `production/epics/input-manager/story-003-gsm-sync-signal-routing.md` — Status: Complete + Completion Notes
  - `production/sprints/sprint-1.md` — Story #8 标记 ✅ Done
- **测试结果**：84/84 通过（47 lock_stack + 27 judgment + 10 gsm_sync）
- **Tech debt logged**：None（4 项 ADVISORY 记录在 Completion Notes）
- **Next recommended**：`production/epics/input-manager/story-004-modal-override-edge-cases.md`（MODAL 覆盖与边缘情况）

## Session Extract — /dev-story 2026-07-29 (Story 004 实现)

- **Story**：`production/epics/input-manager/story-004-modal-override-edge-cases.md` — MODAL 覆盖机制与边缘情况
- **Changes**：
  - `src/foundation/input_manager.gd` — 新增 `_exit_tree()` 方法（AC-025/AC-026：断开 tree_changed 连接、清空锁栈、最终 GSM 同步）
  - `tests/unit/input/test_modal_override.gd` — 新建 9 个测试函数（AC-001→009）
  - `tests/unit/input/test_device_mask_edge_cases.gd` — 新建 5 个测试函数（AC-010→013）
  - `tests/unit/input/test_lock_leak_prevention.gd` — 新建 8 个测试函数（AC-014→017 + AC-025/026）
  - `tests/integration/input/test_modal_integration.gd` — 新建 13 个测试函数（AC-018→024 + 补充场景）
- **测试结果**：123/123 通过（84 旧 + 39 新增），719 断言，零失败
- **Next recommended**：`/code-review` 然后 `/story-done`

## Session Extract — /story-done 2026-07-29 (Story 004 关闭)

- **Verdict**：✅ COMPLETE WITH NOTES
- **Story**：`production/epics/input-manager/story-004-modal-override-edge-cases.md` — MODAL 覆盖机制与边缘情况
- **Code Review**：GDScript 专家 + QA 测试员双审查 — 4 项关键问题修复（`is_connected` 守卫、AC-010/AC-011 文本修正、同义反复断言移除、AC-025 树内测试重写）
- **Changes**：
  - `src/foundation/input_manager.gd` — 新增 `_exit_tree()` 方法（含 `is_connected()` 守卫）
  - `tests/unit/input/test_modal_override.gd` — 新建 9 个测试函数（AC-001→009）
  - `tests/unit/input/test_device_mask_edge_cases.gd` — 新建 5 个测试函数（AC-010→013）
  - `tests/unit/input/test_lock_leak_prevention.gd` — 新建 8 个测试函数（AC-014→017 + AC-025/026）
  - `tests/integration/input/test_modal_integration.gd` — 新建 13 个测试函数（AC-018→024 + 补充场景）
  - `production/epics/input-manager/story-004-modal-override-edge-cases.md` — Status: Complete + Completion Notes
- **测试结果**：123/123 通过，719 断言，零失败
- **Tech debt logged**：None（5 项 ADVISORY 记录在 Completion Notes）
- **Next recommended**：Input Manager Epic 全部 4 个 Story 完成——Sprint 1 Foundation 层输入子系统完毕

## Session Extract — /story-done 2026-07-30 (Story 004 关闭)

- **Verdict**：✅ COMPLETE WITH NOTES
- **Story**：`production/epics/scene-manager/story-004-loading-screen-async-error-recovery.md` — 加载画面 + 异步加载 + 错误恢复
- **Code Review**：LP-CODE-REVIEW NEEDS REVISION → APPROVED（B1 已修复），QL-TEST-COVERAGE GAPS（Phase 3 异步路径受 GUT 约束限制）
- **Fixes**：B1（阻塞）——优雅降级路径 `_phase3_in_progress` 标志位修复，Phase 4 守卫正确通过
- **Changes**：
  - `src/ui/loading/loading_screen.gd` — 新建 33 行：`class_name LoadingScreen extends Control` + `set_context()` 同步方法
  - `src/ui/loading/loading_screen.tscn` — 新建 14 行：全屏 Control + 黑色 ColorRect（D3D12 闪烁遮挡） + "加载中…" Label
  - `src/foundation/scene_manager.gd` — Phase 3 重构（优雅降级 + _phase3_in_progress 重排 + _inject_loading_context 提取）+ `create_fade_overlay`/`fade_out_overlay` 静态方法（422 行）
  - `tests/integration/scene_manager/test_loading_screen.gd` — 新建 21 测试，覆盖 AC-1 到 AC-8（340 行）
  - `production/epics/scene-manager/story-004-*.md` — Status: Complete + Completion Notes
  - `production/sprints/sprint-1.md` — Story #13 标记 ✅ Done
- **测试结果**：242/242 通过，1051 断言，零失败（15 脚本）
- **Tech debt logged**：None（5 项 LP SUGGESTIONS 记录在 Completion Notes）
- **Next recommended**：Scene Manager Epic ✅ 已全部完成——Foundation 层场景子系统完毕。下一个 Epic：`save-load`——Story #14 `save-load/story-001-json-engine-enums.md`（JSON 引擎 + 枚举定义，2.5h）

## Session Extract — /story-done 2026-07-30 (Story 003 关闭)

- **Verdict**：✅ COMPLETE WITH NOTES
- **Story**：`production/epics/scene-manager/story-003-autosave-input-lock-integration.md` — 转场前自动存档 + 输入锁定集成
- **Code Review**：LP-CODE-REVIEW APPROVED WITH CONCERNS — 1 MEDIUM（L300 回退返回值未检查）+ 2 LOW
- **Fixes**：MEDIUM 已修复——L300 回退 `request_scene_change` 返回值检查（`fallback_ok`）+ `push_error` 记录
- **Changes**：
  - `src/foundation/scene_manager.gd` — 新增 `_save_load` 依赖注入、`_cleanup_on_error()` 统一错误恢复、`_phase3_in_progress` 双重保底、Phase 2 push_lock + auto_save、Phase 3 两段加载 + 错误恢复（~62 行新增代码）
  - `tests/integration/scene_manager/test_input_lock_integration.gd` — 新建 10 个测试（AC-1/3/7）
  - `tests/integration/scene_manager/test_auto_save_integration.gd` — 新建 7 个测试（AC-2/8）
  - `tests/integration/scene_manager/test_error_recovery_integration.gd` — 新建 9 个测试（AC-4/5/6）
  - `production/epics/scene-manager/story-003-autosave-input-lock-integration.md` — Status: Complete + Completion Notes
  - `production/sprints/sprint-1.md` — Story #12 标记 ✅ Done
- **测试结果**：221/221 通过，1000 断言，零失败
- **Tech debt logged**：None（2 项 LOW ADVISORY 记录在 Completion Notes）
- **Next recommended**：`production/epics/scene-manager/story-004-loading-screen-async-error-recovery.md`（加载画面 + 异步加载 + 错误恢复）
