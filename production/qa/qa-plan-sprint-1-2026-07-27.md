# QA 计划：Sprint 1 — Foundation 层
**日期**：2026-07-27
**由**：/qa-plan 生成
**范围**：5 个 Foundation 系统，预计 21 个 story
**引擎**：Godot 4.6
**Sprint 文件**：production/sprints/sprint-1.md

---

## 测试摘要

| # | Story（预期） | 系统 | 类型 | 需要自动化测试 | 需要手动验证 |
|---|---------------|------|------|------------------------|------------------------------|
| 1 | GSM 三层 API 实现 | 游戏状态管理器 | 逻辑 | 单元测试 — `tests/unit/gsm/` | 无 |
| 2 | GSM 信号广播机制 | 游戏状态管理器 | 集成 | 集成测试 — `tests/integration/gsm/` | 无 |
| 3 | GSM 初始化序列 | 游戏状态管理器 | 集成 | 集成测试 — `tests/integration/gsm/` | 无 |
| 4 | GSM 战斗状态快照生命周期 | 游戏状态管理器 | 逻辑 | 单元测试 — `tests/unit/gsm/` | 无 |
| 5 | GSM 状态校验规则 | 游戏状态管理器 | 逻辑 | 单元测试 — `tests/unit/gsm/` | 无 |
| 6 | 四级输入锁栈 | 输入管理器 | 逻辑 | 单元测试 — `tests/unit/input-manager/` | 无 |
| 7 | Godot 4.6 双焦点独立判定 | 输入管理器 | 集成 | 集成测试 — `tests/integration/input-manager/` | 手动设备切换演练 |
| 8 | MODAL 强制覆盖机制 | 输入管理器 | 逻辑 | 单元测试 — `tests/unit/input-manager/` | 无 |
| 9 | 白名单语义实现 | 输入管理器 | 逻辑 | 单元测试 — `tests/unit/input-manager/` | 无 |
| 10 | 投递前查询 + GSM batch_updated 传播 | 输入管理器 | 集成 | 集成测试 — `tests/integration/input-manager/` | 无 |
| 11 | 5 阶段场景转换管线 | 场景管理器 | 集成 | 集成测试 — `tests/integration/scene-manager/` | 无 |
| 12 | TransitionType 枚举 + 音频过渡矩阵 | 场景管理器 | 逻辑 | 单元测试 — `tests/unit/scene-manager/` | 无 |
| 13 | 转场前自动存档触发 | 场景管理器 | 集成 | 集成测试 — `tests/integration/scene-manager/` | 无 |
| 14 | 场景树变更唯一调用者 | 场景管理器 | 逻辑 | 单元测试 — `tests/unit/scene-manager/` | 代码审查 grep 验证 |
| 15 | JSON 序列化/反序列化 | 存档/读档系统 | 逻辑 | 单元测试 — `tests/unit/save-load/` | 无 |
| 16 | 原子双写策略 | 存档/读档系统 | 逻辑 | 单元测试 — `tests/unit/save-load/` | Windows 平台手动验证 |
| 17 | schema_version 迁移链 | 存档/读档系统 | 逻辑 | 单元测试 — `tests/unit/save-load/` | 无 |
| 18 | 4 种存档类型管理 | 存档/读档系统 | 集成 | 集成测试 — `tests/integration/save-load/` | 无 |
| 19 | 事件模板解析器 | 事件系统 | 逻辑 | 单元测试 — `tests/unit/event-system/` | 无 |
| 20 | 条件分支评估 + 概率结果结算 | 事件系统 | 逻辑 | 单元测试 — `tests/unit/event-system/` | 无 |
| 21 | 连锁事件 + story_flags 委托写入 | 事件系统 | 集成 | 集成测试 — `tests/integration/event-system/` | 无 |

**说明**：Story 文件尚未通过 `/create-stories` 创建。以上 story 根据 Epic 概述、GDD 需求和控制清单规则推导。类型为推断的（非声明的），需在 story 创建时显式标注。

---

## 需要自动化测试

### GSM-1：三层 API 实现 — 逻辑
**测试文件路径**：`tests/unit/gsm/gsm_api_test.gd`
**参考 GDD**：`design/gdd/game-state-manager.md` §公式、§详细设计 #1-#2
**参考控制清单**：Foundation 层 — "绝不直接写 GSM 属性——始终通过第二层原子方法"、"绝不使用通用 set(path, value)——使用专用原子方法"

**测试内容**：
- **第一层读取**：get() 按路径读取，O(1) 属性直读（get_player_realm()、get_resource(type)、get_owned_cards()）
- **第二层写入**：add_cultivation(amount) 含上限校验+溢出处理；spend_resource(type, amount) 含余额校验返回 bool；add_card_to_collection(card_id) 含引用完整性校验
- **第三层订阅**：subscribe()/unsubscribe() 信号连接管理
- **allocate_card_instance_id()**：全局唯一单调递增 ID 分配
- **enable_validation(db)**：一次性调用——重复调用触发警告但不重复初始化

**需要覆盖的边界情况**：
- spend_resource() 余额不足 → 返回 false，余额不变
- add_cultivation() 溢出 → 溢出部分存入 overflow_pool
- get() 路径不存在 → 返回 null + debug 日志
- set() 路径不存在 → 拒绝写入 + 错误日志
- enable_validation() 重复调用 → 警告但不重复初始化
- 同一帧内多次写入同一路径 → 仅广播最后一次变更
- 批量修改 → 广播单个 batch_updated 而非多个逐条事件

**预估测试数量**：~20 个单元测试

---

### GSM-2：信号广播机制 — 集成
**测试文件路径**：`tests/integration/gsm/gsm_signals_test.gd`
**参考 GDD**：`design/gdd/game-state-manager.md` §详细设计 #3
**参考控制清单**：Foundation 层 — "batch_updated 信号携带展平的 {path: {old, new}} 字典"、"Cat 2 信号必须通过 _emit_signal_safe() 包装器路由"、"信号命名：snake_case 过去式"、"绝不发射携带指令的信号——信号携带事实"

**测试内容**：
- 13 个命名信号：realm_changed、cultivation_changed、cultivation_full、resource_changed、action_points_changed、deck_modified、battle_started、battle_ended、scene_changed、card_collection_changed、game_initialized、progression_reset、batch_updated
- batch_updated 载荷格式：展平的 `{path: {old, new}}` 字典
- 同帧去重：同一路径多次写入仅广播最后一次
- Cat 1 信号处理器内禁止写回 GSM（递归写入检测 + 日志警告）
- 信号载荷参数 ≤3 优先，>3 使用具名字典

**需要覆盖的边界情况**：
- 同一帧多次修改同一路径 → 仅最后一次变更广播
- 批量变更（战斗结算）→ batch_updated 携带全部变更
- 系统 B 在系统 A 的 Cat 1 回调中写入同一路径 → 检测到递归写入，允许但日志警告
- 信号 chain 深度不超过 4 → 截断 + push_error

**预估测试数量**：~10 个集成测试

---

### GSM-3：初始化序列 — 集成
**测试文件路径**：`tests/integration/gsm/gsm_init_test.gd`
**参考 GDD**：`design/gdd/game-state-manager.md` §详细设计 #5、§公式 #5
**参考控制清单**：Foundation 层 — "GSM 必须占据 Autoload #1 位置"、"启动时校验跳过模式：GSM 以 validation_enabled = false 初始化"

**测试内容**：
- _ready() 在 Autoload #1 位置——先于任何消费者读取完成
- 默认值初始化：所有字段初始化为安全的默认值
- validation_enabled = false 启动——不执行带卡牌校验的写入
- enable_validation(db) 调用后——校验开启
- card_validation_ready 信号发射

**需要覆盖的边界情况**：
- enable_validation() 被调用前 add_card_to_collection() 行为——跳过校验
- enable_validation() 被调用后 add_card_to_collection(invalid_id)——拒绝写入

**预估测试数量**：~6 个集成测试

---

### GSM-4：战斗状态快照生命周期 — 逻辑
**测试文件路径**：`tests/unit/gsm/gsm_battle_lifecycle_test.gd`
**参考 GDD**：`design/gdd/game-state-manager.md` §公式 #3

**测试内容**：
- battle_start()：初始化 battle 域 + 快照 player.realm → snapshot_realm
- battle_start() 重复调用：幂等保护——记录警告，无副作用
- battle_end(victory)：应用奖励 → battle = null
- battle_end(defeat)：无奖励 → battle = null
- battle_end(retreat)：无奖励、保留角色 → battle = null
- battle_end() 无活跃战斗调用：幂等保护——记录警告，无副作用
- 序列化时 battle 域和 session 域不包含在输出中

**需要覆盖的边界情况**：
- 战斗中存档 → battle 域不被序列化
- 读档后 battle 域为 null——战斗未发生
- battle_start() 幂等：重复调用不产生副作用

**预估测试数量**：~8 个单元测试

---

### GSM-5：状态校验规则 — 逻辑
**测试文件路径**：`tests/unit/gsm/gsm_validation_test.gd`
**参考 GDD**：`design/gdd/game-state-manager.md` §详细设计 #6

**测试内容**：
- 类型校验：String→String、int→int 匹配检查
- 范围校验：资源不可为负数、修为不超过上限、境界必须是有效枚举值
- 引用完整性：add_card_to_collection() 自动调用 validate_card_id()
- 校验失败抛出可捕获错误，拒绝写入

**需要覆盖的边界情况**：
- 写入负数资源 → 校验失败，拒绝写入
- 写入无效境界枚举 → 校验失败
- 写入无效卡牌 ID → validate_card_id() 返回 false，拒绝写入

**预估测试数量**：~6 个单元测试

---

### Input-1：四级输入锁栈 — 逻辑
**测试文件路径**：`tests/unit/input-manager/input_lock_stack_test.gd`
**参考控制清单**：Foundation 层 — "四级锁栈 (dialogue=0 < animation=1 < modal=2 < transition=3)"、"push_lock() / pop_lock() 必须配对——以 StringName 追踪来源"、"is_input_allowed(): <0.005ms/调用"

**测试内容**：
- push_lock(type, source: StringName)：添加锁到栈
- pop_lock(source: StringName)：移除匹配源的锁
- is_input_allowed()：检查当前最高级别锁是否允许给定 action_type
- 重复 push 同一源 → 记录警告
- pop 不存在的锁 → 记录警告
- 锁优先级：transition(3) 阻塞所有，dialogue(0) 仅阻塞 gameplay

**需要覆盖的边界情况**：
- 空栈 → is_input_allowed() 返回 true
- transition 锁存在 → 所有 is_input_allowed() 返回 false
- dialogue 锁存在 → is_input_allowed(any) 返回 true，is_input_allowed(gameplay) 返回 false
- push_lock → pop_lock 配对验证：遗漏 pop 在 _exit_tree() 中检测
- 性能：is_input_allowed() <0.005ms（O(n)，n≤4）

**预估测试数量**：~10 个单元测试

---

### Input-2：Godot 4.6 双焦点独立判定 — 集成
**测试文件路径**：`tests/integration/input-manager/input_dual_focus_test.gd`
**参考控制清单**：Foundation 层 — "设备类型独立判定 (MOUSE | KEYBOARD | GAMEPAD 位掩码)"、"Godot 4.6 双焦点合规"

**测试内容**：
- 鼠标焦点和键盘焦点可独立获取/失去
- 双焦点模式下锁同时影响两个焦点
- 设备类型位掩码独立判定
- 锁状态通过 GSM batch_updated 传播

**需要覆盖的边界情况**：
- 鼠标有焦点 + 键盘无焦点 → 鼠标事件正常，键盘事件阻塞
- 两者都无焦点 → 所有输入阻塞
- 设备类型切换（键盘→手柄）不影响锁状态

**预估测试数量**：~6 个集成测试

---

### Input-3：MODAL 强制覆盖机制 — 逻辑
**测试文件路径**：`tests/unit/input-manager/input_modal_override_test.gd`
**参考控制清单**：Foundation 层 — "MODAL 层在紧急情况下的强制覆盖机制"

**测试内容**：
- MODAL 锁存在时其他输入被阻塞
- MODAL 覆盖：紧急操作（如 ESC 暂停菜单）可穿透 MODAL 锁
- 覆盖不改变锁栈——仅对特定 action 临时放行

**需要覆盖的边界情况**：
- 战斗中（MODAL 锁）ESC 打开暂停菜单 → 允许
- MODAL 锁 + transition 锁同时存在 → transition 优先
- 覆盖操作完成后 → MODAL 锁恢复正常

**预估测试数量**：~5 个单元测试

---

### Input-4：白名单语义实现 — 逻辑
**测试文件路径**：`tests/unit/input-manager/input_whitelist_test.gd`
**参考控制清单**：Foundation 层 — "白名单语义（锁类型而非键位）"

**测试内容**：
- 锁定义使用语义名称而非硬编码键位
- "战斗期间锁定除 ESC 外的所有键" → 白名单包含 ESC
- 白名单解析不依赖键位映射

**需要覆盖的边界情况**：
- 白名单为空 → 所有键被锁阻塞
- 白名单包含多个语义名称 → 逐一检查
- 未知语义名称 → 记录警告，忽略

**预估测试数量**：~5 个单元测试

---

### Input-5：投递前查询 + GSM batch_updated 传播 — 集成
**测试文件路径**：`tests/integration/input-manager/input_gsm_integration_test.gd`
**参考控制清单**：Foundation 层 — "锁状态通过 GSM batch_updated 传播——无 InputManager 自有信号"、"投递前查询 GSM.session.input_locks"

**测试内容**：
- 锁变更后 GSM batch_updated 包含 input_locks 路径
- 消费者（战斗 UI、探索 UI 等）通过 batch_updated 感知锁变更
- InputManager 自身不发射锁变更信号（全部通过 GSM）

**需要覆盖的边界情况**：
- InputManager 无自有信号声明
- batch_updated 载荷中 input_locks 路径格式正确

**预估测试数量**：~4 个集成测试

---

### Scene-1：5 阶段转换管线 — 集成
**测试文件路径**：`tests/integration/scene-manager/scene_transition_pipeline_test.gd`
**参考控制清单**：Foundation 层 — "所有场景转换必须通过 SceneManager.request_scene_change()"、"5 阶段转换管线：验证 → 转场前（锁输入 + 自动存档）→ 加载（加载画面 → 目标场景）→ 加载后（GSM 更新 + 解锁）→ 收尾"

**测试内容**：
- 阶段 1 验证：目标场景路径存在性检查，无效路径返回错误
- 阶段 2 转场前：输入锁 transition = true + 触发自动存档
- 阶段 3 加载：显示加载画面 → 场景树原子替换
- 阶段 4 加载后：GSM.session.current_scene 更新 + transition 锁释放
- 阶段 5 收尾：发射 scene_changed(from, to) 信号

**需要覆盖的边界情况**：
- 目标场景不存在 → 阶段 1 失败，不进入后续阶段
- 自动存档失败 → 记录警告但继续转换（不阻塞）
- 转换中再次请求转换 → 排队或拒绝

**预估测试数量**：~8 个集成测试

---

### Scene-2：TransitionType 枚举 + 音频过渡矩阵 — 逻辑
**测试文件路径**：`tests/unit/scene-manager/scene_transition_type_test.gd`
**参考控制清单**：Foundation 层 — "TransitionType 枚举驱动音频过渡矩阵"

**测试内容**：
- 枚举值映射到过渡效果（instant、fade、slide）
- 每种 TransitionType 对应正确的音频过渡参数
- 未知/无效枚举值 → 回退到默认过渡

**需要覆盖的边界情况**：
- TransitionType 为 instant → 无过渡动画，无音频过渡
- TransitionType 为 fade → 淡入淡出 + 对应音频交叉淡化
- 枚举扩展：新增类型时有默认处理

**预估测试数量**：~5 个单元测试

---

### Scene-3：转场前自动存档触发 — 集成
**测试文件路径**：`tests/integration/scene-manager/scene_autosave_trigger_test.gd`
**参考控制清单**：Foundation 层 — "5 阶段转换管线：验证 → 转场前（锁输入 + 自动存档）"、"绝不直接调用 get_tree().change_scene_to_file()"

**测试内容**：
- request_scene_change() 触发时自动存档被调用
- 存档文件时间戳在场景切换前更新
- 自动存档失败 → 场景转换继续进行（警告但非阻塞）

**需要覆盖的边界情况**：
- 存档系统不可用时 → 跳过存档，记录警告，继续转换
- 连续快速场景切换 → 自动存档防抖生效

**预估测试数量**：~4 个集成测试

---

### Scene-4：场景树变更唯一调用者 — 逻辑
**测试文件路径**：`tests/unit/scene-manager/scene_single_caller_test.gd`
**参考控制清单**：Foundation 层 — "绝不直接调用 get_tree().change_scene_to_file()——使用 SceneManager.request_scene_change()"、"绝不在 SceneManager 之外写 GSM.session.current_scene"

**测试内容**：
- SceneManager 是唯一持有 change_scene 调用逻辑的系统
- GSM.session.current_scene 仅由 SceneManager 写入
- 代码库中无直接的 get_tree().change_scene_* 调用（grep 验证）

**需要覆盖的边界情况**：
- 绕过 SceneManager 直接调用 get_tree() → 代码审查/CI 阻断
- 在 SceneManager 之外写入 GSM.session.current_scene → 控制清单禁止

**预估测试数量**：~3 个单元测试 + grep 验证脚本

---

### Save-1：JSON 序列化/反序列化 — 逻辑
**测试文件路径**：`tests/unit/save-load/save_serialization_test.gd`
**参考 GDD**：`design/gdd/save-load-system.md` §详细设计 #3
**参考控制清单**：Foundation 层 — "使用 JSON.new().parse()——绝不使用 JSON.parse_string()"、"存档容器必须包含 'complete': true 标记"

**测试内容**：
- serialize() → 全量状态 Dictionary 输出
- deserialize(data) → 正确恢复状态
- JSON.new().parse() 区分合法 null 和解析错误
- 存档容器包含 "complete": true 标记
- schema_version 字段存在且为整数

**需要覆盖的边界情况**：
- JSON.new().parse() 返回 Error → 拒绝加载
- 合法 JSON 中字段为 null → 正确解析为 null（不被误判为错误）
- "complete": false 或无此字段 → 拒绝加载
- 序列化后反序列化 → 数据往返一致

**预估测试数量**：~8 个单元测试

---

### Save-2：原子双写策略 — 逻辑
**测试文件路径**：`tests/unit/save-load/save_atomic_write_test.gd`
**参考控制清单**：Foundation 层 — "原子写入策略：.tmp 文件 → DirAccess.rename_absolute() → .bak 备份 → 删除 .bak"、"Windows 重命名重试：最多重试 3 次 × 50ms 延迟"

**测试内容**：
- 写入流程：.tmp → rename → .bak → 删除 .bak
- rename 失败时重试：最多 3 次 × 50ms
- 写入中断后 .tmp 文件存在但无 .json → 下次写入覆盖 .tmp

**需要覆盖的边界情况**：
- rename 第一次失败 → 重试，第二次成功 → 写入完成
- rename 3 次全部失败 → 返回错误，保留 .bak
- 写入过程中崩溃 → .tmp 残留，下次读取不受影响
- DirAccess 不可用 → 优雅错误处理

**预估测试数量**：~6 个单元测试

---

### Save-3：schema_version 迁移链 — 逻辑
**测试文件路径**：`tests/unit/save-load/save_migration_test.gd`
**参考控制清单**：Foundation 层 — "存档格式必须为 JSON，以 schema_version 为唯一迁移驱动字段"、"绝不让 schema_version > CURRENT 的存档静默加载——拒绝并返回 VERSION_MISMATCH"

**测试内容**：
- schema_version = CURRENT → 直接加载
- schema_version < CURRENT → 顺序运行迁移链直到最新
- 每步迁移是纯函数：migrate_vN_to_vN_plus_1(data) → data
- 迁移失败 → 保留原始存档备份 + 记录日志

**需要覆盖的边界情况**：
- schema_version = 1, CURRENT = 3 → 运行 migrate_v1_to_v2 + migrate_v2_to_v3
- schema_version > CURRENT → 拒绝加载，返回 VERSION_MISMATCH
- 迁移中抛出异常 → 备份保留，错误记录到日志
- 缺失字段在迁移中补充默认值

**预估测试数量**：~8 个单元测试

---

### Save-4：4 种存档类型管理 — 集成
**测试文件路径**：`tests/integration/save-load/save_slot_management_test.gd`
**参考 GDD**：`design/gdd/save-load-system.md` §详细设计 #1、#2

**测试内容**：
- 自动存档：autosave 槽位，自动覆盖
- 手动存档：save_1/2/3 槽位，可命名/覆盖/删除
- 战斗前快照：pre_battle 槽位，战斗后自动清除
- 跨局元进度：progression.dat 独立文件，跨局保留
- meta.json 正确反映槽位状态

**需要覆盖的边界情况**：
- 手动存档覆盖自动存档槽位 → 允许，自动存档不再覆盖
- 删除当前局存档 → 内存状态不变
- progression.dat 不存在 → 初始化为默认值，不报错
- 新游戏 → 清空 autosave + 标记手动槽位不存在 + 不删除 progression.dat
- 战斗快照不存在时"重试"→ 按钮不可用

**预估测试数量**：~8 个集成测试

---

### Event-1：事件模板解析器 — 逻辑
**测试文件路径**：`tests/unit/event-system/event_template_parser_test.gd`
**参考 GDD**：`design/gdd/event-system.md` §详细设计 #1
**参考控制清单**：Foundation 层 — "EventTemplate 存储为 Godot Resource (.tres)——所有 @export 字段 Inspector 可编辑，禁止使用 Variant 类型"

**测试内容**：
- 6 种事件类型模板全部可解析
- EventTemplate 字段类型正确（id、type、title、description、min_realm、weight 等）
- Option 子结构正确（id、text、condition、outcomes）
- Outcome 子结构正确（type、target、value、min、max、chance）
- 禁止 Variant 类型字段——全部使用类型化 @export

**需要覆盖的边界情况**：
- 模板文件缺失 → 优雅错误而非崩溃
- 模板字段缺失 → 默认值填充 + 日志警告
- Option 数量异常（0 个或 >4 个）→ 日志警告
- 连锁事件 chain_next 指向不存在的模板 → 日志警告

**预估测试数量**：~8 个单元测试

---

### Event-2：条件分支评估 + 概率结果结算 — 逻辑
**测试文件路径**：`tests/unit/event-system/event_condition_outcome_test.gd`
**参考 GDD**：`design/gdd/event-system.md` §公式 #1-#4

**测试内容**：
- 加权随机选择：select_weighted(candidates)
- 条件判定：realm >= N、faction == X、resource >= N、card_owned
- 概率结算：resolve_chance(outcome)——chance≥1.0 必触发，chance=0.5 约 50%
- 随机值范围：resolve_value(outcome)——[min, max] 均匀分布
- 不满足条件的选项完全不可见（非灰色）

**需要覆盖的边界情况**：
- 所有选项都不满足条件 → 显示默认"谨慎行事"选项
- chance = 0.0 → 永不触发
- chance = 1.0 → 必触发
- min = max = 0 → 结果为 0（"什么都没有得到"）
- 随机结果在 [min, max] 范围内（统计验证：1000 次抽样）

**预估测试数量**：~12 个单元测试

---

### Event-3：连锁事件 + story_flags 委托写入 — 集成
**测试文件路径**：`tests/integration/event-system/event_chain_flags_test.gd`
**参考控制清单**：Foundation 层 — "story_flags 的唯一运行时写入者是 EventSystem——所有其他系统通过 EventSystem.set_flag() 委托写入"、"连锁事件：MAX_CHAIN_DEPTH = 3 + visited_ids 循环检测"、"ADD_CARD 结果使用信号委托 card_reward_requested"

**测试内容**：
- 连锁事件触发——chain_next 非空时立即弹出下一事件
- 连锁不消耗额外行动力
- MAX_CHAIN_DEPTH = 3 强制截断
- visited_ids 循环检测——防止无限循环
- set_flag() 写入 story_flags → GSM 第二层方法 set_narrative_flag()
- card_reward_requested 信号发射——EventSystem 不直接调用 CardSystem

**需要覆盖的边界情况**：
- 链深度 = 3 → 允许
- 链深度 = 4（第 4 层）→ 强制截断，返回 nothing
- chain_next 指向已访问过的事件 → visited_ids 检测，截断
- 剧情系统通过 EventSystem.set_flag() 委托写入——验证中间写入
- 对话系统 set_flag outcome → 路由到 EventSystem.set_flag()

**预估测试数量**：~8 个集成测试

---

## 手动 QA 检查清单

### Input-2：Godot 4.6 双焦点独立判定 — 集成
**验证方法**：手动逐步验证 + 截图
**必须签收人**：lead-programmer
**需要捕获的证据**：鼠标/键盘焦点分离行为的日志或视频片段

检查清单：
- [ ] 鼠标点击窗口内 → 鼠标焦点获取，键盘焦点未变化
- [ ] Tab 键切换 → 键盘焦点切换，鼠标焦点保留
- [ ] 两者都失去焦点（Alt+Tab）→ 所有输入被阻塞
- [ ] 键盘焦点在 UI 元素上时 → 鼠标仍可点击其他区域
- [ ] Godot 4.6 双焦点 API 行为与 engine-reference 文档一致

---

### Scene-4：场景树变更唯一调用者 — 逻辑
**验证方法**：代码审查（grep 扫描）
**必须签收人**：lead-programmer
**需要捕获的证据**：grep 扫描结果报告

检查清单：
- [ ] `grep -r "change_scene_to_file\|change_scene_to_packed" src/` 仅返回 SceneManager
- [ ] `grep -r "GSM.session.current_scene\s*=" src/` 仅返回 SceneManager 和测试文件

---

### Save-2：原子双写策略 — Windows 平台复现
**验证方法**：手动测试
**必须签收人**：qa-lead
**需要捕获的证据**：测试日志

检查清单：
- [ ] 写入过程中强制结束 Godot 进程 → .tmp 文件存在，下次启动不受影响
- [ ] 防病毒软件扫描时触发保存 → 重试机制生效，保存成功
- [ ] 磁盘空间不足时尝试保存 → 返回 DISK_FULL 错误，游戏不崩溃

---

## 冒烟测试范围

在 Sprint 1 的任何 QA 交接前需要验证的关键路径：

1. Godot 项目启动无崩溃——5 个 Autoload 按序初始化（#1 GSM → #2 InputManager → #3 SceneManager → #4 SaveLoadSystem → #5 EventSystem）
2. GSM 三层 API 可端到端调用——get() 读取默认状态、add_cultivation() 写入并触发信号
3. 输入锁栈可正确阻塞/释放输入——push transition 锁 → is_input_allowed() 返回 false → pop → 恢复
4. 场景可通过 SceneManager.request_scene_change() 转换——目标场景加载 + GSM.session.current_scene 更新
5. 存档可写入 user://saves/autosave/save.json 并成功读取——往返数据一致
6. 事件模板可解析——EventTemplate .tres 加载 + 条件分支判定 + 结果结算
7. 内存使用 <500MB 空闲状态（5 个 Foundation Autoload）
8. 无直接的 get_tree().change_scene_to_file() 调用——grep 扫描通过
9. 无 JSON.parse_string() 使用——grep 扫描通过

*冒烟测试由开发者通过 `/smoke-check sprint` 验证。*

---

## 试玩要求

**本次 sprint 无需试玩会期。** Foundation 层是纯基础设施层——5 个 Autoload 系统没有面向玩家的 UI。试玩验证将在 Sprint 4+（表现层——HUD、战斗 UI、探索 UI）开始引入。

---

## 完成定义 — 本次 Sprint

当以下所有条件都满足时，Sprint 1 才算完成：

- [ ] 全部 21 个 story 的验收标准已验证
- [ ] 所有逻辑和集成类 story 的测试文件存在于指定路径并通过
- [ ] 手动 QA 检查清单中 3 个项目全部完成并有证据
- [ ] 冒烟检查通过（`/smoke-check sprint`）
- [ ] `grep -r "change_scene_to_file\|change_scene_to_packed" src/` 仅返回 SceneManager
- [ ] `grep -r "JSON.parse_string" src/` 返回零结果
- [ ] 无回归问题
- [ ] 代码已审查（通过 `/code-review`）
- [ ] 所有 story 文件已更新为 `Status: Complete`（通过 `/story-done`）
- [ ] GSM _ready() 先于任何消费者在 Autoload 链中完成