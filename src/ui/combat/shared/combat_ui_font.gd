class_name CombatUiFont
extends RefCounted
## CombatUiFont —— combat-ui 共享纯函数模块（combat-ui-layout Story 001）。
##
## [b]职责[/b]：表现层共享纯函数的唯一落地处——本 epic 后续 story
## （002 角色卡 / 004 顶部条 / 005 费用栏 / 006 手牌）消费，
## **不得各自内联实现**（story 001 实现说明强制条款）。[br]
## [br][b]纯函数[/b]（ADR-0031 Logic 内核模式）：无状态、无副作用、
## 输入 → 输出确定映射——单元测试零依赖。[br]
## [br][b]字号响应式[/b]（UX `design/ux/combat-ui.md` + control-manifest
## 「分辨率基准 1920×1080，不支持 1280×720 以下」）：
## ≥1080 原值 / ≥720 ×0.85 / <720 保底 12pt。
##
## @experimental
## 来源: ADR-0031、design/ux/combat-ui.md、combat-ui-layout Story 001（AC-8）。

## 缩放档位阈值（px——屏幕高度）。
const TIER_FULL_HEIGHT: int = 1080
const TIER_SCALED_HEIGHT: int = 720
## 720-1079 缩放系数（85%）。
const TIER_SCALED_RATIO: float = 0.85
## 保底字号（pt）——小于 720 分辨率不做更小缩放（可读性下限）。
const MIN_FONT_SIZE: int = 12


## 字号响应式计算——按屏幕高度分档缩放。[br]
## [br][b]档位[/b]（UX 规范）：[br]
##   - 屏幕高度 ≥1080 → 原值（基准分辨率）[br]
##   - 720 ≤ 高度 <1080 → 原值 × 0.85（结果过 12pt 保底——QA 规格
##     base=14@720 → max(11.9, 12) = 12「保底截断」）[br]
##   - 高度 <720 → 保底 12pt（不支持 720 以下，防御性保底）[br]
## [br][param base_font_size]: 基准字号（pt，1920×1080 设计值）。[br]
## [param screen_height]: 屏幕高度（px）。[br]
## [b]返回[/b]: 响应式字号 [code]int[/code]——四舍五入取整
## （Godot font_size 为 int），缩放档结果向上保底 12pt。
static func font_size_responsive(base_font_size: int, screen_height: int) -> int:
	if screen_height >= TIER_FULL_HEIGHT:
		return base_font_size
	if screen_height < TIER_SCALED_HEIGHT:
		return MIN_FONT_SIZE
	return maxi(int(round(float(base_font_size) * TIER_SCALED_RATIO)), MIN_FONT_SIZE)
