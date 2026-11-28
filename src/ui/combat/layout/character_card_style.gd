extends RefCounted
## CharacterCardStyle —— 角色状态卡的视觉规格（常量唯一来源，纯数据）。[br]
## [br][b]为什么单独成文件[/b]：[code]character_status_card.gd[/code] 越过单文件
## 300 行软上限（coding-standards），而六层绘制用到的尺寸/配色占了其中一大块；
## 「长什么样」与「什么时候变」是两件事——改配色不必翻状态更新逻辑。[br]
## [br][b]数据驱动[/b]（R-02 §2）：取值来自 UX 规格表与 GDD 调优参数表，
## 绘制侧只引用不内联。[br]
## [br]来源: ADR-0031、design/ux/combat-ui.md §角色状态卡、
## production/qa/evidence/r02-batching-spec.md、combat-ui-layout Story 002/003。

## === 卡牌尺寸（UX Layout Zones：120×168 前排基准）=========================

const CARD_WIDTH: float = 120.0
const CARD_HEIGHT: float = 168.0
## L2 侧栏宽（px）。
const SIDE_BAR_WIDTH: float = 28.0
## L2 图标尺寸（20×20px，间距 4px——UX 规格表）。
const ICON_SIZE: float = 20.0
const ICON_GAP: float = 4.0
## L2 图标每侧上限（UX：功法/法宝各最多 3）。
const SIDE_ICON_LIMIT: int = 3
## L3 底部条高（px）。
const BOTTOM_BAR_HEIGHT: float = 40.0
## L4 buff 图标上限（UX：最多 3-5——取 5 上限）。
const BUFF_LIMIT: int = 5
## L4/L5 角标尺寸（R-02 corner_badge 20×20）。
const BADGE_SIZE: float = 20.0

## L3 底部条内的几何：HP 条相对条顶的下移量 / 条高 / 文字基线偏移。
const HP_TRACK_TOP: float = 6.0
const HP_TRACK_HEIGHT: float = 8.0
const STAT_LABEL_BASELINE: float = 22.0
## 文字 Label 高度（R-02 §3 单 Label 合并——名与数值共用同一行高）。
const LABEL_HEIGHT: float = 18.0
## L5 名牌位置：移到 HP 条正上方——放顶部会压住立绘的头（120×168 的卡上
## 头顶只留得下 26px，人脸正好在那条带上）。
const NAME_LABEL_TOP: float = 106.0
## L4 角标外边距/间距（R-02 corner_badge）。
const BADGE_INSET: float = 2.0
const BADGE_GAP: float = 2.0
const BADGE_BOTTOM_INSET: float = 4.0
## L2 图标区相对卡左上角的起点偏移（含背板外扩）。
const ICON_ORIGIN: float = 4.0
## L2 图标区相对卡顶的下移量（名牌已移到底部，图标回到贴近顶边）。
const ICON_SLOT_TOP: float = 8.0
const ICON_BACKING_INSET: float = 4.0

## 基准字号（pt——经 [code]CombatUiFont.font_size_responsive[/code] 分档）。
const BASE_FONT_SIZE: int = 14

## === 视觉配色（集中定义——R-02 数据驱动条款）==============================

## 前排边框色（金色实线）。
const FRONT_BORDER_COLOR: Color = Color(0.91, 0.76, 0.35)
## 后排边框色（蓝色虚线）。
const BACK_BORDER_COLOR: Color = Color(0.45, 0.62, 0.85)
## 边框线宽。
const BORDER_WIDTH: float = 2.0
## 虚线段长/间隔（后排虚线边框）。
const DASH_LENGTH: float = 6.0
## L3 底部条不透明背板色。
const BOTTOM_BAR_BG: Color = Color(0.06, 0.06, 0.09, 0.92)
## HP 条底槽色。
const HP_TRACK_COLOR: Color = Color(0.16, 0.16, 0.20, 0.9)
## ATK 数字色（暖白——对比度 ≥4.5:1 on 遮罩）。
const ATK_COLOR: Color = Color(0.96, 0.94, 0.88)
## 头像缺失时的占位块色（stub 阶段头像未入库）。
const PORTRAIT_PLACEHOLDER: Color = Color(0.18, 0.20, 0.24)
## 名牌底衬色（半透明深色横条——立绘上放浅色字要垫一层）。
const NAME_PLATE_COLOR: Color = Color(0.05, 0.05, 0.08, 0.55)

## 空槽描边（L2 侧栏在 0 件时仍要露出「功法 / 法宝栏」——老板 2026-11-28 反馈
## 「角色卡还有法宝栏和功法栏，怎么没看到」：只有计数 > 0 才画，看着就像没有这两栏）。
const EMPTY_SLOT_COLOR: Color = Color(0.42, 0.46, 0.55, 0.55)

## 侧栏最少画几格（计数为 0 时画空槽，让玩家知道这两栏存在）。
const SIDE_MIN_SLOTS: int = 2
## 已行动遮罩色（story 003 AC-2——GDD「已行动角色：灰色遮罩」）。
const ACTED_OVERLAY_COLOR: Color = Color(0.5, 0.5, 0.52, 0.5)

## === 动画时长（GDD 公式 3 调优旋钮）=======================================

## HP 条平滑过渡时长（0.3s 线性——GDD 调优表 0.2~0.5 默认 0.3）。
const HP_TWEEN_SEC: float = 0.3
## 沙漏标记淡出时长（GDD 动画表 L611 前半句——待命→已就绪 0.3s；
## 文字通道推迟见 DEBT-CUI-003，角标部分归本 story）。
const BADGE_FADE_SEC: float = 0.3
