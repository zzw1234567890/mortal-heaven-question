# 资产规范 — 符箓卡符纸墨迹图

> **来源**：design/gdd/card-system-design.md 第七部分
> **美术圣经**：design/art/art-bible.md §5.X.6
> **生成日期**：2026-07-26
> **审查模式**：Solo（art-director + technical-artist 代理因 API 503 不可用）
> **状态**：30 个资产已规范 / 0 个已批准 / 0 个生产中 / 0 个完成

## 技术参数

| 参数 | 值 |
|------|-----|
| 规格 | 200×280px |
| 工作分辨率 | 600×840px（3倍缩放） |
| 格式 | PSD 源文件 + PNG 导出 |
| 图层要求 | (1) 符纸基底层（暖灰纹理） (2) 符文朱砂红墨迹层 (3) 边缘晕染层 (4) 卷曲褶皱纹理层 |
| Godot 导入预设 | 2D Texture, Filter=Disabled, Mipmaps=Off, Compress=Lossless |
| 单张预估 | ~120KB RGBA8 → ~30KB DXT5 |
| 总计预估 | 30 张 × 30KB = ~900KB VRAM |

## 符文风格速查

| 符文类型 | 线条风格 | 构图特征 | 数量 |
|----------|----------|----------|:--:|
| 攻击符 | 尖锐、放射状、爆发感 | 中央爆发点向外辐射 | 8 |
| 防御符 | 圆润、围合状、守护感 | 同心环绕结构 | 6 |
| 功能符 | 蜿蜒、流动状、变化感 | S 形或波浪线为主 | 8 |
| 高阶符 | 复杂、多层级、威压感 | 嵌套符文层级结构 | 5 |
| 特殊符 | 综合特征 | 根据具体效果定制 | 3 |

---

## 攻击符（尖锐放射状）

### ASSET-134 — 烈火符

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 符箓符文图 |
| 尺寸 | 200×280px (LOD-1) / 600×840px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `talisman_liehuo_fu.png` |
| 卡牌数据 | 稀有度=白色 费用=1 效果=对单体造成3点伤害 |

**视觉描述：**
暖灰符纸满幅，四角微卷。中央朱砂红符文呈火焰形——三条主笔从中心向上方喷涌，起笔浓、收笔带飞白如火焰舔舐。符文外圈有三层同心扩散纹——如热浪。符纸边缘有轻微的焦痕（淡墨皴擦）。符纸右下方有微小的「火」字篆书朱印。

**美术圣经锚点：**
- §5.X.6 符纸墨迹构图：符纸满幅，符文居中
- §5.X.6 符文风格：攻击符=放射状爆发感
- §4 语义色：朱砂红=法术封印（攻击）

**生成提示 (Midjourney)：**
Chinese ink brush talisman on warm-gray aged paper — vermillion-red flame-shaped rune with 3 main strokes bursting upward, thick-to-thin flying-white brush texture, 3 concentric heat-wave rings around rune, slight scorched edges in dry ink, tiny seal-script "火" stamp at bottom right, paper corners slightly curled, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no person, no color except warm gray paper and vermillion red

**反向提示 (Stable Diffusion)：**
person, character, landscape, background, colorful, 3D, photorealistic, blue, green, clean paper

**状态：** Needed

---

### ASSET-135 — 五雷符

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 符箓符文图 |
| 尺寸 | 200×280px (LOD-1) / 600×840px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `talisman_wulei_fu.png` |
| 卡牌数据 | 稀有度=蓝色 费用=2 效果=对敌方全体造成2点伤害 |

**视觉描述：**
暖灰符纸满幅。中央朱砂红符文由五条锯齿闪电线组成——五雷从中心向五个方向劈出。闪电线的每个折角处有微小的朱砂红溅点——如电火花。符文外圈有云气纹——暗示雷从云中来。符纸边缘有静电般的细密飞白。符纸右下有「雷」字朱印。

**美术圣经锚点：**
- §5.X.6 符文风格：攻击符=放射状
- §5.X.6 构图：符文居中
- §4 语义色：朱砂红=雷电封印

**生成提示 (Midjourney)：**
Chinese ink brush talisman on warm-gray aged paper — vermillion-red 5-zigzag lightning rune striking in 5 directions, tiny red splash dots at each zigzag corner, cloud-qi rings around rune, static-electricity fine flying-white at paper edges, "雷" seal stamp, curled corners, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except warm gray paper and vermillion red

**反向提示 (Stable Diffusion)：**
person, landscape, background, colorful, 3D, photorealistic, smooth

**状态：** Needed

---

### ASSET-136 — 引雷符

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 符箓符文图 |
| 尺寸 | 200×280px (LOD-1) / 600×840px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `talisman_yinlei_fu.png` |
| 卡牌数据 | 稀有度=蓝色 费用=1 效果=对单体造成4点伤害 |

**视觉描述：**
暖灰符纸。中央朱砂红符文为一竖一折的简洁闪电形——从符纸上方直劈而下，折角尖锐。起笔处（上方）极浓——如天雷灌顶；收笔处（下方）飞白散开——如雷击地面后的电弧。符纸上半部有密集的朱砂红小点——如雨滴。整体传递「引导天雷」的意象。

**美术圣经锚点：**
- §5.X.6 符文风格：攻击符=尖锐
- §5.X.6 构图：自上而下
- §4 语义色：朱砂红=天雷

**生成提示 (Midjourney)：**
Chinese ink brush talisman on warm-gray aged paper — single vermillion-red vertical-then-zigzag lightning stroke from top to bottom, extremely dense at top, flying-white scatter at bottom like ground arc, dense red micro-dots in upper half like rain, "引" seal stamp, curled corners, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except warm gray and vermillion

**反向提示 (Stable Diffusion)：**
person, landscape, background, colorful, 3D, photorealistic

**状态：** Needed

---

### ASSET-137 — 爆破符

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 符箓符文图 |
| 尺寸 | 200×280px (LOD-1) / 600×840px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `talisman_baopo_fu.png` |
| 卡牌数据 | 稀有度=紫色 费用=2 效果=对目标和相邻两个目标各造成2点伤害 |

**视觉描述：**
暖灰符纸。中央朱砂红符文呈三连爆裂形——一个中心圆+三个方向的爆炸波纹。中心圆极浓，三个方向的波纹向外扩散时渐淡。波纹之间有飞溅的朱砂红细点——如弹片。符纸在三个波纹方向上边缘略微撕裂。右下有「爆」字朱印。

**美术圣经锚点：**
- §5.X.6 符文风格：攻击符=放射状
- §5.X.6 构图：三向扩散
- §4 语义色：朱砂红=爆炸

**生成提示 (Midjourney)：**
Chinese ink brush talisman on warm-gray aged paper — vermillion-red triple-blast rune: one dense center circle + 3 directional explosion shockwave rings fading outward, red splash dots between waves like shrapnel, paper edges slightly torn in wave directions, "爆" seal stamp, curled corners, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except warm gray and vermillion

**反向提示 (Stable Diffusion)：**
person, landscape, background, colorful, 3D, photorealistic, clean

**状态：** Needed

---

### ASSET-138 — 破甲符

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 符箓符文图 |
| 尺寸 | 200×280px (LOD-1) / 600×840px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `talisman_pojia_fu.png` |
| 卡牌数据 | 稀有度=紫色 费用=2 效果=无视目标50%防御，造成伤害 |

**视觉描述：**
暖灰符纸。中央朱砂红符文呈尖锐的楔形——如一根锥子刺入盾牌。楔形尖端极锐利（以极细的收笔表现），楔形尾部粗壮有力。符纸上有淡墨绘制的盾形轮廓——被朱砂红楔形刺穿的中心位置。整体传递「锐不可当」的穿透感。

**美术圣经锚点：**
- §5.X.6 符文风格：攻击符=尖锐
- §5.X.6 构图：穿透结构
- §4 语义色：朱砂红=破甲

**生成提示 (Midjourney)：**
Chinese ink brush talisman on warm-gray aged paper — vermillion-red sharp wedge-shaped rune like an awl piercing a shield, extremely fine point at tip, thick powerful tail, light ink shield outline being pierced at center by red wedge, unstoppable penetration energy, curled corners, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except warm gray, light ink, and vermillion

**反向提示 (Stable Diffusion)：**
person, landscape, background, colorful, 3D, photorealistic, blunt, soft

**状态：** Needed

---

### ASSET-139 — 灭魔符

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 符箓符文图 |
| 尺寸 | 200×280px (LOD-1) / 600×840px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `talisman_miemo_fu.png` |
| 卡牌数据 | 稀有度=金色 费用=3 效果=对魔道目标伤害翻倍 |

**视觉描述：**
暖灰符纸。中央朱砂红符文由交叉的两道剑形笔画组成——如双剑交叉斩落。交叉点正下方有一个被劈开的黑色魔气团（以淡墨渲染出被从中斩断的魔气）。剑形笔画的交叉处有一个朱砂红的「灭」字小印。符纸边缘有金光暗示——仅通过墨色浓淡对比暗示，不使用实际金色。

**美术圣经锚点：**
- §5.X.6 符文风格：高阶符=复杂多层
- §5.X.6 构图：双剑交叉
- §4 语义色：朱砂红=对魔克制

**生成提示 (Midjourney)：**
Chinese ink brush talisman on warm-gray aged paper — vermillion-red crossed double-sword rune, light ink severed demonic-qi cloud below the cross point, tiny "灭" (destroy) stamp at intersection, subtle golden-hint via ink density contrast around edges, curled corners, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except warm gray, ink, and vermillion

**反向提示 (Stable Diffusion)：**
person, landscape, background, colorful, 3D, photorealistic, gold

**状态：** Needed

---

### ASSET-140 — 斩妖符

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 符箓符文图 |
| 尺寸 | 200×280px (LOD-1) / 600×840px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `talisman_zhanyao_fu.png` |
| 卡牌数据 | 稀有度=金色 费用=3 效果=对灵兽/魔物目标伤害翻倍 |

**视觉描述：**
暖灰符纸。中央朱砂红符文为一竖贯穿全符的巨剑形——剑尖向下，剑格处左右展开为兽首形。剑身两侧有被斩断的妖气残影（淡墨渲染两个向外倒下的模糊兽形剪影）。剑脊正中有一道朱砂红从浓到淡的竖线——标识致命一击。右下有「斩」字朱印。

**美术圣经锚点：**
- §5.X.6 符文风格：高阶符=多层
- §5.X.6 构图：竖向贯穿
- §4 语义色：朱砂红=斩妖

**生成提示 (Midjourney)：**
Chinese ink brush talisman on warm-gray aged paper — vermillion-red vertical greatsword rune piercing full length, beast-head shaped crossguard, two faint collapsed beast silhouettes in light ink on either side, red vertical line dense-to-faint along blade spine for lethal strike, "斩" stamp, curled corners, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except warm gray, ink, and vermillion

**反向提示 (Stable Diffusion)：**
person, animal, landscape, background, colorful, 3D, photorealistic

**状态：** Needed

---

### ASSET-141 — 狂暴符

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 符箓符文图 |
| 尺寸 | 200×280px (LOD-1) / 600×840px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `talisman_kuangbao_fu.png` |
| 卡牌数据 | 稀有度=紫色 费用=3 效果=单个角色攻击+4，防御-2，持续一回合 |

**视觉描述：**
暖灰符纸。中央朱砂红符文狂暴不羁——笔画粗壮狂放，大量飞白和毛边。符文呈向上喷发的火山形——四条主线向上方炸裂，中间夹杂向外飞溅的朱砂红细点（防御力被炸飞的视觉暗示）。符纸边缘比其它符箓更显残破——如被狂暴之力撕裂。右下有「狂」字朱印。

**美术圣经锚点：**
- §5.X.6 符文风格：攻击符=爆发感
- §5.X.6 构图：火山喷发形
- §4 语义色：朱砂红=狂暴力量

**生成提示 (Midjourney)：**
Chinese ink brush talisman on warm-gray aged paper — vermillion-red berserk volcano-eruption rune with 4 thick wild main strokes blasting upward, flying-white and rough edges everywhere, red splash dots flying outward like defense being blasted away, paper edges notably more torn than other talismans, "狂" stamp, curled corners, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except warm gray and vermillion

**反向提示 (Stable Diffusion)：**
person, landscape, background, colorful, 3D, photorealistic, clean, neat, calm

**状态：** Needed

---

## 防御符（圆润围合状）

### ASSET-142 — 玄冰盾符

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 符箓符文图 |
| 尺寸 | 200×280px (LOD-1) / 600×840px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `talisman_xuanbing_dun_fu.png` |
| 卡牌数据 | 稀有度=蓝色 费用=2 效果=抵挡一次5点以上伤害，持续一回合 |

**视觉描述：**
暖灰符纸。中央朱砂红符文呈同心三层圆盾形——三层圆环从内到外渐淡，最内层圆环最浓。圆盾内有冰晶六角形纹路（以朱砂红的纤细线条表现）。符纸整体有冷冽感——符纸暖灰调偏冷。边缘完整，无撕裂。右下有「盾」字朱印。

**美术圣经锚点：**
- §5.X.6 符文风格：防御符=围合状
- §5.X.6 构图：同心环绕
- §4 语义色：朱砂红=护盾封印

**生成提示 (Midjourney)：**
Chinese ink brush talisman on cool-gray aged paper — vermillion-red 3-layer concentric shield circle rune fading from dense inner to light outer, hexagonal ice-crystal pattern in fine red lines within shield, paper tone slightly cooler, clean intact edges, "盾" seal stamp, curled corners, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except cool gray paper and vermillion

**反向提示 (Stable Diffusion)：**
person, landscape, background, colorful, 3D, photorealistic, warm, broken, torn

**状态：** Needed

---

### ASSET-143 — 金刚符

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 符箓符文图 |
| 尺寸 | 200×280px (LOD-1) / 600×840px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `talisman_jingang_fu.png` |
| 卡牌数据 | 稀有度=紫色 费用=3 效果=全体加3防御，持续一回合 |

**视觉描述：**
暖灰符纸。中央朱砂红符文呈厚重的方盾形——不是圆形而是方形，四角有金刚杵的小型朱砂红符号。方盾内有一个「坚」字篆书（以朱砂红粗笔书写）。方盾外缘有向外辐射的朱砂红短直线——标识防御力辐射至全体。符纸厚实平整。

**美术圣经锚点：**
- §5.X.6 符文风格：防御符=围合状
- §5.X.6 构图：方形盾+辐射线
- §4 语义色：朱砂红=全体防御

**生成提示 (Midjourney)：**
Chinese ink brush talisman on warm-gray aged paper — vermillion-red thick square shield rune with tiny vajra symbols at 4 corners, "坚" (solid) seal character in bold red within, short red radiating lines from shield edge for party-wide defense, paper thick and flat, curled corners, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except warm gray and vermillion

**反向提示 (Stable Diffusion)：**
person, landscape, background, colorful, 3D, photorealistic, round, circle

**状态：** Needed

---

### ASSET-144 — 防御符

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 符箓符文图 |
| 尺寸 | 200×280px (LOD-1) / 600×840px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `talisman_fangyu_fu.png` |
| 卡牌数据 | 稀有度=白色 费用=1 效果=单个角色加2防御，持续一回合 |

**视觉描述：**
暖灰符纸。中央朱砂红符文为简洁的单环圆——一个饱满的朱砂红圆圈内有一个更小的实心红点（防御核心）。圆环线条均匀流畅。符纸边缘微卷。整体极简克制——最基础的防御符。

**美术圣经锚点：**
- §5.X.6 符文风格：防御符=围合状
- §5.X.6 构图：单环圆
- §4 语义色：朱砂红=防御

**生成提示 (Midjourney)：**
Chinese ink brush talisman on warm-gray aged paper — simple single vermillion-red circle rune with solid red dot at center, even smooth brush weight, minimal clean aesthetic, curled corners, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except warm gray and vermillion

**反向提示 (Stable Diffusion)：**
person, landscape, background, colorful, 3D, photorealistic, complex, decorative

**状态：** Needed

---

### ASSET-145 — 铁壁符

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 符箓符文图 |
| 尺寸 | 200×280px (LOD-1) / 600×840px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `talisman_tiebi_fu.png` |
| 卡牌数据 | 稀有度=蓝色 费用=1 效果=单个角色本回合受到伤害降低50% |

**视觉描述：**
暖灰符纸。中央朱砂红符文呈城墙形——底部一条粗横线（城墙根基）、上方锯齿状的城垛线（城墙顶部）。城墙内有细密的砖纹线（以朱砂红细线表现）。整体呈长方形围合。符纸上半部留白较多——标识「城墙上方的天空」。

**美术圣经锚点：**
- §5.X.6 符文风格：防御符=围合状
- §5.X.6 构图：城墙形
- §4 语义色：朱砂红=铁壁防御

**生成提示 (Midjourney)：**
Chinese ink brush talisman on warm-gray aged paper — vermillion-red castle-wall rune: thick horizontal base line + battlement zigzag top, fine brick-pattern lines within wall in thin red, rectangular enclosing form, more negative space in upper half, curled corners, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except warm gray and vermillion

**反向提示 (Stable Diffusion)：**
person, landscape, background, colorful, 3D, photorealistic, round

**状态：** Needed

---

### ASSET-146 — 疗伤符

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 符箓符文图 |
| 尺寸 | 200×280px (LOD-1) / 600×840px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `talisman_liaoshang_fu.png` |
| 卡牌数据 | 稀有度=白色 费用=1 效果=回复单个角色2点血量 |

**视觉描述：**
暖灰符纸。中央朱砂红符文呈柔和的水滴形——一颗向下滴落的水滴。滴落的轨迹有三段渐小的朱砂红圆点。水滴底部有扩散的涟漪纹（三圈淡朱砂红同心弧）。符纸暖灰调偏暖偏柔。整体传递「滋润、疗愈」的感觉。

**美术圣经锚点：**
- §5.X.6 符文风格：防御符=围合状（涟漪）
- §5.X.6 构图：水滴+涟漪
- §4 语义色：朱砂红=疗愈

**生成提示 (Midjourney)：**
Chinese ink brush talisman on warm-soft gray aged paper — vermillion-red water-drop rune with 3 descending smaller dots, 3 concentric ripple arcs at bottom in lighter red, soft warm paper tone, nourishing healing feeling, curled corners, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except warm gray and vermillion

**反向提示 (Stable Diffusion)：**
person, landscape, background, colorful, 3D, photorealistic, sharp, aggressive

**状态：** Needed

---

### ASSET-147 — 群体疗伤符

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 符箓符文图 |
| 尺寸 | 200×280px (LOD-1) / 600×840px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `talisman_qunti_liaoshang_fu.png` |
| 卡牌数据 | 稀有度=紫色 费用=2 效果=回复全体角色1点血量 |

**视觉描述：**
暖灰符纸。中央朱砂红符文由五个小水滴组成——呈梅花形排列（中央一滴+四角各一滴）。每滴下方都有涟漪。水滴之间以细朱砂红线相连——形成生命网络。整体传递「雨露均沾」的全员回复感。

**美术圣经锚点：**
- §5.X.6 符文风格：防御符=围合状
- §5.X.6 构图：梅花五点
- §4 语义色：朱砂红=全体疗愈

**生成提示 (Midjourney)：**
Chinese ink brush talisman on warm-gray aged paper — vermillion-red 5-drop plum-blossom rune arrangement (center + 4 corners), ripples under each, thin red lines connecting all drops into life network, even-blessing party-wide heal energy, curled corners, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except warm gray and vermillion

**反向提示 (Stable Diffusion)：**
person, landscape, background, colorful, 3D, photorealistic, single

**状态：** Needed

---

## 功能符（蜿蜒流动状）

### ASSET-148 — 遁地符

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 符箓符文图 |
| 尺寸 | 200×280px (LOD-1) / 600×840px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `talisman_dundi_fu.png` |
| 卡牌数据 | 稀有度=蓝色 费用=1 效果=战斗中直接逃跑，保留全部资源 |

**视觉描述：**
暖灰符纸。中央朱砂红符文呈向下蜿蜒的S形——从符纸上方向下方钻入，在底部消失于三道横线（代表地面）。S形笔画的末端渐变消失——模拟遁入地下的瞬间。符纸下半部有淡墨的土壤纹理暗纹。右下有「遁」字朱印。

**美术圣经锚点：**
- §5.X.6 符文风格：功能符=蜿蜒流动
- §5.X.6 构图：S形向下
- §4 语义色：朱砂红=遁逃

**生成提示 (Midjourney)：**
Chinese ink brush talisman on warm-gray aged paper — vermillion-red S-curve rune winding downward and fading into 3 horizontal ground lines, brush stroke tapering to nothing at bottom like sinking into earth, light ink soil-texture pattern in lower half, "遁" stamp, curled corners, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except warm gray, light ink, and vermillion

**反向提示 (Stable Diffusion)：**
person, landscape, background, colorful, 3D, photorealistic

**状态：** Needed

---

### ASSET-149 — 速行符

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 符箓符文图 |
| 尺寸 | 200×280px (LOD-1) / 600×840px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `talisman_suxing_fu.png` |
| 卡牌数据 | 稀有度=白色 费用=0 效果=本回合抽1张牌 |

**视觉描述：**
暖灰符纸。中央朱砂红符文为三道横向流线——如风吹过的速度线。线条从左向右逐渐加速（起笔处略顿、收笔处飞白拉长）。符文上方有一片飘落的淡墨叶片——暗示抽到的牌如叶子飘至手中。符纸轻微不对称的卷曲——如被风吹起。

**美术圣经锚点：**
- §5.X.6 符文风格：功能符=流动状
- §5.X.6 构图：横向流线
- §4 语义色：朱砂红=抽牌加速

**生成提示 (Midjourney)：**
Chinese ink brush talisman on warm-gray aged paper — vermillion-red 3 horizontal speed-line rune strokes accelerating left-to-right, light ink floating leaf above rune suggesting card drawn like leaf to hand, slightly asymmetric paper curl like wind-blown, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except warm gray, light ink, and vermillion

**反向提示 (Stable Diffusion)：**
person, landscape, background, colorful, 3D, photorealistic, static

**状态：** Needed

---

### ASSET-150 — 冰缚符

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 符箓符文图 |
| 尺寸 | 200×280px (LOD-1) / 600×840px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `talisman_bingfu_fu.png` |
| 卡牌数据 | 稀有度=蓝色 费用=1 效果=冰冻目标一回合，造成1点伤害 |

**视觉描述：**
暖灰符纸。中央朱砂红符文呈螺旋冻结形——从外向内旋转收缩，至中心时线条由流动变为僵硬（收笔由飞白变为顿笔）。螺旋纹路中夹杂着冰晶六角形的朱砂红细纹。符纸有冷冽的偏灰调。右下有「冰」字朱印。

**美术圣经锚点：**
- §5.X.6 符文风格：功能符=螺旋流动
- §5.X.6 构图：向内螺旋冻结
- §4 语义色：朱砂红=冰冻

**生成提示 (Midjourney)：**
Chinese ink brush talisman on cool-gray aged paper — vermillion-red inward spiral rune freezing from fluid to rigid at center, hexagonal ice-crystal thin red lines woven in, cool gray paper tone, "冰" seal stamp, curled corners, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except cool gray and vermillion

**反向提示 (Stable Diffusion)：**
person, landscape, background, colorful, 3D, photorealistic, warm, fire

**状态：** Needed

---

### ASSET-151 — 净化符

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 符箓符文图 |
| 尺寸 | 200×280px (LOD-1) / 600×840px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `talisman_jinghua_fu.png` |
| 卡牌数据 | 稀有度=蓝色 费用=1 效果=驱散单个角色一个debuff |

**视觉描述：**
暖灰符纸。中央朱砂红符文呈上升的羽毛形——轻灵的曲线从底部向上飘升，线条越来越细越来越淡——在顶端化为几乎看不见的淡红微点后消失。符纸上半部有淡墨的浊气被推出符外的残影。整体传递「将浊气推出、轻身上升」的净化感。

**美术圣经锚点：**
- §5.X.6 符文风格：功能符=流动上升
- §5.X.6 构图：羽毛形上升
- §4 语义色：朱砂红=净化

**生成提示 (Midjourney)：**
Chinese ink brush talisman on warm-gray aged paper — vermillion-red feather-light rising curve rune tapering to nearly invisible red micro-dot at apex, light ink turbid-qi wisps being pushed out in upper half, cleansing ascending purity energy, curled corners, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except warm gray, light ink, and vermillion

**反向提示 (Stable Diffusion)：**
person, landscape, background, colorful, 3D, photorealistic, heavy, dark

**状态：** Needed

---

### ASSET-152 — 寻宝符

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 符箓符文图 |
| 尺寸 | 200×280px (LOD-1) / 600×840px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `talisman_xunbao_fu.png` |
| 卡牌数据 | 稀有度=紫色 费用=2 效果=查看牌库顶3张牌，选1张入手牌 |

**视觉描述：**
暖灰符纸。中央朱砂红符文呈三扇门形——三条竖线并列，中间一条最亮、两侧略淡。每扇「门」上方各悬浮一张微小的淡墨卡牌剪影——三张牌呈扇形排列。符纸上方有淡墨的眼形轮廓——标识「看牌库顶」的窥视之力。整体传递「三选一、取所需」的选择感。右下有「选」字朱印。

**美术圣经锚点：**
- §5.X.6 符文风格：功能符=流动（三选一抽牌）
- §5.X.6 构图：三扇门形
- §4 语义色：朱砂红=牌库窥视

**生成提示 (Midjourney)：**
Chinese ink brush talisman on warm-gray aged paper — vermillion-red 3-gate rune: 3 parallel vertical lines with middle brightest, small tiny ink card silhouettes floating above each gate in fan arrangement, faint eye-shaped outline in light ink above for peeking top 3 cards, selective choice energy, "选" seal stamp, curled corners, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except warm gray and vermillion

**反向提示 (Stable Diffusion)：**
person, landscape, background, colorful, 3D, photorealistic

**状态：** Needed

---

### ASSET-153 — 涨灵符

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 符箓符文图 |
| 尺寸 | 200×280px (LOD-1) / 600×840px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `talisman_zhangling_fu.png` |
| 卡牌数据 | 稀有度=蓝色 费用=2 效果=本回合获得1费，抽1张牌 |

**视觉描述：**
暖灰符纸。中央朱砂红符文为两个相连的半圆——如涌泉：下方的半圆中有一道上涌的朱砂红竖线（获得1费），上方的半圆中有一片飘出的淡墨叶片（抽1张牌）。两个半圆以一条S形朱砂红线相连。整体传递「资源涌现」的充盈感。

**美术圣经锚点：**
- §5.X.6 符文风格：功能符=流动
- §5.X.6 构图：双半圆涌泉
- §4 语义色：朱砂红=资源增长

**生成提示 (Midjourney)：**
Chinese ink brush talisman on warm-gray aged paper — vermillion-red double-half-circle wellspring rune: lower half with rising vertical red line (gain 1 energy), upper half with light ink floating leaf (draw 1 card), S-curve red line connecting both halves, resource-bubbling abundance energy, curled corners, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except warm gray, light ink, and vermillion

**反向提示 (Stable Diffusion)：**
person, landscape, background, colorful, 3D, photorealistic

**状态：** Needed

---

### ASSET-154 — 惑心符

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 符箓符文图 |
| 尺寸 | 200×280px (LOD-1) / 600×840px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `talisman_huoxin_fu.png` |
| 卡牌数据 | 稀有度=紫色 费用=2 效果=魅惑目标一回合，仅对男性生效 |

**视觉描述：**
暖灰符纸。中央朱砂红符文呈桃花形的双重螺旋——外层顺时针、内层逆时针，营造视觉催眠效果。螺旋中心有一个心形的小小朱砂红点。符文外有淡墨桃花瓣的飘散轮廓。符纸暖灰调偏暖偏柔。整体传递「迷离、诱惑」的氛围。

**美术圣经锚点：**
- §5.X.6 符文风格：功能符=螺旋流动
- §5.X.6 构图：双螺旋桃花
- §4 语义色：朱砂红=魅惑

**生成提示 (Midjourney)：**
Chinese ink brush talisman on warm-soft gray aged paper — vermillion-red peach-blossom double-spiral rune: outer clockwise + inner counter-clockwise for hypnotic effect, tiny heart-shaped red dot at center, light ink scattered peach petal silhouettes, warm soft seductive atmosphere, curled corners, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except warm gray, light ink, and vermillion

**反向提示 (Stable Diffusion)：**
person, landscape, background, colorful, 3D, photorealistic, sharp, cold

**状态：** Needed

---

### ASSET-155 — 天眼符

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 符箓符文图 |
| 尺寸 | 200×280px (LOD-1) / 600×840px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `talisman_tianyan_fu.png` |
| 卡牌数据 | 稀有度=紫色 费用=3 效果=本回合可以看到敌方牌库顶3张牌，可抽1张 |

**视觉描述：**
暖灰符纸。中央朱砂红符文为一只竖向的天眼——眼形拉长（杏仁形），瞳孔为一个朱砂红实心圆。眼上方有三条极细的朱砂红虚线——代表窥视三张牌的视觉延伸。眼下方有一个手势状的朱砂红小钩——代表抽取一张牌。整体传递「窥视天机」的神秘感。

**美术圣经锚点：**
- §5.X.6 符文风格：功能符=流动（视线）
- §5.X.6 构图：天眼形
- §4 语义色：朱砂红=窥视

**生成提示 (Midjourney)：**
Chinese ink brush talisman on warm-gray aged paper — vermillion-red vertical heavenly-eye rune: elongated almond-shaped eye with solid red pupil, 3 extremely thin red dashed lines above eye for peeking 3 cards, small red hook below for drawing 1 card, mystical divination energy, curled corners, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except warm gray, light ink, and vermillion

**反向提示 (Stable Diffusion)：**
person, face, landscape, background, colorful, 3D, photorealistic, eye, realistic

**状态：** Needed

---

## 高阶符（复杂多层级威压感）

### ASSET-156 — 破邪符

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 符箓符文图 |
| 尺寸 | 200×280px (LOD-1) / 600×840px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `talisman_poxie_fu.png` |
| 卡牌数据 | 稀有度=金色 费用=3 效果=驱散我方所有debuff |

**视觉描述：**
暖灰符纸。中央朱砂红符文极为复杂——由九个「卍」字变体符号（以极简化的朱砂红笔画）排列成九宫格。九个符号之间以朱砂红射线相连。符文外围有向外推出的淡墨浊气残影——从符纸边缘被排挤出去。符纸上半部有一轮朱砂红的朝阳——象征万象更新。右下有「破」字朱印。

**美术圣经锚点：**
- §5.X.6 符文风格：高阶符=多层嵌套
- §5.X.6 构图：九宫格
- §4 语义色：朱砂红=全队驱散

**生成提示 (Midjourney)：**
Chinese ink brush talisman on warm-gray aged paper — vermillion-red complex 9-grid rune of simplified swastika-variant symbols in 3x3 formation, red rays connecting all 9 symbols, light ink turbid-qi wisps being pushed outward from paper edges, vermillion rising sun in upper half for renewal, "破" seal stamp, curled corners, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except warm gray, light ink, and vermillion

**反向提示 (Stable Diffusion)：**
person, landscape, background, colorful, 3D, photorealistic, simple, minimal

**状态：** Needed

---

### ASSET-157 — 破空符

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 符箓符文图 |
| 尺寸 | 200×280px (LOD-1) / 600×840px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `talisman_pokong_fu.png` |
| 卡牌数据 | 稀有度=金色 费用=3 效果=本回合所有攻击无视伤害减免，必中 |

**视觉描述：**
暖灰符纸。中央朱砂红符文呈空间撕裂形——一道又粗又直的朱砂红竖线从符纸顶端直劈到底端，竖线上有锯齿状的撕裂纹理。竖线两侧有被撕开的空间裂缝（以朱砂红的细密平行短线模拟裂缝边缘）。符纸在竖线处有真实的撕裂痕迹——不是边缘卷曲而是中线开裂。右下有「破」字朱印。

**美术圣经锚点：**
- §5.X.6 符文风格：高阶符=贯穿多层
- §5.X.6 构图：竖向撕裂
- §4 语义色：朱砂红=破空必中

**生成提示 (Midjourney)：**
Chinese ink brush talisman on warm-gray aged paper — vermillion-red space-tearing vertical slash rune from top to bottom with serrated tear texture, fine parallel short red lines along both sides of slash simulating torn space fabric, actual tear in paper along the slash line, unstoppable piercing energy, "破" seal stamp, curled corners, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except warm gray and vermillion

**反向提示 (Stable Diffusion)：**
person, landscape, background, colorful, 3D, photorealistic, intact, smooth

**状态：** Needed

---

### ASSET-158 — 聚灵符

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 符箓符文图 |
| 尺寸 | 200×280px (LOD-1) / 600×840px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `talisman_juling_fu.png` |
| 卡牌数据 | 稀有度=金色 费用=4 效果=本回合所有卡牌伤害翻倍 |

**视觉描述：**
暖灰符纸。中央朱砂红符文极为壮观——一个巨大的旋转星云形，由十二条朱砂红旋臂从中心向外展开。每条旋臂的末端有一个朱砂红圆点——代表十二分力量的汇聚。中心有一个实心朱砂红圆——所有力量的归一点。符文外围有淡墨的能量环。符纸显得庄严厚重。右下有「聚」字朱印。

**美术圣经锚点：**
- §5.X.6 符文风格：高阶符=多层嵌套
- §5.X.6 构图：星云形旋转
- §4 语义色：朱砂红=力量汇聚

**生成提示 (Midjourney)：**
Chinese ink brush talisman on warm-gray aged paper — vermillion-red magnificent 12-arm spiral galaxy rune radiating from center, solid red dot at each arm tip for 12-fold power convergence, dense red central core, light ink energy rings in background, solemn weighty presence, "聚" seal stamp, curled corners, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except warm gray, light ink, and vermillion

**反向提示 (Stable Diffusion)：**
person, landscape, background, colorful, 3D, photorealistic, simple, minimal

**状态：** Needed

---

### ASSET-159 — 天劫符

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 符箓符文图 |
| 尺寸 | 200×280px (LOD-1) / 600×840px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `talisman_tianjie_fu.png` |
| 卡牌数据 | 稀有度=金色 费用=4 效果=对敌方全体造成3点伤害，对高阶目标伤害+2 |

**视觉描述：**
暖灰符纸。中央朱砂红符文呈天雷轰顶形——上方是一个朱砂红太阳（天劫之源），从中劈下七道锯齿闪电覆盖整个符面。闪电由上至下逐渐变粗，最下方的闪电末端有溅射的红色火星。符纸上方边缘有淡墨云层——雷从云中生。下方有被雷击的焦痕墨迹。右下有「劫」字朱印。

**美术圣经锚点：**
- §5.X.6 符文风格：高阶符=多层嵌套
- §5.X.6 构图：天雷轰顶
- §4 语义色：朱砂红=天劫

**生成提示 (Midjourney)：**
Chinese ink brush talisman on warm-gray aged paper — vermillion-red heavenly-tribulation rune: sun disk at top as tribulation source, 7 zigzag lightning bolts spreading across entire paper, bolts thickening downward with red spark splashes at tips, light ink cloud layer at top edge, scorched ink marks at bottom, cataclysmic divine punishment energy, "劫" seal stamp, curled corners, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except warm gray, light ink, and vermillion

**反向提示 (Stable Diffusion)：**
person, landscape, background, colorful, 3D, photorealistic, gentle

**状态：** Needed

---

### ASSET-160 — 回魂符

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 符箓符文图 |
| 尺寸 | 200×280px (LOD-1) / 600×840px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `talisman_huihun_fu.png` |
| 卡牌数据 | 稀有度=紫色 费用=3 效果=复活一个低阶角色，回复一半血量 |

**视觉描述：**
暖灰符纸。中央朱砂红符文呈魂魄回归形——从符纸下方（代表冥界）向上升起三道朱砂红S形魂魄线，上升到符纸中部汇合为一个完整的人形剪影（简洁的朱砂红人形）。人形剪影的一半（左半）为实心朱砂红、另一半（右半）为淡朱砂红——标识回复一半血量。右下有「魂」字朱印。

**美术圣经锚点：**
- §5.X.6 符文风格：高阶符=多层级
- §5.X.6 构图：魂魄上升
- §4 语义色：朱砂红=复活

**生成提示 (Midjourney)：**
Chinese ink brush talisman on warm-gray aged paper — vermillion-red soul-return rune: 3 S-curve soul-threads rising from bottom (underworld) merging into simplified human silhouette at mid-paper, left half solid red and right half light red for half-HP return, profound resurrection energy, "魂" seal stamp, curled corners, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except warm gray, light ink, and vermillion

**反向提示 (Stable Diffusion)：**
person, face, landscape, background, colorful, 3D, photorealistic, ghost, skull

**状态：** Needed

---

## 特殊符

### ASSET-161 — 定身符

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 符箓符文图 |
| 尺寸 | 200×280px (LOD-1) / 600×840px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `talisman_dingshen_fu.png` |
| 卡牌数据 | 稀有度=紫色 费用=3 效果=让目标一回合无法行动 |

**视觉描述：**
暖灰符纸。中央朱砂红符文呈锁链束缚形——三条朱砂红锁链纹（链环相接的精细笔触）从一个中心结向外延伸，每条锁链末端有一个朱砂红的重锁符号（圆形内有「封」字微印）。中心结处有一个朱砂红的「定」字。符纸整体有束缚感的张力——锁链将符文牢牢锁在中央。

**美术圣经锚点：**
- §5.X.6 符文风格：特殊符=束缚结构
- §5.X.6 构图：锁链放射
- §4 语义色：朱砂红=定身

**生成提示 (Midjourney)：**
Chinese ink brush talisman on warm-gray aged paper — vermillion-red binding-chain rune: 3 chain-link lines radiating from central knot with lock symbols at ends (tiny "封" inside circles), bold red "定" (freeze) at center, taut binding tension across paper, curled corners, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except warm gray and vermillion

**反向提示 (Stable Diffusion)：**
person, landscape, background, colorful, 3D, photorealistic, free, loose

**状态：** Needed

---

### ASSET-162 — 隐匿符

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 符箓符文图 |
| 尺寸 | 200×280px (LOD-1) / 600×840px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `talisman_yinni_fu.png` |
| 卡牌数据 | 稀有度=蓝色 费用=2 效果=战后两次探索不遇高阶修士 |

**视觉描述：**
暖灰符纸。中央朱砂红符文极为简约——仅有三道渐淡的竖线（从符纸中部开始向下逐渐变淡至消失），模拟隐匿时身形逐渐淡去的视觉效果。符文上方有淡墨的雾气——遮蔽身形。符纸大量留白——与其它符箓形成鲜明反差，暗示「空、无、隐」。右下有「隐」字朱印——极淡。

**美术圣经锚点：**
- §5.X.6 符文风格：特殊符=极简淡出
- §5.X.6 构图：渐淡竖线
- §4 语义色：朱砂红淡出=隐匿

**生成提示 (Midjourney)：**
Chinese ink brush talisman on warm-gray aged paper — ultra-minimal vermillion-red 3 vertical fade-out strokes disappearing downward, light ink mist above, abundant negative space contrasting all other talismans for emptiness/concealment, very faint "隐" stamp, minimal Zen aesthetic, curled corners, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except warm gray, faint ink, and pale vermillion

**反向提示 (Stable Diffusion)：**
person, landscape, background, colorful, 3D, photorealistic, busy, dense, complex

**状态：** Needed

---

### ASSET-163 — 傀儡丹（符箓视觉处理）

*注：此条目为丹药系统中的傀儡丹，在视觉上既有丹药的丹丸特征也有符箓的符纸特征。此处列入符箓类以备外包参考。*

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 符箓符文图 |
| 尺寸 | 200×280px (LOD-1) / 600×840px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `talisman_kuilei_dan.png` |
| 卡牌数据 | 稀有度=紫色 费用=3 效果=召唤临时傀儡 |

**视觉描述：**
参照 ASSET-124（丹药卡）。如需符箓版本的视觉处理：暖灰符纸中央朱砂红符文呈人形傀儡轮廓——一个简化的关节人形，关节处有朱砂红圆点标识活动节点。

**状态：** Needed（备用变体）

---

## LOD 快速参考

| LOD | 规格 | 内容 |
|-----|------|------|
| LOD-1 | 200×280px | 完整符箓图（卡牌插画区域） |
| LOD-2 | 64×90px | 符文主体裁切（战斗头像） |
| LOD-3 | 80×100px | 符文简化剪影（缩略图标——长方形） |