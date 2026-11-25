# ADR-0032：天劫 Boss 名册 — 四档雷灵模板与数值来源

## 状态
Accepted（2026-11-25——补齐 DEBT-TRB-001 的战方名册缺链。）

## 日期
2026-11-25

## 引擎兼容性

| 字段 | 值 |
|-------|-------|
| **引擎** | Godot 4.6 |
| **领域** | Feature / Progression / 数据 |
| **知识风险** | LOW（只用 `Resource` / `load()` / `DirAccess` 等 4.0+ 稳定 API） |
| **查阅的参考** | `docs/engine-reference/godot/VERSION.md` |
| **使用的截止后 API** | None |
| **需要验证** | `AISystem.load_templates` 的目录扫描为**非递归**（已实测：顶层 4 份 .tres 进表，`tribulation/` 子目录 4 份均不进） |

## ADR 依赖关系

| 字段 | 值 |
|-------|-------|
| **依赖** | ADR-0017（`EnemyTemplate` / `EnemyBattleState` 模板-实例分离、`create_state` 纯映射）、ADR-0021（`get_tribulation_boss_config` 的字段契约）、ADR-0008（`battle_start(config.enemy_roster)` 消费口径） |
| **启用** | 渡劫突破 Epic——渡劫战从「打一场判不出胜负的空场」变为可结算 |
| **阻塞** | DEBT-TRB-001（渡劫战敌方名册整段缺链） |

## 上下文

渡劫开战时 `config["enemy_roster"]` 恒为 `[]`：`TribulationSystem.get_tribulation_boss_config()` 只回 `{realm, hp, atk}`，没有任何调用点把它翻成名册；`assets/enemies/` 下只有四份普通敌人模板，没有天劫 Boss 可点。`CombatEndCheck._all_enemies_dead` 对空名册返回 `false`——判据本身是对的（「信息不足则不判」），是数据没给：把敌人打光也判不出胜负。

## 决策

**为四个渡劫档各建一份雷灵模板，由一张显式表把「Boss 境界」映射到模板。**

### 1. 四档怎么分

| 文件（`assets/enemies/tribulation/`） | template_id | realm | base_hp | base_attack | base_defense |
|---|---|---|---|---|---|
| `lianqi_leiling.tres` | `tribulation_leiling_lianqi` | 1 | 45 | 14 | 0 |
| `zhuji_leiling.tres` | `tribulation_leiling_zhuji` | 2 | 57 | 17 | 3 |
| `jindan_leiling.tres` | `tribulation_leiling_jindan` | 3 | 86 | 26 | 5 |
| `yuanying_leiling.tres` | `tribulation_leiling_yuanying` | 4 | 129 | 39 | 8 |

键为 **Boss 境界**（不是玩家境界）：常规渡劫取玩家境界那一档，越阶取 +1 那一档（GDD §3 的 Boss境界 列 + §6「天劫Boss = 当前境界+1 的雷灵」）。映射表在 `src/feature/tribulation/tribulation_boss_roster.gd`，路径只写一次。

### 2. 数值来源——没有 GDD 依据

**GDD §3 只列了雷灵的特殊机制（雷伤叠加、范围攻击、护盾、召唤），没有给基础属性表。** §3 的原话是「雷灵的基础战斗属性与同境界普通 Boss 相同」——但工程内**没有任何同境界普通 Boss 模板**可参照（`assets/enemies/` 只有散修/鬼修/魔修/妖兽四份普通敌人）。

故四份模板按 **「比同档精英高约 1.5 倍」** 取值，以工程内真实存在的基线锚定：基准取 `gui_xiu`（鬼修，realm 2，hp 38 / atk 11 / def 2，现存最强的一份），炼气档 ≈ 鬼修 × 1.2，其后每档 HP / ATK / DEF 各 × 1.5 取整。交叉校验：炼气角色卡 `lin_yuan` 是 hp 10 / atk 2——雷灵 45 HP 意味着数回合集火，与 §3「雷伤才是难度增量……迫使玩家找到足够快的击杀速度」同向。

**这不是从 GDD 推导出来的数值，是开工时的占位基线。** 平衡调优期以实测回合数为准重取。

### 3. 为什么不过难度曲线

**档位轴**的输入是 `地图境界档 − 玩家境界`，而渡劫**没有地图**——`CombatSceneBattleSetup._resolve_roster` 在无探索上下文时正是传 `map_realm = 0`（未定档 → 系数 1.0）。

**追赶轴**的公式是 `1 + (玩家境界 − 模板境界) × 0.3`，而雷灵模板的境界与它要打的那一劫一一对应（第 L 档 = 境界 L），gap 恒为 0、系数恒 1.0。**即便调用也是 1.0**，故 `TribulationBossRoster.build` 直接不调。

> 将来若要按玩家练度缩放天劫，改动点是 `difficulty_curve.gd` 加一条**新的轴**，而不是在渡劫域另写一组系数——全库唯一系数来源这条约束不因本 ADR 放宽。

### 4. 四档缺失时怎么退化

`tier_of()` 把 Boss 境界**夹到 1~4**。唯一现实触发路径是**化神前的越阶渡劫**：元婴期（realm 4）越阶 → Boss 境界 5，而 §3 只给了四档雷灵（化神是最高境界，没有第五只）。夹取后这一场按**元婴雷灵**打，越阶的额外金卡仍按 `is_cross_realm` 保留。

**为什么不返回空名册**：空名册 → `_all_enemies_dead` 返回 false → 战斗永远打不完（正是 DEBT-TRB-001 的形态）。宁可退到邻档，也不给一场判不出胜负的仗。模板**资产缺失**（路径写错/文件被删）时 `template_for()` 返回 `null` 并 `push_error`——那是构建事故，如实报错比悄悄退档更可诊断。

### 5. 为什么不进 AISystem 的共享注册表

`load_templates()` 只扫 `assets/enemies/` 顶层（非递归，已实测）。雷灵刻意放子目录：注册表是「探索/遭遇战能点到的敌人」的全集，进了表，任何一张地图配置写错一个 id 就能把天劫雷灵刷进普通遭遇。运行时状态改由 `AISystem.create_state(template)` 现建（纯映射，不查注册表），阵位与预配置绑定两步在 `build()` 里单独补上。

## 替代方案

| 方案 | 为什么没选 |
|---|---|
| 在 `get_tribulation_boss_config()` 里写死 hp/atk 再乘系数 | 数值散在代码里，与「游戏数值必须数据驱动」（`src/CLAUDE.md`）冲突；且无法在 Inspector 里调 |
| 复用现有四份普通敌人模板当 Boss | 名册非空了，但 Boss 战变成「打一只散修」——§3 的天劫 Boss 有独立身份 |
| 把雷灵放进 `assets/enemies/` 顶层共享注册表 | 地图配置能把天劫雷灵刷进普通遭遇（见决策 §5） |
| 每档给多只雷灵（元婴劫的雷球） | 雷球是**战斗内召唤**（§3「初始 0 个，Boss 第 2 回合末召唤」），不在开战名册里 |

## 后果

- **正向**：渡劫战从「打不完的空场」变为可结算——打光雷灵即 `VICTORY` → 境界 +1 且修为不扣。数值改在 `.tres` 里调，加第五档只需一份模板 + 表里一行。
- **代价**：四份模板的数值是**无 GDD 依据的占位基线**，平衡调优期须以实测回合数重取。
- **未覆盖（范围边界）**：§3 给雷灵列的特殊机制（每回合叠雷伤、范围攻击、护盾、召唤雷球）本次**未实现**——本 ADR 只解决「名册非空」。名册里的雷灵目前只有普通攻击与「落雷」（单体 1.3×）；叠雷伤仍由 `TribulationSystem.calculate_lightning_damage` 的纯函数单独提供。补齐机制另立任务。
- **未覆盖**：元婴劫的雷球小怪；四份模板的 `phase_transitions` 均为空（阶段转换机制对它们不生效）。

## 相关制品

- `src/feature/tribulation/tribulation_boss_roster.gd` — 映射表 + 名册组装
- `src/feature/tribulation/tribulation_settlement.gd §get_tribulation_boss_config` — 返回 `enemy_roster` 的调用点
- `src/feature/tribulation/tribulation_combat.gd §build_tribulation_config` — 名册进战斗配置的路径
- `tests/integration/tribulation/test_tribulation_roster_arming.gd` — 名册配装守卫
- `design/gdd/tribulation-system.md §3 天劫Boss 雷灵 / §6 越阶渡劫`
