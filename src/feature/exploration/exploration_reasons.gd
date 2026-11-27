extends RefCounted
## ExplorationReasons —— [b]移动判定拒绝原因词表[/b]（字符串常量唯一出处）。[br]
##
## [b]为什么单独一份[/b]：[code]exploration_system_ops.gd[/code] 抵到单文件 300 行
## 软上限（.claude/docs/coding-standards.md）。词表是「系统说得出」与「UI 认得」之间
## 的[b]跨层契约[/b]——它既不读状态也不调方法，与同层的查询/命令没有交集，是这一层里
## 最适合整体搬走的一块。[br]
##
## [br][b]访问方式不变[/b]：系统侧用 [code]const REASON_*: String = Reasons.REASON_*[/code]
## 逐条转发，[code]ES_SCRIPT.REASON_AP_SHORT[/code] 在继承链上照旧解析；测试与 UI 的
## 读法一个字没改。[br]
##
## [br][b]为什么提成常量[/b]：[method ExplorationSystem.can_move_to_detail]（判定）与
## [method ExplorationSystem.move_to_node]（命令）说的是同一件事，而 UI 的
## [code]NodeMoveInteractor.REASON_TEXTS[/code] 拿这些字符串当查表的键——字面量散在
## 三处时，改一处文案就会让 UI 悄悄落进兜底提示（玩家看到「无法移动」而不是
## 「行动力不足」）。常量集中后，「系统说得出」与「UI 认得」是同一份词表。[br]
##
## [br][b]UI 侧另有一份字面量副本[/b]（[code]NodeStateLogic.REASON_*[/code]——
## headless 下不加载 Feature 层），由单测锁定两者同源（同
## [code]AP_EXEMPT_TYPES[/code] 的处置）。[br]
##
## [br][b]★ 本轮起产出面收窄（词表本身一条没删）★[/b]：老板 2026-11-27 18:40
## 「每个节点之间都可达，只是消耗的行动力不一样」+「已访问节点可以重入」之后，
## [constant VISITED] 与旧的「不可达=图里没有这条边」都不再由移动判定产出；
## [constant UNREACHABLE] 的含义收窄为[b]目标节点根本不在本图[/b]。
## 常量仍是契约的一部分（旧存档的 toast 记录、UI 分类器的词表都要它），见
## [method ExplorationSystem.can_move_to_detail] 的注记。[br]
##
## 来源: ADR-0014 §关键接口、GDD action-point-system.md §公式 2/3、
## 本轮任务书第 3 条。


## DAG 缓存未就绪（读档重建前的窗口）——守卫态，不是「不可达」。
const NOT_READY: String = "DAG 缓存未就绪"
## 不可达——[b]本轮起唯一含义是「目标节点不在本图」[/b]（越界 ID / 存档脏数据）。
const UNREACHABLE: String = "不可达"
## GSM 不可用（Autoload 缺失——测试直调场景）。
const NO_GSM: String = "GSM 不可用"
## 已访问——[b]本轮起不再由移动判定产出[/b]（可重入），保留为跨层契约常量。
const VISITED: String = "已访问"
## 行动力不足——移动判定里唯二的资源类拒绝理由。
const AP_SHORT: String = "行动力不足"
