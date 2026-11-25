extends Node
## ProgressionSystem 声明面（继承链首段）——[b]6 信号 / 14 实例字段 / 1 常量表 / 0 方法[/b]。
##
## [b]本层职责[/b]：整条链的[b]共享声明[/b]。[br]
##   · [b]6 条信号[/b]——[signal progression_initialized]（第 2 段 [method _ready] 发射）与
##     [signal progression_updated]（第 2 段 [method _mark_dirty_and_emit] 与第 3 段
##     [method batch_update_end] 都发）随本段落链首；两条成长域信号
##     [signal achievement_unlocked] / [signal talent_purchased] 归第 3 段，
##     [signal ending_unlocked_signal] / [signal card_discovered] 归链尾。[br]
##     [b]为什么信号不跟着发射方走[/b]：基段声明的信号可在派生段 [code]emit[/code]，
##     反过来（派生段声明、基段发射）解析期即失败——[signal progression_updated] 有两个
##     发射方（第 2 段与第 3 段），只能落链首。[br]
##   · [b]6 个域存储[/b]——achievements / talents / card_gallery / endings / statistics /
##     meta 六张运行期字典，是[b]按名访问的公开面[/b]：子模块
##     [code]progression_serializer.gd[/code] 用 [code]_parent.set("_achievements", …)[/code]
##     逐个写入，[code]tests/integration/identity_selection_system/test_identity_start_flow.gd[/code]
##     用 [code]ProgressionSystem.get("_talent_defs")[/code] 读出——字段名逐字不动。[br]
##   · [b]4 个内部标志[/b]——[_dirty] / [_batch_depth] / [_batch_pending_domains] /
##     [_initialized_and_loaded]，被第 2/3 段读写（单元测试亦直接读 [_batch_depth]）。[br]
##   · [b]2 张定义注册表 + 2 个句柄[/b]——[_achievement_defs] / [_talent_defs] 由外部系统
##     在运行时注册；[_serializer] 是惰性子模块句柄；[_save_load_override] 是有意敞开的
##     测试注入口（替身 SaveLoad 优先于 Autoload #4）。[br]
##   · [b]1 张常量表[/b]——[constant _META_KEYS]，[method set_meta_value] 的唯一准入白名单。
## [b]本层不含任何方法[/b]：链序由「被调方必须在本段或祖先段」定死（说明见链尾段文档），
## 全部方法按职责落在后三段——故本段天然没有「祖先调后代」的风险。
##
## 来源: ADR-0012 §决策（域存储声明 + 关键接口 + 初始化策略）、
## .claude/docs/coding-standards.md §文件行数限制（300 行软上限）。

# === 域存储（运行时，内存中）=================================================

## 成就域——Dict[String → Dictionary]。
var _achievements: Dictionary = {}
## 天赋域——Dict[String → Dictionary]。
var _talents: Dictionary = {}
## 卡牌图鉴域——Dict[String → bool]。
var _card_gallery: Dictionary = {}
## 结局域——Dict[String → Dictionary]。
var _endings: Dictionary = {}
## 统计域——Dict[String → int]。
var _stats: Dictionary = {}
## 元信息域——Dict[String → Variant]。
var _meta: Dictionary = {}


# === 内部标志 =================================================================

## 自上次保存后是否有变更。
var _dirty: bool = false
## 批量更新嵌套计数器——>0 时暂缓 progression_updated 信号。
var _batch_depth: int = 0
## 批量更新期间累积的变更域集合——batch_update_end 时一次性发射。
var _batch_pending_domains: Dictionary = {}
## 初始化完成标志——特征系统查询前检查此标志。
var _initialized_and_loaded: bool = false


## 序列化子模块——惰性初始化（Sprint 9 Story 6 拆分）。
var _serializer: RefCounted = null


## 成就定义注册表——由 AchievementSystem 在运行时注册。
var _achievement_defs: Dictionary = {}

## 天赋定义注册表——由 ReincarnationTalentSystem 初始化时调用。
var _talent_defs: Dictionary = {}


# === meta 领域 API ===========================================================

## 可写入的 meta key 白名单。
const _META_KEYS: Array = [
	"highest_realm_ever",
	"total_reincarnations",
	"total_playtime_seconds",
	"total_completions",
]


## SaveLoadSystem 引用——测试注入优先。
var _save_load_override: Node = null
