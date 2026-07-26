# 资产规范 — 功法卡运功图

> **来源**：design/gdd/card-system-design.md 第三部分
> **美术圣经**：design/art/art-bible.md §5.X.3
> **生成日期**：2026-07-26
> **审查模式**：Solo（art-director + technical-artist 代理因 API 503 不可用——技术约束按美术圣经第 8 部分推导）
> **状态**：52 个资产已规范 / 0 个已批准 / 0 个生产中 / 0 个完成

## 技术参数

| 参数 | 值 |
|------|-----|
| 规格 | 200×280px |
| 工作分辨率 | 800×1120px（4倍缩放后裁切） |
| 格式 | PSD 源文件 + PNG 导出 |
| 图层要求 | (1) 墨线骨架层 (2) 松石青真气汇聚层 (3) 朱砂红断点层（攻击型功法） (4) 题字层 |
| Godot 导入预设 | 2D Texture, Filter=Disabled, Mipmaps=Off, Compress=Lossless |
| 单张预估 | ~160KB RGBA8 → ~40KB DXT5 |
| 总计预估 | 52 张 × 40KB = ~2.1MB VRAM |

## 墨线语言速查

| 类型 | 线条风格 | 线条特征 | 适用功法类别 |
|------|----------|----------|-------------|
| 攻击型 | 锐利直线 | 从丹田向上放射的折线，有剑锋感 | 增攻、伤害、暴击类 |
| 防御/回复型 | 柔和曲线 | 环形、弧形包裹线，有护体感 | 加血、减伤、回复类 |
| 操控/控制型 | 螺旋线 | 从丹田盘旋上升的涡旋线 | 魅惑、冰冻、控制类 |
| 范围/全体型 | 放射线 | 从中央向外均匀辐射的多向线条 | 全体增益/减益光环类 |

---

## 攻击型功法（锐利直线墨迹）

### ASSET-016 — 青云剑诀

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 功法运功图 |
| 尺寸 | 200×280px (LOD-1) / 800×1120px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD 源文件 |
| 命名 | `technique_qingyun_jianjue.png` |
| 卡牌数据 | 稀有度=金色 费用=3 效果=绑定角色每回合攻击+2；绑定青锋逐影剑后效果翻倍 |

**视觉描述：**
七条锐利墨线从丹田区向上方辐射，线条折角分明如剑锋出鞘。中央汇聚区呈现剑尖对撞的菱形形态，朱砂红断点散布于每条墨线的折角处——标识每回合攻击增长的能量爆发点。右下角行书题字「青云剑诀」四字。

**美术圣经锚点：**
- §5.X.3 运功图四层构图
- §5.X.3 墨线语言：锐利直线=攻击型
- §4 语义色：朱砂红断点=攻击标识

**生成提示 (Midjourney)：**
Traditional Chinese ink wash painting of qi meridians flowing through a cultivator's body -- style "墨骨丹青" monochrome ink skeleton with vermillion red accent dots on sharp angular lines -- abstract internal energy map, 7 sharp straight lines radiating upward from dantian center, diamond-shaped convergence zone at upper center, calligraphy inscription at bottom right, transparent background, ink on rice paper texture, precise linework, Zen minimalism --ar 5:7 --no figure, no character, no face, no background scene, no color except ink black and vermillion red

**反向提示 (Stable Diffusion)：**
person, human, figure, face, portrait, landscape, background, environment, colorful, rainbow, graffiti, digital art, 3D render, photograph, realistic

**状态：** Needed

---

### ASSET-017 — 裂风拳

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 功法运功图 |
| 尺寸 | 200×280px (LOD-1) / 800×1120px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `technique_liefeng_quan.png` |
| 卡牌数据 | 稀有度=蓝色 费用=1 效果=绑定角色对单个目标伤害+2 |

**视觉描述：**
三条粗壮浓墨直线从丹田区向上爆发，线条宽度不均——起笔处浓墨重按、末端飞白散开，模拟拳劲的冲击波质感。中央汇聚区呈拳印状的圆形冲击纹，朱砂红断点凝聚于冲击纹的中心——标识拳劲的致命一击点。题字「裂风拳」以粗犷行楷书写于右下。

**美术圣经锚点：**
- §5.X.3 运功图四层构图
- §5.X.3 墨线语言：锐利直线=攻击型
- §4 语义色：朱砂红断点=攻击标识

**生成提示 (Midjourney)：**
Chinese ink wash qi circulation diagram, 3 thick bold straight brush strokes exploding upward from dantian, fist-impact circular shockwave pattern at convergence center, single vermillion red focal dot at impact center, rough calligraphy inscription, rice paper texture, transparent background -- style "墨骨丹青" --ar 5:7 --no figure, no person, no face, no landscape, no color except ink black and vermillion red

**反向提示 (Stable Diffusion)：**
person, human, figure, face, portrait, landscape, background, environment, colorful, 3D, photograph, realistic

**状态：** Needed

---

### ASSET-018 — 黑风刀法

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 功法运功图 |
| 尺寸 | 200×280px (LOD-1) / 800×1120px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `technique_heifeng_daofa.png` |
| 卡牌数据 | 稀有度=蓝色 费用=1 效果=绑定角色满血攻击+2 |

**视觉描述：**
五条弧形折线从丹田区斜向劈出——线条走势如同刀刃斩击的轨迹，起于丹田、向外斜切。中央汇聚区呈刀锋交错的十字形，朱砂红断点位于十字交叉点——标识满血一击的暴击核心。墨色偏浓，线条边缘有飞白效果模拟刀气。题字「黑风刀法」以刀刻般硬朗的隶书题于右下。

**美术圣经锚点：**
- §5.X.3 运功图四层构图
- §5.X.3 墨线语言：锐利斜线=攻击型
- §4 语义色：朱砂红断点=攻击标识

**生成提示 (Midjourney)：**
Chinese ink wash meridian map, 5 diagonal slashing brush strokes from dantian outward in blade-cut trajectories, crossed-blade convergence pattern, single vermillion red point at intersection, bold ink density with flying-white edges, rigid clerical script inscription, rice paper texture, transparent background -- style "墨骨丹青" --ar 5:7 --no figure, no person, no landscape, no color except ink and vermillion

**反向提示 (Stable Diffusion)：**
person, human, figure, face, portrait, landscape, background, colorful, realistic, photograph, 3D

**状态：** Needed

---

### ASSET-019 — 黄枫剑诀

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 功法运功图 |
| 尺寸 | 200×280px (LOD-1) / 800×1120px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `technique_huangfeng_jianjue.png` |
| 卡牌数据 | 稀有度=蓝色 费用=2 效果=绑定角色攻击+2 |

**视觉描述：**
六条中等浓度的墨线从丹田区向斜上方延伸，线型介于剑锋与枫叶脉络之间——每条线的末端有微小的分叉如枫叶尖。中央汇聚区呈剑花状漩涡，朱砂红断点如枫叶飘落般散布于漩涡边缘。题字「黄枫剑诀」以秀丽的楷书题写于右下角。

**美术圣经锚点：**
- §5.X.3 运功图四层构图
- §5.X.3 墨线语言：锐利直线=攻击型
- §4 语义色：朱砂红断点=攻击标识

**生成提示 (Midjourney)：**
Chinese ink wash internal energy diagram, 6 medium-density straight brush strokes angled upward with tiny maple-leaf-like forks at tips, sword-flower spiral convergence zone, scattered vermillion red dots like falling leaves, elegant regular script inscription, transparent background -- style "墨骨丹青" --ar 5:7 --no figure, no person, no landscape, no color except ink black and vermillion

**反向提示 (Stable Diffusion)：**
person, human, figure, portrait, landscape, background, colorful, 3D, photograph, realistic, leaf

**状态：** Needed

---

### ASSET-020 — 六道魔功

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 功法运功图 |
| 尺寸 | 200×280px (LOD-1) / 800×1120px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `technique_liudao_mogong.png` |
| 卡牌数据 | 稀有度=紫色 费用=2 效果=绑定角色攻击+2，血量上限-1 |

**视觉描述：**
六条浓墨粗线从丹田区向六个方向放射（对应六道轮回），线条粗犷不羁——大量飞白和毛边模拟魔道功法的狂暴感。中央汇聚区呈不规则的六芒星形，朱砂红断点在每条墨线的起点密集分布——标识以血换攻的代价。题字「六道魔功」以狂草书写于右下，墨迹有滴洒效果。

**美术圣经锚点：**
- §5.X.3 运功图四层构图
- §5.X.3 墨线语言：锐利直线=攻击型
- §4 语义色：朱砂红断点=攻击标识

**生成提示 (Midjourney)：**
Chinese ink wash qi flow diagram, 6 thick wild brush strokes radiating in 6 directions from dantian, irregular 6-pointed star convergence, dense vermillion red dots clustered at stroke origins, rough cursive calligraphy with ink drip effect, flying-white texture, transparent background -- style "墨骨丹青" --ar 5:7 --no figure, no person, no landscape, no color except ink black and vermillion

**反向提示 (Stable Diffusion)：**
person, human, figure, portrait, landscape, background, colorful, 3D, photograph, realistic, clean

**状态：** Needed

---

### ASSET-021 — 玄骨阴功

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 功法运功图 |
| 尺寸 | 200×280px (LOD-1) / 800×1120px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `technique_xuangu_yingong.png` |
| 卡牌数据 | 稀有度=紫色 费用=3 效果=绑定角色对正道伤害+20% |

**视觉描述：**
五条带有骨节感的墨线从丹田区向上扭曲延伸——线条在中段有骷髅关节状的结节，暗示「玄骨」之名。中央汇聚区呈碎裂的骨片放射状，朱砂红断点密集分布——标识对正道的克制伤害。整体线条偏干笔，大量枯墨飞白营造阴森感。题字「玄骨阴功」以阴刻感的篆书题于右下。

**美术圣经锚点：**
- §5.X.3 运功图四层构图
- §5.X.3 墨线语言：锐利直线=攻击型
- §4 语义色：朱砂红断点=攻击标识

**生成提示 (Midjourney)：**
Chinese ink wash qi circulation, 5 bone-jointed twisted brush strokes with skull-like knots at midpoints, shattered-bone radial convergence pattern, dense vermillion red clusters, dry brush with heavy flying-white for eerie feel, seal script inscription, transparent background -- style "墨骨丹青" --ar 5:7 --no figure, no person, no face, no landscape, no color except ink and vermillion

**反向提示 (Stable Diffusion)：**
person, human, figure, portrait, landscape, background, colorful, 3D, photograph, realistic, skeleton

**状态：** Needed

---

### ASSET-022 — 魔元淬体

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 功法运功图 |
| 尺寸 | 200×280px (LOD-1) / 800×1120px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `technique_moyuan_cuiti.png` |
| 卡牌数据 | 稀有度=紫色 费用=4 效果=绑定角色攻击+4，每回合掉1血 |

**视觉描述：**
四条极浓墨线从丹田区向上如烈火般升腾——线条粗壮、边缘焦黑干裂，模拟淬体的灼烧感。中央汇聚区呈火焰状的涡流，朱砂红断点分布于墨线中段——标识以血换力的燃烧节点。每一处朱砂红断点都与墨线的焦痕交错。题字「魔元淬体」以焦墨飞白书写于右下。

**美术圣经锚点：**
- §5.X.3 运功图四层构图
- §5.X.3 墨线语言：锐利直线=攻击型
- §4 语义色：朱砂红断点=攻击标识

**生成提示 (Midjourney)：**
Chinese ink wash internal energy map, 4 extremely dark thick brush strokes rising like flames from dantian, scorched cracked edges on lines, flame-like vortex convergence, vermillion red dots at mid-stroke burning nodes, charred-ink flying-white calligraphy, transparent background -- style "墨骨丹青" --ar 5:7 --no figure, no person, no landscape, no color except ink black and vermillion

**反向提示 (Stable Diffusion)：**
person, human, figure, portrait, landscape, background, colorful, 3D, photograph, realistic, fire

**状态：** Needed

---

### ASSET-023 — 天雷诀

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 功法运功图 |
| 尺寸 | 200×280px (LOD-1) / 800×1120px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `technique_tianlei_jue.png` |
| 卡牌数据 | 稀有度=紫色 费用=3 效果=绑定角色攻击对敌方全体造成1点溅射伤害 |

**视觉描述：**
九条锯齿状墨线从丹田区向上方炸裂——线条折角尖锐如闪电劈落。中央汇聚区呈雷暴云状的扩散圆形，朱砂红断点分布于每条墨线的每个折角处——模拟雷击的连环爆裂。线条密集处的墨色渗开如雷云。题字「天雷诀」以电击般的颤抖笔法写于右下。

**美术圣经锚点：**
- §5.X.3 运功图四层构图
- §5.X.3 墨线语言：锐利锯齿线=范围攻击型
- §4 语义色：朱砂红断点=闪电爆点

**生成提示 (Midjourney)：**
Chinese ink wash meridian chart, 9 zigzag lightning-bolt brush strokes exploding upward from dantian, thunderstorm-cloud circular diffusion convergence, vermillion red dots at every zigzag corner point, trembling brush calligraphy, ink bleed at dense stroke clusters, transparent background -- style "墨骨丹青" --ar 5:7 --no figure, no person, no landscape, no color except ink and vermillion

**反向提示 (Stable Diffusion)：**
person, human, figure, portrait, landscape, background, colorful, 3D, photograph, realistic, lightning

**状态：** Needed

---

### ASSET-024 — 冰凰玄功

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 功法运功图 |
| 尺寸 | 200×280px (LOD-1) / 800×1120px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `technique_binghuang_xuangong.png` |
| 卡牌数据 | 稀有度=紫色 费用=4 效果=绑定角色溅射伤害+1 |

**视觉描述：**
七条冰晶裂纹状的墨线从丹田区向上展开——线条细密、边缘有霜冻般的白色飞白，模拟冰裂的纹路。中央汇聚区呈雪花六角形冰晶图案，朱砂红断点位于冰晶的六个顶点——标识溅射伤害的冰爆范围。松石青点缀于冰晶中心，暗示寒气的修为属性。题字「冰凰玄功」以清瘦的瘦金体题于右下。

**美术圣经锚点：**
- §5.X.3 运功图四层构图
- §5.X.3 墨线语言：细密裂纹线=范围攻击型
- §4 语义色：朱砂红=伤害标识，松石青=冰系修为属性

**生成提示 (Midjourney)：**
Chinese ink wash qi diagram, 7 frost-crack delicate lines spreading from dantian with icy white flying-white edges, hexagonal snowflake crystal convergence pattern, vermillion red dots at 6 crystal vertices, turquoise-blue center dot for ice attribute, slender calligraphy in thin gold style, transparent background -- style "墨骨丹青" --ar 5:7 --no figure, no person, no landscape, no color except ink black, vermillion red, and one turquoise dot

**反向提示 (Stable Diffusion)：**
person, human, figure, portrait, landscape, background, colorful, 3D, photograph, realistic, snowflake, ice, bird, phoenix

**状态：** Needed

---

### ASSET-025 — 天琊剑诀

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 功法运功图 |
| 尺寸 | 200×280px (LOD-1) / 800×1120px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `technique_tianya_jianjue.png` |
| 卡牌数据 | 稀有度=金色 费用=4 效果=绑定角色攻击对魔道伤害+50% |

**视觉描述：**
八条如天剑般垂直下劈的墨线从丹田区向上斩出——线条极直、极锐、有剑脊中锋的力感。中央汇聚区呈剑阵放射状——八剑齐聚一点，朱砂红断点凝聚于交汇中心——标识对魔道的致命一击。线条边缘有金色光晕暗示（仅通过墨色浓淡暗示，不使用实际金色）。题字「天琊剑诀」以刚正的颜体正楷题于右下。

**美术圣经锚点：**
- §5.X.3 运功图四层构图
- §5.X.3 墨线语言：锐利垂直线=天罚型攻击
- §4 语义色：朱砂红断点=致命一击标识

**生成提示 (Midjourney)：**
Chinese ink wash internal energy chart, 8 vertical sword-slash brush strokes rising from dantian like heaven-sent blades, sword-array radial convergence with all lines meeting at one vermillion red focal point, ink density gradient suggesting golden glow around edges, upright regular script calligraphy, transparent background -- style "墨骨丹青" --ar 5:7 --no figure, no person, no landscape, no color except ink black and vermillion red

**反向提示 (Stable Diffusion)：**
person, human, figure, portrait, landscape, background, colorful, 3D, photograph, realistic, gold, golden

**状态：** Needed

---

### ASSET-026 — 玄天剑诀

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 功法运功图 |
| 尺寸 | 200×280px (LOD-1) / 800×1120px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `technique_xuantian_jianjue.png` |
| 卡牌数据 | 稀有度=暗金 费用=5 效果=绑定角色攻击无视30%防御 |

**视觉描述：**
十二条极浓墨线从丹田区向上方贯穿——线条密度为所有功法之最，如千剑齐发。中央汇聚区呈破碎的圆形——剑锋穿透圆形护盾的视觉效果，朱砂红断点密布于穿透点上——标识无视防御的破甲之力。松石青点缀于中央圆形的边缘，暗示被穿透的是修为防御。题字「玄天剑诀」以威严厚重的隶书题于右下。

**美术圣经锚点：**
- §5.X.3 运功图四层构图
- §5.X.3 墨线语言：锐利密集直线=破甲型攻击
- §4 语义色：朱砂红=破甲标识，松石青=防御穿透

**生成提示 (Midjourney)：**
Chinese ink wash qi map, 12 extremely dense sharp brush strokes piercing upward through a circular shield formation, shattered-circle convergence pattern with blades penetrating through, dense vermillion red dots at penetration points, turquoise-blue rim on the broken circle edge, heavy clerical script inscription, transparent background -- style "墨骨丹青" --ar 5:7 --no figure, no person, no landscape, no color except ink black, vermillion red, and one turquoise accent

**反向提示 (Stable Diffusion)：**
person, human, figure, portrait, landscape, background, colorful, 3D, photograph, realistic, sword

**状态：** Needed

---

### ASSET-027 — 血魂魔功

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 功法运功图 |
| 尺寸 | 200×280px (LOD-1) / 800×1120px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `technique_xuehun_mogong.png` |
| 卡牌数据 | 稀有度=紫色 费用=3 效果=绑定角色击杀敌方后攻击永久+1 |

**视觉描述：**
六条如血管般蜿蜒的墨线从丹田区向上延伸——线条粗细交替，模拟血脉搏动的节奏感。中央汇聚区呈滴血的心形涡旋，朱砂红断点沿墨线依次点亮——从丹田开始逐级向上，模拟击杀后的血魂攀升。整体墨色偏浓偏暖。题字「血魂魔功」以滴血效果的狂草题于右下。

**美术圣经锚点：**
- §5.X.3 运功图四层构图
- §5.X.3 墨线语言：蜿蜒上升线=成长型攻击
- §4 语义色：朱砂红断点=击杀成长标识

**生成提示 (Midjourney)：**
Chinese ink wash meridian flow, 6 vein-like pulsating brush strokes with alternating thick-thin rhythm rising from dantian, blood-drop heart-shaped vortex convergence, vermillion red dots lighting up sequentially along strokes from bottom to top, dripping-blood wild cursive calligraphy, warm dark ink tone, transparent background -- style "墨骨丹青" --ar 5:7 --no figure, no person, no landscape, no color except ink black and vermillion red

**反向提示 (Stable Diffusion)：**
person, human, figure, portrait, landscape, background, colorful, 3D, photograph, realistic, heart, blood, gore

**状态：** Needed

---

### ASSET-028 — 血影大法

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 功法运功图 |
| 尺寸 | 200×280px (LOD-1) / 800×1120px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `technique_xueying_dafa.png` |
| 卡牌数据 | 稀有度=紫色 费用=3 效果=绑定角色每掉1血，攻击+1 |

**视觉描述：**
五条由淡到浓渐变的墨线从丹田区向上攀升——每条线在三分之一处开始变浓变粗，模拟血量下降→攻击上升的转化过程。中央汇聚区呈双螺旋交织的血影状——两条螺旋线互相缠绕上升。朱砂红断点分布于墨线增粗的转折处——标识「以血换攻」的转化节点。题字「血影大法」以渐粗渐浓的变体行书题于右下。

**美术圣经锚点：**
- §5.X.3 运功图四层构图
- §5.X.3 墨线语言：渐变增粗线=转化型攻击
- §4 语义色：朱砂红=转化节点标识

**生成提示 (Midjourney)：**
Chinese ink wash qi circulation, 5 gradient brush strokes thin-to-thick rising from dantian with thickening at one-third mark, double-helix intertwined blood-shadow convergence pattern, vermillion red dots at stroke-thickening transition points, variable-weight running script calligraphy growing bolder, transparent background -- style "墨骨丹青" --ar 5:7 --no figure, no person, no landscape, no color except ink black and vermillion

**反向提示 (Stable Diffusion)：**
person, human, figure, portrait, landscape, background, colorful, 3D, photograph, realistic

**状态：** Needed

---

## 防御/回复型功法（柔和曲线墨迹）

### ASSET-029 — 枯木逢春诀

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 功法运功图 |
| 尺寸 | 200×280px (LOD-1) / 800×1120px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `technique_kumu_fengchun_jue.png` |
| 卡牌数据 | 稀有度=蓝色 费用=1 效果=绑定角色血量上限+2 |

**视觉描述：**
从丹田区向上蜿蜒的五条柔和曲线——线条如枯木生芽般在细处萌发新枝。中央汇聚区呈萌芽状的圆形——新芽从枯枝中探出，松石青点缀于新芽尖端——标识生命力的复苏。整体墨色偏淡，大量柔和的淡墨过渡。题字「枯木逢春诀」以温润的行楷题于右下。

**美术圣经锚点：**
- §5.X.3 运功图四层构图
- §5.X.3 墨线语言：柔和萌芽曲线=回复型
- §4 语义色：松石青=生命力标识

**生成提示 (Midjourney)：**
Chinese ink wash internal energy chart, 5 gentle curving brush strokes rising from dantian like withered branches sprouting new buds, sprout-shaped circular convergence, turquoise-blue dots at bud tips for life force, soft light ink transitions, warm running-regular calligraphy, transparent background -- style "墨骨丹青" --ar 5:7 --no figure, no person, no landscape, no color except ink black and turquoise accent dots

**反向提示 (Stable Diffusion)：**
person, human, figure, portrait, landscape, background, colorful, 3D, photograph, realistic, tree, plant

**状态：** Needed

---

### ASSET-030 — 枯木逢春诀总纲

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 功法运功图 |
| 尺寸 | 200×280px (LOD-1) / 800×1120px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `technique_kumu_fengchun_zonggang.png` |
| 卡牌数据 | 稀有度=紫色 费用=2 效果=全体角色血量上限+1 |

**视觉描述：**
从丹田区向外八条柔和弧线如树冠般展开——覆盖整个画面，模拟一棵大树的枝干遍布全体。中央汇聚区呈树冠状的扩散圆形，松石青点缀于每条弧线的末端——标识全队生命力的均衡提升。线条粗细均匀，有温润的毛笔圆转笔意。题字「枯木逢春诀总纲」以小字行楷题于右下。

**美术圣经锚点：**
- §5.X.3 运功图四层构图
- §5.X.3 墨线语言：放射弧线=全体回复型
- §4 语义色：松石青=全队生命力标识

**生成提示 (Midjourney)：**
Chinese ink wash qi diagram, 8 gentle arcing brush strokes spreading like tree canopy from dantian covering entire frame, tree-crown circular diffusion convergence, turquoise-blue dots at tips of each arc for party-wide life boost, even brush weight with warm round turns, small running-regular calligraphy, transparent background -- style "墨骨丹青" --ar 5:7 --no figure, no person, no landscape, no color except ink black and turquoise accent dots

**反向提示 (Stable Diffusion)：**
person, human, figure, portrait, landscape, background, colorful, 3D, photograph, realistic, tree, leaves

**状态：** Needed

---

### ASSET-031 — 圣魔护体功

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 功法运功图 |
| 尺寸 | 200×280px (LOD-1) / 800×1120px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `technique_shengmo_huti_gong.png` |
| 卡牌数据 | 稀有度=金色 费用=4 效果=绑定角色受到伤害降低30%，血量上限+4 |

**视觉描述：**
七条极粗的弧形墨线从丹田区向外环抱——线条构成一个近似护盾的椭圆形包裹住丹田区域。中央汇聚区呈多层同心椭圆——每层代表一重护体真气，松石青点缀于最内层核心——标识伤害减免的守护核心。线条饱满厚实，有铁壁般的沉稳感。题字「圣魔护体功」以庄重的楷书大字题于右下。

**美术圣经锚点：**
- §5.X.3 运功图四层构图
- §5.X.3 墨线语言：环抱弧线=护体型防御
- §4 语义色：松石青=守护核心标识

**生成提示 (Midjourney)：**
Chinese ink wash meridian map, 7 thick embracing arc strokes forming elliptical protective cocoon around dantian area, multi-layered concentric ellipse convergence, single turquoise-blue dot at innermost core, heavy solid brush weight suggesting iron-wall sturdiness, solemn regular script large calligraphy, transparent background -- style "墨骨丹青" --ar 5:7 --no figure, no person, no landscape, no color except ink black and one turquoise dot

**反向提示 (Stable Diffusion)：**
person, human, figure, portrait, landscape, background, colorful, 3D, photograph, realistic, shield, armor

**状态：** Needed

---

### ASSET-032 — 鬼王魔功

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 功法运功图 |
| 尺寸 | 200×280px (LOD-1) / 800×1120px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `technique_guiwang_mogong.png` |
| 卡牌数据 | 稀有度=紫色 费用=2 效果=绑定角色每回合回复1血 |

**视觉描述：**
四条环形墨线从丹田区向外如涟漪般扩散——线条层层环绕，间距均匀，模拟持续不断的回复节奏。中央汇聚区呈泉涌状的圆形——真气如泉水从丹田涌出、层层向外扩散。松石青点缀于泉涌中心——标识每回合的生命回复源头。墨色偏淡，线条柔和不刺目。题字「鬼王魔功」以圆润的篆书题于右下。

**美术圣经锚点：**
- §5.X.3 运功图四层构图
- §5.X.3 墨线语言：环形涟漪线=持续回复型
- §4 语义色：松石青=回复源头标识

**生成提示 (Midjourney)：**
Chinese ink wash qi circulation chart, 4 concentric ripple-like ring strokes spreading outward from dantian with even spacing, spring-well circular convergence with qi bubbling upward, turquoise-blue dot at spring source, light ink density with gentle non-aggressive curves, rounded seal script calligraphy, transparent background -- style "墨骨丹青" --ar 5:7 --no figure, no person, no landscape, no color except ink black and one turquoise dot

**反向提示 (Stable Diffusion)：**
person, human, figure, portrait, landscape, background, colorful, 3D, photograph, realistic, ghost, demon

**状态：** Needed

---

### ASSET-033 — 碎星玄功

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 功法运功图 |
| 尺寸 | 200×280px (LOD-1) / 800×1120px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `technique_suixing_xuangong.png` |
| 卡牌数据 | 稀有度=紫色 费用=2 效果=绑定角色受到伤害降低10% |

**视觉描述：**
六条弧形墨线从丹田区向外如星轨般环绕——线条如星体运行的椭圆轨道，每层轨道微微偏移角度。中央汇聚区呈星核状的密集圆点——模拟碎星汇聚的光芒，松石青微光分布于星核外围——标识减伤的星辰庇护。线条细而均匀，有天文图般的精密感。题字「碎星玄功」以清瘦的行书小字题于右下。

**美术圣经锚点：**
- §5.X.3 运功图四层构图
- §5.X.3 墨线语言：星轨弧线=减伤型防御
- §4 语义色：松石青=星辰庇护标识

**生成提示 (Midjourney)：**
Chinese ink wash internal energy diagram, 6 elliptical orbital arc strokes circling dantian like star trajectories at slightly offset angles, star-core dense dot convergence, faint turquoise-blue glow at core periphery for stellar protection, thin precise lines like astronomical chart, slender running script small calligraphy, transparent background -- style "墨骨丹青" --ar 5:7 --no figure, no person, no landscape, no color except ink black and subtle turquoise

**反向提示 (Stable Diffusion)：**
person, human, figure, portrait, landscape, background, colorful, 3D, photograph, realistic, stars, galaxy, space

**状态：** Needed

---

### ASSET-034 — 正天罡气

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 功法运功图 |
| 尺寸 | 200×280px (LOD-1) / 800×1120px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `technique_zhengtian_gangqi.png` |
| 卡牌数据 | 稀有度=紫色 费用=2 效果=绑定角色受到伤害降低15% |

**视觉描述：**
四条方正刚直的弧形墨线从丹田区向外展开——线条虽为曲线却带有方正之气，弧度接近正方形圆角。中央汇聚区呈方盾形的守护印——四角对应天地四方，松石青点缀于方盾中心——标识正道的减伤护体。线条粗壮均匀，有铁壁铜墙的不可撼动感。题字「正天罡气」以方正的魏碑体题于右下。

**美术圣经锚点：**
- §5.X.3 运功图四层构图
- §5.X.3 墨线语言：方正弧线=刚正型防御
- §4 语义色：松石青=正道护体标识

**生成提示 (Midjourney)：**
Chinese ink wash qi map, 4 square-arc brush strokes expanding from dantian with rigid curvature like rounded square corners, square-shield guardian seal convergence, turquoise-blue dot at shield center for righteous protection, thick even brush weight suggesting immovable fortress, square Wei-stele style calligraphy, transparent background -- style "墨骨丹青" --ar 5:7 --no figure, no person, no landscape, no color except ink black and one turquoise dot

**反向提示 (Stable Diffusion)：**
person, human, figure, portrait, landscape, background, colorful, 3D, photograph, realistic, shield

**状态：** Needed

---

### ASSET-035 — 苍玄元气功

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 功法运功图 |
| 尺寸 | 200×280px (LOD-1) / 800×1120px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `technique_cangxuan_yuanqi_gong.png` |
| 卡牌数据 | 稀有度=蓝色 费用=3 效果=绑定角色血量上限+3 |

**视觉描述：**
五条温和饱满的弧形墨线从丹田区向上如气球般鼓起——线条圆润丰腴，有充盈之感。中央汇聚区呈饱满的气球形——模拟元气充沛的气海形态，松石青点缀于气球中央——标识血量上限的提升。墨色醇厚不刺目，线条间距均匀。题字「苍玄元气功」以饱满的楷书题于右下。

**美术圣经锚点：**
- §5.X.3 运功图四层构图
- §5.X.3 墨线语言：饱满弧线=增益型防御
- §4 语义色：松石青=生命上限提升标识

**生成提示 (Midjourney)：**
Chinese ink wash internal energy chart, 5 plump full arc strokes rising from dantian like gently inflated balloons, full balloon-shaped qi-sea convergence, turquoise-blue dot at center for max HP boost, mellow dark ink without harshness, plump regular script calligraphy, transparent background -- style "墨骨丹青" --ar 5:7 --no figure, no person, no landscape, no color except ink black and one turquoise dot

**反向提示 (Stable Diffusion)：**
person, human, figure, portrait, landscape, background, colorful, 3D, photograph, realistic, balloon

**状态：** Needed

---

### ASSET-036 — 星斗护体功

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 功法运功图 |
| 尺寸 | 200×280px (LOD-1) / 800×1120px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `technique_xingdou_huti_gong.png` |
| 卡牌数据 | 稀有度=蓝色 费用=2 效果=绑定角色防御+1 |

**视觉描述：**
七条细小弧形墨线如北斗七星般从丹田区向上排列——每条线短小而精悍，对应一颗星位。中央汇聚区呈北斗勺形的星群排列——七星连线形成斗柄斗勺，松石青微光点缀于勺口处——标识防御力的星辰加持。线条细而不弱，有星光的穿透感。题字「星斗护体功」以星点般的小楷题于右下。

**美术圣经锚点：**
- §5.X.3 运功图四层构图
- §5.X.3 墨线语言：星位弧线=防御增幅型
- §4 语义色：松石青=星辰防御标识

**生成提示 (Midjourney)：**
Chinese ink wash meridian chart, 7 small precise arc strokes arranged in Big Dipper constellation pattern rising from dantian, dipper-shaped star-group convergence, faint turquoise-blue glimmer at dipper mouth for stellar defense boost, thin but penetrating line quality like starlight, star-dot small regular calligraphy, transparent background -- style "墨骨丹青" --ar 5:7 --no figure, no person, no landscape, no color except ink black and subtle turquoise

**反向提示 (Stable Diffusion)：**
person, human, figure, portrait, landscape, background, colorful, 3D, photograph, realistic, stars, constellation

**状态：** Needed

---

### ASSET-037 — 银翎灵诀

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 功法运功图 |
| 尺寸 | 200×280px (LOD-1) / 800×1120px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `technique_yinling_lingjue.png` |
| 卡牌数据 | 稀有度=金色 费用=3 效果=绑定角色受到伤害降低15%，全队受到伤害额外降低3% |

**视觉描述：**
从丹田区向外展开的三层弧形羽翼状墨线——内层厚实（自身减伤15%），外两层轻灵薄透（全队减伤3%），模拟银翎族的羽翼庇护。中央汇聚区呈羽毛层叠的扇形，松石青点缀于内层羽根——标识自身核心防护，外层羽尖散布着更淡的松石青微粒——标识全队光环。题字「银翎灵诀」以纤细灵动的行书题于右下。

**美术圣经锚点：**
- §5.X.3 运功图四层构图
- §5.X.3 墨线语言：羽翼弧线=光环型防御
- §4 语义色：松石青=自身+团队双重防护

**生成提示 (Midjourney)：**
Chinese ink wash qi diagram, 3 layered feather-wing arc strokes spreading from dantian — inner layer solid, outer 2 layers light and translucent, feather-fan layered convergence, turquoise-blue dot at inner wing root, fainter turquoise particles at outer wing tips for party aura, delicate flowing running script calligraphy, transparent background -- style "墨骨丹青" --ar 5:7 --no figure, no person, no landscape, no color except ink black and turquoise with opacity variation

**反向提示 (Stable Diffusion)：**
person, human, figure, portrait, landscape, background, colorful, 3D, photograph, realistic, wings, feathers, bird

**状态：** Needed

---

### ASSET-038 — 灵狐诀

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 功法运功图 |
| 尺寸 | 200×280px (LOD-1) / 800×1120px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `technique_linghu_jue.png` |
| 卡牌数据 | 稀有度=紫色 费用=4 效果=绑定角色受到伤害降低15% |

**视觉描述：**
六条灵巧柔滑的弧线从丹田区向外如狐尾般环绕——线条纤细、转折灵动，有狡黠的躲避感。中央汇聚区呈九尾扇形——虽只六条线但有九尾的暗示（三隐三现），松石青点缀于扇形中心——标识灵狐的庇护核心。墨色偏淡，线条飘逸有丝绸感。题字「灵狐诀」以俏丽的瘦金体题于右下。

**美术圣经锚点：**
- §5.X.3 运功图四层构图
- §5.X.3 墨线语言：柔滑弧线=灵巧型防御
- §4 语义色：松石青=灵兽庇护标识

**生成提示 (Midjourney)：**
Chinese ink wash internal energy chart, 6 sleek graceful arc strokes curling around dantian like fox tails with nimble dodging feel, nine-tail fan suggestion with 3 hidden and 3 visible, turquoise-blue dot at fan center for fox spirit protection, light ink density with silky flowing curves, charming slender gold-style calligraphy, transparent background -- style "墨骨丹青" --ar 5:7 --no figure, no person, no landscape, no color except ink black and one turquoise dot

**反向提示 (Stable Diffusion)：**
person, human, figure, portrait, landscape, background, colorful, 3D, photograph, realistic, fox, animal, tail

**状态：** Needed

---

### ASSET-039 — 归墟之境心经

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 功法运功图 |
| 尺寸 | 200×280px (LOD-1) / 800×1120px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `technique_guixuzhijing_xinjing.png` |
| 卡牌数据 | 稀有度=蓝色 费用=4 效果=绑定角色攻防各+2 |

**视觉描述：**
八条平衡对称的弧线从丹田区向四周均衡展开——四条向上弧（攻击增长）+ 四条向下弧（防御增长），形成完美的上下镜像对称。中央汇聚区呈阴阳太极形的平衡图案——松石青点缀于太极的阳眼，标识攻防均衡的增长核心。墨线粗细均匀，有精密的天平感。题字「归墟之境心经」以端正的小楷居中题于右下。

**美术圣经锚点：**
- §5.X.3 运功图四层构图
- §5.X.3 墨线语言：均衡对称弧线=双属性增益
- §4 语义色：松石青=攻防平衡标识

**生成提示 (Midjourney)：**
Chinese ink wash qi circulation map, 8 balanced symmetric arcs — 4 rising, 4 descending — spreading evenly from dantian, yin-yang taiji balance convergence pattern, turquoise-blue dot at yang eye for balanced dual-stat boost, precise even brush weight like a balance scale, upright small regular calligraphy, transparent background -- style "墨骨丹青" --ar 5:7 --no figure, no person, no landscape, no color except ink black and one turquoise dot

**反向提示 (Stable Diffusion)：**
person, human, figure, portrait, landscape, background, colorful, 3D, photograph, realistic, yin yang

**状态：** Needed

---

### ASSET-040 — 真灵涅槃功

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 功法运功图 |
| 尺寸 | 200×280px (LOD-1) / 800×1120px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `technique_zhenling_niepan_gong.png` |
| 卡牌数据 | 稀有度=金色 费用=3 效果=绑定角色可复活一次，回复50%血量 |

**视觉描述：**
从丹田区向下的五条弧线沉入画面底部，然后从底部以更淡的墨色重新向上攀升——形成「下沉→重生」的双重弧线结构。中央汇聚区呈凤凰涅槃状的火焰形涡旋——下沉线条汇聚于此，松石青点缀于重生上升线的起点——标识复活的生命力回归。墨色有沉入淡出再渐浓的循环感。题字「真灵涅槃功」以浴火重生般的有力行书题于右下。

**美术圣经锚点：**
- §5.X.3 运功图四层构图
- §5.X.3 墨线语言：下沉再升弧线=复活型
- §4 语义色：松石青=重生标识

**生成提示 (Midjourney)：**
Chinese ink wash internal energy diagram, 5 descending-then-ascending arc strokes — sink from dantian to bottom then rise again in lighter ink, phoenix-flame vortex convergence at bottom, turquoise-blue dot at rebirth ascension point, cyclic ink density fading then strengthening, powerful running script calligraphy, transparent background -- style "墨骨丹青" --ar 5:7 --no figure, no person, no landscape, no color except ink black and one turquoise dot

**反向提示 (Stable Diffusion)：**
person, human, figure, portrait, landscape, background, colorful, 3D, photograph, realistic, phoenix, fire, bird

**状态：** Needed

---

### ASSET-041 — 素女轮回功

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 功法运功图 |
| 尺寸 | 200×280px (LOD-1) / 800×1120px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `technique_sunv_lunhui_gong.png` |
| 卡牌数据 | 稀有度=紫色 费用=2 效果=绑定角色治疗效果提升100% |

**视觉描述：**
四条柔和如丝带的弧线从丹田区向上螺旋环绕——线条细腻绵长，如女性长袖舞动的轨迹。中央汇聚区呈水滴形的生命之源——从丹田涌出如水滴落，松石青在水滴中心浓郁发光——标识治疗效果翻倍的灵力源泉。墨线纤细柔美，有丝绸的顺滑感。题字「素女轮回功」以婉约的簪花小楷题于右下。

**美术圣经锚点：**
- §5.X.3 运功图四层构图
- §5.X.3 墨线语言：丝带螺旋线=治疗增幅型
- §4 语义色：松石青=治疗灵力源泉

**生成提示 (Midjourney)：**
Chinese ink wash qi flow chart, 4 soft ribbon-like spiral arcs circling upward from dantian like flowing sleeves, water-drop life-source convergence, concentrated turquoise-blue glow at drop center for healing power doubling, fine delicate feminine line quality with silk smoothness, graceful flower-pin small regular calligraphy, transparent background -- style "墨骨丹青" --ar 5:7 --no figure, no person, no landscape, no color except ink black and turquoise

**反向提示 (Stable Diffusion)：**
person, human, figure, portrait, landscape, background, colorful, 3D, photograph, realistic, woman, silk

**状态：** Needed

---

## 操控/控制型功法（螺旋线墨迹）

### ASSET-042 — 合欢迷魂诀

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 功法运功图 |
| 尺寸 | 200×280px (LOD-1) / 800×1120px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `technique_hehuan_mihun_jue.png` |
| 卡牌数据 | 稀有度=紫色 费用=2 效果=绑定角色魅惑概率提升10% |

**视觉描述：**
从丹田区向上螺旋缠绕的三条涡旋线——线条如桃花花瓣飘落的轨迹，旋转中带有迷离的诱惑感。中央汇聚区呈桃花形的涡旋——外层旋转方向与内层相反，营造视觉上的催眠效果。松石青与朱砂红交替点缀于螺旋节点上——标识魅惑的灵力波动。墨色偏淡偏柔，有氤氲的暧昧感。题字「合欢迷魂诀」以妩媚的行草题于右下。

**美术圣经锚点：**
- §5.X.3 运功图四层构图
- §5.X.3 墨线语言：反向双螺旋=催眠型控制
- §4 语义色：松石青+朱砂红交替=精神控制标识

**生成提示 (Midjourney)：**
Chinese ink wash meridian diagram, 3 spiral vortex strokes coiling upward from dantian like falling peach blossom trajectories, peach-blossom-shaped vortex convergence with outer layer spinning opposite to inner for hypnotic effect, alternating turquoise-blue and vermillion-red dots at spiral nodes for charm energy, soft light ink with hazy ambiguous atmosphere, seductive running-cursive calligraphy, transparent background -- style "墨骨丹青" --ar 5:7 --no figure, no person, no landscape, no color except ink black, turquoise, and vermillion dots

**反向提示 (Stable Diffusion)：**
person, human, figure, portrait, landscape, background, colorful, 3D, photograph, realistic, flower, peach

**状态：** Needed

---

### ASSET-043 — 极阴玄冰功

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 功法运功图 |
| 尺寸 | 200×280px (LOD-1) / 800×1120px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `technique_jiyin_xuanbing_gong.png` |
| 卡牌数据 | 稀有度=紫色 费用=2 效果=绑定角色攻击有20%概率冰冻目标一回合 |

**视觉描述：**
从丹田区向上缓慢螺旋的五条冰晶裂纹线——线条在旋转中逐渐凝结，每一圈螺旋都比上一圈更密集——模拟寒气逐渐冻结的过程。中央汇聚区呈冰花六角形的凝结态——螺旋线在核心处止步、冻结成冰晶。松石青浓郁分布于冰晶核心——标识冰冻控制效力的冰寒源头。墨线有冰裂的脆硬质感。题字「极阴玄冰功」以瘦硬的仿宋体题于右下。

**美术圣经锚点：**
- §5.X.3 运功图四层构图
- §5.X.3 墨线语言：凝结型螺旋=冰冻控制
- §4 语义色：松石青浓郁=冰冻源头标识

**生成提示 (Midjourney)：**
Chinese ink wash qi circulation, 5 frost-crack spiral strokes slowly coiling upward from dantian with each loop denser than the last, hexagonal ice-flower frozen convergence where spiral stops and crystallizes, concentrated turquoise-blue at ice core for freeze control source, brittle crackled line texture, thin hard calligraphy, transparent background -- style "墨骨丹青" --ar 5:7 --no figure, no person, no landscape, no color except ink black and turquoise

**反向提示 (Stable Diffusion)：**
person, human, figure, portrait, landscape, background, colorful, 3D, photograph, realistic, ice, snow, frost

**状态：** Needed

---

### ASSET-044 — 元阴锁魂功

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 功法运功图 |
| 尺寸 | 200×280px (LOD-1) / 800×1120px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `technique_yuanyin_suohun_gong.png` |
| 卡牌数据 | 稀有度=紫色 费用=4 效果=绑定角色控制概率提升15% |

**视觉描述：**
六条如锁链般的螺旋线从丹田区向外延伸——每条线在旋转中形成环环相扣的链状结构，模拟锁魂的束缚感。中央汇聚区呈多重锁扣交织的圆形——每个锁扣都与另一条螺旋线相连，形成不可挣脱的困锁结构。松石青点缀于每个锁扣的连接处——标识控制力的强化节点。墨线粗中有细，有金属锁链的质感。题字「元阴锁魂功」以铁线般的篆书题于右下。

**美术圣经锚点：**
- §5.X.3 运功图四层构图
- §5.X.3 墨线语言：锁链型螺旋=强力控制
- §4 语义色：松石青=控制节点标识

**生成提示 (Midjourney)：**
Chinese ink wash internal energy map, 6 chain-link spiral strokes extending outward from dantian forming interlocking rings, multi-lock circular convergence with each lock connecting to another spiral for inescapable binding, turquoise-blue dots at each lock junction for control strength nodes, chain-like metal texture in brushwork, iron-line seal script calligraphy, transparent background -- style "墨骨丹青" --ar 5:7 --no figure, no person, no landscape, no color except ink black and turquoise dots

**反向提示 (Stable Diffusion)：**
person, human, figure, portrait, landscape, background, colorful, 3D, photograph, realistic, chains, metal

**状态：** Needed

---

### ASSET-045 — 啼魂镇魂诀

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 功法运功图 |
| 尺寸 | 200×280px (LOD-1) / 800×1120px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `technique_tihun_zhenhun_jue.png` |
| 卡牌数据 | 稀有度=紫色 费用=3 效果=绑定角色对魔物伤害翻倍 |

**视觉描述：**
从丹田区向上螺旋的五条惊涛骇浪般的旋转线——线条粗犷有力，旋转速度感极强，模拟啼魂兽的震慑吼声。中央汇聚区呈音波扩散的同心涡旋——从核心向外层层扩散的声波纹。朱砂红分布于每个声波纹的波峰——标识对魔物的双倍伤害节点。墨线浓重有冲击力。题字「啼魂镇魂诀」以吼声般粗犷的行书题于右下。

**美术圣经锚点：**
- §5.X.3 运功图四层构图
- §5.X.3 墨线语言：爆发型螺旋=震慑控制
- §4 语义色：朱砂红=魔物克制伤害标识

**生成提示 (Midjourney)：**
Chinese ink wash qi diagram, 5 powerful surging spiral strokes coiling upward from dantian with intense rotational speed, sound-wave concentric vortex convergence rippling outward from core, vermillion red dots at each wave crest for double damage against demons, heavy bold ink with percussive impact, rough powerful running script calligraphy, transparent background -- style "墨骨丹青" --ar 5:7 --no figure, no person, no landscape, no color except ink black and vermillion red

**反向提示 (Stable Diffusion)：**
person, human, figure, portrait, landscape, background, colorful, 3D, photograph, realistic, animal, beast, sound

**状态：** Needed

---

### ASSET-046 — 万化归元功

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 功法运功图 |
| 尺寸 | 200×280px (LOD-1) / 800×1120px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `technique_wanhua_guiyuan_gong.png` |
| 卡牌数据 | 稀有度=紫色 费用=3 效果=绑定角色每回合净化自身一个debuff |

**视觉描述：**
从丹田区向上旋转的五条净化螺旋——线条从浓到淡、从浊到清——下层墨色浓郁（代表debuff杂质）、上层墨色清透（代表净化后的纯净真气）。中央汇聚区呈过滤状的漏斗形——浊气从下方进入、清气从上方逸出。松石青点缀于清气的逸出端——标识净化完成后的纯净状态。墨线有从混沌到清明的渐变感。题字「万化归元功」以清透的楷书题于右下。

**美术圣经锚点：**
- §5.X.3 运功图四层构图
- §5.X.3 墨线语言：净化渐变螺旋=debuff清除型
- §4 语义色：松石青=净化完成标识

**生成提示 (Midjourney)：**
Chinese ink wash meridian chart, 5 purifying spiral strokes rising from dantian with gradient from dark/turbid at bottom to light/clear at top, funnel-filter convergence with turbid qi entering below and clear qi emerging above, turquoise-blue dot at clear qi exit for purified state, ink density gradient from chaotic to crystal-clear, crisp regular script calligraphy, transparent background -- style "墨骨丹青" --ar 5:7 --no figure, no person, no landscape, no color except ink black gradient and one turquoise dot

**反向提示 (Stable Diffusion)：**
person, human, figure, portrait, landscape, background, colorful, 3D, photograph, realistic, water, filter

**状态：** Needed

---

### ASSET-047 — 大衍清心诀

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 功法运功图 |
| 尺寸 | 200×280px (LOD-1) / 800×1120px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `technique_dayan_qingxin_jue.png` |
| 卡牌数据 | 稀有度=紫色 费用=2 效果=绑定角色免疫debuff概率+15% |

**视觉描述：**
从丹田区向上平稳螺旋的四条清静线条——螺旋节奏均匀缓慢，有冥想般的宁静感。中央汇聚区呈莲花座形的清净圆——莲花瓣层层展开，松石青点缀于莲心——标识心灵清净、不受外邪侵扰。墨线纤细清雅，无任何飞白或毛边。题字「大衍清心诀」以静穆的楷书题于右下。

**美术圣经锚点：**
- §5.X.3 运功图四层构图
- §5.X.3 墨线语言：平稳螺旋=心灵防御型
- §4 语义色：松石青=清净心智标识

**生成提示 (Midjourney)：**
Chinese ink wash internal energy chart, 4 serene steady spiral strokes rising from dantian with slow meditative rhythm, lotus-throne circular convergence with petals unfolding layer by layer, turquoise-blue dot at lotus heart for mental clarity against debuffs, fine elegant lines without any rough edges, tranquil regular script calligraphy, transparent background -- style "墨骨丹青" --ar 5:7 --no figure, no person, no landscape, no color except ink black and one turquoise dot

**反向提示 (Stable Diffusion)：**
person, human, figure, portrait, landscape, background, colorful, 3D, photograph, realistic, lotus, flower

**状态：** Needed

---

## 范围/全体型功法（放射线墨迹）

### ASSET-048 — 苍玄正功总纲

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 功法运功图 |
| 尺寸 | 200×280px (LOD-1) / 800×1120px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `technique_cangxuan_zhenggong_zonggang.png` |
| 卡牌数据 | 稀有度=紫色 费用=3 效果=全体角色攻击+10% |

**视觉描述：**
从丹田区向外均匀放射的九条直线——覆盖整个画面，每条线等角度分布，形成完美的放射状对称。中央汇聚区呈太阳光芒状的扩散圆——从丹田核心向外层层扩散的光辉。朱砂红点缀于每条放射线中段——标识全体攻击力的同步增长。墨线均匀有力，有号令天下的气势。题字「苍玄正功总纲」以端正的楷书大字题于右下。

**美术圣经锚点：**
- §5.X.3 运功图四层构图
- §5.X.3 墨线语言：均匀放射线=全体增益型
- §4 语义色：朱砂红=全队攻击增幅标识

**生成提示 (Midjourney)：**
Chinese ink wash qi circulation map, 9 evenly spaced straight lines radiating from dantian in all directions covering entire frame, sun-ray circular diffusion convergence, vermillion red dot at midpoint of each radial line for synchronized party attack boost, uniform powerful brushwork with commanding presence, upright regular script large calligraphy, transparent background -- style "墨骨丹青" --ar 5:7 --no figure, no person, no landscape, no color except ink black and vermillion red dots

**反向提示 (Stable Diffusion)：**
person, human, figure, portrait, landscape, background, colorful, 3D, photograph, realistic, sun

**状态：** Needed

---

### ASSET-049 — 归墟之境百族总图

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 功法运功图 |
| 尺寸 | 200×280px (LOD-1) / 800×1120px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `technique_guixuzhijing_baizu_zongtu.png` |
| 卡牌数据 | 稀有度=金色 费用=4 效果=全体角色受到伤害降低8% |

**视觉描述：**
从丹田区向外放射的十二条弧形辐射线——每条线末端有不同的族纹符号（百族标记）。中央汇聚区呈万花筒般的多族徽记交织圆——百族之力汇聚一体。松石青点缀于核心，向外渐淡散布于每条弧线——标识百族共担伤害的守护网络。墨线精细有图腾感。题字「归墟之境百族总图」以古朴的篆隶题于右下。

**美术圣经锚点：**
- §5.X.3 运功图四层构图
- §5.X.3 墨线语言：族纹放射线=多种族光环
- §4 语义色：松石青=百族共护标识

**生成提示 (Midjourney)：**
Chinese ink wash internal energy diagram, 12 curved radiating strokes from dantian with different clan emblem symbols at each tip, kaleidoscope multi-clan crest convergence, turquoise-blue dot at core fading outward along each arc for clan-wide shared protection network, fine totemic line detail, archaic seal-clerical calligraphy, transparent background -- style "墨骨丹青" --ar 5:7 --no figure, no person, no landscape, no color except ink black and turquoise gradient

**反向提示 (Stable Diffusion)：**
person, human, figure, portrait, landscape, background, colorful, 3D, photograph, realistic, totem

**状态：** Needed

---

### ASSET-050 — 百族战诀

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 功法运功图 |
| 尺寸 | 200×280px (LOD-1) / 800×1120px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `technique_baizu_zhanjue.png` |
| 卡牌数据 | 稀有度=紫色 费用=3 效果=所有归墟之境百族攻击+1 |

**视觉描述：**
从丹田区向外放射的十条带有不同兵器剪影的放射线——每条线末端隐约浮现一种百族武器的轮廓（刀、枪、斧、矛等）。中央汇聚区呈兵器轮转的圆形——百族兵器环绕丹田。朱砂红点缀于每条兵器的刃尖——标识百族统一的战斗增幅。墨线刚劲有力，有战阵的肃杀感。题字「百族战诀」以刀劈斧凿般的隶书题于右下。

**美术圣经锚点：**
- §5.X.3 运功图四层构图
- §5.X.3 墨线语言：兵器放射线=种族增益型
- §4 语义色：朱砂红=战斗增幅标识

**生成提示 (Midjourney)：**
Chinese ink wash qi diagram, 10 radiating strokes from dantian with subtle weapon silhouette suggestions at each tip — blades, spears, axes, halberds, weapon-wheel circular convergence, vermillion red dot at each weapon's edge for unified battle boost, strong angular brushwork with battle-formation severity, chiseled clerical script calligraphy, transparent background -- style "墨骨丹青" --ar 5:7 --no figure, no person, no landscape, no color except ink black and vermillion red dots

**反向提示 (Stable Diffusion)：**
person, human, figure, portrait, landscape, background, colorful, 3D, photograph, realistic, weapons, war

**状态：** Needed

---

### ASSET-051 — 魔道血契

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 功法运功图 |
| 尺寸 | 200×280px (LOD-1) / 800×1120px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `technique_modao_xueqi.png` |
| 卡牌数据 | 稀有度=紫色 费用=4 效果=全体魔道攻击+10%，血量上限-1 |

**视觉描述：**
从丹田区向外放射的八条如血色契约般的暗色墨线——线条粗粝有滴血效果，从丹田中心向外扩散时逐渐变淡——暗示以血换攻的代价。中央汇聚区呈血契烙印的圆环——不规则的烙印纹理环绕丹田。朱砂红在每条线的起点浓郁分布——标识以血换攻的交易节点。墨色偏暗偏暖。题字「魔道血契」以滴血效果的狂草题于右下。

**美术圣经锚点：**
- §5.X.3 运功图四层构图
- §5.X.3 墨线语言：滴血放射线=代价型全体增益
- §4 语义色：朱砂红浓郁=血之代价标识

**生成提示 (Midjourney)：**
Chinese ink wash meridian map, 8 dark radiating strokes from dantian with blood-drip effect fading outward, blood-pact brand circular convergence with irregular brand texture, dense vermillion red at each stroke origin for blood-for-power transaction nodes, dark warm ink tone, dripping-blood wild cursive calligraphy, transparent background -- style "墨骨丹青" --ar 5:7 --no figure, no person, no landscape, no color except ink black and dense vermillion red

**反向提示 (Stable Diffusion)：**
person, human, figure, portrait, landscape, background, colorful, 3D, photograph, realistic, blood, gore

**状态：** Needed

---

### ASSET-052 — 正道护体

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 功法运功图 |
| 尺寸 | 200×280px (LOD-1) / 800×1120px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `technique_zhengdao_huti.png` |
| 卡牌数据 | 稀有度=紫色 费用=4 效果=全体正道血量上限+2，攻击-5% |

**视觉描述：**
从丹田区向外放射的七条方正直线——线条端正沉稳，形成如城墙般的防护散射。中央汇聚区呈盾牌形——方盾的核心是松石青标识的生命守护，盾的边缘略微有向内的收缩（标识攻击-5%的代价）。线条粗壮均匀，有坚不可摧的正道气概。题字「正道护体」以雄浑的颜体楷书题于右下。

**美术圣经锚点：**
- §5.X.3 运功图四层构图
- §5.X.3 墨线语言：方正放射线=防御型光环
- §4 语义色：松石青=生命守护标识

**生成提示 (Midjourney)：**
Chinese ink wash qi circulation, 7 square upright radiating lines from dantian forming fortress-wall protective spread, shield-shaped convergence with turquoise-blue life-guardian core and slightly inward-tapered edges, thick even brushwork with unbreakable righteous presence, bold Yan-style regular script calligraphy, transparent background -- style "墨骨丹青" --ar 5:7 --no figure, no person, no landscape, no color except ink black and turquoise dot

**反向提示 (Stable Diffusion)：**
person, human, figure, portrait, landscape, background, colorful, 3D, photograph, realistic, shield, wall

**状态：** Needed

---

### ASSET-053 — 大衍阵图

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 功法运功图 |
| 尺寸 | 200×280px (LOD-1) / 800×1120px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `technique_dayan_zhentu.png` |
| 卡牌数据 | 稀有度=金色 费用=4 效果=每两回合额外多抽1张牌 |

**视觉描述：**
从丹田区向外放射的八条如活页般翻动的弧线——每条线在中段有一个折叠转折，模拟牌页被翻动的视觉效果。中央汇聚区呈翻书状的层叠圆——上层与下层错开，形成「两回合翻一页」的节奏暗示。松石青点缀于翻页节点——标识额外的抽牌机会。墨线灵动有纸张翻飞感。题字「大衍阵图」以清秀的行楷题于右下。

**美术圣经锚点：**
- §5.X.3 运功图四层构图
- §5.X.3 墨线语言：翻页弧线=抽牌增益型
- §4 语义色：松石青=额外抽牌标识

**生成提示 (Midjourney)：**
Chinese ink wash internal energy chart, 8 page-turning arc strokes radiating from dantian with fold at midpoint like flipping card pages, layered book-flip circular convergence with upper and lower layers offset for rhythmic draw timing, turquoise-blue dot at page-turn node for extra draw, lively paper-fluttering line quality, elegant running-regular calligraphy, transparent background -- style "墨骨丹青" --ar 5:7 --no figure, no person, no landscape, no color except ink black and one turquoise dot

**反向提示 (Stable Diffusion)：**
person, human, figure, portrait, landscape, background, colorful, 3D, photograph, realistic, book, pages

**状态：** Needed

---

### ASSET-054 — 大衍算天诀

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 功法运功图 |
| 尺寸 | 200×280px (LOD-1) / 800×1120px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `technique_dayan_suantian_jue.png` |
| 卡牌数据 | 稀有度=金色 费用=4 效果=抽卡概率提升10% |

**视觉描述：**
从丹田区向外放射的十条如算筹般的直线——线条排列呈卦象般的数理图案，每条线代表天干之数。中央汇聚区呈六十四卦卦盘形——卦象环绕丹田，松石青在卦盘的核心闪烁——标识推演天机带来的抽卡概率提升。墨线精确如尺规作图，有数学般的美感。题字「大衍算天诀」以规整的小篆题于右下。

**美术圣经锚点：**
- §5.X.3 运功图四层构图
- §5.X.3 墨线语言：算筹直线=概率增益型
- §4 语义色：松石青=演算天机标识

**生成提示 (Midjourney)：**
Chinese ink wash qi diagram, 10 counting-rod straight strokes radiating from dantian in trigram-like mathematical pattern, 64-hexagram circular convergence array, turquoise-blue flicker at hexagram core for fate-calculation draw probability boost, ruler-precise geometric linework with mathematical beauty, neat small seal script calligraphy, transparent background -- style "墨骨丹青" --ar 5:7 --no figure, no person, no landscape, no color except ink black and one turquoise dot

**反向提示 (Stable Diffusion)：**
person, human, figure, portrait, landscape, background, colorful, 3D, photograph, realistic, math, numbers

**状态：** Needed

---

## 增益型功法（综合墨线类型）

### ASSET-055 — 青云功

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 功法运功图 |
| 尺寸 | 200×280px (LOD-1) / 800×1120px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `technique_qingyun_gong.png` |
| 卡牌数据 | 稀有度=蓝色 费用=1 效果=绑定角色攻击+1 |

**视觉描述：**
三条简洁明快的直线从丹田区向上——线条清爽不拖沓，是典型的青云剑宗基础功法的朴素风格。中央汇聚区呈小剑尖状的菱形——剑锋直指上方，朱砂红点缀于剑尖——标识基础攻击力的增幅。墨色清爽，无线条的冗余装饰。题字「青云功」以简洁的楷书题于右下。

**美术圣经锚点：**
- §5.X.3 运功图四层构图
- §5.X.3 墨线语言：简洁直线=基础增益
- §4 语义色：朱砂红=攻击力增幅标识

**生成提示 (Midjourney)：**
Chinese ink wash meridian chart, 3 clean simple straight strokes rising from dantian with unadorned clarity, small sword-tip diamond convergence, vermillion red dot at tip for basic attack boost, clean ink without decorative excess, simple regular script calligraphy, transparent background -- style "墨骨丹青" --ar 5:7 --no figure, no person, no landscape, no color except ink black and vermillion dot

**反向提示 (Stable Diffusion)：**
person, human, figure, portrait, landscape, background, colorful, 3D, photograph, realistic

**状态：** Needed

---

### ASSET-056 — 掩月心经

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 功法运功图 |
| 尺寸 | 200×280px (LOD-1) / 800×1120px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `technique_yanyue_xinjing.png` |
| 卡牌数据 | 稀有度=蓝色 费用=2 效果=绑定角色治疗效果+20% |

**视觉描述：**
四条如月光般柔和的弧线从丹田区向上——线条若隐若现，有云遮月般的朦胧美感。中央汇聚区呈弯月形——一弯新月从云中露出，松石青如月光般洒落在月色核心——标识治疗效果的月华增幅。墨色极淡，以大量留白表现月光的清冷。题字「掩月心经」以清瘦的行书小字题于右下。

**美术圣经锚点：**
- §5.X.3 运功图四层构图
- §5.X.3 墨线语言：月弧线=治疗增益型
- §4 语义色：松石青=月华治疗增幅

**生成提示 (Midjourney)：**
Chinese ink wash qi circulation, 4 moonlight-soft faint arc strokes rising from dantian with cloud-veiled moon haziness, crescent moon convergence emerging from mist, turquoise-blue glow like moonlight at crescent core for healing boost, extremely light ink with abundant negative space, slender running script small calligraphy, transparent background -- style "墨骨丹青" --ar 5:7 --no figure, no person, no landscape, no color except ink black and turquoise glow

**反向提示 (Stable Diffusion)：**
person, human, figure, portrait, landscape, background, colorful, 3D, photograph, realistic, moon, night

**状态：** Needed

---

### ASSET-057 — 万象推衍术

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 功法运功图 |
| 尺寸 | 200×280px (LOD-1) / 800×1120px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `technique_wanxiang_tuiyan_shu.png` |
| 卡牌数据 | 稀有度=金色 费用=3 效果=绑定角色炼丹炼器产出额外+1，副属性加成+15% |

**视觉描述：**
从丹田区向外放射又交织的复杂墨线网络——线条既放射又横向连接，形成类似炼金术符号的精密构图。中央汇聚区呈丹炉形的涡旋——丹炉口有真气与器物交织的复杂图案。松石青与朱砂红交替点缀——松石青标识炼丹增益、朱砂红标识炼器增益。墨线如工笔般精密繁复。题字「万象推衍术」以工整的隶书题于右下。

**美术圣经锚点：**
- §5.X.3 运功图四层构图
- §5.X.3 墨线语言：交织网络线=复合增益型
- §4 语义色：松石青=炼丹增幅，朱砂红=炼器增幅

**生成提示 (Midjourney)：**
Chinese ink wash internal energy diagram, complex network of radiating and interconnecting brush strokes forming alchemical-symbol-like precise composition, alchemy-furnace vortex convergence with qi and artifact patterns intertwined, alternating turquoise-blue (alchemy boost) and vermillion-red (crafting boost) dots, fine gongbi-precision linework, neat clerical script calligraphy, transparent background -- style "墨骨丹青" --ar 5:7 --no figure, no person, no landscape, no color except ink black, turquoise, and vermillion dots

**反向提示 (Stable Diffusion)：**
person, human, figure, portrait, landscape, background, colorful, 3D, photograph, realistic, furnace, machine

**状态：** Needed

---

### ASSET-058 — 残魂养神诀

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 功法运功图 |
| 尺寸 | 200×280px (LOD-1) / 800×1120px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `technique_canhun_yangshen_jue.png` |
| 卡牌数据 | 稀有度=紫色 费用=4 效果=绑定角色每回合抽卡+1 |

**视觉描述：**
从丹田区向上飘散的六条如残魂般断续的墨线——线条不连续，由众多小段墨迹组成——不完整却持续向上，模拟魂魄碎片缓慢凝聚的过程。中央汇聚区呈魂魄汇聚的雾状圆形——残片在此处汇合形成神识。松石青点缀于每段墨迹的连接处——标识每回合神识的恢复。墨线轻灵飘忽。题字「残魂养神诀」以断续感的行楷题于右下。

**美术圣经锚点：**
- §5.X.3 运功图四层构图
- §5.X.3 墨线语言：断续上升线=渐进增益型
- §4 语义色：松石青=神识恢复标识

**生成提示 (Midjourney)：**
Chinese ink wash qi flow, 6 fragmentary discontinuous brush strokes drifting upward from dantian like scattered soul fragments slowly coalescing, misty soul-gathering circular convergence forming spiritual consciousness, turquoise-blue dot at each fragment connection for per-turn mental recovery, light floating ethereal line quality, staccato running-regular calligraphy, transparent background -- style "墨骨丹青" --ar 5:7 --no figure, no person, no landscape, no color except ink black and turquoise dots

**反向提示 (Stable Diffusion)：**
person, human, figure, portrait, landscape, background, colorful, 3D, photograph, realistic, ghost, spirit

**状态：** Needed

---

### ASSET-059 — 轮回道经

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 功法运功图 |
| 尺寸 | 200×280px (LOD-1) / 800×1120px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `technique_lunhui_daojing.png` |
| 卡牌数据 | 稀有度=金色 费用=4 效果=复活角色时回复血量提升50% |

**视觉描述：**
从丹田区向下沉入又向上回升的七条轮回弧线——线条向下穿过一个象征死亡的淡墨横线，然后以更浓的墨色向上回升——模拟死亡与重生的轮回。中央汇聚区呈∞形（无限符号）的轮回之环——朱砂红在下沉端标识死亡、松石青在回升端标识重生。墨线在下沉半段偏淡、回升半段偏浓。题字「轮回道经」以庄重的楷书题于右下。

**美术圣经锚点：**
- §5.X.3 运功图四层构图
- §5.X.3 墨线语言：下沉回升弧线=复活增益型
- §4 语义色：朱砂红（死亡）+ 松石青（重生）=轮回标识

**生成提示 (Midjourney)：**
Chinese ink wash meridian map, 7 samsara arc strokes descending below dantian through a faint death-line then rising back stronger in darker ink, infinity-symbol figure-8 convergence, vermillion-red dot at descent/death point, turquoise-blue at ascent/rebirth point, ink density transition from light in descent to dark in ascent, solemn regular script calligraphy, transparent background -- style "墨骨丹青" --ar 5:7 --no figure, no person, no landscape, no color except ink black, one vermillion, and one turquoise dot

**反向提示 (Stable Diffusion)：**
person, human, figure, portrait, landscape, background, colorful, 3D, photograph, realistic, skeleton, death

**状态：** Needed

---

### ASSET-060 — 梵天圣功

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 功法运功图 |
| 尺寸 | 200×280px (LOD-1) / 800×1120px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `technique_fantian_shenggong.png` |
| 卡牌数据 | 稀有度=金色 费用=4 效果=绑定角色防御+3，攻击+2 |

**视觉描述：**
六条庄严的放射线从丹田区向六个方向延伸——线条如佛光普照般均匀、温和、有威严。中央汇聚区呈莲花绽开的层次圆形——三层莲花依次展开，松石青在莲心标识防御核心、朱砂红在花瓣尖标识攻击力。墨线醇厚温润，有宗教壁画般的庄严美感。题字「梵天圣功」以庄重的楷书大字题于右下。

**美术圣经锚点：**
- §5.X.3 运功图四层构图
- §5.X.3 墨线语言：庄严放射线=双属性增益型
- §4 语义色：松石青=防御，朱砂红=攻击

**生成提示 (Midjourney)：**
Chinese ink wash internal energy chart, 6 solemn radiating strokes extending in 6 directions like divine light, three-layered lotus bloom convergence with turquoise-blue at heart for defense and vermillion red at petal tips for attack, mellow warm dignified brushwork like religious mural, solemn regular script large calligraphy, transparent background -- style "墨骨丹青" --ar 5:7 --no figure, no person, no landscape, no color except ink black, one turquoise, and vermillion dots

**反向提示 (Stable Diffusion)：**
person, human, figure, portrait, landscape, background, colorful, 3D, photograph, realistic, buddha, religion, temple

**状态：** Needed

---

### ASSET-061 — 混沌秘功

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 功法运功图 |
| 尺寸 | 200×280px (LOD-1) / 800×1120px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `technique_hundun_migong.png` |
| 卡牌数据 | 稀有度=暗金 费用=5 效果=绑定混沌宝瓶后，每回合从牌库抽一张功法牌入手牌 |

**视觉描述：**
从丹田区向外扩散的混沌墨线——线条粗犷不羁、形态不定，如原始混沌之气在丹田中翻滚。中央汇聚区呈宝瓶形的漩涡——混沌之气在瓶口汇聚成形，一道金色墨线从漩涡中心延伸至画面顶部，末端呈现一张展开的卷轴形虚影——标识绑定混沌宝瓶后从牌库抽取功法牌的专属效果。墨色极浓，多处飞白表现混沌未分的原始感。题字「混沌秘功」以古朴的甲骨文风格题于右下。

**美术圣经锚点：**
- §5.X.3 运功图四层构图
- §5.X.3 墨线语言：混沌扩散线=绑定增益型
- §4 语义色：松石青+朱砂红混合=混沌之力标识（混沌秘功=从牌库抽功法牌）

**生成提示 (Midjourney)：**
Chinese ink wash qi diagram, chaotic formless brush strokes billowing outward from dantian like primordial chaos, treasure-vase vortex convergence with qi coalescing at mouth, turquoise and vermillion blended dots at vase mouth for double material output when bound to Chaos Vase, extremely dark ink with heavy flying-white for primordial undivided feel, archaic oracle-bone calligraphy, transparent background -- style "墨骨丹青" --ar 5:7 --no figure, no person, no landscape, no color except ink black and blended turquoise-vermillion dots

**反向提示 (Stable Diffusion)：**
person, human, figure, portrait, landscape, background, colorful, 3D, photograph, realistic, vase, bottle

**状态：** Needed

---

### ASSET-062 — 玄阴经

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 功法运功图 |
| 尺寸 | 200×280px (LOD-1) / 800×1120px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `technique_xuanyin_jing.png` |
| 卡牌数据 | 稀有度=紫色 费用=2 效果=绑定角色击杀敌方后回复自身2血 |

**视觉描述：**
四条阴柔弧线从丹田区向上如暗流般涌动——线条带有吸收感，末端微微向内钩，模拟击杀后吸取生命力的动作。中央汇聚区呈吸盘状的漩涡——真气被吸入丹田核心，松石青在吸入点标识生命力的回归。墨色偏暗偏柔。题字「玄阴经」以阴柔的行书题于右下。

**美术圣经锚点：**
- §5.X.3 运功图四层构图
- §5.X.3 墨线语言：吸收弧线=击杀回复型
- §4 语义色：松石青=生命力吸收标识

**生成提示 (Midjourney)：**
Chinese ink wash internal energy map, 4 dark gentle arc strokes rising from dantian with inward-hooking tips like absorbing life force, suction-cup vortex convergence drawing qi into dantian core, turquoise-blue dot at suction point for life return on kill, dark soft ink tone, gentle running script calligraphy, transparent background -- style "墨骨丹青" --ar 5:7 --no figure, no person, no landscape, no color except ink black and one turquoise dot

**反向提示 (Stable Diffusion)：**
person, human, figure, portrait, landscape, background, colorful, 3D, photograph, realistic

**状态：** Needed

---

### ASSET-063 — 轮回道经（重复条目已覆盖）

*参见 ASSET-059*

---

## LOD 快速参考

| LOD | 规格 | 内容 |
|-----|------|------|
| LOD-1 | 200×280px | 完整运功图（卡牌插画区域） |
| LOD-2 | 64×90px | 中央运功区裁切（战斗头像） |
| LOD-3 | 80×100px | 墨线轨迹简化剪影（缩略图标） |

---