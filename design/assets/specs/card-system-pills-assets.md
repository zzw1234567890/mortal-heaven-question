# 资产规范 — 丹药卡丹丸静物图

> **来源**：design/gdd/card-system-design.md 第六部分
> **美术圣经**：design/art/art-bible.md §5.X.5
> **生成日期**：2026-07-26
> **审查模式**：Solo（art-director + technical-artist 代理因 API 503 不可用）
> **状态**：24 个资产已规范 / 0 个已批准 / 0 个生产中 / 0 个完成

## 技术参数

| 参数 | 值 |
|------|-----|
| 规格 | 200×280px |
| 工作分辨率 | 400×400px（缩放至 200×280px 居中） |
| 格式 | PSD 源文件 + PNG 导出 |
| 图层要求 | (1) 丹丸主体层 (2) 云纹线条层 (3) 烟云承托层 (4) 边缘金线层（仅暗金） |
| Godot 导入预设 | 2D Texture, Filter=Disabled, Mipmaps=Off, Compress=Lossless |
| 单张预估 | ~80KB RGBA8 → ~20KB DXT5 |
| 总计预估 | 24 张 × 20KB = ~480KB VRAM |

## 品质纹样速查

| 稀有度 | 纹样 | 数量 | 代表丹药 |
|--------|------|:--:|------|
| 白色 | 无纹（光面） | 3 | 低级炼气丹、低级回血丹、速行符* |
| 蓝色 | 单纹（单环线） | 8 | 中级炼气丹、低级聚气丹、清毒丹等 |
| 紫色 | 双纹（经纬交叉） | 8 | 高级炼气丹、高级回血丹、破障丹等 |
| 金色 | 三纹（网状龟裂） | 4 | 高级聚气丹、高级渡劫丹、蕴神丹、涅槃丹 |
| 暗金 | 龙纹（盘龙云气） | 1 | 升灵丹 |

> *注：速行符严格来说不属于丹药，但在视觉类别上归入白色无纹丹药处理。

---

## 白色品质（无纹·光面）

### ASSET-109 — 低级炼气丹

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 丹药静物图 |
| 尺寸 | 200×280px (LOD-1) / 400×400px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `pill_diji_lianqi_dan.png` |
| 卡牌数据 | 稀有度=白色 费用=0 效果=本回合额外获得1费 |

**视觉描述：**
一颗光洁无纹的圆形丹丸居中悬浮——表面平滑如珠，无任何纹路。墨色偏淡——淡墨圆形的边缘柔和如珍珠光晕。下方淡墨烟云轻薄如纱，量极少——象征这是一颗最基础的丹药。整体极简克制，以大面积留白传递「基础」的视觉信号。

**美术圣经锚点：**
- §5.X.5 品质纹样：白色=无纹光面
- §5.X.5 构图：丹药居中 25% 宽度
- §4 语义色：无色彩=基础品质

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a single smooth unadorned pill — perfect circle, no surface markings, light ink pearl-like soft edge glow, thin wisp of smoke-cloud below, abundant negative space, minimal Zen aesthetic, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no decoration, no color except light ink

**反向提示 (Stable Diffusion)：**
texture, pattern, decoration, color, background, landscape, 3D, photorealistic, metallic

**状态：** Needed

---

### ASSET-110 — 低级回血丹

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 丹药静物图 |
| 尺寸 | 200×280px (LOD-1) / 400×400px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `pill_diji_huixue_dan.png` |
| 卡牌数据 | 稀有度=白色 费用=1 效果=回复单个角色3点血量 |

**视觉描述：**
一颗光洁无纹的丹丸——与炼气丹相似但墨色偏暖、偏柔。淡墨圆形的边缘晕开更宽的光晕——暗示血量回复的滋养感。下方淡墨烟云比炼气丹略厚——象征更强的药效。整体仍极简克制。

**美术圣经锚点：**
- §5.X.5 品质纹样：白色=无纹
- §5.X.5 构图：丹药居中
- §4 语义色：无色彩=基础品质

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a smooth unadorned healing pill — slightly warmer softer ink than basic pill, wider soft halo at edges for nourishing heal feel, slightly thicker smoke-cloud below, minimal Zen aesthetic, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no decoration, no color except soft warm ink

**反向提示 (Stable Diffusion)：**
texture, pattern, color, background, landscape, 3D, photorealistic

**状态：** Needed

---

### ASSET-111 — 速行符（丹药类视觉处理）

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 丹药静物图 |
| 尺寸 | 200×280px (LOD-1) / 400×400px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `pill_suxing_fu.png` |
| 卡牌数据 | 稀有度=白色 费用=0 效果=本回合抽1张牌 |

**视觉描述：**
一颗无纹丹丸但形态略有不同——丹丸不完全是正圆形，而是微微拉长的椭圆，暗示「速度」。墨色极淡，边缘有风吹过般的淡墨拖尾。烟云不是在下方承托，而是在丹丸后方形成一道横向的淡墨线——如飞驰的轨迹。整体传递「轻、快、瞬」的感觉。

**美术圣经锚点：**
- §5.X.5 品质纹样：白色=无纹
- §5.X.5 构图：椭圆居中 + 横向拖尾
- §4 语义色：无色彩=基础品质

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a slightly elongated pill with wind-trail — oval not perfectly round, extremely light ink, faint horizontal ink trail behind like speed lines, no supporting cloud below but wind-stream across, transient fast light feeling, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no decoration, no color except faint ink

**反向提示 (Stable Diffusion)：**
texture, pattern, color, background, landscape, 3D, photorealistic, round

**状态：** Needed

---

## 蓝色品质（单纹·单环线）

### ASSET-112 — 中级炼气丹

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 丹药静物图 |
| 尺寸 | 200×280px (LOD-1) / 400×400px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `pill_zhongji_lianqi_dan.png` |
| 卡牌数据 | 稀有度=蓝色 费用=1 效果=本回合额外获得2费 |

**视觉描述：**
一颗带有单条云纹环线的丹丸——一条环绕丹丸赤道位置的墨线清晰可见。线圈完整平滑，环绕一周。丹丸主体墨色适中。下方烟云比白色品质更厚实——暗示药力更强。整体比白色品质多了「精致」的视觉信号。

**美术圣经锚点：**
- §5.X.5 品质纹样：蓝色=单纹（单环线）
- §5.X.5 构图规则
- §4 语义色：无色彩=蓝色品质

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a pill with single ring line — one clean unbroken ink line circling the equator, medium ink density on body, thicker supporting smoke-cloud below, refined simple elegance, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no decoration, no color except ink

**反向提示 (Stable Diffusion)：**
texture, pattern, color, background, landscape, 3D, photorealistic, double line

**状态：** Needed

---

### ASSET-113 — 中级回血丹

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 丹药静物图 |
| 尺寸 | 200×280px (LOD-1) / 400×400px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `pill_zhongji_huixue_dan.png` |
| 卡牌数据 | 稀有度=蓝色 费用=2 效果=回复全体角色2点血量 |

**视觉描述：**
一粒单环线丹丸——与中级炼气丹相似但墨色更暖更柔。环绕线微微加粗，暗示更重要的药效。下方烟云比中级炼气丹更浓——且烟云有向外扩散的趋势，模拟全体的回复范围。丹丸上方有微微的暖色光晕——通过墨色浓淡表现而非实际暖色。

**美术圣经锚点：**
- §5.X.5 品质纹样：蓝色=单纹
- §5.X.5 构图：烟云向外扩散
- §4 语义色：无色彩=蓝色品质

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a single-ring healing pill — slightly thicker ring line, warmer softer ink than energy pill, smoke-cloud diffusing outward for party-wide heal, faint warm halo above via ink density, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except ink

**反向提示 (Stable Diffusion)：**
texture, pattern, color, background, landscape, 3D, photorealistic

**状态：** Needed

---

### ASSET-114 — 低级聚气丹

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 丹药静物图 |
| 尺寸 | 200×280px (LOD-1) / 400×400px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `pill_diji_juqi_dan.png` |
| 卡牌数据 | 稀有度=蓝色 费用=1 效果=单个角色本回合攻击+3 |

**视觉描述：**
一粒单环线丹丸——环绕线在赤道偏上位置（不在正中间），暗示攻击力的向上提升。墨色比同级丹药略浓——传递「攻击」的锐利感。下方烟云向上方聚拢——如真气向上升腾。整体传递「一往无前」的进攻气质。

**美术圣经锚点：**
- §5.X.5 品质纹样：蓝色=单纹
- §5.X.5 构图：环线偏上=攻击提升
- §4 语义色：无色彩=蓝色品质

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a single-ring attack pill — ring line positioned slightly above equator, slightly denser ink than same-tier pills for offensive sharpness, smoke-cloud gathering upward like rising qi, forward aggressive energy, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except ink

**反向提示 (Stable Diffusion)：**
texture, pattern, color, background, landscape, 3D, photorealistic

**状态：** Needed

---

### ASSET-115 — 清毒丹

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 丹药静物图 |
| 尺寸 | 200×280px (LOD-1) / 400×400px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `pill_qingdu_dan.png` |
| 卡牌数据 | 稀有度=蓝色 费用=1 效果=去除单个角色2层毒素/厄运debuff |

**视觉描述：**
一粒单环线丹丸——环绕线由内向外旋转（从丹丸的北极螺旋到赤道），模拟毒素被推出体外的净化路径。墨色偏清透，烟云中有一缕更为澄澈的淡墨笔触——如清泉冲刷。整体传递「清洁、净化」的感觉。

**美术圣经锚点：**
- §5.X.5 品质纹样：蓝色=单纹（螺旋型）
- §5.X.5 构图：螺旋环线=净化
- §4 语义色：无色彩=蓝色品质

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a detox pill with spiral ring — ring line spiraling from north pole to equator suggesting toxins being expelled, clear crisp ink, one especially clean brush stroke in smoke-cloud like cleansing spring water, purifying clean feeling, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except ink

**反向提示 (Stable Diffusion)：**
texture, pattern, color, background, landscape, 3D, photorealistic, dirty

**状态：** Needed

---

### ASSET-116 — 隐身丹

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 丹药静物图 |
| 尺寸 | 200×280px (LOD-1) / 400×400px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `pill_yinshen_dan.png` |
| 卡牌数据 | 稀有度=蓝色 费用=1 效果=让一个角色本回合不会被敌方主动攻击 |

**视觉描述：**
一粒有断续环线的丹丸——单条环线不是连续的，而是虚线状（由若干小段墨迹组成），模拟隐身的时隐时现。丹丸本身墨色极淡——几乎融入留白中。烟云也极薄，且偏向一侧——如丹丸正在隐去。整体传递「即将消失」的暂存感。

**美术圣经锚点：**
- §5.X.5 品质纹样：蓝色=单纹（虚线变体）
- §5.X.5 构图：丹丸极淡
- §4 语义色：无色彩=蓝色品质

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a faint pill with dashed ring — ring line broken into small segments suggesting flickering in-and-out of visibility, pill body extremely light ink nearly blending into white space, thin smoke offset to one side as if pill is fading, transient disappearing feeling, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except faint ink

**反向提示 (Stable Diffusion)：**
texture, pattern, color, background, landscape, 3D, photorealistic, solid, opaque

**状态：** Needed

---

### ASSET-117 — 固元丹

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 丹药静物图 |
| 尺寸 | 200×280px (LOD-1) / 400×400px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `pill_guyuan_dan.png` |
| 卡牌数据 | 稀有度=蓝色 费用=1 效果=单个角色获得护盾，吸收3点伤害，持续两回合 |

**视觉描述：**
一粒单环线丹丸——环绕线加粗成带状（在赤道处如腰带般环绕），暗示护盾的包裹和保护。丹丸墨色坚实沉稳。下方烟云呈环形包裹丹丸下半部——如护盾的承托。整体传递「稳固、可靠」的感觉。

**美术圣经锚点：**
- §5.X.5 品质纹样：蓝色=单纹（加粗带状）
- §5.X.5 构图：烟云环形包裹
- §4 语义色：无色彩=蓝色品质

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a shield pill with thick band ring — ring thickened into an equatorial belt suggesting protective wrapping, solid stable ink density, smoke-cloud wrapping lower half of pill like shield support, steady reliable feeling, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except ink

**反向提示 (Stable Diffusion)：**
texture, pattern, color, background, landscape, 3D, photorealistic, fragile

**状态：** Needed

---

### ASSET-118 — 低级渡劫丹

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 丹药静物图 |
| 尺寸 | 200×280px (LOD-1) / 400×400px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `pill_diji_dujie_dan.png` |
| 卡牌数据 | 稀有度=蓝色 费用=1 效果=天劫战斗中，敌方攻击降低10% |

**视觉描述：**
一粒单环线丹丸——环绕线如闪电般锯齿状（非平滑曲线），模拟天劫的雷霆。墨色偏暗偏沉。下方烟云不是柔和的承托而是向上方升腾、在丹丸上方形成遮蔽——如护盾抵御天雷。整体传递「对抗、抵抗」的防御感。

**美术圣经锚点：**
- §5.X.5 品质纹样：蓝色=单纹（锯齿变体）
- §5.X.5 构图：烟云上腾遮蔽
- §4 语义色：无色彩=蓝色品质

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a tribulation pill with jagged ring — zigzag ring line suggesting lightning strikes, dark somber ink, smoke-cloud rising upward to canopy above pill like shield against heaven's thunder, resistant defensive feeling, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except ink

**反向提示 (Stable Diffusion)：**
texture, pattern, color, background, landscape, 3D, photorealistic, smooth

**状态：** Needed

---

## 紫色品质（双纹·经纬交叉）

### ASSET-119 — 高级炼气丹

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 丹药静物图 |
| 尺寸 | 200×280px (LOD-1) / 400×400px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `pill_gaoji_lianqi_dan.png` |
| 卡牌数据 | 稀有度=紫色 费用=2 效果=本回合额外获得3费 |

**视觉描述：**
一粒拥有双条云纹线的丹丸——两条线在丹丸表面交叉：一条水平环绕（赤道线）+ 一条垂直环绕（经线）。交叉点形成十字。墨色比蓝色品质更浓。下方烟云厚实且向上延伸至丹丸三分之一高度。整体呈现「精密、进阶」的视觉信号。

**美术圣经锚点：**
- §5.X.5 品质纹样：紫色=双纹（经纬交叉）
- §5.X.5 构图规则
- §4 语义色：无色彩=紫色品质

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a double-ring pill — two lines crossing: one equatorial + one meridional, forming cross at intersection, denser ink than blue tier, thicker taller smoke-cloud, precise advanced feel, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except ink

**反向提示 (Stable Diffusion)：**
texture, pattern, color, background, landscape, 3D, photorealistic, single line

**状态：** Needed

---

### ASSET-120 — 高级回血丹

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 丹药静物图 |
| 尺寸 | 200×280px (LOD-1) / 400×400px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `pill_gaoji_huixue_dan.png` |
| 卡牌数据 | 稀有度=紫色 费用=3 效果=回复单个角色满血+血量上限+2 |

**视觉描述：**
一粒双纹丹丸——经纬线均加粗为双线（每条线由两根紧贴的细线组成），标识「回复满血+上限增长」的双重效果。墨色偏暖偏厚。下方烟云极为饱满——从底部包裹至丹丸半腰，如温润的治愈之力。整体传递「充沛、圆满」的感觉。

**美术圣经锚点：**
- §5.X.5 品质纹样：紫色=双纹（双线加粗）
- §5.X.5 构图：烟云饱满包裹
- §4 语义色：无色彩=紫色品质

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a full-heal pill with thickened double rings — both equatorial and meridional lines doubled into paired thin lines, warm thick ink, smoke-cloud very full wrapping to pill mid-height like abundant healing power, complete fulfilled feeling, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except ink

**反向提示 (Stable Diffusion)：**
texture, pattern, color, background, landscape, 3D, photorealistic

**状态：** Needed

---

### ASSET-121 — 中级聚气丹

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 丹药静物图 |
| 尺寸 | 200×280px (LOD-1) / 400×400px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `pill_zhongji_juqi_dan.png` |
| 卡牌数据 | 稀有度=紫色 费用=2 效果=全体角色本回合攻击+2 |

**视觉描述：**
一粒双纹丹丸——两条线在交叉点处微微上扬（经纬线交点偏上），暗示攻击力的群体提升。烟云从底部向四面扩散——如攻击力辐射至全体。墨色饱满有力。整体传递「爆发、扩散」的战斗感。

**美术圣经锚点：**
- §5.X.5 品质纹样：紫色=双纹（交叉点上扬）
- §5.X.5 构图：烟云四向扩散
- §4 语义色：无色彩=紫色品质

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a party-attack pill — crossing point of double rings slightly elevated, smoke-cloud diffusing in all four directions for party-wide buff, full powerful ink, burst-spread combat energy, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except ink

**反向提示 (Stable Diffusion)：**
texture, pattern, color, background, landscape, 3D, photorealistic

**状态：** Needed

---

### ASSET-122 — 中级渡劫丹

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 丹药静物图 |
| 尺寸 | 200×280px (LOD-1) / 400×400px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `pill_zhongji_dujie_dan.png` |
| 卡牌数据 | 稀有度=紫色 费用=2 效果=天劫战斗中敌方攻击降低20%，我方全体防御+2 |

**视觉描述：**
一粒双纹丹丸——一条线锯齿状（天劫削弱）、一条线平滑加粗（防御提升），两条线的对比直接编码了「减敌攻+增我防」的双重机制。墨色深沉。烟云在丹丸上方形成保护性的伞盖——如抵御天劫的屏障。整体传递「攻守兼备」的平衡感。

**美术圣经锚点：**
- §5.X.5 品质纹样：紫色=双纹（锯齿+平滑对比）
- §5.X.5 构图：烟云伞盖
- §4 语义色：无色彩=紫色品质

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a tribulation-defense pill — one jagged ring (weaken), one thick smooth ring (defend) in deliberate contrast, dark ink, smoke-cloud canopy above pill like barrier against tribulation, balanced offense+defense feel, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except ink

**反向提示 (Stable Diffusion)：**
texture, pattern, color, background, landscape, 3D, photorealistic

**状态：** Needed

---

### ASSET-123 — 破障丹

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 丹药静物图 |
| 尺寸 | 200×280px (LOD-1) / 400×400px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `pill_podan_zhangdan.png` |
| 卡牌数据 | 稀有度=紫色 费用=2 效果=去除己方所有角色debuff，同时免疫debuff一回合 |

**视觉描述：**
一粒双纹丹丸——两条线在交叉点处向外炸裂（交叉点上有微小的墨点放射），模拟debuff被炸开的瞬间。墨色清亮锐利。烟云从交叉点向外急速扩散——如冲击波般推开所有负面效果。整体传递「爆发、净化、扫除一切」的气势。

**美术圣经锚点：**
- §5.X.5 品质纹样：紫色=双纹（炸裂交叉点）
- §5.X.5 构图：烟云爆炸扩散
- §4 语义色：无色彩=紫色品质

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a debuff-cleanse pill — rings meeting at explosive intersection with micro ink dots radiating outward, crisp sharp ink, smoke-cloud blasting outward from intersection like shockwave, explosive purging sweeping energy, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except ink

**反向提示 (Stable Diffusion)：**
texture, pattern, color, background, landscape, 3D, photorealistic, calm, gentle

**状态：** Needed

---

### ASSET-124 — 傀儡丹

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 丹药静物图 |
| 尺寸 | 200×280px (LOD-1) / 400×400px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `pill_kuilei_dan.png` |
| 卡牌数据 | 稀有度=紫色 费用=3 效果=召唤一个临时傀儡（攻击3，血量3），持续一回合 |

**视觉描述：**
一粒双纹丹丸——两条线的交叉点延伸出微小的四肢轮廓（极为简化的头+手+足的点线），暗示丹丸化形为傀儡。墨色偏浓。烟云在丹丸下方凝聚成形——不是散开的雾而是聚拢的团块，如在形成傀儡的躯体。整体传递「化形、具现」的创造感。

**美术圣经锚点：**
- §5.X.5 品质纹样：紫色=双纹（化形延伸）
- §5.X.5 构图：烟云聚拢成形
- §4 语义色：无色彩=紫色品质

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a puppet-summon pill — tiny simplified limb dots extending from ring intersection suggesting humanoid form, dense ink, smoke-cloud clumping into shape beneath pill like forming a puppet body, manifestation creative energy, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except ink

**反向提示 (Stable Diffusion)：**
texture, pattern, color, background, landscape, 3D, photorealistic, person, figure

**状态：** Needed

---

### ASSET-125 — 暴灵丹

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 丹药静物图 |
| 尺寸 | 200×280px (LOD-1) / 400×400px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `pill_baoling_dan.png` |
| 卡牌数据 | 稀有度=紫色 费用=3 效果=临时傀儡属性翻倍，持续一回合 |

**视觉描述：**
一粒双纹丹丸——比傀儡丹墨色更浓、线条更粗。交叉点上的四肢轮廓更加分明且粗壮——每个肢端有微小的放射短线。烟云在丹丸下方凝聚得比傀儡丹更大更厚。整体传递「增幅、翻倍」的强化感。与ASSET-124形成鲜明的「普通版→暴击版」对比。

**美术圣经锚点：**
- §5.X.5 品质纹样：紫色=双纹（强化变体）
- §5.X.5 构图：烟云加倍凝聚
- §4 语义色：无色彩=紫色品质

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a supercharged puppet pill — thicker darker rings than standard puppet pill, more defined thicker limb dots with micro radiating lines at tips, larger denser smoke-clump beneath, doubled-intensified feeling, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except ink

**反向提示 (Stable Diffusion)：**
texture, pattern, color, background, landscape, 3D, photorealistic, thin, delicate

**状态：** Needed

---

### ASSET-126 — 爆气丹

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 丹药静物图 |
| 尺寸 | 200×280px (LOD-1) / 400×400px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `pill_baoqi_dan.png` |
| 卡牌数据 | 稀有度=紫色 费用=2 效果=一个角色下一次攻击必定暴击 |

**视觉描述：**
一粒双纹丹丸——两条线在交叉点处形成尖锐的星形放射（8条短线从交叉点向外刺出），模拟暴击的爆发感。墨色极浓。烟云从丹丸内部向外喷薄——不是在下方承托，而是从丹丸表面向外四射，如上膛的子弹般充满势能。整体传递「即发、致命一击」的紧张感。

**美术圣经锚点：**
- §5.X.5 品质纹样：紫色=双纹（星形放射）
- §5.X.5 构图：烟云四射
- §4 语义色：无色彩=紫色品质

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a critical-hit pill — 8 short spiky lines radiating from ring intersection like starburst, extremely dense ink, smoke-cloud blasting outward from pill surface not below, cocked-and-loaded potential energy, imminent lethal strike tension, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except ink

**反向提示 (Stable Diffusion)：**
texture, pattern, color, background, landscape, 3D, photorealistic, soft, gentle

**状态：** Needed

---

## 金色品质（三纹·网状龟裂）

### ASSET-127 — 高级聚气丹

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 丹药静物图 |
| 尺寸 | 200×280px (LOD-1) / 400×400px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `pill_gaoji_juqi_dan.png` |
| 卡牌数据 | 稀有度=金色 费用=3 效果=单个角色本回合伤害翻倍 |

**视觉描述：**
一粒三纹网状丹丸——三条云纹线在丹丸表面交叉编织成精致的龟裂纹网。每个交叉点都是一个小小的墨色节点。墨色浓郁饱满。下方烟云旋转上升如龙卷——包裹丹丸半身，传递「伤害翻倍」的巨大能量。整体呈现「精密的强大」——不是混沌的强力而是受控的爆发。

**美术圣经锚点：**
- §5.X.5 品质纹样：金色=三纹（网状龟裂）
- §5.X.5 构图：烟云旋转上升
- §4 语义色：无色彩=金色品质

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a damage-doubling pill with triple-ring net — 3 lines interweaving into fine crackle-glaze mesh, tiny nodes at each intersection, dense rich ink, tornado-spiraling smoke-cloud wrapping pill for doubled power, controlled refined explosive energy, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except ink

**反向提示 (Stable Diffusion)：**
texture, pattern, color, background, landscape, 3D, photorealistic, simple

**状态：** Needed

---

### ASSET-128 — 高级渡劫丹

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 丹药静物图 |
| 尺寸 | 200×280px (LOD-1) / 400×400px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `pill_gaoji_dujie_dan.png` |
| 卡牌数据 | 稀有度=金色 费用=3 效果=天劫战斗中敌方攻击降低30%，开局抵消一次天劫伤害 |

**视觉描述：**
一粒三纹丹丸——网状纹路在丹丸上半部加密（形成防护网）、下半部保持正常密度。上方烟云形成穹顶状的防护罩——厚重如天幕。丹丸墨色深沉。整体传递「不可撼动的防御」——天劫在此丹前止步。

**美术圣经锚点：**
- §5.X.5 品质纹样：金色=三纹（上半加密网）
- §5.X.5 构图：烟云穹顶
- §4 语义色：无色彩=金色品质

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a supreme tribulation pill — crackle mesh denser on upper half forming protective net, smoke-cloud canopy forming dome-like shield overhead, deep dark ink, immovable unshakable defense, tribulation-stopping presence, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except ink

**反向提示 (Stable Diffusion)：**
texture, pattern, color, background, landscape, 3D, photorealistic

**状态：** Needed

---

### ASSET-129 — 蕴神丹

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 丹药静物图 |
| 尺寸 | 200×280px (LOD-1) / 400×400px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `pill_yunshen_dan.png` |
| 卡牌数据 | 稀有度=金色 费用=2 效果=本回合抽卡数量+2 |

**视觉描述：**
一粒三纹丹丸——龟裂纹网在丹丸表面形成类似大脑皮层的沟回纹路，暗示「神识提升」。丹丸上方悬浮着两片微小的淡墨花瓣（或纸页）——标识额外抽两张牌。烟云轻柔平稳。整体传递「智慧、洞察」的气质。

**美术圣经锚点：**
- §5.X.5 品质纹样：金色=三纹（沟回纹变体）
- §5.X.5 构图：悬浮花瓣/纸页
- §4 语义色：无色彩=金色品质

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a mind-expanding pill — crackle pattern resembling cerebral cortex folds suggesting mental boost, two tiny ink petals/pages floating above pill for 2 extra draws, gentle steady smoke-cloud, wise insightful energy, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except ink

**反向提示 (Stable Diffusion)：**
texture, pattern, color, background, landscape, 3D, photorealistic, brain

**状态：** Needed

---

### ASSET-130 — 涅槃丹

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 丹药静物图 |
| 尺寸 | 200×280px (LOD-1) / 400×400px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `pill_niepan_dan.png` |
| 卡牌数据 | 稀有度=金色 费用=3 效果=复活一个已阵亡的角色，保留所有绑定的功法法宝 |

**视觉描述：**
一粒三纹丹丸——丹丸中央有一道竖立的裂痕（非实际裂开，而是纹路形成的错觉），从裂痕中透出微光（以留白表现）。网状纹路从裂痕处向两侧展开——如凤凰从火焰中重生。烟云在丹丸下方形成凤凰尾羽般的火焰状承托。整体传递「死亡→重生」的涅槃意境。

**美术圣经锚点：**
- §5.X.5 品质纹样：金色=三纹（涅槃裂痕）
- §5.X.5 构图：留白裂痕 + 凤凰尾羽烟云
- §4 语义色：无色彩（留白）=复活之光

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a phoenix-rebirth pill — vertical central crack illusion in mesh pattern with white light seeping through, crackle mesh spreading from crack like phoenix rising, phoenix-tail feather shaped smoke-flame cradling below, death-to-rebirth nirvana transcendence, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except ink with strategic white space

**反向提示 (Stable Diffusion)：**
texture, pattern, color, background, landscape, 3D, photorealistic, bird, fire

**状态：** Needed

---

## 暗金品质（龙纹·盘龙云气）

### ASSET-131 — 冲脉丹

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 丹药静物图 |
| 尺寸 | 200×280px (LOD-1) / 400×400px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `pill_chongmai_dan.png` |
| 卡牌数据 | 稀有度=金色 费用=4 效果=随机给一个已有角色解锁一个未开放的功法/法宝槽 |

**视觉描述：**
一粒三纹丹丸——龟裂纹呈钥匙孔的形状（非对称纹路），暗示「解锁」。丹丸墨色厚重饱满。下方烟云中有三道淡淡的向上箭头状的笔触——标识功法槽+法宝槽的开启。整体传递「突破界限」的扩展感。

**美术圣经锚点：**
- §5.X.5 品质纹样：金色=三纹（钥匙孔变体）
- §5.X.5 构图：箭头烟云
- §4 语义色：无色彩=金色品质

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a slot-unlock pill — crackle mesh forming keyhole-shaped asymmetric pattern suggesting unlocking, heavy full ink, three faint upward-arrow brush strokes in smoke-cloud for technique+artifact slots opening, boundary-breaking expansion energy, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except ink

**反向提示 (Stable Diffusion)：**
texture, pattern, color, background, landscape, 3D, photorealistic, key, lock

**状态：** Needed

---

### ASSET-132 — 融灵丹

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 丹药静物图 |
| 尺寸 | 200×280px (LOD-1) / 400×400px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `pill_rongling_dan.png` |
| 卡牌数据 | 稀有度=金色 费用=4 效果=让绑定在一个角色身上的两个同效果功法/法宝，效果叠加提升50% |

**视觉描述：**
一粒三纹丹丸——网状纹路在丹丸表面形成双螺旋交织（两条主纹路互相缠绕），暗示两种力量的融合叠加。墨色浓郁。下方烟云左右对称——两道烟柱在丹丸处汇合为一。整体传递「融合、叠加、1+1>2」的协同感。

**美术圣经锚点：**
- §5.X.5 品质纹样：金色=三纹（双螺旋交织）
- §5.X.5 构图：双烟柱汇合
- §4 语义色：无色彩=金色品质

**生成提示 (Midjourney)：**
Chinese ink brush still-life of a fusion pill — double-helix interweaving main lines in crackle mesh suggesting two powers merging, rich ink, two smoke columns merging into one beneath pill, synergy superposition 1+1>2 energy, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except ink

**反向提示 (Stable Diffusion)：**
texture, pattern, color, background, landscape, 3D, photorealistic

**状态：** Needed

---

### ASSET-133 — 升灵丹

| 字段 | 值 |
|------|-----|
| 类别 | 精灵 / 2D 丹药静物图 |
| 尺寸 | 200×280px (LOD-1) / 400×400px (工作分辨率) |
| 格式 | PNG (RGBA8) + PSD |
| 命名 | `pill_shengling_dan.png` |
| 卡牌数据 | 稀有度=暗金 费用=5 效果=所有己方角色攻防永久+1，仅本局生效 |

**视觉描述：**
唯一一粒龙纹丹丸——丹丸表面盘绕着一条由云气构成的龙形纹路。龙身不具象——而是由云雾般的墨迹勾勒出的蜿蜒龙影：龙首在丹丸北极、龙身盘绕丹丸三圈、龙尾在南极隐入烟云。琉璃金微光在龙首的眼睛位置闪烁——两颗极小的金点。下方烟云呈现九龙捧珠的形态（九缕烟云从不同方向托举丹丸）。整体呈现「至高无上、君临天下」的威压感。

**美术圣经锚点：**
- §5.X.5 品质纹样：暗金=龙纹（盘龙云气）
- §5.X.5 色彩规则：琉璃金仅用极微量（龙睛两点）
- §4 语义色：琉璃金=至高品级标识

**生成提示 (Midjourney)：**
Chinese ink brush still-life of the supreme dragon pill — cloud-formed dragon shadows coiling around pill surface: head at north pole, body wrapping 3 times, tail fading into smoke at south pole, two micro golden dots at dragon eye position, nine smoke streams cradling from all directions like nine dragons presenting a pearl, supreme sovereign imperial presence, transparent background -- style "墨骨丹青" --ar 5:7 --no background, no color except ink and two gold micro-dots

**反向提示 (Stable Diffusion)：**
texture, pattern, color, background, landscape, 3D, photorealistic, dragon, animal, realistic

**状态：** Needed

---

## LOD 快速参考

| LOD | 规格 | 内容 |
|-----|------|------|
| LOD-1 | 200×280px | 完整丹丸图（卡牌插画区域） |
| LOD-2 | 64×90px | 丹丸主体裁切（战斗头像） |
| LOD-3 | 80×100px | 丹丸剪影（缩略图标——纯圆形） |