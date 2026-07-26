# 资产规范 — 法宝卡器物静物图

> **来源**：design/gdd/card-system-design.md 第四部分
> **美术圣经**：design/art/art-bible.md §5.X.4
> **生成日期**：2026-07-26
> **审查模式**：Solo（art-director + technical-artist 代理因 API 503 不可用）
> **状态**：48 个资产已规范 / 0 个已批准 / 0 个生产中 / 0 个完成

## 技术参数

| 参数 | 值 |
|------|-----|
| 规格 | 200×280px |
| 工作分辨率 | 800×800px（等比缩放，以宽度为准） |
| 格式 | PSD 源文件 + PNG 导出 |
| 图层要求 | (1) 器物主体墨线层 (2) 琉璃金灵光层 (3) 淡墨阴影层 |
| Godot 导入预设 | 2D Texture, Filter=Disabled, Mipmaps=Off, Compress=Lossless |
| 单张预估 | ~160KB RGBA8 → ~40KB DXT5 |
| 总计预估 | 48 张 × 40KB = ~1.9MB VRAM |

## 材质墨阶表达速查

| 材质 | 墨阶特征 | 适用法宝 |
|------|---------|---------|
| 剑器 | 浓墨高对比，剑锋处有极细白线反光 | 青锋逐影剑、青冥剑、玄天斩灵剑等 |
| 防具 | 淡墨柔过渡，圆润体积感 | 乌金软甲、幻风袍、五光十色盾等 |
| 玉器 | 淡墨半透明，有玉质温润光 | 银翎玉瓶、七宝琉璃树、辟邪玉等 |
| 法器/道具 | 浓淡交替，精细纹饰 | 大衍罗盘、万灵幡、墨玉符等 |
| 金属重器 | 浓墨粗线，厚重体量感 | 斩皇刀、乾坤圈、混沌宝瓶等 |

## 攻击武器类法宝

### ASSET-064 — 青锋逐影剑（凡器）

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 法宝器物图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `artifact_qingfeng_zhuying_jian_common.png` |
| 卡牌数据 | 稀有度=蓝色 费用=2 效果=绑定角色攻击+3，每回合额外涨1点攻击 |

**视觉描述：**
一柄清雅的青色剑影悬浮于画面中——剑身窄长，剑脊一道浓墨中锋线贯穿全长，剑格为简单的云纹如意形。剑身周围有淡墨剑影微微偏移——暗示「逐影」之名。琉璃金微光从剑格处向外氤氲——标识每回合攻击增长的效果。底部淡墨阴影指示悬浮空间感。

**美术圣经锚点：**
- §5.X.4 工笔器物画构图规则：器物居中悬浮
- §5.X.4 材质：剑器=浓墨高对比
- §4 语义色：琉璃金=灵力光芒

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a slender blue-tinted sword floating in void — gongbi precision linework, single dark ink central ridge line, subtle offset ink shadow blade suggesting "shadow-chasing", faint golden glow at crossguard, light ink drop shadow below, transparent background, white space, ink on rice paper texture -- style "墨骨丹青" --ar 5:7 --no background, no scene, no hand, no person, no color except ink black and subtle gold

**反向提示 (Stable Diffusion)：**
person, hand, character, background, landscape, colorful, 3D render, photorealistic, environment

**状态：** Needed

---

### ASSET-065 — 青锋逐影剑（灵宝）

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 法宝器物图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `artifact_qingfeng_zhuying_jian_lingbao.png` |
| 卡牌数据 | 稀有度=金色 费用=4 效果=绑定角色攻击+6，每回合涨2点攻击，配合青云剑诀效果翻倍 |

**视觉描述：**
与凡器版形成鲜明对比——剑身增宽30%，剑脊从单线变为复线双脊，剑格从简单如意升级为繁复的九层如意。剑身周围有三道淡墨剑影（凡器仅一道），琉璃金光芒从剑格和剑尖两端同时绽放——光芒面积为凡器版的三倍，标识稀有度升级。剑身表面隐约浮现微小的灵文刻痕。

**美术圣经锚点：**
- §5.X.4 工笔器物画：升级变体必须有明显差异
- §5.X.4 色彩规则：金色法宝琉璃金面积可扩大至 10%
- §4 语义色：琉璃金=稀有度视觉信号

**生成提示 (Midjourney)：**
Chinese ink brush still-life of an upgraded legendary flying sword — wider blade than common version, double-ridge central line, elaborate 9-tier ruyi crossguard, 3 offset ink shadow blades, intense golden glow radiating from both crossguard and blade tip, faint spirit runes etched on blade surface, light ink drop shadow, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no person, no hand, no color except ink black and gold

**反向提示 (Stable Diffusion)：**
person, hand, character, background, landscape, colorful, 3D, photorealistic

**状态：** Needed

---

### ASSET-066 — 玄天斩灵剑（雏形）

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 法宝器物图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `artifact_xuantian_zhanling_jian.png` |
| 卡牌数据 | 稀有度=金色 费用=5 效果=绑定角色攻击无视防御，对魔物伤害翻倍 |

**视觉描述：**
一柄尚未完全成形的巨剑悬浮——剑身有明显的锻造未完成的痕迹：剑刃边缘不规则、剑脊有断裂后重新熔接的纹理。但正是这种「未完成」感赋予了它无视防御的混沌力量。琉璃金光芒从剑身的裂缝中向外泄漏——而非从剑格正常发出——暗示力量的不受约束。剑尖特别粗壮厚重。底部阴影浓重，暗示巨剑的重量感。

**美术圣经锚点：**
- §5.X.4 工笔器物画构图规则
- §5.X.4 材质：金属重器=浓墨粗线
- §4 语义色：琉璃金=破防之力

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a massive incomplete ancient sword — raw unfinished blade edges, fractured-then-reforged texture along spine, chaotic golden light leaking from blade cracks rather than crossguard, disproportionately thick blade tip, heavy dark drop shadow suggesting immense weight, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no person, no hand, no color except ink black and golden cracks

**反向提示 (Stable Diffusion)：**
person, hand, character, background, landscape, colorful, 3D, photorealistic, clean, polished

**状态：** Needed

---

### ASSET-067 — 斩皇刀

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 法宝器物图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `artifact_zhanhuang_dao.png` |
| 卡牌数据 | 稀有度=金色 费用=5 效果=绑定角色对魔道/邪修伤害+50%，攻击+5 |

**视觉描述：**
一柄宽刃巨刀斜悬于画面——刀身极宽、刀背厚实、刀刃薄如一线。刀身上方雕刻着正道符印（朱砂红微点标识），下方是一道被斩断的魔气残痕（淡墨渲染）。琉璃金光芒从刀刃一线迸发——光线如刀锋般锐利细长，沿刀刃方向延伸。整件器物传递「斩皇」的王者之气。底部阴影厚重。

**美术圣经锚点：**
- §5.X.4 工笔器物画：金属重器=浓墨粗线
- §5.X.4 构图：器物占垂直高度 40%
- §4 语义色：琉璃金=克制魔道之力

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a massive wide-blade executioner's dao — extremely wide blade, thick spine, paper-thin edge line, righteous talisman marks above blade with vermillion micro-dots, severed demonic-qi stain below in light ink wash, razor-thin golden brilliance line along cutting edge, royal/regal presence, heavy drop shadow, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no person, no hand, no color except ink black, subtle gold, and micro vermillion dots

**反向提示 (Stable Diffusion)：**
person, hand, character, background, landscape, colorful, 3D, photorealistic

**状态：** Needed

---

### ASSET-068 — 六极魔刃

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 法宝器物图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `artifact_liuji_moren.png` |
| 卡牌数据 | 稀有度=紫色 费用=2 效果=绑定角色攻击+3 |

**视觉描述：**
一柄六边形截面的短刃悬浮——刃身并非传统的平直刀片，而是六棱柱形的刺刃。六个面上各有不同的魔纹刻痕（淡墨精细线刻），琉璃金微光从六棱交汇的尖端发出。刃的握柄端粗糙如兽骨——与精密刃身形成质感对比。底部阴影偏暗偏暖。

**美术圣经锚点：**
- §5.X.4 工笔器物画构图规则
- §5.X.4 材质：金属浓墨 + 兽骨粗笔触
- §4 语义色：琉璃金=攻击力标识

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a hexagonal-section demonic dagger — 6-sided prism blade not flat, different demonic rune engravings on each face in fine light ink, faint golden glow from 6-edge convergence tip, rough bone-like grip handle contrasting with precise blade, dark warm drop shadow, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no person, no hand, no color except ink black and subtle gold

**反向提示 (Stable Diffusion)：**
person, hand, character, background, landscape, colorful, 3D, photorealistic

**状态：** Needed

---

### ASSET-069 — 青冥剑

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 法宝器物图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `artifact_qingming_jian.png` |
| 卡牌数据 | 稀有度=紫色 费用=3 效果=绑定角色对魔道伤害+30% |

**视觉描述：**
一柄碧青色半透明的长剑——剑身如青色琉璃般通透，透过剑身可以看到后方的淡墨线条。这是唯一大面积使用松石青暗示的法宝——剑脊处的松石青渲染象征对魔道的克制属性，但严格控制在剑脊一条细线内。剑身周围有青色剑气的淡墨氤氲。剑格简洁方正。

**美术圣经锚点：**
- §5.X.4 材质：玉器=淡墨半透明
- §5.X.4 色彩规则：松石青仅在修为标识使用
- §4 语义色：松石青=克制属性标识

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a translucent jade-green longsword — semi-transparent blade body like celadon jade, dark ink spine line visible through blade, single thin turquoise-blue line along spine for demon-subduing property, faint cyan sword-qi mist around blade in light ink, simple square crossguard, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no person, no hand, no color except ink black and one thin turquoise line

**反向提示 (Stable Diffusion)：**
person, hand, character, background, landscape, colorful, 3D, photorealistic, neon

**状态：** Needed

---

### ASSET-070 — 曼陀罗法杵

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 法宝器物图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `artifact_mantuoluo_fachu.png` |
| 卡牌数据 | 稀有度=紫色 费用=2 效果=绑定角色对鬼道角色伤害+30% |

**视觉描述：**
一柄金刚杵形法器——两端为对称的三股叉，中段握柄缠绕着降魔纹。杵身为深墨色金属质感——浓墨线条配合中段的繁复纹饰形成密宗的庄严感。琉璃金光芒从杵的两端叉尖发出——光呈叉状射线，标识对鬼道的克制。底部阴影呈金刚座形态。

**美术圣经锚点：**
- §5.X.4 工笔器物画：法器=精细纹饰
- §5.X.4 材质：金属=浓墨高对比
- §4 语义色：琉璃金=克制鬼道之力

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a vajra/dorje ritual implement — symmetrical 3-pronged ends, demon-subduing mantra patterns wrapped around central grip, dark ink metallic texture, golden light radiating in trident rays from both prong tips, vajra-throne shaped drop shadow, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no person, no hand, no color except ink black and subtle gold

**反向提示 (Stable Diffusion)：**
person, hand, character, background, landscape, colorful, 3D, photorealistic, religious, buddha

**状态：** Needed

---

### ASSET-071 — 飞叉

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 法宝器物图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `artifact_feicha.png` |
| 卡牌数据 | 稀有度=蓝色 费用=2 效果=绑定角色攻击+2 |

**视觉描述：**
一柄简洁的三尖飞叉悬浮——叉身为实用的兵器造型，无过多装饰。中间的叉尖略长于两侧，叉柄缠绕着防滑的皮绳纹理（以粗糙墨笔表现）。琉璃金微光仅出现在中间叉尖——小而克制。整体一件朴实无华的战斗兵器，墨色干净利落。底部阴影轻巧。

**美术圣经锚点：**
- §5.X.4 工笔器物画构图
- §5.X.4 材质：金属=浓墨 + 皮绳=粗糙笔触
- §4 语义色：琉璃金微光=攻击力标识

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a simple practical trident — utilitarian weapon design, center prong slightly longer than sides, leather-wrap grip texture in rough brush strokes, small subtle gold glint at center prong tip only, clean efficient ink work, light drop shadow, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no person, no hand, no color except ink black and micro gold dot

**反向提示 (Stable Diffusion)：**
person, hand, character, background, landscape, colorful, 3D, photorealistic, ornate, decorative

**状态：** Needed

---

### ASSET-072 — 三焰扇

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 法宝器物图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `artifact_sanyan_shan.png` |
| 卡牌数据 | 稀有度=紫色 费用=3 效果=绑定角色对敌方全体造成1点溅射伤害 |

**视觉描述：**
一把三片羽毛组成的羽扇——三片羽毛以不同角度展开，每片羽毛的羽轴用浓墨勾勒、羽片用淡墨渲染。羽毛边缘有微焦的痕迹（干墨皴擦），暗示「火焰」之名。琉璃金微光在羽片的扇面交汇处闪烁——标识溅射伤害的散布范围。扇柄为竹节形（墨竹画法）。底部阴影呈三瓣扇形。

**美术圣经锚点：**
- §5.X.4 材质：羽毛=淡墨柔过渡
- §5.X.4 构图：器物居中悬浮
- §4 语义色：琉璃金=溅射伤害标识

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a 3-feather fan — 3 feathers spread at different angles, dark ink quill lines and light ink feather vanes, slightly singed edges in dry-brush texture suggesting flame, subtle gold glint where feathers converge, bamboo-joint handle in ink bamboo painting style, 3-petal fan-shaped drop shadow, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no person, no hand, no color except ink black and subtle gold

**反向提示 (Stable Diffusion)：**
person, hand, character, background, landscape, colorful, 3D, photorealistic, bird

**状态：** Needed

---

### ASSET-073 — 海魔笛

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 法宝器物图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `artifact_haimo_di.png` |
| 卡牌数据 | 稀有度=紫色 费用=2 效果=绑定角色攻击有20%概率混乱目标一回合 |

**视觉描述：**
一支弯曲如海螺的骨笛——笛身由不知名海兽的骨骼制成，表面有螺旋状的天然骨纹。笛孔排列成波浪形（非直线），吹口处有珊瑚状的骨质增生。琉璃金微光从笛孔中溢出——光呈涟漪状扩散，暗示声音带来的混乱效果。墨色偏暗，骨纹处有细腻的淡墨晕染。

**美术圣经锚点：**
- §5.X.4 材质：骨器=淡墨柔过渡 + 天然纹理
- §5.X.4 构图规则
- §4 语义色：琉璃金=混乱音波标识

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a curved sea-beast bone flute — spiral natural bone grain on surface, wave-pattern finger holes not in straight line, coral-like bone growth at mouthpiece, golden ripples emerging from finger holes suggesting confusion-inducing sound waves, dark ink with delicate bone-grain ink wash, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no person, no hand, no color except ink black and subtle gold ripples

**反向提示 (Stable Diffusion)：**
person, hand, character, background, landscape, colorful, 3D, photorealistic, ocean, sea

**状态：** Needed

---

### ASSET-074 — 乾坤圈

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 法宝器物图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `artifact_qiankun_quan.png` |
| 卡牌数据 | 稀有度=紫色 费用=3 效果=绑定角色攻击+4，有20%概率击晕目标 |

**视觉描述：**
一个厚重的金属圆环悬浮——环体粗壮如臂，外圈刻有乾坤卦象（乾三连在上、坤六断在下），内圈光滑。环体以浓墨工笔绘制，金属的高光用留白表现。琉璃金光芒沿外圈的卦象刻痕流动——乾卦处光较强（天）、坤卦处光较弱（地），标识击晕力量的循环。底部阴影厚实。

**美术圣经锚点：**
- §5.X.4 金属重器：浓墨粗线
- §5.X.4 构图：器物居中
- §4 语义色：琉璃金=控制效果标识

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a heavy metal ring — thick arm-width ring body, qian-kun trigrams engraved on outer surface (three solid lines above, six broken below), smooth inner ring, metallic highlights via negative space, golden light flowing along trigram engravings — brighter at qian, dimmer at kun, heavy drop shadow, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no person, no hand, no color except ink black and gold

**反向提示 (Stable Diffusion)：**
person, hand, character, background, landscape, colorful, 3D, photorealistic

**状态：** Needed

---

### ASSET-075 — 冰魄剑

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 法宝器物图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `artifact_bingpo_jian.png` |
| 卡牌数据 | 稀有度=紫色 费用=4 效果=绑定角色攻击附带冰冻效果，概率30% |

**视觉描述：**
一柄如冰晶凝结般的长剑——剑身半透明，内部有霜花状的裂纹纹理（以留白表现冰裂纹）。剑格如六角冰花展开，护手处结着霜（细密白点状飞白）。松石青微光从剑脊中心透出——冷冽而克制，标识冰冻属性的来源。整体线条偏细偏冷，大量使用留白表现冰的透明度。底部阴影极淡。

**美术圣经锚点：**
- §5.X.4 材质：冰晶=大量留白表现透明度
- §5.X.4 构图规则
- §4 语义色：松石青冷光=冰冻属性标识

**生成提示 (Midjourney)：**
Chinese ink brush still-life of an ice-crystal longsword — semi-transparent blade with frost-flower crack patterns in negative space, hexagonal ice-flower crossguard with frost accumulation in fine white flying-brush dots, cool turquoise-blue glimmer from blade spine center, thin cold linework with abundant negative space for ice transparency, extremely light drop shadow, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no person, no hand, no color except ink black and cool turquoise glimmer

**反向提示 (Stable Diffusion)：**
person, hand, character, background, landscape, colorful, 3D, photorealistic, fire, warm

**状态：** Needed

---

### ASSET-076 — 金光砖

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 法宝器物图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `artifact_jinguang_zhuan.png` |
| 卡牌数据 | 稀有度=蓝色 费用=3 效果=绑定角色攻击+3，防御+1 |

**视觉描述：**
一块长方形金砖悬浮——砖体方正厚重，表面刻有「金光」二字的篆书阳文。砖的四边有回纹装饰边框。琉璃金微光从砖面均匀散发——不强烈但持续不断，标识攻防兼备的稳定增益。墨线粗壮方正，有建筑基石的稳重感。底部阴影方正如砖体投影。

**美术圣经锚点：**
- §5.X.4 金属重器：浓墨粗线
- §5.X.4 构图规则
- §4 语义色：琉璃金=均衡增益标识

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a rectangular golden brick — heavy square body, seal-script "金光" characters in raised relief on face, meander-pattern border on all four edges, steady subtle golden glow evenly from surface for balanced dual-stat boost, thick square brushwork like building foundation, square drop shadow matching brick projection, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no person, no hand, no color except ink black and subtle gold

**反向提示 (Stable Diffusion)：**
person, hand, character, background, landscape, colorful, 3D, photorealistic

**状态：** Needed

---

### ASSET-077 — 血玉骷髅

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 法宝器物图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `artifact_xueyu_kulou.png` |
| 卡牌数据 | 稀有度=紫色 费用=3 效果=绑定角色攻击每次给敌方叠1层毒素，毒素每层掉1血 |

**视觉描述：**
一颗由血玉雕成的微型骷髅悬浮——骷髅眉心嵌有一颗朱砂红色的小珠（这是朱砂红在法宝中极少的使用场景——标识毒素的致命性）。骷髅眼眶深陷，以浓墨渲染；颅骨表面有细密的玉质裂纹纹理。琉璃金光芒从眉心朱砂珠向外微微渗出——标识毒素的蔓延。整体尺寸小于一般法宝，暗示其诡秘性质。底部阴影呈扩散的毒素云状。

**美术圣经锚点：**
- §5.X.4 材质：玉器=淡墨半透明 + 裂纹纹理
- §5.X.4 色彩规则：朱砂红极小面积（毒素标识）
- §4 语义色：朱砂红=毒素，琉璃金=效果触发

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a miniature blood-jade carved skull — vermillion-red bead embedded in forehead for poison lethality, deep dark ink in eye sockets, fine jade crackle texture on cranium surface, faint golden glow seeping from vermillion bead for poison spread, small scale suggesting sinister nature, poison-cloud diffusion shaped drop shadow, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no person, no hand, no color except ink black, one vermillion dot, and subtle gold

**反向提示 (Stable Diffusion)：**
person, hand, character, background, landscape, colorful, 3D, photorealistic, gore, horror, skeleton

**状态：** Needed

---

### ASSET-078 — 天凤火羽

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 法宝器物图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `artifact_tianfeng_huoyu.png` |
| 卡牌数据 | 稀有度=金色 费用=4 效果=绑定角色伤害+15%，对冰系目标翻倍 |

**视觉描述：**
一根凤凰尾羽悬浮——羽轴修长笔直（浓墨中锋），羽片华丽展开，边缘呈火焰般的波浪形。羽毛并非纯墨色——在羽片边缘以朱砂红渲染出火焰的余烬感（控制在羽片边缘 5% 范围内）。琉璃金光芒从羽根处向上延伸至羽尖——光如火焰般跳动。整体线条有凤凰的高贵华美感。底部阴影极淡，几乎不承托。

**美术圣经锚点：**
- §5.X.4 材质：羽毛=淡墨柔过渡
- §5.X.4 色彩规则：朱砂红点缀=火焰属性
- §4 语义色：琉璃金=伤害增幅，朱砂红=火属性

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a single phoenix tail feather — long straight quill in dark ink center-line, luxuriant vane with flame-like wavy edges, vermillion-red ember rendering at vane edges (5% area max), golden light flowing from quill base to tip like dancing flame, noble regal line quality, extremely light drop shadow, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no person, no hand, no color except ink black, vermillion edge tint, and gold

**反向提示 (Stable Diffusion)：**
person, hand, character, background, landscape, colorful, 3D, photorealistic, bird, phoenix

**状态：** Needed

---

### ASSET-079 — 啼魂铃

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 法宝器物图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `artifact_tihun_ling.png` |
| 卡牌数据 | 稀有度=紫色 费用=4 效果=绑定角色溅射伤害+1 |

**视觉描述：**
一只小巧的青铜铃铛悬浮——铃身圆润，表面有兽面纹浮雕（以浓淡墨交替表现浮雕立体感）。铃舌可见，悬于铃中。琉璃金光芒从铃口向下辐射——光呈声波般的同心圆扩散，标识溅射伤害的震荡范围。铃铛顶部有兽首钮环。墨色偏暗偏古。

**美术圣经锚点：**
- §5.X.4 材质：青铜器=浓淡墨交替浮雕
- §5.X.4 构图规则
- §4 语义色：琉璃金=溅射震荡标识

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a small bronze bell — rounded body with beast-mask relief pattern in alternating dark/light ink for 3D relief effect, visible clapper suspended inside, golden concentric sound-wave rings radiating downward from bell mouth for splash damage, beast-head loop at top, dark antique ink tone, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no person, no hand, no color except ink black and gold rings

**反向提示 (Stable Diffusion)：**
person, hand, character, background, landscape, colorful, 3D, photorealistic

**状态：** Needed

---

### ASSET-080 — 鬼灵珠

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 法宝器物图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `artifact_guiling_zhu.png` |
| 卡牌数据 | 稀有度=紫色 费用=4 效果=绑定角色死后对敌方造成当前血量50%的伤害 |

**视觉描述：**
一颗暗色宝珠悬浮——珠体内部有缭绕的魂魄状墨迹（以淡墨在珠内渲染出不规则的卷曲烟云）。宝珠表面有一道裂纹——琉璃金光芒从裂纹中泄漏而出——光不是向外照射，而是向下沉坠如泪滴，暗示死后爆发的诅咒力量。裂纹处墨色最深。底部阴影呈扩散的爆裂状。

**美术圣经锚点：**
- §5.X.4 材质：宝珠=浓淡墨叠染
- §5.X.4 色彩规则：琉璃金=死后爆发之力
- §4 语义色：琉璃金=诅咒伤害标识

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a dark orb/pearl — swirling spirit-smoke ink wash trapped inside, single crack on surface with golden light leaking downward like tear drops for death-triggered curse damage, deepest ink at crack, explosive-burst shaped drop shadow, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no person, no hand, no color except ink black and golden tear-light

**反向提示 (Stable Diffusion)：**
person, hand, character, background, landscape, colorful, 3D, photorealistic, ghost

**状态：** Needed

---

## 防具/护甲类法宝

### ASSET-081 — 踏风靴

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 法宝器物图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `artifact_tafeng_xue.png` |
| 卡牌数据 | 稀有度=蓝色 费用=1 效果=绑定角色受到伤害降低10%，每回合首次受击伤害减半 |

**视觉描述：**
一双轻便的布靴悬浮——靴面有风的流线纹（以流动的淡墨曲线表现），靴底有微小的云纹刻痕。靴口处系着飘带（以飞白笔法表现飘带的轻盈）。琉璃金微光从靴底的云纹中亮起——标识踏风而行的减伤效果。整体墨色轻淡，有满不在乎的轻快感。

**美术圣经锚点：**
- §5.X.4 材质：布料织物=淡墨轻笔
- §5.X.4 构图规则
- §4 语义色：琉璃金=减伤标识

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a pair of lightweight cloth boots — wind-streamline curves on boot surface in flowing light ink, tiny cloud-pattern engravings on soles, flying ribbons at boot cuffs in flying-white brush technique, subtle golden glow from sole cloud patterns for damage reduction, light breezy ink density, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no person, no foot, no color except ink black and subtle gold

**反向提示 (Stable Diffusion)：**
person, foot, character, background, landscape, colorful, 3D, photorealistic

**状态：** Needed

---

### ASSET-082 — 五光十色盾

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 法宝器物图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `artifact_wuguang_shise_dun.png` |
| 卡牌数据 | 稀有度=金色 费用=3 效果=每场战斗开局全体抵挡一次5点以上伤害 |

**视觉描述：**
一面五层嵌套的盾牌——每层由不同的墨阶表现（从外到内：浓→中→淡→极淡→留白核心），暗示五色光华。盾面呈花瓣形（五瓣花），每瓣对应一道光。琉璃金光芒从留白核心向外辐射——光沿五瓣的脉络扩散，标识全队抵挡大量伤害的守护结界。盾缘有云纹雕刻。底部阴影厚重。

**美术圣经锚点：**
- §5.X.4 材质：金属盾=浓淡墨交替
- §5.X.4 构图：大型防具占画面 45%
- §4 语义色：琉璃金=全队守护标识

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a 5-layered shield — each layer in different ink density from dark outer to white core, 5-petal flower shape with one color-light per petal, golden radiance from white core outward along petal veins for party-wide damage ward, cloud-pattern rim engraving, heavy drop shadow, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no person, no hand, no color except ink black and gold

**反向提示 (Stable Diffusion)：**
person, hand, character, background, landscape, colorful, rainbow, 3D, photorealistic

**状态：** Needed

---

### ASSET-083 — 玄冰盾

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 法宝器物图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `artifact_xuanbing_dun.png` |
| 卡牌数据 | 稀有度=蓝色 费用=2 效果=绑定角色防御+2 |

**视觉描述：**
一面冰晶凝成的圆盾——盾面半透明，内部有霜花六角纹理。盾的边缘不规则——如自然冻结的冰面边缘。松石青淡光从盾面中心微微透出——冷冽而均匀，标识纯粹的防御力。大量留白表现冰的透明度。底部阴影极淡，几乎消失。

**美术圣经锚点：**
- §5.X.4 材质：冰晶=大量留白
- §5.X.4 构图规则
- §4 语义色：松石青冷光=冰系防御标识

**生成提示 (Midjourney)：**
Chinese ink brush still-life of an ice-crystal round shield — semi-transparent shield face with internal frost-flower hexagonal patterns, irregular naturally-frozen ice edge, cool turquoise-blue light softly emanating from center for pure defense, abundant negative space for ice transparency, nearly invisible drop shadow, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no person, no hand, no color except ink black and cool turquoise glimmer

**反向提示 (Stable Diffusion)：**
person, hand, character, background, landscape, colorful, 3D, photorealistic, water

**状态：** Needed

---

### ASSET-084 — 乌金软甲

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 法宝器物图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `artifact_wujin_ruanjia.png` |
| 卡牌数据 | 稀有度=紫色 费用=2 效果=绑定角色血量上限+3 |

**视觉描述：**
一件折叠整齐的软甲悬浮——甲面由无数小金属片连缀而成（以细密的网格线表现），每片金属片中央有微小的铆钉点。甲缘包边以淡墨渲染出皮革质感。琉璃金微光从甲面整体的网格纹路中均匀散发——标识血量上限的全面提升。墨线细密工整，有鱼鳞甲的精密感。

**美术圣经锚点：**
- §5.X.4 材质：金属片甲=细密网格线
- §5.X.4 构图规则
- §4 语义色：琉璃金=生命上限标识

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a folded flexible scale armor — countless tiny metal scales in fine grid lines, tiny rivet dots at each scale center, leather-trim edges in light ink wash, subtle even golden glow from overall grid pattern for max HP boost, fine precise fish-scale precision, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no person, no body, no color except ink black and subtle gold

**反向提示 (Stable Diffusion)：**
person, body, character, background, landscape, colorful, 3D, photorealistic

**状态：** Needed

---

### ASSET-085 — 幻风袍

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 法宝器物图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `artifact_huanfeng_pao.png` |
| 卡牌数据 | 稀有度=紫色 费用=3 效果=绑定角色受到伤害降低12% |

**视觉描述：**
一件随风展开的长袍悬浮——袍身如被无形之风撑开，呈现飘逸的弧线形态。袍面以淡墨渲染为主，边缘有风的流线纹。领口和袖口有暗纹镶边（精细的几何纹饰）。琉璃金微光从袍的内衬中透出——如在袍内藏了一轮微光，标识风之减伤的庇护。整体线条轻盈飘逸。

**美术圣经锚点：**
- §5.X.4 材质：织物=淡墨轻笔 + 流畅曲线
- §5.X.4 构图：袍身占画面 45%
- §4 语义色：琉璃金=减伤庇护

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a wind-swept robe floating — billowing arc form as if held open by invisible wind, light ink wash with wind streamline patterns at edges, subtle geometric trim at collar and cuffs, soft golden glow from inner lining like hidden sun for wind-protection damage reduction, light flowing line quality, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no person, no body, no color except ink black and subtle gold

**反向提示 (Stable Diffusion)：**
person, body, character, background, landscape, colorful, 3D, photorealistic

**状态：** Needed

---

### ASSET-086 — 墨玉符

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 法宝器物图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `artifact_moyu_fu.png` |
| 卡牌数据 | 稀有度=紫色 费用=2 效果=替绑定角色抵挡一次致命伤害，触发后法宝失效 |

**视觉描述：**
一块墨玉符牌悬浮——符牌呈长方形，边角圆润，玉质温润半透明。符面刻有一个「护」字篆书，刻痕中填入琉璃金——这是标识该符牌仅能使用一次的预存灵力。符牌边缘有一道细微的裂纹——暗示触发后即将碎裂。墨色偏淡偏暖，有玉石特有的温润光泽。

**美术圣经锚点：**
- §5.X.4 材质：玉器=淡墨半透明 + 温润光
- §5.X.4 色彩规则：琉璃金=预存灵力（一次性）
- §4 语义色：琉璃金=致命伤抵挡

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a rectangular ink-jade talisman tablet — rounded corners, warm semi-translucent jade texture, seal-script "护" (protect) character engraved and filled with golden ink for one-time stored spirit power, hairline crack at edge suggesting imminent shattering on use, warm light ink with jade's characteristic luster, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no person, no hand, no color except ink black and gold inlay

**反向提示 (Stable Diffusion)：**
person, hand, character, background, landscape, colorful, 3D, photorealistic

**状态：** Needed

---

## 辅助/功能类法宝

### ASSET-087 — 风雷翅

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 法宝器物图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `artifact_fenglei_chi.png` |
| 卡牌数据 | 稀有度=金色 费用=3 效果=绑定角色受到伤害降低10%，每回合额外抽1张牌 |

**视觉描述：**
一对展开的羽翼悬浮——左翼为风纹（流畅曲线）、右翼为雷纹（锯齿折线）。双翼在中央以一道流光相连。风翼以淡墨轻染，雷翼以浓墨重笔——形成质感对比。琉璃金光芒从风雷交汇的中心圆环中迸发——光同时具有风的流动感和雷的爆发感，标识额外抽牌的灵机。根部有金属羽轴结构。

**美术圣经锚点：**
- §5.X.4 材质：风翼=淡墨 + 雷翼=浓墨对比
- §5.X.4 色彩规则：金色法宝琉璃金面积可扩大
- §4 语义色：琉璃金=额外抽牌标识

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a pair of spread wings — left wing wind-pattern (flowing curves in light ink), right wing lightning-pattern (zigzag lines in dark ink), golden radiance from center ring where wind and lightning converge with both flowing and bursting qualities, metallic feather-shaft root structure, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no person, no bird, no color except ink black and gold

**反向提示 (Stable Diffusion)：**
person, bird, animal, character, background, landscape, colorful, 3D, photorealistic

**状态：** Needed

---

### ASSET-088 — 储物袋

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 法宝器物图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `artifact_chuwu_dai.png` |
| 卡牌数据 | 稀有度=蓝色 费用=1 效果=每场战斗开局全体额外获得2费 |

**视觉描述：**
一只朴素的布袋悬浮——布袋口微微张开，袋身有「纳」字的绣纹。袋口处有淡墨渲染的真气溢出——模拟袋中储藏的灵力向外流动。琉璃金微光从袋口的内侧隐约可见——标识额外的费用储备。袋身以粗布纹理（干墨皴擦）表现质朴感。束口绳系成如意结。

**美术圣经锚点：**
- §5.X.4 材质：布袋=干墨皴擦粗布纹理
- §5.X.4 构图规则
- §4 语义色：琉璃金=费用储备标识

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a simple cloth storage pouch — mouth slightly open, embroidered "纳" (store) character on body, light ink qi wisps spilling from mouth, subtle golden glimmer inside pouch mouth for extra resource storage, rough cloth texture in dry-brush technique, ruyi-knot drawstring, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no person, no hand, no color except ink black and subtle gold

**反向提示 (Stable Diffusion)：**
person, hand, character, background, landscape, colorful, 3D, photorealistic

**状态：** Needed

---

### ASSET-089 — 吸星袋

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 法宝器物图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `artifact_xixing_dai.png` |
| 卡牌数据 | 稀有度=紫色 费用=2 效果=绑定角色每次击杀敌方偷取1费，转化为自身攻击 |

**视觉描述：**
一只深色魔纹布袋悬浮——袋身有螺旋状的吸纳纹（墨线从袋口向外呈螺旋放射），暗示吸取之力。袋口完全张开，袋内是深邃的浓墨黑暗。琉璃金光芒呈星点状从袋外被吸入袋中——光的方向不是向外辐射，而是向袋内收敛，标识「偷取」而非「产出」的本质。袋身材质以粗糙墨笔表现。

**美术圣经锚点：**
- §5.X.4 材质：魔纹织物=浓淡墨螺旋
- §5.X.4 色彩规则：琉璃金向内收敛
- §4 语义色：琉璃金=偷取标识

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a dark demonic-pattern pouch — spiral absorption runes radiating from mouth outward, mouth wide open revealing deep dark ink void, golden light particles being pulled INTO the pouch not radiating out for steal mechanic, rough dark fabric texture, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no person, no hand, no color except ink black and gold particles moving inward

**反向提示 (Stable Diffusion)：**
person, hand, character, background, landscape, colorful, 3D, photorealistic

**状态：** Needed

---

### ASSET-090 — 合欢铃

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 法宝器物图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `artifact_hehuan_ling.png` |
| 卡牌数据 | 稀有度=紫色 费用=2 效果=绑定角色魅惑概率+15% |

**视觉描述：**
一对小巧的银铃悬浮——两铃以丝线相连，铃身镂空雕花（桃花纹样）。铃舌为心形。琉璃金光芒从铃身的镂空花纹中透出——光呈涟漪状在两铃之间往返流动，标识魅惑的灵力波动。墨线纤细柔美，有女性的精致感。底部阴影轻巧如铃铛的回音。

**美术圣经锚点：**
- §5.X.4 材质：银器=淡墨精细线条
- §5.X.4 构图规则
- §4 语义色：琉璃金=魅惑灵力标识

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a pair of delicate silver bells connected by silk thread — peach-blossom openwork filigree on bell bodies, heart-shaped clappers, golden light rippling between the two bells through the filigree for charm energy, fine delicate feminine line quality, light echo-like drop shadow, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no person, no hand, no color except ink black and gold

**反向提示 (Stable Diffusion)：**
person, hand, character, background, landscape, colorful, 3D, photorealistic

**状态：** Needed

---

### ASSET-091 — 大衍罗盘

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 法宝器物图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `artifact_dayan_luopan.png` |
| 卡牌数据 | 稀有度=金色 费用=3 效果=每回合从牌库抽一张法宝牌入手牌 |

**视觉描述：**
一面精密的天文罗盘悬浮——盘面由多层同心圆环构成，每层刻有不同的天干地支符号（以极细的淡墨线刻）。罗盘中心有指南针（以留白表现磁针，指向正上方）。琉璃金光芒在罗盘的最外层圆环上缓缓旋转——光如星辰运行，有轨道的规律感。罗盘上方悬浮着一张法宝卡牌的淡墨虚影——标识每回合从牌库中召出一张法宝牌的推演之力。墨线极精密，有天文仪器般的科技美感。

**美术圣经锚点：**
- §5.X.4 材质：精密仪器=极细墨线
- §5.X.4 构图：圆盘居中占画面 45%
- §4 语义色：琉璃金=推演天机、召出法宝牌

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a precise astronomical compass — multi-layered concentric rings with heavenly-stem earthly-branch symbols in extremely fine light ink engraving, compass needle in negative space pointing upward, golden light slowly rotating along outermost ring like celestial orbit, a faint artifact-card silhouette floating above the compass center for drawing artifact cards from the deck, precise scientific-instrument linework, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no person, no hand, no color except ink black and gold

**反向提示 (Stable Diffusion)：**
person, hand, character, background, landscape, colorful, 3D, photorealistic, clock

**状态：** Needed

---

### ASSET-092 — 万灵幡

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 法宝器物图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `artifact_wanling_fan.png` |
| 卡牌数据 | 稀有度=紫色 费用=4 效果=每回合召唤一个1攻1血的小傀儡 |

**视觉描述：**
一面幡旗悬浮——幡面展开，旗面上以淡墨绘制众多小型人形轮廓（代表被召唤的傀儡）。幡杆为骨制，顶部有兽首吞口。琉璃金光芒从幡面的小傀儡图案中星星点点地亮起——每点亮一个就象征当回合的一个召唤。墨色在旗面上偏淡、在幡杆上偏浓。底部阴影呈众多小傀儡的扩散状。

**美术圣经锚点：**
- §5.X.4 材质：幡旗=淡墨轻薄 + 骨杆浓墨
- §5.X.4 构图：幡面占画面 50%
- §4 语义色：琉璃金=召唤标识

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a summoning banner — unfurled banner face with many tiny humanoid silhouettes in light ink representing summoned puppets, bone shaft with beast-head finial at top, golden light twinkling from puppet patterns one by one for per-turn summon, banner face light ink, shaft dark ink, puppet-diffusion drop shadow, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no person, no hand, no color except ink black and gold sparkles

**反向提示 (Stable Diffusion)：**
person, hand, character, background, landscape, colorful, 3D, photorealistic

**状态：** Needed

---

### ASSET-093 — 黑风旗

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 法宝器物图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `artifact_heifeng_qi.png` |
| 卡牌数据 | 稀有度=蓝色 费用=1 效果=绑定角色攻击+1，受到伤害降低5% |

**视觉描述：**
一面三角黑旗悬浮——旗面在风中飘扬（以飞白和曲线表现布的飘扬动态）。旗面中央绣有一个「风」字（行书墨迹）。琉璃金微光从旗杆顶端的小小旗尖发出——光如一点星光，标识攻防兼备的平衡。旗杆为竹制，简洁实用。墨色在旗面飘扬处有浓淡交替。

**美术圣经锚点：**
- §5.X.4 材质：织物旗面=飞白飘扬笔法
- §5.X.4 构图规则
- §4 语义色：琉璃金=攻防均衡

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a triangular black banner — flag fabric billowing in wind with flying-white and flowing curves, embroidered "风" (wind) character in running script at center, subtle golden glint from small finial at pole tip for balanced offense+defense, bamboo pole, alternating ink density in billowing areas, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no person, no hand, no color except ink black and subtle gold

**反向提示 (Stable Diffusion)：**
person, hand, character, background, landscape, colorful, 3D, photorealistic

**状态：** Needed

---

### ASSET-094 — 玄阴旗

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 法宝器物图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `artifact_xuanyin_qi.png` |
| 卡牌数据 | 稀有度=紫色 费用=4 效果=敌方全体攻击-5% |

**视觉描述：**
一面暗色长幡悬浮——幡面下垂如夜幕，表面有暗纹的阴气缭绕（以浓淡墨叠染表现暗沉之气）。幡面中央有一个向下的箭头符号——标识削弱之力。琉璃金光芒不是从幡面发出，而是在幡的下方形成一个向下的暗金色光晕——标识敌方全体攻击被吸走削弱的负面光环。幡杆为黑铁色。

**美术圣经锚点：**
- §5.X.4 材质：暗纹织物=浓淡墨叠染
- §5.X.4 色彩规则：琉璃金方向向下=削弱
- §4 语义色：琉璃金暗光=敌方削弱

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a dark long banner — drooping banner face like night curtain with dark yin-qi patterns in layered ink wash, downward-pointing arrow symbol at center for weakening, dark golden downward halo below banner for sapping enemy attack, black-iron pole, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no person, no hand, no color except ink black and dark gold

**反向提示 (Stable Diffusion)：**
person, hand, character, background, landscape, colorful, 3D, photorealistic

**状态：** Needed

---

## 全体光环/团队类法宝

### ASSET-095 — 七宝琉璃树

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 法宝器物图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `artifact_qibao_liuli_shu.png` |
| 卡牌数据 | 稀有度=金色 费用=3 效果=每回合给血量最低角色回复1血 |

**视觉描述：**
一株微型宝树悬浮——树干以浓墨皴擦表现树皮质感，七片叶子以淡墨渲染表现琉璃般的半透明质感。每片叶子的叶脉用松石青勾勒——不是叶面全部着色，仅叶脉一线——标识生命回复的七条通道。琉璃金光芒从树根处的土壤团块中微微渗出——标识每回合持续不断的回复源泉。整体造型雅致如盆景。

**美术圣经锚点：**
- §5.X.4 材质：树干=浓墨皴擦，琉璃叶=淡墨半透明
- §5.X.4 色彩规则：松石青仅叶脉一线
- §4 语义色：松石青=回复通道，琉璃金=持续回复

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a miniature treasure tree — dark ink bark texture on trunk with dry-brush technique, 7 translucent glaze-like leaves in light ink wash, each leaf vein traced in single turquoise-blue line for 7 healing channels, subtle golden glow from root-soil clump for per-turn healing source, elegant bonsai-like composition, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no person, no hand, no color except ink black, 7 thin turquoise lines, and subtle gold

**反向提示 (Stable Diffusion)：**
person, hand, character, background, landscape, colorful, 3D, photorealistic, forest, tree

**状态：** Needed

---

### ASSET-096 — 银翎玉瓶

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 法宝器物图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `artifact_yinling_yuping.png` |
| 卡牌数据 | 稀有度=紫色 费用=4 效果=每回合给队友回复1血 |

**视觉描述：**
一只白玉小瓶悬浮——瓶身修长优雅，玉质温润半透明。瓶口微微倾斜，瓶内有淡墨渲染的灵液——灵液从瓶口以极细的一线向下滴落。松石青微光从灵液的滴落轨迹中闪烁——标识每回合的生命回复。瓶身有银翎族的羽翼纹浅浮雕。琉璃金微光仅出现在瓶口灵液溢出的一瞬间。

**美术圣经锚点：**
- §5.X.4 材质：白玉=淡墨半透明温润光
- §5.X.4 构图：瓶身居中
- §4 语义色：松石青=回复标识，琉璃金=触发瞬间

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a white jade bottle — slender elegant form, warm semi-translucent jade texture, slightly tilted mouth with light ink spirit liquid dripping in single fine thread, turquoise-blue shimmer along drip trajectory for per-turn team heal, silver-feather clan wing-pattern low relief on body, micro golden glint at mouth where liquid emerges, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no person, no hand, no color except ink black, turquoise shimmer, and micro gold

**反向提示 (Stable Diffusion)：**
person, hand, character, background, landscape, colorful, 3D, photorealistic

**状态：** Needed

---

### ASSET-097 — 真灵号角

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 法宝器物图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `artifact_zhenling_haojiao.png` |
| 卡牌数据 | 稀有度=金色 费用=5 效果=所有真灵角色攻防额外+10% |

**视觉描述：**
一只古老的骨质号角悬浮——号角由不知名巨兽的角制成，表面有螺旋状的天然生长纹。号角口敞开，边缘有不规则的自然磨损。琉璃金光芒从号角口如号声般扩散而出——光呈扇形扩散，标识真灵全族的战力号令。号角根部有皮革绑带和铜环装饰。墨色在骨质部分偏暖偏淡。

**美术圣经锚点：**
- §5.X.4 材质：骨角=暖淡墨 + 天然螺旋纹
- §5.X.4 色彩规则：金色法宝琉璃金面积扩大
- §4 语义色：琉璃金=全体真灵增幅标识

**生成提示 (Midjourney)：**
Chinese ink brush still-life of an ancient bone war horn — massive unknown beast horn with natural spiral growth rings, irregular naturally-worn mouth edge, golden fan-shaped blast radiating from horn mouth like battle cry for all true-spirit clan buff, leather binding and bronze rings at root, warm light ink on bone sections, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no person, no hand, no color except ink black and gold

**反向提示 (Stable Diffusion)：**
person, hand, character, background, landscape, colorful, 3D, photorealistic, animal

**状态：** Needed

---

### ASSET-098 — 元明灯

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 法宝器物图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `artifact_yuanming_deng.png` |
| 卡牌数据 | 稀有度=金色 费用=4 效果=每回合30%概率熄灭敌方一个角色的天赋效果 |

**视觉描述：**
一盏青铜油灯悬浮——灯座为三足鼎形，灯盏中有淡墨渲染的灯油，灯芯燃烧着一朵微弱的火焰（以留白表现火焰的形状，边缘以淡墨勾勒）。琉璃金光芒从火焰的焰心周期性地向外脉动——光时而明亮时而微暗，模拟 30% 概率的不稳定性。油灯外壁有古篆铭文。

**美术圣经锚点：**
- §5.X.4 材质：青铜器=浓淡墨交替
- §5.X.4 色彩规则：琉璃金脉动=概率触发
- §4 语义色：琉璃金=概率性天赋熄灭

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a bronze oil lamp — tripod base, light ink lamp oil in bowl, wick burning a small flickering flame in negative space with light ink edges, golden light pulsing from flame core — bright then dim cyclically for 30% probability effect, ancient seal-script inscriptions on lamp body, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no person, no hand, no color except ink black and gold

**反向提示 (Stable Diffusion)：**
person, hand, character, background, landscape, colorful, 3D, photorealistic, fire

**状态：** Needed

---

### ASSET-099 — 百兽图

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 法宝器物图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `artifact_baishou_tu.png` |
| 卡牌数据 | 稀有度=紫色 费用=4 效果=所有灵兽角色攻击+1 |

**视觉描述：**
一幅卷轴画悬浮——画轴微微展开，露出画卷上以淡墨绘制的众多灵兽剪影（虎、鹤、龟、狐、蛇、鹰等）。画卷中的灵兽剪影如活物般微微颤动（以细微的墨迹偏移表现）。琉璃金光芒从画卷展开的部分沿卷轴方向流动——光如赋灵般唤醒画中灵兽。卷轴两端为玉质轴头。

**美术圣经锚点：**
- §5.X.4 材质：画卷=淡墨绘制 + 玉轴浓淡对比
- §5.X.4 构图：画卷展开占画面 45%
- §4 语义色：琉璃金=灵兽增幅标识

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a partially unrolled hanging scroll painting — light ink spirit-beast silhouettes (tiger, crane, turtle, fox, snake, eagle) subtly quivering with micro ink offsets, golden light flowing along unrolled scroll direction like awakening the painted beasts, jade roller ends, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no person, no hand, no color except ink black and gold

**反向提示 (Stable Diffusion)：**
person, hand, character, background, landscape, colorful, 3D, photorealistic, detailed animals

**状态：** Needed

---

### ASSET-100 — 大衍神炉

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 法宝器物图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `artifact_dayan_shenlu.png` |
| 卡牌数据 | 稀有度=金色 费用=4 效果=炼丹炼器必出高品质概率+15% |

**视觉描述：**
一座三足炼丹炉悬浮——炉身饱满如葫芦形，炉盖上有八卦镂空图案。炉身以浓墨渲染金属质感，炉足为兽足形（粗壮浓墨）。琉璃金光芒从炉盖的八卦镂空处溢出——光中夹杂着微小的星点（灵材升华的暗示），标识高品质炼制概率。炉身周围有淡墨的丹气蒸腾。

**美术圣经锚点：**
- §5.X.4 材质：金属炉=浓墨厚重
- §5.X.4 色彩规则：金色法宝琉璃金面积扩大
- §4 语义色：琉璃金=高品质概率标识

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a 3-legged alchemy furnace — gourd-shaped body, 8-trigram openwork patterns on lid, dark ink metallic texture, beast-paw feet in thick dark ink, golden light spilling from lid trigram openings with tiny sparkles for high-quality crafting boost, light ink alchemical steam around body, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no person, no hand, no color except ink black and gold with sparkles

**反向提示 (Stable Diffusion)：**
person, hand, character, background, landscape, colorful, 3D, photorealistic, fire

**状态：** Needed

---

### ASSET-101 — 啼魂傀儡

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 法宝器物图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `artifact_tihun_kuilei.png` |
| 卡牌数据 | 稀有度=紫色 费用=3 效果=每回合开始对敌方全体造成1点伤害 |

**视觉描述：**
一具小型机关傀儡悬浮——傀儡为人形轮廓但关节为木制球形关节（以浓墨线勾勒）。傀儡胸腔敞开，内有齿轮和发条结构（精密淡墨线刻）。琉璃金光芒从傀儡胸腔的发条结构中周期性地向外脉动——标识每回合的自动伤害触发。傀儡面部为空白——无五官，只有一道横线。底部阴影分散如音波。

**美术圣经锚点：**
- §5.X.4 材质：木制机关=浓淡墨交替精密线条
- §5.X.4 构图：人形居中
- §4 语义色：琉璃金=自动伤害触发

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a small mechanical puppet — humanoid silhouette with wooden ball-joints in dark ink lines, open chest cavity revealing gears and clockwork in fine light ink engraving, golden light pulsing periodically from chest mechanism for per-turn auto-damage, blank face with single horizontal line, sound-wave dispersed drop shadow, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no person, no face, no color except ink black and gold

**反向提示 (Stable Diffusion)：**
person, face, character, background, landscape, colorful, 3D, photorealistic

**状态：** Needed

---

### ASSET-102 — 轮回镜

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 法宝器物图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `artifact_lunhui_jing.png` |
| 卡牌数据 | 稀有度=金色 费用=5 效果=每局可复活一次核心角色，回复70%血量 |

**视觉描述：**
一面古老的青铜镜悬浮——镜面并非反射而是呈现深邃的漩涡（以淡墨同心圆向内收缩表现）。镜背有六道轮回的浮雕图案（天道、人道、阿修罗道、畜生道、饿鬼道、地狱道——以细密线刻表现）。琉璃金光芒从镜面的漩涡中心向外螺旋扩散——光如从另一个世界返回的通道，标识复活之力。镜缘有云纹包边。

**美术圣经锚点：**
- §5.X.4 材质：青铜镜=浓淡墨精细线刻
- §5.X.4 色彩规则：金色法宝琉璃金面积扩大
- §4 语义色：琉璃金=复活之力

**生成提示 (Midjourney)：**
Chinese ink brush still-life of an ancient bronze mirror — mirror face showing deep vortex of concentric light ink circles shrinking inward instead of reflection, reverse side with 6-realms-of-rebirth relief carvings in fine line engraving, golden light spiraling outward from vortex center like passage from another world for resurrection, cloud-pattern rim, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no person, no hand, no color except ink black and gold

**反向提示 (Stable Diffusion)：**
person, face, hand, reflection, character, background, landscape, colorful, 3D, photorealistic

**状态：** Needed

---

### ASSET-103 — 素女轮回镜

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 法宝器物图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `artifact_sunv_lunhui_jing.png` |
| 卡牌数据 | 稀有度=金色 费用=4 效果=绑定角色每回合净化自身1个debuff，治疗量+50% |

**视觉描述：**
一面精致的银框梳妆镜悬浮——镜面清澈如水，镜中有淡墨的波纹在向外扩散（象征净化之力推开debuff）。镜背有月宫仙女的浮雕。琉璃金光芒沿镜面的波纹边缘流动——光如月光般温柔均匀。松石青微光在镜面波纹的中心——标识治疗量的提升。镜框有缠枝花纹。

**美术圣经锚点：**
- §5.X.4 材质：银器=淡墨精细线条
- §5.X.4 色彩规则：松石青=治疗增幅
- §4 语义色：琉璃金=净化，松石青=治疗

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a delicate silver-framed dressing mirror — crystal-clear mirror face with light ink ripples expanding outward for debuff cleansing, moon-palace fairy relief on reverse, golden light flowing along ripple edges like gentle moonlight, turquoise-blue glimmer at ripple center for healing boost, entwined-flower frame pattern, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no person, no face, no color except ink black, gold, and one turquoise dot

**反向提示 (Stable Diffusion)：**
person, face, reflection, hand, character, background, landscape, colorful, 3D, photorealistic

**状态：** Needed

---

### ASSET-104 — 辟邪玉

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 法宝器物图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `artifact_bixie_yu.png` |
| 卡牌数据 | 稀有度=紫色 费用=5 效果=我方全体免疫debuff概率+20% |

**视觉描述：**
一块辟邪玉佩悬浮——玉佩为圆形，雕刻着一只辟邪神兽（狮头、有角、有翼）的侧影浮雕。玉质温润半透明，以淡墨渲染表现其通透感。琉璃金光芒在辟邪神兽的眼睛处闪烁——两个微小的金点标识全体免疫debuff的守护之力。玉佩上方有丝绦悬挂。

**美术圣经锚点：**
- §5.X.4 材质：玉器=淡墨半透明
- §5.X.4 构图：玉佩居中
- §4 语义色：琉璃金=全队免疫标识

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a circular bixie-exorcism jade pendant — beast silhouette relief (lion head, horned, winged), warm semi-translucent jade texture in light ink wash, golden light flickering from the beast's eyes as two tiny gold dots for party-wide debuff immunity guard, silk cord above, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no person, no hand, no color except ink black and two gold micro-dots

**反向提示 (Stable Diffusion)：**
person, hand, character, background, landscape, colorful, 3D, photorealistic, animal, lion

**状态：** Needed

---

### ASSET-105 — 血河旗

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 法宝器物图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `artifact_xuehe_qi.png` |
| 卡牌数据 | 稀有度=金色 费用=5 效果=所有魔道角色击杀后回复2血 |

**视觉描述：**
一面血色军旗悬浮——旗面以浓墨重染为主，边缘不规则如被战火撕裂。旗面中央绣有一个巨大的「杀」字，以朱砂红点缀「杀」字的核心一笔。琉璃金光芒从旗杆顶端向下方全体魔道辐射——光呈血红色的暗金（通过浓墨+朱砂红暗示金色），标识击杀后的全体生命回复。旗杆为黑铁长矛形。

**美术圣经锚点：**
- §5.X.4 材质：战旗=浓墨重染 + 撕裂边缘
- §5.X.4 色彩规则：朱砂红点缀「杀」
- §4 语义色：朱砂红=击杀，琉璃金=回复

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a blood-red war banner — heavy dark ink with torn battle-damaged irregular edges, giant "杀" (kill) character with single vermillion-red stroke at its core, dark-golden radiance from pole top downward for all demon-faction heal-on-kill, black-iron spear-shaped pole, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no person, no hand, no color except ink black, one vermillion stroke, and dark gold

**反向提示 (Stable Diffusion)：**
person, hand, character, background, landscape, colorful, 3D, photorealistic, blood

**状态：** Needed

---

### ASSET-106 — 苍玄令

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 法宝器物图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `artifact_cangxuan_ling.png` |
| 卡牌数据 | 稀有度=紫色 费用=5 效果=所有东域角色攻防+5% |

**视觉描述：**
一面青铜令牌悬浮——令牌长方形，上方铸有「苍玄」二字（篆书阳文），下方刻有东域地图的简化轮廓（以细线刻表现山川河流）。令牌边缘有回纹边框。琉璃金光芒从「苍玄」二字上均匀散发——光覆盖下方的东域轮廓图，标识对东域全体角色的均衡增幅。令牌有青铜的锈绿色墨染。

**美术圣经锚点：**
- §5.X.4 材质：青铜器=浓淡墨 + 锈绿染
- §5.X.4 构图规则
- §4 语义色：琉璃金=区域光环标识

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a bronze command token — rectangular, raised "苍玄" characters in seal script above, simplified Eastern Domain map contour in fine line engraving below, meander-pattern border, golden light evenly radiating from characters covering the domain map for balanced region-wide buff, bronze-green patina ink wash, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no person, no hand, no color except ink black, patina green tint, and gold

**反向提示 (Stable Diffusion)：**
person, hand, character, background, landscape, colorful, 3D, photorealistic, map

**状态：** Needed

---

### ASSET-107 — 混沌宝瓶（小成）

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 法宝器物图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `artifact_hundun_baoping_xiaocheng.png` |
| 卡牌数据 | 稀有度=金色 费用=3 效果=每回合随机抽1张牌入手牌 |

**视觉描述：**
一只古朴的宝瓶悬浮——瓶身饱满如胆形，瓶口细小。瓶身表面有混沌未分的云雾纹理（以浓淡墨渲染出翻滚的云气）。瓶口处一张淡墨卡牌虚影正在逸出——卡牌背面无字，标识「随机抽牌」的不确定性。琉璃金光芒从瓶腹深处隐约透出——光透过混沌云雾形成斑驳的光影。瓶底有三足。整体墨色偏暗偏古。

**美术圣经锚点：**
- §5.X.4 材质：古瓶=浓淡墨渲染云雾
- §5.X.4 色彩规则：琉璃金透过混沌
- §4 语义色：琉璃金=随机抽牌标识

**生成提示 (Midjourney)：**
Chinese ink brush still-life of an ancient treasure vase — gourd-shaped body with primordial chaos cloud patterns in layered dark/light ink wash, a faint card silhouette emerging from narrow mouth, golden light seeping from deep within belly through the chaos clouds in dappled patches, 3 short feet, dark antique ink tone, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no person, no hand, no color except ink black and gold

**反向提示 (Stable Diffusion)：**
person, hand, character, background, landscape, colorful, 3D, photorealistic

**状态：** Needed

---

### ASSET-108 — 混沌宝瓶（大成）

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 法宝器物图 |
| 尺寸 | 200×280px (LOD-1) / 800×800px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `artifact_hundun_baoping_dacheng.png` |
| 卡牌数据 | 稀有度=暗金 费用=5 效果=每回合随机抽2张牌入手牌 |

**视觉描述：**
小成版的全面升级——瓶身扩大 40%，混沌云雾不再是模糊的墨染而是精细的云纹雕刻（龙纹与云纹交织）。瓶口喷薄出两道清晰的卡牌虚影——两张淡墨卡牌背面交替浮现，标识每回合随机抽两张牌的强大效果。琉璃金光芒从两道虚影中强烈辐射——光量是小成版的 3 倍。宝瓶底部有「混沌初开」四字篆刻。整体气势磅礴如天地初分。

**美术圣经锚点：**
- §5.X.4 升级变体必须有明显差异
- §5.X.4 色彩规则：暗金法宝琉璃金面积最大化
- §4 语义色：琉璃金（强烈）=每回合随机抽2张牌

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a fully-realized chaos treasure vase — 40% larger body, dragon-and-cloud fine engraving replacing blurred ink wash, 2 clear beams of card silhouettes alternating at mouth, intense golden radiance 3x the lesser version from all 2 beams, "混沌初开" (primordial chaos opening) seal engraving at base, magnificent primordial creation presence, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no person, no hand, no color except ink black and intense gold

**反向提示 (Stable Diffusion)：**
person, hand, character, background, landscape, colorful, 3D, photorealistic

**状态：** Needed

---

## LOD 快速参考

| LOD | 规格 | 内容 |
|-----|------|------|
| LOD-1 | 200×280px | 完整器物图（卡牌插画区域） |
| LOD-2 | 64×90px | 器物主体裁切（战斗头像） |
| LOD-3 | 80×100px | 器物剪影（缩略图标） |