extends RefCounted
## NodeGraphStyleIcon —— 节点图[b]类型图标[/b]的视觉规格（常量，纯数据）。[br]
##
## [b]为什么从 [code]node_graph_style.gd[/code] 拆出来[/b]：那份总表已贴 300 行软上限
## （coding-standards），而本轮图标从「图集 glyph 方片」换成「圆形水墨印章」要加四个
## 常量。拆的判据是[b]内聚[/b]：下面这四个数只被「画一个类型图标」的那一处读
## （[code]node_graph_node_painter.gd[/code] 的 [code]draw_type_icon[/code] /
## [code]blit_type_icon[/code]），与尺寸、连线、迷雾都不相交。[br]
##
## [br][b]仍然只有一个对外名字[/b]：[code]node_graph_style.gd[/code] 把本模块的常量
## 逐条转出（[code]const ICON_ALPHA = IconStyle.ICON_ALPHA[/code]），调用方照旧写
## [code]Style.ICON_ALPHA[/code]——拆分不改任何引用点。[br]
##
## [br]来源: 本轮任务书任务二（节点配图标——尺寸随节点缩放、印章化处理、六态可读）、
## design/gdd/exploration-ui-system.md §2、ADR-0031 §5。

## 图标显示边长相对节点边长（倍）。[br]
## [br][b]为什么不是 1.0[/b]：图标是[b]圆形裁切[/b]的水墨线稿（见
## [code]node_icon_art.gd[/code] 的印章说明），圆的内接正方形只有外框的 √2/2 ≈ 0.707；
## 取 0.82 让圆盘略大于「内接」而仍留在节点方框内——远看是「一块石台上嵌着一枚圆徽」。[br]
## [br][b]随节点尺寸缩放[/b]：本值是[b]倍率[/b]不是绝对像素，悬停放大（
## [constant NodeGraphStyleIcon.ICON_EDGE_RATIO] 的宿主常量
## [code]NodeGraphStyle.HOVER_SCALE_RATIO[/code]）时图标跟着节点一起长，不出现
## 「框大了图没大」。
const ICON_EDGE_RATIO: float = 0.82
## 图标圆盘的底衬色（深色圆盘——压住地图插画的花纹，让线稿有对比）。[br]
## [br][b]为什么必须有一块底[/b]：水墨线稿是[b]黑线[/b]，直接压在地图插画上时，
## 插画暗部与线稿糊成一片（本轮取证图里节点图标曾经读不出来）。圆盘把线稿托在
## 一个稳定的深底上，与「石台嵌徽」的观感也一致。[br]
## [br][b]为什么比地形暗而不是纯黑[/b]：纯黑圆盘会在暖色插画上割出一圈生硬的黑边；
## 暖深灰与 [code]NodeGraphStyleFog.FOG_COLOR[/code] 同族，边缘自然。
const ICON_DISC_COLOR: Color = Color(0.09, 0.085, 0.07, 0.88)
## 图标圆盘相对图标边长的放大倍率（圆盘比图标本身略大一圈，线稿不顶到圆边）。
const ICON_DISC_SCALE: float = 1.12
## 图标本体的不透明度——线稿在黑线之外还有一层淡墨灰，压一档让它更像「印在盘上的
## 印记」而不是贴上去的贴纸。0.85~0.95 是任务书给的区间，取上限附近保清晰度。
const ICON_ALPHA: float = 0.92
