# 资产规范 — 阵法卡阵盘几何图

> **来源**：design/gdd/card-system-design.md 第五部分
> **美术圣经**：design/art/art-bible.md §5.X.7
> **生成日期**：2026-07-26
> **审查模式**：Solo（art-director + technical-artist 代理因 API 503 不可用）
> **状态**：16 个资产已规范 / 0 个已批准 / 0 个生产中 / 0 个完成

## 技术参数

| 参数 | 值 |
|------|-----|
| 规格 | 200×280px |
| 工作分辨率 | 800×800px（等比缩放至 200×280px 居中） |
| 格式 | PSD 源文件 + PNG 导出 |
| 图层要求 | (1) 几何阵线层（浓墨精密线条） (2) 琉璃金阵眼层 (3) 辅助灵文标注层（淡墨） |
| Godot 导入预设 | 2D Texture, Filter=Disabled, Mipmaps=Off, Compress=Lossless |
| 单张预估 | ~100KB RGBA8 → ~25KB DXT5 |
| 总计预估 | 16 张 × 25KB = ~400KB VRAM |

## 阵法几何形态速查

| 几何类型 | 形态 | 阵眼特征 | 适用阵法 |
|----------|------|----------|------|
| 阵营联动阵 | 多层同心圆 + 阵营标记点 | 圆心为金色阵眼 | 青云合击阵、苍玄正道盟阵、苍玄魔道盟阵、苍玄正邪盟阵、丹霞剑阵、玄冰回春阵 |
| 角色专属阵 | 正多边形（5-8边形）+ 顶点标注 | 多边形中心为阵眼 | 青锋剑阵、乾坤颠倒阵、轮回往生阵 |
| 条件触发阵 | 三角形或六边形 + 边上触发条件刻字 | 几何中心为阵眼 | 万象忘尘阵、合欢迷魂阵 |
| 区域光环阵 | 正方形或八边形 + 辐射渐变线 | 阵眼在中心，光环向外渐淡 | 归墟之境真灵大阵、魔域血海阵、碎星守护阵、血海阴煞阵、归墟之境百族大阵 |

---

## 阵营联动阵（同心圆 + 标记点）

### ASSET-164 — 青云合击阵

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 阵盘几何图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `formation_qingyun_heji_zhen.png` |
| 卡牌数据 | 稀有度=蓝色 费用=1 触发=场上≥3个青云剑宗角色 效果=所有青云剑宗角色攻击+2 |

**视觉描述：**
三层同心圆阵盘——内圈最小最浓（核心触发圈）、中圈略大、外圈最大。外圈上均匀分布着三个剑形标记（代表青云剑宗角色），以浓墨刻线绘制。琉璃金阵眼在内圈圆心——光芒沿三条半径线直达三个剑形标记，形成「三剑汇心」的视觉结构。外圈有细密的剑纹灵文标注。

**美术圣经锚点：**
- §5.X.7 阵盘几何形态：阵营联动阵（同心圆+标记）
- §5.X.7 构图规则：阵盘居中 60%
- §4 语义色：琉璃金=阵眼标识

**生成提示 (Midjourney)：**
Chinese ink brush geometric formation diagram — 3 concentric circles, 3 sword-shaped markers evenly spaced on outer ring, golden light at center core radiating along 3 radius lines to sword markers, fine sword-pattern spirit text on outer ring, precise gongbi linework, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no person, no color except ink black and gold at center

**反向提示 (Stable Diffusion)：**
person, character, landscape, background, colorful, 3D, photorealistic, organic, messy, hand-drawn

**状态：** Needed

---

### ASSET-165 — 苍玄正道盟阵

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 阵盘几何图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `formation_cangxuan_zhengdao_mengzhen.png` |
| 卡牌数据 | 稀有度=紫色 费用=2 触发=场上≥3个正道角色 效果=所有正道角色血量上限+2，防御+1 |

**视觉描述：**
四层同心圆阵盘——每层代表不同的防御层级。外圈上分布着三个「正」字标记（以方正小篆刻于外圈），正字之间以盾形符纹相连。琉璃金阵眼在圆心——光芒从阵眼向外扩散至第二层圆环处停止（防御光环的半径），在此处形成一圈明亮的金环。外圈灵文为端正的楷书笔画。

**美术圣经锚点：**
- §5.X.7 阵营联动阵：同心圆+正字标记
- §5.X.7 构图规则
- §4 语义色：琉璃金=正道防御阵眼

**生成提示 (Midjourney)：**
Chinese ink brush geometric formation — 4 concentric circles, 3 "正" (righteous) seal-script markers on outer ring connected by shield-symbol arcs, golden core with light stopping at second ring forming bright gold defensive halo, upright regular-script spirit text on outer ring, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except ink black and gold

**反向提示 (Stable Diffusion)：**
person, landscape, background, colorful, 3D, photorealistic

**状态：** Needed

---

### ASSET-166 — 苍玄魔道盟阵

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 阵盘几何图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `formation_cangxuan_modao_mengzhen.png` |
| 卡牌数据 | 稀有度=紫色 费用=2 触发=场上≥3个魔道角色 效果=所有魔道角色攻击+2，暴击率+10% |

**视觉描述：**
三层同心圆阵盘——与正道盟阵对应但内圈不完整（有两处故意断裂），暗示魔道的不羁。外圈上分布着三个魔纹标记（不规则的三尖爪痕形）。琉璃金阵眼不在圆心正中央——而是微微偏移，形成不对称的张力和不稳定的能量感。外圈灵文为狂放的草书笔意。

**美术圣经锚点：**
- §5.X.7 阵营联动阵：同心圆+魔纹标记
- §5.X.7 构图规则（不对称变体）
- §4 语义色：琉璃金偏移=魔道不稳定能量

**生成提示 (Midjourney)：**
Chinese ink brush geometric formation — 3 concentric circles with deliberant breaks in inner rings, 3 claw-mark demonic symbols on outer ring, golden core slightly off-center for unstable tension, wild cursive-style spirit text on outer ring, dark aggressive energy, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except ink black and gold

**反向提示 (Stable Diffusion)：**
person, landscape, background, colorful, 3D, photorealistic, symmetric, balanced

**状态：** Needed

---

### ASSET-167 — 苍玄正邪盟阵

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 阵盘几何图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `formation_cangxuan_zhengxie_mengzhen.png` |
| 卡牌数据 | 稀有度=紫色 费用=2 触发=场上正道+魔道各≥2个 效果=全体攻防+15% |

**视觉描述：**
四层同心圆阵盘——最独特的双色结构：左侧两个「正」字标记（正道）、右侧两个魔纹爪痕（魔道），以阵盘中心为界左右分治。两套标记之间有交织的波纹线——正邪之力交汇处形成螺旋状的融合纹理。琉璃金阵眼在圆心——左右各有一道金色弧线分别连接正道和魔道标记。外圈灵文左半端正、右半狂放。

**美术圣经锚点：**
- §5.X.7 阵营联动阵：同心圆+双阵营标记
- §5.X.7 构图规则（左右分治变体）
- §4 语义色：琉璃金=正邪融合阵眼

**生成提示 (Midjourney)：**
Chinese ink brush geometric formation — 4 concentric circles split left/right, left half with 2 "正" markers, right half with 2 claw-mark demonic symbols, interweaving wave patterns where forces meet at center, golden core with arcs connecting to both faction markers, left spirit text regular, right text wild cursive, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except ink black and gold

**反向提示 (Stable Diffusion)：**
person, landscape, background, colorful, 3D, photorealistic, uniform, symmetric

**状态：** Needed

---

### ASSET-168 — 丹霞剑阵

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 阵盘几何图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `formation_danxia_jianzhen.png` |
| 卡牌数据 | 稀有度=紫色 费用=2 触发=场上丹霞谷角色≥2个 效果=所有丹霞谷角色攻击+2 |

**视觉描述：**
二层同心圆阵盘——外圈上分布着两个丹炉形标记（代表丹霞谷的炼丹传统）。两标记之间以火焰纹弧线相连。琉璃金阵眼在内圈圆心——光沿火焰纹弧线传导至两个丹炉标记，丹炉的炉口处金光明亮如炼丹时的火光。外圈灵文为古朴的篆隶。

**美术圣经锚点：**
- §5.X.7 阵营联动阵：同心圆+丹炉标记
- §5.X.7 构图规则
- §4 语义色：琉璃金=丹霞攻击阵眼

**生成提示 (Midjourney)：**
Chinese ink brush geometric formation — 2 concentric circles, 2 alchemy-furnace markers on outer ring connected by flame-pattern arcs, golden core light traveling along flame arcs to furnace mouths which glow brightly like alchemical fire, archaic seal-clerical spirit text, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except ink black and gold

**反向提示 (Stable Diffusion)：**
person, landscape, background, colorful, 3D, photorealistic

**状态：** Needed

---

### ASSET-169 — 玄冰回春阵

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 阵盘几何图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `formation_xuanbing_huichun_zhen.png` |
| 卡牌数据 | 稀有度=紫色 费用=2 触发=场上玄冰宫角色≥2个 效果=每回合全体回复1血 |

**视觉描述：**
三层同心圆阵盘——外圈上有两个雪花六角标记（代表玄冰宫）。标记之间以水滴连线相连（每一滴水滴为一个微型同心圆）。琉璃金阵眼在圆心——光沿水滴连线以脉动的方式（断续的金色弧线）扩散至雪花标记，模拟每回合的生命回复节奏。外圈灵文清瘦冷峻。

**美术圣经锚点：**
- §5.X.7 阵营联动阵：同心圆+雪花标记
- §5.X.7 构图：脉动连线=回复节奏
- §4 语义色：琉璃金=回复阵眼

**生成提示 (Midjourney)：**
Chinese ink brush geometric formation — 3 concentric circles, 2 hexagonal snowflake markers on outer ring connected by water-drop chain (micro concentric rings), golden core pulsing along drop-chain in broken golden arcs for per-turn heal rhythm, cool slender spirit text, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except ink black and gold

**反向提示 (Stable Diffusion)：**
person, landscape, background, colorful, 3D, photorealistic, warm

**状态：** Needed

---

## 角色专属阵（正多边形 + 顶点标注）

### ASSET-170 — 青锋剑阵

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 阵盘几何图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `formation_qingfeng_jianzhen.png` |
| 卡牌数据 | 稀有度=紫色 费用=2 触发=场上绑定青锋逐影剑的角色≥2个 效果=所有绑定青锋逐影剑的角色攻击+3 |

**视觉描述：**
正五边形阵盘——五个顶点各有剑形标记（标识青锋逐影剑的绑定角色），最多五个位置暗示可以有多达五个角色触发。五边形内部有从一个顶点到另一个顶点的剑锋线——五条线交织成星形。琉璃金阵眼在正五边形中心。外圈灵文细密如剑刻。

**美术圣经锚点：**
- §5.X.7 角色专属阵：正多边形+顶点标注
- §5.X.7 构图：五边形+剑锋星形
- §4 语义色：琉璃金=剑阵阵眼

**生成提示 (Midjourney)：**
Chinese ink brush geometric formation — regular pentagon with sword markers at all 5 vertices, 5 intersecting blade-lines forming star pattern inside pentagon, golden core at exact center, fine sword-engraved spirit text on outer ring, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except ink black and gold

**反向提示 (Stable Diffusion)：**
person, landscape, background, colorful, 3D, photorealistic

**状态：** Needed

---

### ASSET-171 — 乾坤颠倒阵

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 阵盘几何图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `formation_qiankun_diandao_zhen.png` |
| 卡牌数据 | 稀有度=金色 费用=3 触发=场上同时存在林渊+月清霜+银翎 效果=敌方全体攻击降低30%，每回合20%概率混乱一个敌方角色 |

**视觉描述：**
正三角形阵盘——三个顶点分别为「渊」「霜」「翎」的篆书铭文。三角形内部不是等边而是略微扭曲——象征「颠倒」之阵。三个顶点之间有双向的颠倒箭头（以淡墨绘制，箭头从顶点A指向顶点B的同时也有逆箭头从B指向A）。琉璃金阵眼在三角形中心——光呈混沌的涡旋（向外扩散的同时也在向内回旋）。外圈灵文繁复如颠倒的密文。

**美术圣经锚点：**
- §5.X.7 角色专属阵：三角形+角色铭文
- §5.X.7 构图：扭曲三角形
- §4 语义色：琉璃金混沌涡旋=混乱效果

**生成提示 (Midjourney)：**
Chinese ink brush geometric formation — slightly distorted triangle with "渊""霜""翎" seal characters at vertices, bidirectional reversal arrows between vertices in light ink, golden chaotic vortex at center (expanding and contracting simultaneously), complex reversed cipher-like spirit text on outer ring, disorienting energy, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except ink black and gold

**反向提示 (Stable Diffusion)：**
person, landscape, background, colorful, 3D, photorealistic, symmetric, orderly, calm

**状态：** Needed

---

### ASSET-172 — 轮回往生阵

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 阵盘几何图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `formation_lunhui_wangsheng_zhen.png` |
| 卡牌数据 | 稀有度=金色 费用=3 触发=场上同时存在沐瑶+轮回殿主 效果=每回合可抽牌+1，复活角色概率+20% |

**视觉描述：**
正六边形阵盘——六个顶点中有两个大顶点（「沐」「轮」的篆书铭文）和四个小顶点（以淡墨小点表示未来可能的位置）。六边形内部有双重螺旋线——从「沐」出发绕中心六圈后到达「轮」，再从「轮」绕六圈回到「沐」——形成无限的轮回循环（∞形变体）。琉璃金阵眼在双螺旋的交汇中心——光沿螺旋线缓慢旋转。外圈灵文有轮回感的环形篆书。

**美术圣经锚点：**
- §5.X.7 角色专属阵：六边形+双角色
- §5.X.7 构图：双螺旋轮回
- §4 语义色：琉璃金旋转=复活概率

**生成提示 (Midjourney)：**
Chinese ink brush geometric formation — regular hexagon with "沐""轮" large seal markers at 2 vertices + 4 small dots, double-helix infinity-loop (∞ variant) spiraling 6 times between the two markers, golden slowly rotating core at helix intersection, circular seal-script spirit text, profound cyclic life-death energy, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except ink black and gold

**反向提示 (Stable Diffusion)：**
person, landscape, background, colorful, 3D, photorealistic, static, linear

**状态：** Needed

---

## 条件触发阵（三角/六边形 + 触发刻字）

### ASSET-173 — 万象忘尘阵

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 阵盘几何图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `formation_wanxiang_wangchen_zhen.png` |
| 卡牌数据 | 稀有度=金色 费用=3 触发=场上存在万象真人角色 效果=每回合随机获取一张当前场上或手中已有卡牌的复制 |

**视觉描述：**
正六边形阵盘——每条边上刻有不同的天干地支触发条件（以淡墨小字刻于边的中点）。六边形内部有两层镜像对称的星图——上层与下层互为镜像（淡墨与浓墨呼应），象征「已有之物复制再现」。琉璃金阵眼在两层星图之间——光从阵眼向上下两个方向同时辐射，在六边形六个顶点处亮起相同的金色光斑——标识「任意一张场上或手中卡牌的复制」。外圈灵文为天文学般的星宿密文。

**美术圣经锚点：**
- §5.X.7 条件触发阵：六边形+触发刻字
- §5.X.7 构图：星图内部
- §4 语义色：琉璃金=复制卡牌之力

**生成提示 (Midjourney)：**
Chinese ink brush geometric formation — regular hexagon with heavenly-stem earthly-branch trigger conditions engraved at each edge midpoint in light ink, complex star-chart constellation map of countless micro-dot connections within, golden core with 6 subtle golden routes to each edge trigger, astronomical star-mansion cipher spirit text on outer ring, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except ink black and gold

**反向提示 (Stable Diffusion)：**
person, landscape, background, colorful, 3D, photorealistic, simple, empty

**状态：** Needed

---

### ASSET-174 — 合欢迷魂阵

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 阵盘几何图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `formation_hehuan_mihun_zhen.png` |
| 卡牌数据 | 稀有度=紫色 费用=3 触发=场上魅影阁角色≥2个 效果=敌方男性角色每回合25%概率被魅惑 |

**视觉描述：**
倒三角形阵盘（顶点向下——非传统的顶点向上）——象征颠倒迷惑。三条边上各刻有一个桃花状的触发标记。三角形内部有迷魂的螺旋——三条螺旋线从各边中点的触发标记向内旋转，在中心附近纠缠成一团。琉璃金阵眼在三角中心——光呈脉动的桃心形（25%概率的闪烁感）。外圈灵文为妩媚的曲线形符文。

**美术圣经锚点：**
- §5.X.7 条件触发阵：倒三角+螺旋纠缠
- §5.X.7 构图：迷魂螺旋
- §4 语义色：琉璃金脉动=概率魅惑

**生成提示 (Midjourney)：**
Chinese ink brush geometric formation — inverted triangle (apex down) with peach-blossom trigger marks on each edge, 3 spiral lines from edge midpoints entangling near center, golden pulsing heart-shaped core for 25% charm probability, seductive curved spirit text on outer ring, disorienting hypnotic energy, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except ink black and gold

**反向提示 (Stable Diffusion)：**
person, landscape, background, colorful, 3D, photorealistic, upright, orderly

**状态：** Needed

---

## 区域光环阵（正方/八边形 + 辐射渐变线）

### ASSET-175 — 归墟之境真灵大阵

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 阵盘几何图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `formation_guixuzhijing_zhenling_dazhen.png` |
| 卡牌数据 | 稀有度=金色 费用=4 触发=场上真灵角色≥3个 效果=所有真灵角色每回合回复2血，暴击率+20% |

**视觉描述：**
正八边形阵盘——代表归墟之境的八方百族。八个顶点各有不同的真灵族徽（以简化符号表示：羽、鳞、角、爪、翼、须、尾、冠）。八边形内部从阵眼向外辐射八条渐淡墨线——每条线末端对应一个族徽。琉璃金阵眼在中心——光芒极为明亮，覆盖整个八边形内区域。外圈灵文为归墟之境的百族古文字。

**美术圣经锚点：**
- §5.X.7 区域光环阵：八边形+辐射线
- §5.X.7 构图：八族徽辐射
- §4 语义色：琉璃金=真灵全族光环

**生成提示 (Midjourney)：**
Chinese ink brush geometric formation — regular octagon with 8 different true-spirit clan crests at vertices (feather, scale, horn, claw, wing, whisker, tail, crown simplified), 8 gradient ink lines radiating from center to each crest, intense bright golden core covering entire octagon interior, hundred-clan ancient spirit text on outer ring, magnificent all-encompassing energy, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except ink black and brilliant gold

**反向提示 (Stable Diffusion)：**
person, landscape, background, colorful, 3D, photorealistic, small, dim

**状态：** Needed

---

### ASSET-176 — 魔域血海阵

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 阵盘几何图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `formation_moyu_xuehai_zhen.png` |
| 卡牌数据 | 稀有度=金色 费用=4 触发=场上魔道角色≥3个 效果=所有魔道角色击杀敌方后攻击永久+2，回复3血 |

**视觉描述：**
不规则八边形阵盘——八边不等长，暗示魔道的混乱无序。八个顶点有三个浓墨粗标的大顶点（代表≥3魔道角色）和五个淡墨小顶点。阵盘内部从中心向外辐射八条如血管般蜿蜒的墨线——每条线到达顶点时末端有微小的尖刺。琉璃金阵眼暗沉发红（通过更厚重更偏暖的墨色暗示金光偏红而非纯金）——标识击杀+回复的魔道之力。外圈灵文粗犷野性。

**美术圣经锚点：**
- §5.X.7 区域光环阵：不规则八边形
- §5.X.7 构图：血管状辐射线
- §4 语义色：琉璃金偏红=魔道击杀回复

**生成提示 (Midjourney)：**
Chinese ink brush geometric formation — irregular octagon with unequal edges for demonic chaos, 3 thick dark marked vertices + 5 light small ones, 8 vein-like winding ink lines radiating from center with tiny barbs at tips, dark reddish-gold core for kill-heal demonic power, rough wild spirit text on outer ring, brutal aggressive energy, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except ink black and dark warm gold

**反向提示 (Stable Diffusion)：**
person, landscape, background, colorful, 3D, photorealistic, regular, orderly, clean

**状态：** Needed

---

### ASSET-177 — 碎星守护阵

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 阵盘几何图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `formation_suixing_shouhu_zhen.png` |
| 卡牌数据 | 稀有度=紫色 费用=3 触发=场上碎星群岛角色≥2个 效果=我方全体受到伤害降低8% |

**视觉描述：**
正方形阵盘——四方各有一个岛屿形的标记（碎星群岛=四个点的群岛轮廓）。正方形内部有细密的星点网格——如同夜空中碎星散布的图案。琉璃金阵眼在正方形中心——光从中心向外渐淡，在四个岛屿标记处再次微微亮起——形成「从中心到群岛」的守护网络。外圈灵文细密如沙滩上的星砂。

**美术圣经锚点：**
- §5.X.7 区域光环阵：正方形+星点网格
- §5.X.7 构图：四方岛屿标记
- §4 语义色：琉璃金渐淡=减伤光环

**生成提示 (Midjourney)：**
Chinese ink brush geometric formation — square with 4 island-archipelago markers at each side, fine star-dot constellation grid filling the interior, golden core fading outward then re-brightening slightly at island markers for protective network, fine star-sand spirit text on outer ring, calm protective cosmic energy, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except ink black and gold

**反向提示 (Stable Diffusion)：**
person, landscape, background, colorful, 3D, photorealistic

**状态：** Needed

---

### ASSET-178 — 血海阴煞阵

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 阵盘几何图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `formation_xuehai_yinsha_zhen.png` |
| 卡牌数据 | 稀有度=紫色 费用=3 触发=场上血海殿角色≥2个 效果=敌方全体每回合掉1血 |

**视觉描述：**
正方形阵盘——但四角不是直角而是尖锐的菱形四角，如四把刀尖向外。四个角上各有一个滴血状的标记（代表血海殿的持续伤害）。正方形内部从中心向外辐射的不是直线而是向下的滴血状弧线——每回合掉1血的持续伤害被视觉化为不断滴落的血滴。琉璃金阵眼暗沉——光向下渗透而非向上照耀。外圈灵文狰狞。

**美术圣经锚点：**
- §5.X.7 区域光环阵：锐角方形+滴血标记
- §5.X.7 构图：向下的滴血弧线
- §4 语义色：琉璃金向下=持续伤害光环

**生成提示 (Midjourney)：**
Chinese ink brush geometric formation — square with sharp diamond-pointed corners like 4 blades outward, blood-drop markers at each corner, downward-dripping arc lines from center for per-turn damage-over-time, dark gold core seeping downward, sinister spirit text on outer ring, malevolent draining energy, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except ink black and dark gold

**反向提示 (Stable Diffusion)：**
person, landscape, background, colorful, 3D, photorealistic, bright, uplifting

**状态：** Needed

---

### ASSET-179 — 归墟之境百族大阵

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 阵盘几何图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `formation_guixuzhijing_baizu_dazhen.png` |
| 卡牌数据 | 稀有度=金色 费用=4 触发=场上归墟之境百族角色≥4个 效果=所有归墟之境百族角色攻防+20% |

**视觉描述：**
正八边形阵盘——与真灵大阵相似但规模更大。八个顶点各有不同的百族族徽（比真灵阵的八个符号更为多样）。八边形内部有繁复的百族图腾交织纹——无数精密的细线将八个族徽连接成一个整体网络。琉璃金阵眼在中心——光芒极为辉煌，八条粗壮金线直达八个族徽——每条都是 20% 增益的全力传导。外圈灵文如百族史诗般展开。整体为 16 张阵法中最为壮观的一张。

**美术圣经锚点：**
- §5.X.7 区域光环阵：正八边形（最大规模）
- §5.X.7 构图：百族图腾交织
- §4 语义色：琉璃金极辉煌=攻防全增幅

**生成提示 (Midjourney)：**
Chinese ink brush geometric formation — regular octagon as grandest formation of all 16, 8 diverse hundred-clan crests at vertices, intricate interweaving totem network of countless fine connecting lines, exceptionally brilliant golden core with 8 thick gold beams reaching each crest for full 20% buff transmission, epic hundred-clan saga spirit text on outer ring, most magnificent composition, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except ink black and brilliant gold

**反向提示 (Stable Diffusion)：**
person, landscape, background, colorful, 3D, photorealistic, simple, small, dim

**状态：** Needed

---

## LOD 快速参考

| LOD | 规格 | 内容 |
|-----|------|------|
| LOD-1 | 200×280px | 完整阵盘图（卡牌插画区域） |
| LOD-2 | 64×90px | 阵眼区域裁切（战斗头像） |
| LOD-3 | 80×100px | 阵盘几何简化剪影（缩略图标——圆形/多边形） |