## CardInstance —— 卡牌运行时实例。
##
## RefCounted 运行时可变实例，持有 [member template_id] 引用到 CardTemplate。
## 同名卡的不同实例独立——RefCounted 每次 [method new()] 分配独立对象，
## 字段互不影响（AC-007 关键行为断言）。
##
## [b]template_id 而非 Resource 引用[/b]（ADR-0006 L160）：
## 实例持有 StringName 引用，通过 [code]CardSystem.get_template(inst.template_id)[/code]
## 查询模板。避免两层引用耦合——Instance 可在未加载模板时被序列化/反序列化。
##
## [b]card_instance_id 由 GSM 分配[/b]（ADR-0006 L158）：
## 本 Story 仅定义字段+默认值 0（未分配状态）。Story 004 的
## [code]CardSystem.create_instance()[/code] 调用 [code]GSM.allocate_card_id()[/code]
## 填充全局唯一 ID。分配后不可更改。
##
## 字段无 @export——CardInstance 是运行时实例，非 Inspector 编辑的 .tres。
class_name CardInstance
extends RefCounted

# === 实例标识 =====================================================================

## 全局唯一实例 ID——由 GSM 单调递增分配。
## 默认 0 表示未分配状态（Story 004 create_instance 填充）。
var card_instance_id: int = 0

## 指向 CardTemplate.card_id——非 Resource 引用（ADR-0006 L160）。
## 通过 CardSystem.get_template(inst.template_id) 查询模板。
## 默认 &"" 表示未关联模板。
var template_id: StringName = &""

# === 成长状态 =====================================================================

## 等级——独立于同模板的其他实例。默认 1。
var level: int = 1

## 铭刻副属性列表——0-3 条铭刻。
## 强类型 Array[Dictionary]（qa-lead 提示——避免裸 Array）。
## 元素结构由 InscriptionSystem Epic（ADR-0030）定义，本 Story 仅声明容器。
var inscriptions: Array[Dictionary] = []

## 突破层数——0-3 层突破。默认 0。
var breakthrough_layers: int = 0

# === 绑定状态 =====================================================================

## 绑定的角色 instance_id——功法/法宝卡专属。
## 默认 &"" 表示未绑定。
var binding_target_id: StringName = &""

# === 获得来源追踪 =================================================================

## 获得时的章节编号——实现支柱 3「机缘巧合，意外之喜」。
## 默认 0 表示未追踪。
var acquired_chapter: int = 0

## 获得时的事件 ID——追踪具体获得来源事件。
## 默认 &"" 表示未追踪。
var acquired_event_id: StringName = &""

## 获得方式——AcquiredMethod 枚举值。
## 默认 0 = AcquiredMethod.DROP（见 acquired_method.gd，ADR-0006 L155 默认值 0 一致）。
## 使用字面量 0 而非 AcquiredMethod.DROP 引用——避免 CardInstance 类定义时
## 依赖全局 class_name 注册时序（GUT headless 单文件模式下不可靠）。
## 测试通过 assert_eq(inst.acquired_method, AcquiredMethod.DROP) 验证语义等价。
var acquired_method: int = 0
