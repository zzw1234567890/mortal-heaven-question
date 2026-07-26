# 资产规范 — system：card-system（角色立绘部分）

> **来源**：`design/gdd/card-system.md`、`design/gdd/card-system-design.md`、`design/art/art-bible.md` §5 + §5.X + §8
> **美术圣经**：design/art/art-bible.md
> **生成日期**：2026-07-26
> **审查模式**：Solo（art-director + technical-artist 代理因 API 503 不可用——技术约束按美术圣经第 8 部分推导，视觉描述基于已批准的美术圣经第 5.1 节六要素规范）
> **状态**：38 个资产已规范 / 待审查（原 15 + 新增 23）

---

## ASSET-001 — 林渊（青云剑宗·外门弟子）全身立绘

| 字段 | 值 |
|-------|-------|
| 类别 | 精灵 / 2D 角色立绘 |
| 尺寸 (LOD-0) | 800×1120px，角色主体占垂直 65%（头距顶边约 12%，足距底边约 8%） |
| 尺寸 (LOD-1) | 200×280px，从 LOD-0 顶部裁 96px（至头顶上方 5%），底部裁至膝盖位置（约 728px 处），水平居中裁切 |
| 格式 | PNG RGBA8，透明背景，sRGB 色彩空间，无损压缩 |
| 源格式 | PSD 分层源文件（必须保留） |
| 文件命名 (LOD-0) | `char_lin_yuan_portrait_full.png` |
| 文件命名 (LOD-1) | `char_lin_yuan_realm1.png`（卡牌模板 `card_id = "char_lin_yuan_realm1"`） |

**图层结构（PSD 必须分层）：**
1. 背景层（锁定透明——确保导出时背景完全透明）
2. 墨色主体层：人物轮廓浓墨粗笔 + 衣袍淡墨飞白 + 面部精细线描
3. 语义色·朱砂红层：剑锋处的一抹红（≤3% 画面面积）
4. 语义色·松石青层：眉心灵光（≤2% 画面面积）

**视觉描述：**
青年男修，束发，身着单层粗布青云道袍。道袍以淡墨（灰度约 70%）大笔渲染，衣袍褶皱使用干笔飞白技法——笔触断裂处露出宣纸的空白。腰束为一条旧麻绳而非腰带，麻绳的纹理以断续的淡墨短线表现。外袍边缘有手工缝补的痕迹——以不规则的细线排列暗示反复修补。长剑竖直握于右手，剑身略宽，剑格为简朴的圆形木制——以浓墨粗线勾勒轮廓，木纹以淡墨短线表现。剑鞘斜背于身后，鞘口有磨损痕迹——以淡墨的不规则小点表现。人物姿态直立但重心微后坐，右肩略低于左肩——长年练剑形成的体态偏移。面部以精细线描勾勒，五官端正但不锐利——剑眉但眉头不锁，双眼平视前方，眼神平静坚定。整体墨色偏淡（灰度 55-70%），视觉层级 L1 中最淡者——作为主角有辨识度但不压过更高稀有度的卡牌。

**美术圣经锚点：**
- 原则 2「克制即表达」：林渊的淡墨调是「日常时刻」的视觉体现——他是玩家最常看到的角色，应保持沉默的视觉存在感
- 原则 3「秩序辨真，气韵传神」：面部精细线描（秩序）+ 衣袍写意飞白（气韵）
- 六要素：法器锚点（长剑竖直）、衣袍语汇（粗布道袍+旧麻绳）、姿态轴线（直立微后坐 左倾 3°）、墨色基调（灰度 55-70%）、阵营纹理（正道均匀细密排线）、眼神方向（平视前方）
- 阵营纹理规则（§5.1.0）：衣袍阴影面使用平行细线而非墨色晕染——「一层一层积累」的剑修练功质感
- 语义色规则（§4）：朱砂红仅用于剑锋一抹（生命/战斗标识），松石青仅用于眉心灵光（修为标识）

**AI 生成提示（Midjourney）：**
```
Full body portrait of a young male Chinese cultivator, standing centered, plain white background. He wears a simple coarse cloth Daoist robe in light gray ink wash, tied with an old hemp rope belt. His long hair is bound up in a topknot. He holds a wide straight sword vertically in his right hand, the wooden guard is round and simple. The robe has visible stitched patches along the edges. His right shoulder is slightly lower than left — a swordsman's body posture. Chinese ink wash painting (水墨写意), xieyi brushwork, sumi-e style. Grayscale ink only, 5-7 levels of ink wash from pale gray to dark gray. A single vermillion red (#C41E1E) touch on the sword edge only. A tiny turquoise blue (#1A8A8A) dot of spiritual light between his eyebrows. Soft diffused light from upper-left, no harsh shadows, no rim lighting. --no oil painting, 3D render, anime style, vibrant colors, detailed background, Western fantasy elements, gradient background, rim light
```

**反向提示（Stable Diffusion）：**
```
oil painting, 3D render, CGI, anime, manga, vibrant colors, colorful, detailed background, landscape background, Western armor, European clothing, rim lighting, harsh shadows, gradient background, photorealistic
```

**角色气质关键词：** 钝拙、坚韧、温润的固执、守势

---

## ASSET-002 — 苏剑鸣（青云剑宗·外门弟子）全身立绘

| 字段 | 值 |
|-------|-------|
| 类别 | 精灵 / 2D 角色立绘 |
| 尺寸 (LOD-0) | 800×1120px，角色主体占垂直 65% |
| 尺寸 (LOD-1) | 200×280px，从 LOD-0 顶部裁 96px，底部裁至膝盖位置（约 728px 处），水平居中裁切 |
| 格式 | PNG RGBA8，透明背景，sRGB 色彩空间，无损压缩 |
| 源格式 | PSD 分层源文件 |
| 文件命名 (LOD-0) | `char_su_jianming_portrait_full.png` |
| 文件命名 (LOD-1) | `char_su_jianming_realm1.png` |

**图层结构（PSD 必须分层）：**
1. 背景层（锁定透明）
2. 墨色主体层：人物轮廓 + 劲装衣袍 + 短打披风 + 面部线描
3. 语义色·朱砂红层：剑尖的一抹红
4. 语义色·松石青层：手心灵力汇聚处

**视觉描述：**
少年剑客，短发，身着单层劲装布衣——与林渊同为外门弟子衣料等级相同但剪裁更合身。衣袍边缘的笔触起笔更尖、收笔更利落——以较快的毛笔运行速度表现「锋」。外罩一件短打披风仅及腰际，披风的下缘以干脆的横笔收尾。袖口收紧——以细密的环绕线表现束袖。长剑斜指前方，剑身比林渊窄约 15%，剑尖更锐——以更细的浓墨线勾勒。剑格为八字形金属——以浓墨平面填充，留出细白线表现金属反光。姿态侧身前倾（左倾 8°），重心前移，脊柱微向前弯——一种「蓄势待发」的姿态。头部微侧，视线越过自己的剑尖——眼白与瞳孔的墨色对比度比林渊高，眼神锐利。整体墨色比林渊深约 10%（灰度 55-60%），作为「快攻副手」需要比续航核心更高的视觉存在感。

**美术圣经锚点：**
- 原则 3「秩序辨真，气韵传神」：束袖的细密线（秩序）+ 披风边缘干脆横笔（气韵）
- 六要素：法器锚点（长剑斜向）、衣袍语汇（劲装+短披风）、姿态轴线（侧身前倾 左倾 8°）、墨色基调（55-60%）、阵营纹理（正道排线稍疏更干脆）、眼神方向（微侧视锐利）
- 身份 1 双人视觉互动（§5.1.1）：林渊剑尖指地（守势垂直线）+ 苏剑鸣剑尖斜指（攻势斜线）= 攻守一体

**AI 生成提示（Midjourney）：**
```
Full body portrait of a young male teenage Chinese swordsman, standing in a forward-leaning ready stance, plain white background. He wears a fitted martial tunic and a short cape that ends at his waist. His sleeves are tightly bound at the wrists. Short hair, sharp eyes looking slightly to the side. He holds a narrow straight sword diagonally forward, the blade tip is sharp and pointed. The sword guard is a simple metal bar shape. Chinese ink wash painting (水墨写意), xieyi brushwork, sumi-e style. Grayscale ink only, 5-7 levels, slightly darker than pale gray. A vermillion red (#C41E1E) touch on the sword tip. A tiny turquoise blue (#1A8A8A) glow at his palm chakra. Soft diffused light from upper-left. --no oil painting, 3D render, anime style, vibrant colors, detailed background, Western fantasy elements, gradient background
```

**反向提示（Stable Diffusion）：**
```
oil painting, 3D render, CGI, anime, manga, vibrant colors, colorful, detailed background, European armor, medieval, rim lighting, harsh shadows, gradient background
```

**角色气质关键词：** 锐利、直接、年轻的锋芒、快攻

---

## ASSET-003 — 月清霜（玄冰宫·正道）全身立绘

| 字段 | 值 |
|-------|-------|
| 类别 | 精灵 / 2D 角色立绘 |
| 尺寸 (LOD-0) | 800×1120px，角色主体占垂直 65% |
| 尺寸 (LOD-1) | 200×280px，从 LOD-0 顶部裁 96px，底部裁至膝盖位置，水平居中裁切 |
| 格式 | PNG RGBA8，透明背景，sRGB 色彩空间 |
| 源格式 | PSD 分层源文件 |
| 文件命名 (LOD-0) | `char_yue_qingshuang_portrait_full.png` |
| 文件命名 (LOD-1) | `char_yue_qingshuang_realm2.png` |

**图层结构（PSD 必须分层）：**
1. 背景层（锁定透明）
2. 墨色主体层：三层衣袍（内衬/中衣/外罩薄纱）+ 冰魄剑 + 白发 + 面部线描
3. 语义色·朱砂红层：无（月清霜不使用朱砂红——她的法器不涉及生命/攻击语义）
4. 语义色·松石青层：冰魄剑剑身的冰蓝灵光 + 眉心灵光

**视觉描述：**
白发女修，身着三层广袖长裙——内衬为最淡的墨色（灰度约 85%）、中衣略深（灰度约 80%）、外罩为半透明薄纱质感（以极淡墨 + 大面积留白表现，「不画纱而知纱在」）。衣袖宽大垂地，袖口的边缘以极细的淡墨线收边。冰魄剑以淡墨和白线勾勒——剑身呈半透明质感，通过「留白 + 极淡墨线」表现冰的透明。剑身上有细碎的冰裂纹理——以断续的极淡墨线随机排列。剑柄缠绕着冰蓝发饰——以淡墨线条表现发丝的缠绕纹理。姿态端正直立，脊柱完全垂直——双手交叠于身前，一手持剑，一手自然下垂。面部以最精细的线描勾勒，五官清秀，白发在头顶以淡墨团表现发髻。眼神平视但目光轻微上飘——「视而不见，仿佛在看向远方」。整体墨色是所有初始角色中最淡者（灰度 75-85%），营造「冰天雪地」的疏离感。

**美术圣经锚点：**
- 原则 2「克制即表达」：月清霜的极淡墨调是「克制」的极致——她的存在感来自于缺墨而非浓墨，正如冰的美来自于透明而非厚重
- 原则 3「秩序辨真，气韵传神」：冰魄剑的精密冰裂纹（秩序）+ 薄纱的大面积留白晕染（气韵）
- 六要素：法器锚点（半透明冰魄剑）、衣袍语汇（三层广袖+外罩薄纱）、姿态轴线（直立端正）、墨色基调（75-85% 极淡）、阵营纹理（极细排线间距宽）、眼神方向（平视上飘）
- 例外：不使用朱砂红——法器不涉及生命/攻击语义。仅松石青用于冰蓝灵光

**AI 生成提示（Midjourney）：**
```
Full body portrait of a young female Chinese cultivator with long white hair, standing straight, plain white background. She wears three layers of wide-sleeved robes — the outermost layer is semi-transparent gossamer silk rendered in the palest gray ink wash with large areas of negative space. Her sleeves are extremely wide and drape down to the ground. She holds a translucent ice sword rendered in pale gray ink lines with fine crack patterns. Her hands are folded gracefully in front. Her expression is serene and distant, gaze slightly upward as if looking at something far away. Chinese ink wash painting (水墨写意), xieyi brushwork, sumi-e. Grayscale ink only, extremely pale — the lightest of all characters. A faint turquoise blue (#1A8A8A) glow on the ice sword blade and between her eyebrows. Soft diffused light, no shadows. --no oil painting, 3D render, anime, vibrant colors, background, Western elements
```

**反向提示（Stable Diffusion）：**
```
oil painting, 3D render, CGI, anime, manga, vibrant colors, colorful, warm colors, dark ink, heavy shadows, detailed background, Western clothing, gradient background
```

**角色气质关键词：** 清冷、疏离、透骨的温雅、冰雪

---

## ASSET-004 — 汐音（魅影阁·魔道）全身立绘

| 字段 | 值 |
|-------|-------|
| 类别 | 精灵 / 2D 角色立绘 |
| 尺寸 (LOD-0) | 800×1120px，角色主体占垂直 65% |
| 尺寸 (LOD-1) | 200×280px，从 LOD-0 顶部裁 96px，底部裁至膝盖位置，水平居中裁切 |
| 格式 | PNG RGBA8，透明背景，sRGB 色彩空间 |
| 源格式 | PSD 分层源文件 |
| 文件命名 (LOD-0) | `char_xiyin_portrait_full.png` |
| 文件命名 (LOD-1) | `char_xiyin_realm2.png` |

**图层结构（PSD 必须分层）：**
1. 背景层（锁定透明）
2. 墨色主体层：薄纱长裙 + 身体轮廓 + 面部线描 + 合欢铃
3. 语义色·朱砂红层：合欢铃铃舌的微小红点
4. 语义色·松石青层：手腕灵光

**视觉描述：**
妖媚女修，散发及腰，身着单层薄纱长裙贴体剪裁——纱裙以淡墨（灰度约 55-65%）和大量留白表现半透明质感。肩部和锁骨暴露——以极淡的墨线勾勒锁骨线条。腰部以细带束紧，细带在腰侧打成一个松散的蝴蝶结。裙摆有波浪形不規則边缘——以飘逸的曲线笔触表现「海水」的韵律。合欢铃悬挂于右手腕的细链上——铃身圆形以浓墨细线勾勒，内有暗色铃舌（朱砂红语义色的唯一位置）。身体呈微 S 弯姿态（右倾 5°），重心偏一侧，胯部微送——这是「浪花拍岸」的瞬间姿态。面部五官精致——眼角微微上挑，嘴角微扬，若有若无的笑。头发以淡墨大笔渲染，发梢有细微的分叉——「海风中的散发」。裙摆边缘使用干笔飞白技法——魔道阵营纹理。

**美术圣经锚点：**
- 原则 3「秩序辨真，气韵传神」：合欢铃的精密细线（秩序）+ 散发和裙摆的飘逸飞白（气韵）——魔道的「气韵」是海洋的不可预测
- 六要素：法器锚点（合欢铃）、衣袍语汇（薄纱长裙+锁骨暴露）、姿态轴线（S 弯 右倾 5°）、墨色基调（55-65%）、阵营纹理（魔道不规则飞白）、眼神方向（侧目斜视上挑）

**AI 生成提示（Midjourney）：**
```
Full body portrait of a seductive young female Chinese cultivator with long flowing unbound hair, standing in a slight S-curve pose, plain white background. She wears a single layer form-fitting gossamer dress, shoulders and collarbone exposed, the fabric rendered in pale ink wash with large areas of negative space suggesting translucency. A small round bell (合欢铃) hangs from a thin chain on her right wrist. The hem of her dress has irregular wave-like edges. Her eyes are slightly upturned at the corners, a faint knowing smile. Chinese ink wash painting (水墨写意), xieyi brushwork, sumi-e. Grayscale ink only, medium-light tones. A tiny vermillion red (#C41E1E) dot on the bell clapper. A faint turquoise blue (#1A8A8A) glow at her wrist. Dry brush (干笔飞白) technique on the dress hem. Soft light. --no oil painting, 3D render, anime, vibrant colors, background
```

**反向提示（Stable Diffusion）：**
```
oil painting, 3D render, CGI, anime, manga, vibrant colors, modest clothing, heavy robes, Western clothing, detailed background, gradient background
```

**角色气质关键词：** 妖媚、飘忽、深海来客、诱惑

---

## ASSET-005 — 墨渊（血海殿·魔道）全身立绘

| 字段 | 值 |
|-------|-------|
| 类别 | 精灵 / 2D 角色立绘 |
| 尺寸 (LOD-0) | 800×1120px，角色主体占垂直 65% |
| 尺寸 (LOD-1) | 200×280px，从 LOD-0 顶部裁 96px，底部裁至膝盖位置，水平居中裁切 |
| 格式 | PNG RGBA8，透明背景，sRGB 色彩空间 |
| 源格式 | PSD 分层源文件 |
| 文件命名 (LOD-0) | `char_moyuan_portrait_full.png` |
| 文件命名 (LOD-1) | `char_moyuan_realm2.png` |

**图层结构（PSD 必须分层）：**
1. 背景层（锁定透明）
2. 墨色主体层：全黑斗篷 + 暗色长袍 + 铁链腰带 + 面容
3. 语义色·朱砂红层：血玉骷髅——眼眶中的暗红火光（语义色在法器上的唯一位置）
4. 语义色·松石青层：无（墨渊不使用修为灵光——他的力量来源是血而非灵力）

**视觉描述：**
黑袍魔头，面容藏在厚重全黑斗篷的连帽之下。斗篷以极浓墨（灰度约 15-20%）大块面泼墨渲染——笔触粗犷，边缘呈干涸痕迹的飞白效果。帽檐压低遮住上半张脸——从帽檐下方可以看到一双眼睛，眼白被刻意缩小，瞳孔几乎占据整个可见眼部。中层为暗色长袍（灰度约 20-25%），腰带为三条铁链而非布料——铁链以断续的浓墨粗线表现金属环扣。最内层为高领内衬（灰度约 25%）。左手微抬于胸前，掌心托着一颗血玉骷髅——骷髅以浓墨线描勾勒，眼眶中有暗红色的微光（朱砂红语义色——这是画面中唯一的色彩，面积≤2%）。身体微前倾但头微低——脊柱呈反向 C 弯（肩前倾、胯后坐），右倾 10°——这是「俯视」而非「蓄势」。整体墨色是全部角色中最深者（灰度 15-25%），墨色投入量是其他角色的 1.5 倍。斗篷边缘使用极度粗粝的飞白 + 墨点飞溅效果。

**美术圣经锚点：**
- 原则 2「克制即表达」：墨渊的极浓墨调是「色彩克制」的另一极端——当色彩完全被拒绝，黑暗本身就成了视觉信息。「这个人是深渊」
- 六要素：法器锚点（血玉骷髅）、衣袍语汇（全黑斗篷+铁链腰带）、姿态轴线（反向 C 弯 右倾 10°）、墨色基调（15-25% 极浓）、阵营纹理（魔道极度粗粝飞白）、眼神方向（帽檐下斜视）
- 语义色预算：仅在血玉骷髅眼眶使用朱砂红——≤2% 画面面积

**AI 生成提示（Midjourney）：**
```
Full body portrait of a menacing male Chinese cultivator in an extremely dark, heavy hooded cloak that covers most of his face, plain white background. The cloak is rendered in the deepest black ink wash with rough dry brush edges and ink splatter effects. Only his eyes are visible from under the hood — pupils extremely large, almost no white visible. A dark robe underneath, belt made of three iron chains. In his left palm he holds a small skull artifact — vermillion red (#C41E1E) faint glow from the skull's eye sockets (the ONLY color in the image). His body leans slightly forward but head tilted down — a looming, oppressive stance. Chinese ink wash painting (水墨写意), extreme dark sumi-e, splashed ink technique (泼墨). Deep grayscale, darkest ink tones of all characters. No turquoise, no other colors. --no oil painting, 3D render, anime, colorful, bright, background, Western elements
```

**反向提示（Stable Diffusion）：**
```
oil painting, 3D render, CGI, anime, manga, bright, vibrant colors, colorful, happy expression, handsome face, visible face, Western clothing, background, light background
```

**角色气质关键词：** 威压、深渊、不可名状的恐怖、黑暗

---

## ASSET-006 — 银翎（归墟之境·真灵）全身立绘

| 字段 | 值 |
|-------|-------|
| 类别 | 精灵 / 2D 角色立绘 |
| 尺寸 (LOD-0) | 800×1120px，角色主体占垂直 65% |
| 尺寸 (LOD-1) | 200×280px，从 LOD-0 顶部裁 96px，底部裁至膝盖位置，水平居中裁切 |
| 格式 | PNG RGBA8，透明背景，sRGB 色彩空间 |
| 源格式 | PSD 分层源文件 |
| 文件命名 (LOD-0) | `char_yinling_portrait_full.png` |
| 文件命名 (LOD-1) | `char_yinling_realm3.png` |

**图层结构（PSD 必须分层）：**
1. 背景层（锁定透明）
2. 墨色主体层：异族服饰 + 羽饰披肩 + 银发 + 玉瓶 + 面部线描
3. 语义色·朱砂红层：无（银翎的生命力不是血色的——真灵超越生死）
4. 语义色·松石青层：瓶口逸出的银线灵光 + 眉心灵光 + 羽饰的微光

**视觉描述：**
银发真灵，服饰为不对称异族设计——右肩暴露、左肩覆盖层叠羽饰披肩。羽饰以淡墨渲染（灰度约 70%）+ 留白表现羽毛的轻盈——每片羽毛的轮廓以极细淡墨线勾勒，内部留白。腰部有编织纹理腰带——以交错的细淡墨线表现编织结构。下摆为多层流苏——以垂直线条表现。银翎玉瓶悬浮于右手掌心上——瓶身以极淡墨（灰度约 80%）+ 白线勾勒，呈半透明质感。瓶口逸出极细的银线——以松石青（#1A8A8A）着色，细线盘旋上升。银发以极淡墨 + 大量留白表现——「不画银而知银在」。姿态直立但有轻微的悬浮感——脚跟微离地面，仿佛飘浮。双手在胸前，右手托瓶，左手护瓶——这是「守护」而非「使用」的姿态。面部以精细线描勾勒，五官端正但有一种「非人」的完美感。眼神平视，温柔但有距离感——「天人相隔」的疏离。

**美术圣经锚点：**
- 原则 3「秩序辨真，气韵传神」：编织腰带的几何秩序 + 羽饰飘浮的有机气韵——归墟之境的秩序是「更高维度的几何」
- 六要素：法器锚点（银翎玉瓶悬浮）、衣袍语汇（异族不对称羽饰）、姿态轴线（直立悬浮）、墨色基调（65-75%）、阵营纹理（中立光滑晕染）、眼神方向（平视温柔疏离）
- 中立阵营纹理（§4.5）：不使用排线或飞白——过渡全部使用水墨晕染（渐变而非线条）

**AI 生成提示（Midjourney）：**
```
Full body portrait of an androgynous silver-haired celestial being (真灵), standing with heels slightly off the ground as if floating, plain white background. Wears asymmetrical exotic clothing — right shoulder bare, left shoulder covered by layered feather-like cape rendered in pale ink wash with negative space. A small translucent jade bottle floats above the right palm, with a thin turquoise blue (#1A8A8A) mist spiraling from its mouth. Woven textured belt, multi-layered tassel hem. Silver hair rendered primarily through negative space with minimal pale ink lines. Gentle distant gaze, inhumanly perfect features. Chinese ink wash painting (水墨写意), smooth wet-ink blending (晕染) with no cross-hatching. Grayscale ink, medium-light tones. Turquoise blue (#1A8A8A) only on the mist and between eyebrows. --no oil painting, 3D render, anime, cross-hatching, dry brush, dark ink, vibrant colors, background
```

**反向提示（Stable Diffusion）：**
```
oil painting, 3D render, CGI, anime, manga, dark, heavy shadows, cross-hatching, dry brush, human appearance, normal human proportions, Western angel, wings, vibrant colors, background
```

**角色气质关键词：** 神圣、古老、跨越时间的温柔、异族

---

## ASSET-007 — 万象真人（万象阁·正道）全身立绘

| 字段 | 值 |
|-------|-------|
| 类别 | 精灵 / 2D 角色立绘 |
| 尺寸 (LOD-0) | 800×1120px，角色主体占垂直 65% |
| 尺寸 (LOD-1) | 200×280px，从 LOD-0 顶部裁 96px，底部裁至膝盖位置，水平居中裁切 |
| 格式 | PNG RGBA8，透明背景，sRGB 色彩空间 |
| 源格式 | PSD 分层源文件 |
| 文件命名 (LOD-0) | `char_wanxiang_zhenren_portrait_full.png` |
| 文件命名 (LOD-1) | `char_wanxiang_zhenren_realm3.png` |

**图层结构（PSD 必须分层）：**
1. 背景层（锁定透明）
2. 墨色主体层：三层道袍（含星纹）+ 罗盘 + 面部线描（含皱纹）
3. 语义色·朱砂红层：无
4. 语义色·松石青层：罗盘边缘的灵光刻度

**视觉描述：**
老年男修，白须垂胸。身着三层道袍——内衬（灰度约 60%）、中衣（灰度约 55%）、外罩道袍（灰度约 50%）——外袍上有星纹图案，以极细的淡墨点排列成星座的形状。腰带为编织丝绦——以交错的细墨线表现编织纹理。袖口宽大垂地。左手托举大衍罗盘在前——罗盘以精密界画风格绘制：多层同心圆 + 方格线，盘边缘有小字标注（以微型墨点模拟文字）。罗盘的精密几何线条与道袍的柔软垂坠形成「秩序 vs 气韵」的对比。右手自然背于身后。姿态微前倾（左倾 2°）——年轮使脊柱自然微弯。面部以精细线描勾勒——眼角和额头有细密皱纹（以极细淡墨短线表现），白须以大块淡墨 + 飞白表现蓬松感。眼周使用细密交叉排线（学术感的阴影处理）。眼神平视但目光略微向下——不是在俯视，而是在思考。整体墨色中灰（灰度 50-60%）。

**美术圣经锚点：**
- 原则 3「秩序辨真，气韵传神」：罗盘的精密界画（秩序——知识的几何化）+ 道袍的柔软垂坠（气韵——智者的从容）。这是原则 3 在同一角色内部的最强对比
- 六要素：法器锚点（大衍罗盘界画风格）、衣袍语汇（三层道袍+星纹+丝绦）、姿态轴线（微前倾 左倾 2°）、墨色基调（50-60%）、阵营纹理（正道极细密交叉排线学术感）、眼神方向（平视略向下思考）

**AI 生成提示（Midjourney）：**
```
Full body portrait of an elderly Chinese Daoist master with a long white beard, standing slightly hunched with age, plain white background. He wears three layers of Daoist robes — the outer robe has subtle constellation patterns rendered as tiny pale ink dots. His belt is a braided silk cord. In his left palm he holds a large circular compass (罗盘) with multiple concentric rings and grid lines in precise ruled-line painting style (界画). His right hand is behind his back. His face has fine wrinkles around the eyes, rendered in tiny pale ink lines. His expression is contemplative, gaze slightly downward. Chinese ink wash painting (水墨写意), precise ruled-line technique for the compass, soft flowing brushwork for the robes. Grayscale ink only, medium tones. Fine cross-hatching in the eye area. A faint turquoise blue (#1A8A8A) marking at the compass edge. --no oil painting, 3D render, anime, vibrant colors, young face, background
```

**反向提示（Stable Diffusion）：**
```
oil painting, 3D render, CGI, anime, manga, young, muscular, clean-shaven, vibrant colors, Western wizard, Western robe, background
```

**角色气质关键词：** 睿智、古老、知识的重量、学者

---

## ASSET-008 — 沐瑶（轮回殿·魔道）全身立绘

| 字段 | 值 |
|-------|-------|
| 类别 | 精灵 / 2D 角色立绘 |
| 尺寸 (LOD-0) | 800×1120px，角色主体占垂直 65% |
| 尺寸 (LOD-1) | 200×280px，从 LOD-0 顶部裁 96px，底部裁至膝盖位置，水平居中裁切 |
| 格式 | PNG RGBA8，透明背景，sRGB 色彩空间 |
| 源格式 | PSD 分层源文件 |
| 文件命名 (LOD-0) | `char_muyao_portrait_full.png` |
| 文件命名 (LOD-1) | `char_muyao_realm2.png` |

**图层结构（PSD 必须分层）：**
1. 背景层（锁定透明）
2. 墨色主体层：双层裙 + 蝴蝶结腰带 + 双马尾 + 面部线描 + 轮回镜
3. 语义色·朱砂红层：无
4. 语义色·松石青层：手背轮回印记 + 轮回镜镜面漩涡的微光

**视觉描述：**
少女魔修，双马尾辫长及腰际——发辫以淡墨渲染，发尾有微卷。身着双层裙——内裙以淡墨（灰度约 65%）平涂，外裙罩（灰度约 70%）有荷叶边——荷叶边以波浪形淡墨线表现。腰部以一只大蝴蝶结束腰——蝴蝶结以浓墨勾勒轮廓，内部淡墨填充。轮回镜悬挂于胸前——小型圆形镜子，镜框有细密的轮回符号雕刻（以极细的淡墨同心圆 + 短线表现），镜面以淡墨渲染出漩涡纹理。右手手背上有轮回印记——以松石青（#1A8A8A）绘制的盘旋纹样（面积≤1.5%）。双手自然交握于胸前——不是防御的姿态，是「期待」。姿态微前倾（右倾 3°），好奇的小女孩姿态。面部以精细线描勾勒——眼睛大而圆（瞳孔占比约 60%），眼神纯真但有暗流——「不是不知世故，是选择了纯真」。嘴角微扬。裙摆边缘有轻微的粗粝飞白（魔道阵营纹理），但比墨渊柔和得多。整体墨色偏淡（灰度 60-70%），保持少女感。

**美术圣经锚点：**
- 原则 2「克制即表达」：沐瑶的纯真外表与她作为轮回殿成员的残酷使命之间的张力——克制在视觉上表现为「淡墨少女」，释放时（复活技能）才是色彩进场
- 六要素：法器锚点（轮回镜+手背印记）、衣袍语汇（双层裙+蝴蝶结+双马尾）、姿态轴线（微前倾好奇 右倾 3°）、墨色基调（60-70%）、阵营纹理（轻微粗粝飞白）、眼神方向（正面大眼纯真）

**AI 生成提示（Midjourney）：**
```
Full body portrait of a young teenage girl cultivator with twin ponytails reaching her waist, standing with a slight forward lean of curiosity, plain white background. She wears a two-layer dress — inner dress in pale ink wash, outer dress with ruffle-edged hem. A large bow belt cinches her waist. A small round mirror (轮回镜) hangs from a cord around her neck, with spiral patterns in pale ink on its surface. On the back of her right hand is a turquoise blue (#1A8A8A) spiral mark. Her eyes are large and round, expression innocent but with hidden depth. Chinese ink wash painting (水墨写意), soft brushwork. Grayscale ink, light to medium-light tones. Slight dry brush (飞白) only at the hem edges. Turquoise blue (#1A8A8A) only on the hand mark and mirror glow. Soft light. --no oil painting, 3D render, anime, dark, heavy ink, mature features, vibrant colors, background
```

**反向提示（Stable Diffusion）：**
```
oil painting, 3D render, CGI, anime, manga, dark, mature, adult woman, heavy makeup, heavy ink, vibrant colors, background
```

**角色气质关键词：** 纯真、矛盾、轮回守护者、少女

---

## ASSET-009 — 啼魂（归墟之境·灵兽）全身立绘

| 字段 | 值 |
|-------|-------|
| 类别 | 精灵 / 2D 角色立绘 |
| 尺寸 (LOD-0) | 800×1120px，角色主体占垂直 60%（比常规角色略矮——幼童体型） |
| 尺寸 (LOD-1) | 200×280px，从 LOD-0 顶部裁 86px（更大的顶部留白因角色矮），底部裁至膝盖位置 |
| 格式 | PNG RGBA8，透明背景，sRGB 色彩空间 |
| 源格式 | PSD 分层源文件 |
| 文件命名 (LOD-0) | `char_tihun_portrait_full.png` |
| 文件命名 (LOD-1) | `char_tihun_realm4.png` |

**图层结构（PSD 必须分层）：**
1. 背景层（锁定透明）
2. 墨色主体层：对襟短衣 + 宽腿短裤 + 兽耳 + 项圈 + 啼魂铃 + 面部线描
3. 语义色·朱砂红层：项圈上的血色符号（≤1%）
4. 语义色·松石青层：啼魂铃的幽冥微光

**视觉描述：**
兽耳幼童，尖耳朵（类似猫耳但更尖长）从蓬松的短发中伸出——耳朵内部以淡墨渲染，边缘以浓墨线勾勒。颈上戴着皮革材质项圈——以浓墨粗线表现皮革质感。项圈上挂着大型啼魂铃——铃身比普通铃铛约大 3 倍，铃身表面有暗色符文雕刻（以浓墨细线表现幽冥符文）。铃口边缘有松石青的幽冥微光（语义色）。身着简单对襟短衣（灰度约 55%）+ 宽腿短裤（灰度约 60%），衣服边缘有毛边——以不规则的淡墨短线表现缝线外的毛边。赤脚——脚趾以简笔淡墨勾勒。姿态微蹲——脊柱微弯，不是站立而是随时要跳起来的姿态。面部以精细线描勾勒——大眼睛向上看观众，瞳孔大而圆（占比约 70%），眼神不是乞求而是好奇。衣服边缘有轻微的粗粝飞白（中立阵营但保留「灵兽的野性」）。

**美术圣经锚点：**
- 原则 3「秩序辨真，气韵传神」：项圈的皮革纹理（秩序）+ 毛边和飞白（气韵——野性）
- 六要素：法器锚点（项圈啼魂铃）、衣袍语汇（对襟短衣+毛边+赤脚+兽耳）、姿态轴线（微蹲随时跳跃）、墨色基调（50-60%）、阵营纹理（光滑晕染+轻微飞白）、眼神方向（上视好奇）
- 中立阵营纹理（§4.5）：主过渡=水墨晕染，但边缘保留轻微飞白——灵兽不完全遵循「正/魔」二分

**AI 生成提示（Midjourney）：**
```
Full body portrait of a beast-eared child cultivator with pointed animal ears poking out of fluffy short hair, standing in a crouched ready-to-jump pose, plain white background. Wears a simple short cross-collar top and loose knee-length pants with raw frayed edges. A leather collar around the neck holds a large bell (啼魂铃) about 3x normal size, with dark runic engravings on its surface. Bare feet. Large round curious eyes looking up at the viewer. Chinese ink wash painting (水墨写意), with slight dry brush texture at clothing edges suggesting wildness. Grayscale ink, medium tones. A faint turquoise blue (#1A8A8A) glow at the bell's rim. A tiny vermillion red (#C41E1E) mark on the collar. --no oil painting, 3D render, anime, human ears, adult proportions, vibrant colors, background
```

**反向提示（Stable Diffusion）：**
```
oil painting, 3D render, CGI, anime, manga, human ears, adult, mature, human proportions, vibrant colors, background
```

**角色气质关键词：** 好奇、野性、冥界小使者、灵兽

---

## ASSET-010 — 柳媚儿（魅影阁·魔道）全身立绘

| 字段 | 值 |
|-------|-------|
| 类别 | 精灵 / 2D 角色立绘 |
| 尺寸 (LOD-0) | 800×1120px，角色主体占垂直 65% |
| 尺寸 (LOD-1) | 200×280px，从 LOD-0 顶部裁 96px，底部裁至膝盖位置，水平居中裁切 |
| 格式 | PNG RGBA8，透明背景，sRGB 色彩空间 |
| 源格式 | PSD 分层源文件 |
| 文件命名 (LOD-0) | `char_liu_meier_portrait_full.png` |
| 文件命名 (LOD-1) | `char_liu_meier_realm1.png` |

**图层结构（PSD 必须分层）：**
1. 背景层（锁定透明）
2. 墨色主体层：修身长裙 + 半透明纱衣 + 刺绣腰带 + 团扇 + 面部线描
3. 语义色·朱砂红层：惑心符上的符文 + 眼角桃花妆淡红晕（合计≤3%）
4. 语义色·松石青层：符纸边缘灵光（≤1.5%）

**视觉描述：**
成熟媚态女修，身着单层修身长裙（灰度约 55%）贴体剪裁，领口大开——锁骨和胸前以极淡墨线勾勒。外罩半透明纱衣——纱衣以极淡墨（灰度约 75%）+ 大面积留白表现透明感。腰部有宽幅刺绣腰带——腰带上以细密的淡墨点排列成花卉纹样。左手持团扇——团扇以圆形淡墨框架 + 内部留白表现，扇面边缘有淡墨晕染的花卉。右手手持惑心符——符纸以朱砂红（#C41E1E）绘制符文（语义色），符纸边缘有松石青（#1A8A8A）的灵光微闪。身体呈 S 弯姿态（右倾 7°）——肩回缩、胸微挺、胯送出。面部以精细线描勾勒——眼角上挑，眉头微抬。桃花妆——眼角有极淡的朱砂红晕（以极淡的红色晕染而非线条，面积≤1%）。头发盘成高髻，以簪子固定——簪子以浓墨线勾勒。裙摆和袖口边缘有不规则飞白（魔道阵营纹理）。整体墨色中灰偏淡（灰度 55-65%）。

**美术圣经锚点：**
- 原则 1「信息即颜色」：柳媚儿的朱砂红用于两处——惑心符符文（「这张符在控制你」）+ 眼角红晕（「她在魅惑你」）。两处红色都在传递同一个信息：危险的美
- 六要素：法器锚点（惑心符朱砂红符文+团扇）、衣袍语汇（修身长裙+纱衣+刺绣腰带）、姿态轴线（S 弯 右倾 7°）、墨色基调（55-65%）、阵营纹理（魔道不规则飞白）、眼神方向（侧目上挑眉微抬桃花妆）

**AI 生成提示（Midjourney）：**
```
Full body portrait of a mature seductive female Chinese cultivator in an S-curve pose, plain white background. She wears a form-fitting long dress with a deep neckline, and a semi-transparent outer robe rendered in the palest ink wash with lots of negative space. A wide embroidered belt cinches her waist. She holds a round flat fan in her left hand and a talisman paper (符箓) in her right — the talisman has vermillion red (#C41E1E) runic symbols and a faint turquoise blue (#1A8A8A) glow at its edges. Her eyes are upturned with faint vermillion blush at the corners (桃花妆). Her hair is in a high bun with a hairpin. Chinese ink wash painting (水墨写意), dry brush (飞白) on the hem and cuffs. Grayscale ink, medium-light tones. Vermillion red (#C41E1E) only on the talisman runes and eye corner blush. --no oil painting, 3D render, anime, modest clothing, dark ink, vibrant colors, background
```

**反向提示（Stable Diffusion）：**
```
oil painting, 3D render, CGI, anime, manga, modest, fully covered, dark, vibrant colors, background, Western clothing
```

**角色气质关键词：** 妖娆、危险的美、无法拒绝的诱惑、桃花

---

## ASSET-011 — 方灵素（丹霞谷·正道）全身立绘

| 字段 | 值 |
|-------|-------|
| 类别 | 精灵 / 2D 角色立绘 |
| 尺寸 (LOD-0) | 800×1120px，角色主体占垂直 65% |
| 尺寸 (LOD-1) | 200×280px，从 LOD-0 顶部裁 96px，底部裁至膝盖位置，水平居中裁切 |
| 格式 | PNG RGBA8，透明背景，sRGB 色彩空间 |
| 源格式 | PSD 分层源文件 |
| 文件命名 (LOD-0) | `char_fang_lingsu_portrait_full.png` |
| 文件命名 (LOD-1) | `char_fang_lingsu_realm1.png` |

**图层结构（PSD 必须分层）：**
1. 背景层（锁定透明）
2. 墨色主体层：宽松布袍 + 围裙 + 药篓 + 储物袋 + 丹炉 + 面部线描
3. 语义色·朱砂红层：无
4. 语义色·松石青层：丹炉逸出的灵光 + 眉心灵光

**视觉描述：**
温婉女丹师，身着宽松素色布袍（灰度约 70%）——袖子比一般道袍更宽，便于在丹炉前操作。袖口以淡墨大笔渲染，笔触柔和无棱角。腰间围有粗布围裙（灰度约 65%），围裙上有淡淡的药材渍迹——以极淡的不规则墨点随机分布，不是污渍而是「工作的痕迹」。背后斜挎一个药篓——药篓以竹编纹理表现（交错的细淡墨线），篓口露出几株草药的叶片（以淡墨勾勒轮廓+留白）。腰间悬挂鼓胀的储物袋——袋口束紧，袋身以圆润的淡墨曲线表现鼓胀感。右手托着小型三足丹炉——丹炉以浓墨线勾勒三足和炉身，炉盖微开，从缝隙中逸出淡墨烟云（以淡墨的波浪形笔触表现丹气）。松石青的灵光（#1A8A8A）从炉盖缝隙中微闪。姿态微前倾（左倾 1°）——双手护着丹炉，不是蓄势而是「照顾」。面部以精细线描勾勒——五官柔和，眼神温暖，嘴角有淡淡的微笑。整体墨色中淡（灰度 65-75%），素雅温婉。卡牌上方悬浮一片淡墨卡牌剪影——标识其天赋效果「每回合额外抽1张牌」。

**美术圣经锚点：**
- 原则 3「秩序辨真，气韵传神」：丹炉的精密三足结构（秩序）+ 药篓竹编纹理（秩序）+ 烟云墨气（气韵）。方灵素是「秩序中藏着气韵」的代表——她的气韵不在衣袍而在丹炉中逸出的那缕烟
- 六要素：法器锚点（储物袋+丹炉）、衣袍语汇（宽袖布袍+围裙+药篓）、姿态轴线（微前倾护炉 左倾 1°）、墨色基调（65-75%）、阵营纹理（正道细密排线间距宽）、眼神方向（平视温暖微笑）

**AI 生成提示（Midjourney）：**
```
Full body portrait of a gentle female Chinese alchemist cultivator, standing with a slight forward lean as if protecting something, plain white background. She wears a loose light-colored cloth robe with especially wide sleeves, and a coarse apron tied at the waist with faint herbal stain marks. A woven bamboo basket (药篓) is slung across her back with herb leaves peeking out. A bulging storage pouch hangs from her waist. In her right palm she holds a small three-legged alchemical furnace (丹炉) — the lid is slightly open and pale ink smoke drifts out, with a faint turquoise blue (#1A8A8A) spiritual glow from the crack. Her expression is warm with a gentle smile. Chinese ink wash painting (水墨写意), soft brushwork. Grayscale ink, light tones. Fine sparse cross-hatching (正道) on the robe shadows. Turquoise blue only on the furnace glow and between eyebrows. --no oil painting, 3D render, anime, dark ink, vibrant colors, background
```

**反向提示（Stable Diffusion）：**
```
oil painting, 3D render, CGI, anime, manga, dark, heavy ink, seductive, mature, vibrant colors, background, Western alchemist
```

**角色气质关键词：** 温婉、细心、丹道的守护者、素雅

---

## ASSET-012 — 赤练仙子（丹霞谷·正道）全身立绘

| 字段 | 值 |
|-------|-------|
| 类别 | 精灵 / 2D 角色立绘 |
| 尺寸 (LOD-0) | 800×1120px，角色主体占垂直 65% |
| 尺寸 (LOD-1) | 200×280px，从 LOD-0 顶部裁 96px，底部裁至膝盖位置，水平居中裁切 |
| 格式 | PNG RGBA8，透明背景，sRGB 色彩空间 |
| 源格式 | PSD 分层源文件 |
| 文件命名 (LOD-0) | `char_chilian_xianzi_portrait_full.png` |
| 文件命名 (LOD-1) | `char_chilian_xianzi_realm1.png` |

**图层结构（PSD 必须分层）：**
1. 背景层（锁定透明）
2. 墨色主体层：多层裙（外层修身+内层火焰纹）+ 三焰扇 + 火焰簪子 + 面部线描
3. 语义色·朱砂红层：袖口下摆火焰纹饰 + 三焰扇上的一簇火焰（合计≤3.5%——这是所有正道角色中朱砂红占比最高者）
4. 语义色·松石青层：三焰扇上的第二簇火焰 + 眉心灵光

**视觉描述：**
自信女修，身着多层裙——外层为修身长裙（灰度约 40%——比一般正道角色略深，与「火」属性相称），内层衬裙有火焰纹饰。袖口和下摆以朱砂红（#C41E1E）绘制火焰纹——纹样为简化的火苗形状，以断续的朱砂红短线排列。发饰为火焰状簪子——簪子以浓墨线勾勒火焰轮廓，内部以朱砂红渲染。一手持三焰扇在胸前展开——扇面以淡墨（灰度约 65%）平涂，扇骨以浓墨直线表现。扇面上有三簇火焰纹饰：第一簇以朱砂红绘制（左侧）、第二簇以松石青绘制（中央）、第三簇以朱砂红绘制（右侧）——这是唯一一个在法器上同时使用两种语义色的角色。另一手叉腰——自信的姿态。姿态直立挺胸（左倾 4°）。面部以精细线描勾勒——眼神明亮自信，直视观众，眼白瞳孔对比度高。嘴角微扬。整体墨色中灰偏浓（灰度 40-50%），配合火焰纹饰，视觉温度最高。

**美术圣经锚点：**
- 原则 2「克制即表达」：赤练仙子是「克制框架内的释放」——她的火焰色彩在正道角色中独占鳌头，但仍在严格的面积预算（朱砂红≤3.5%、松石青≤1.5%）内
- 六要素：法器锚点（三焰扇·双语义色）、衣袍语汇（多层裙+火焰纹饰+火焰簪）、姿态轴线（直立挺胸叉腰 左倾 4°）、墨色基调（40-50%比一般正道深）、阵营纹理（正道排线+火焰纹理）、眼神方向（直视自信）
- 特殊许可：两种语义色同时出现于法器——经 §5.X.2 特别批准（法器尺寸较大时允许双色标注）

**AI 生成提示（Midjourney）：**
```
Full body portrait of a confident female Chinese cultivator, standing tall with one hand on her hip, plain white background. She wears a multi-layered dress — the outer layer is a fitted long dress in medium-dark ink wash with vermillion red (#C41E1E) flame patterns along the cuffs and hem. A flame-shaped hairpin in her hair. She holds a large open folding fan (折扇) in front of her chest — the fan has three flame emblems: vermillion red on left and right, turquoise blue (#1A8A8A) in the center. Her expression is bright and confident, looking directly at the viewer. Chinese ink wash painting (水墨写意), fine cross-hatching (正道) on robe shadows with flame-like stroke variations. Grayscale ink, medium-dark tones. Vermillion red on flame patterns and fan emblems. Turquoise blue on center fan flame and between eyebrows. --no oil painting, 3D render, anime, dark robes, muted expression, vibrant colors, background
```

**反向提示（Stable Diffusion）：**
```
oil painting, 3D render, CGI, anime, manga, dark robes, shy, muted, fully black ink, no red, background
```

**角色气质关键词：** 自信、热烈、火焰的主人、正道之光

---

## ASSET-013 — 通用正道立绘

| 字段 | 值 |
|-------|-------|
| 类别 | 精灵 / 2D 角色立绘 |
| 尺寸 (LOD-0) | 800×1120px，角色主体占垂直 65% |
| 尺寸 (LOD-1) | 200×280px，从 LOD-0 顶部裁 96px，底部裁至膝盖位置，水平居中裁切 |
| 格式 | PNG RGBA8，透明背景，sRGB 色彩空间 |
| 源格式 | PSD 分层源文件 |
| 文件命名 (LOD-0) | `char_generic_zhengdao_portrait_full.png` |
| 文件命名 (LOD-1) | `char_generic_zhengdao.png` |

**复用范围**：石岩、刘青松、刘青松（筑基）、耿忠、叶知秋、万三姑、卫天寒——所有无专属立绘的正道填充角色共用此立绘。

**图层结构（PSD 必须分层）：**
1. 背景层（锁定透明）
2. 墨色主体层：标准青云剑宗道袍 + 普通长剑 + 中性面容
3. 语义色层：无——通用立绘不使用任何语义色（这是「通用」的视觉信号——没有个性=没有色彩）

**视觉描述：**
标准青云剑宗外门弟子——与林渊同款的粗布道袍（灰度约 60%），腰束为布带而非麻绳。手持普通长剑——剑身为标准宽度，剑格为简单方形金属。面容中性——无明显情绪特征，五官端正但不突出。姿态直立（左倾 1°）。头发束起为标准道髻。衣袍阴影使用正道细密排线（灰度约 55%）。整体墨色中灰（灰度 55-65%）。这张立绘的视觉原则是「不被记住」——它代表的是一个群体而非个体。

**AI 生成提示（Midjourney）：**
```
Full body portrait of a generic young male Chinese Daoist cultivator, standing straight, plain white background. He wears a standard coarse cloth Daoist robe, tied with a cloth belt. He holds a normal straight sword with a simple square guard. His hair is in a standard topknot. His facial features are neutral and unremarkable — neither handsome nor ugly. Chinese ink wash painting (水墨写意), fine cross-hatching on robe shadows. Grayscale ink only, medium tones. NO vermillion red, NO turquoise blue — purely monochrome ink. --no oil painting, 3D render, anime, distinctive features, scars, tattoos, vibrant colors, semantic colors, background
```

**反向提示（Stable Diffusion）：**
```
oil painting, 3D render, CGI, anime, manga, distinctive, unique, scarred, tattooed, handsome, ugly, expressive, vibrant colors, red, blue, gold, background
```

**角色气质关键词：** 标准、普通、群体代表、无个性

---

## ASSET-014 — 通用魔道立绘

| 字段 | 值 |
|-------|-------|
| 类别 | 精灵 / 2D 角色立绘 |
| 尺寸 (LOD-0) | 800×1120px，角色主体占垂直 65% |
| 尺寸 (LOD-1) | 200×280px，从 LOD-0 顶部裁 96px，底部裁至膝盖位置，水平居中裁切 |
| 格式 | PNG RGBA8，透明背景，sRGB 色彩空间 |
| 源格式 | PSD 分层源文件 |
| 文件命名 (LOD-0) | `char_generic_modao_portrait_full.png` |
| 文件命名 (LOD-1) | `char_generic_modao.png` |

**复用范围**：贾天煞、陆夫人、乌煞、古长老、血海少主、余子童——所有无专属立绘的魔道填充角色共用此立绘。

**图层结构（PSD 必须分层）：**
1. 背景层（锁定透明）
2. 墨色主体层：深色劲装 + 短披风 + 面容
3. 语义色层：无——通用魔道也不使用语义色

**视觉描述：**
标准魔道散修——深色劲装（灰度约 40%），外罩短披风（灰度约 35%）。披风边缘有粗粝飞白——魔道阵营纹理。面容阴冷但不狰狞——眉头微锁，嘴角平直。姿态微前倾（右倾 3°）。头发束起但比正道松散——几缕散发垂在脸侧。腰部束有皮质腰带。与通用正道相比，墨色整体深 20-25 灰度点。同样遵循「不被记住」的视觉原则。

**AI 生成提示（Midjourney）：**
```
Full body portrait of a generic male Chinese dark cultivator, standing with a slight forward lean, plain white background. He wears a dark martial tunic with a short cape. The cape edges have rough dry brush (飞白) texture. His expression is cold but not menacing — brows slightly furrowed. His hair is tied back but looser than Daoist style, with a few strands framing his face. Chinese ink wash painting (水墨写意), rough dry brush on cape edges. Grayscale ink only, medium-dark tones. NO vermillion red, NO turquoise blue — purely monochrome ink. --no oil painting, 3D render, anime, distinctive features, scars, tattoos, handsome, ugly, expressive, vibrant colors, background
```

**反向提示（Stable Diffusion）：**
```
oil painting, 3D render, CGI, anime, manga, distinctive, unique, scarred, tattooed, handsome, ugly, expressive, vibrant colors, red, blue, gold, background
```

**角色气质关键词：** 阴冷、普通、魔道散修、无个性

---

## ASSET-015 — 通用中立立绘

| 字段 | 值 |
|-------|-------|
| 类别 | 精灵 / 2D 角色立绘 |
| 尺寸 (LOD-0) | 800×1120px，角色主体占垂直 65% |
| 尺寸 (LOD-1) | 200×280px，从 LOD-0 顶部裁 96px，底部裁至膝盖位置，水平居中裁切 |
| 格式 | PNG RGBA8，透明背景，sRGB 色彩空间 |
| 源格式 | PSD 分层源文件 |
| 文件命名 (LOD-0) | `char_generic_zhongli_portrait_full.png` |
| 文件命名 (LOD-1) | `char_generic_zhongli.png` |

**复用范围**：血玉虫——所有无明确正魔归属的填充角色共用此立绘。

**图层结构（PSD 必须分层）：**
1. 背景层（锁定透明）
2. 墨色主体层：布衣 + 短打 + 面容
3. 语义色层：无

**视觉描述：**
散修装扮——介于正魔之间。布衣（灰度约 55%）+ 短打（灰度约 50%），无披风、无道袍、无劲装特征。面容中性——无阵营倾向。姿态直立。衣袍阴影使用中立阵营的水墨晕染（无排线、无飞白——纯墨色渐变过渡）。不携带法器——或者只携带一个简单的储物袋。这是「无归属者」的视觉定义。

**AI 生成提示（Midjourney）：**
```
Full body portrait of a generic neutral cultivator, standing straight, plain white background. He wears simple cloth clothes — no Daoist robe, no martial tunic, no cape. His expression is neutral, unaligned. No visible weapon or artifact. Chinese ink wash painting (水墨写意), smooth wet-ink blending (晕染) with no cross-hatching or dry brush. Grayscale ink only, medium tones. NO vermillion red, NO turquoise blue — purely monochrome ink. --no oil painting, 3D render, anime, Daoist robe, martial clothing, cape, weapon, distinctive features, vibrant colors, background
```

**反向提示（Stable Diffusion）：**
```
oil painting, 3D render, CGI, anime, manga, Daoist, martial, armed, cape, robe, distinctive, unique, expressive, vibrant colors, red, blue, gold, background
```

**角色气质关键词：** 中性、散修、无归属、普通人

---

## 技术规范汇总

### 内存估算

| LOD 级别 | 单张内存 (RGBA8) | 数量 | 合计 |
|:--:|:--:|:--:|:--:|
| LOD-0 | ~3.4 MB | 15 | ~51 MB |
| LOD-1 | ~219 KB | 15 | ~3.3 MB |
| DXT5/BC3 压缩后 (LOD-0) | ~0.85 MB | 15 | ~12.8 MB |
| DXT5/BC3 压缩后 (LOD-1) | ~55 KB | 15 | ~0.8 MB |

> Godot 4.6 在 D3D12 后端默认使用 BC3/DXT5 VRAM 压缩——实际 GPU 内存约为上表压缩后数字。峰值加载全部 15 张 LOD-0 + 15 张 LOD-1 ≈ 13.6 MB，远在 2GB 预算之内。

### Godot 导入预设（统一应用于全部 15 个 PNG）

```gdscript
[import]
type = "Texture2D"

[params]
compress/mode = 2              # VRAM 压缩（D3D12 = BC3/DXT5）
compress/high_quality = true
compress/hdr_compression = 1   # 禁用 HDR 压缩
mipmaps/generate = false       # 2D 固定分辨率——无 MipMaps
mipmaps/limit = -1
detect_3d/compress_to = 0
svg/scale = 1.0
roughness/mode = 0
process/channel_pack = 0
process/fix_alpha_border = true
process/premult_alpha = true
process/normal_map_invert_y = 0
process/hdr_as_srgb = true
process/hdr_clamp_exposure = false
process/size_limit = 0
```

### 色彩校准参考值

| 墨阶级别 | 十六进制 | 允许的灰度偏差 |
|:--:|----------|:--:|
| 纯黑 | #000000 | **禁止在插画中使用** |
| 浓墨 | #1a1a1a | ±5（#151515 - #1f1f1f） |
| 中墨 | #4a4a4a | ±5（#454545 - #4f4f4f） |
| 淡墨 | #7a7a7a | ±5（#757575 - #7f7f7f） |
| 极淡墨 | #aaaaaa | ±5（#a5a5a5 - #afafaf） |
| 烟灰 | #d4d4d4 | ±3（#d1d1d1 - #d7d7d7） |
| 暖白 | #f5f0eb | ±3（#f2ede8 - #f8f3ee） |

| 语义色 | 十六进制 | Delta E 上限 |
|------|----------|:--:|
| 朱砂红 | #C41E1E | ≤3 |
| 松石青 | #1A8A8A | ≤3 |
| 琉璃金 | #C9A96E | ≤3 |

### LOD-1 裁切统一参数

对于常规成人角色（ASSET-001 至 008、010 至 015）：
- 从 LOD-0 顶部裁切：96px（保留角色头顶上方约 5% 的呼吸空间）
- 从 LOD-0 底部裁切：768px 处截止（约为膝盖位置，裁去小腿和脚——保留 LOD-0 的全部辨识特征）
- 水平居中裁切：以角色脊椎线为基准，左右各取 100px
- 输出分辨率：200×280px

对于幼童体型（ASSET-009 啼魂）：
- 从 LOD-0 顶部裁切：86px（因角色矮，更大的顶部留白比例）
- 底部裁切和水平裁切同上

---

## 补充角色立绘规格（扩展至全部独立角色）

> **追加日期**：2026-07-26
> **追加范围**：23 张新增独立角色立绘（ASSET-180 至 ASSET-202），覆盖除 12 核心+3 通用外的全部独立角色
> **总立绘量**：12 核心 + 3 通用 + 23 新增 = 38 张 LOD-0 立绘
> **跨境界复用**：同名角色各境界共用一张立绘（如李元化炼气/金丹共用 ASSET-186）

---

## 炼气期新增角色（6 张）

### ASSET-180 — 石岩（青云剑宗·正道）

| 字段 | 值 |
|-------|-------|
| 类别 | 精灵 / 2D 角色立绘 |
| 尺寸 (LOD-0) | 800×1120px，角色主体占垂直 65% |
| 尺寸 (LOD-1) | 200×280px，标准裁切参数 |
| 格式 | PNG RGBA8，透明背景 |
| 源格式 | PSD 分层源文件 |
| 文件命名 (LOD-0) | `char_shi_yan_portrait_full.png` |
| 文件命名 (LOD-1) | `char_shi_yan_realm1.png` |

**图层结构（PSD 必须分层）：**
1. 背景层（锁定透明）
2. 墨色主体层：厚实布袍 + 宽肩体格 + 面容 + 无专用法器
3. 语义色·朱砂红层：无
4. 语义色·松石青层：无（纯墨色——承伤角色不追求视觉突出）

**视觉描述：**
青年男修，体格宽厚——肩宽明显大于林渊和苏剑鸣，身体呈倒梯形。身着最低调的厚实布袍（灰度约 55%），袍身宽大但不飘逸——布料垂感重。双手微张置于身侧——不是进攻或防御的姿态，而是随时准备跨步挡在队友身前的「守护」姿态。无专用法器——石岩的「武器」就是他的身体。面部线条圆润——与苏剑鸣的锐利形成最大反差，五官敦厚，眉头平直不锁，眼神平静可靠。姿态微蹲（重心下沉），膝盖微弯——这是习练硬气功站桩的姿态。衣袍阴影使用正道均匀细密排线。墨色中灰（灰度 50-60%）。整体视觉信号：「这面墙不会倒」。

**美术圣经锚点：**
- 六要素：法器锚点（无——身体即武器）、衣袍语汇（宽肩厚袍垂重感）、姿态轴线（微蹲重心下沉 左倾 2°）、墨色基调（50-60%）、阵营纹理（正道细密排线）、眼神方向（平视可靠）
- 原则 2「克制即表达」：无语义色 × 无专属法器 × 敦厚线条 = 「沉默的守护者」

**生成提示（Midjourney）：**
Full body portrait of a broad-shouldered young male Chinese cultivator in a slight crouching horse-stance, plain white background. He wears a thick heavy cloth Daoist robe that hangs with weight. His build is noticeably wider and stockier than typical cultivators — inverted triangle torso. No visible weapon or artifact. His hands are slightly open at his sides, ready to step in front of allies. His facial features are round and earnest, eyebrows level and calm. Chinese ink wash painting (水墨写意), fine cross-hatching on robe shadows. Grayscale ink only, medium tones. No semantic colors. Soft light. --no oil painting, 3D render, anime, weapon, sword, artifact, vibrant colors, background

**反向提示（Stable Diffusion）：**
oil painting, 3D render, CGI, anime, manga, sword, weapon, slim, thin, aggressive, colorful, vibrant, background

**角色气质关键词：** 宽厚、可靠、沉默的守护者、不倒的墙

---

### ASSET-181 — 王绝尘（青云剑宗·正道）

| 字段 | 值 |
|-------|-------|
| 类别 | 精灵 / 2D 角色立绘 |
| 尺寸 (LOD-0) | 800×1120px |
| 尺寸 (LOD-1) | 200×280px，标准裁切 |
| 格式 | PNG RGBA8，透明背景 |
| 源格式 | PSD 分层源文件 |
| 文件命名 (LOD-0) | `char_wang_juechen_portrait_full.png` |
| 文件命名 (LOD-1) | `char_wang_juechen_realm1.png` |

**图层结构：**
1. 背景层（锁定透明）
2. 墨色主体层：修身劲装 + 双短剑 + 面容
3. 语义色·朱砂红层：短剑刃尖一抹红（≤1.5%）
4. 语义色·松石青层：无

**视觉描述：**
青年男修，身形精瘦——与石岩的宽厚形成体态两极。身着深色修身劲装（灰度约 40%），袖口和裤腿紧束——全身无一处多余的布料。双手各持一把短剑——短剑交叉于胸前，剑尖向外。这是「快攻突破」的经典起手式。面容削瘦——颧骨微凸，眼眶微陷，长期风餐露宿的痕迹。眼神锐利且短暂停留——视线不固定在一点，而是扫视。头发束为简单马尾——比道髻更实用的束发方式。姿态微蹲前倾（左倾 8°）。衣袍阴影使用正道排线但间距更疏、笔触更快——「随时要动的排线」。墨色中灰偏浓（灰度 40-50%）。

**美术圣经锚点：**
- 六要素：法器锚点（双短剑交叉）、衣袍语汇（束身劲装无冗余）、姿态轴线（微蹲前倾 左倾 8°）、墨色基调（40-50%）、阵营纹理（正道疏排线快速笔触）、眼神方向（扫视不定焦）
- 与苏剑鸣区分度：苏剑鸣=长剑斜指（中距攻击），王绝尘=双短剑交叉（近距快攻）

**生成提示（Midjourney）：**
Full body portrait of a lean young male Chinese cultivator, crouched slightly forward with two short swords crossed at his chest, plain white background. He wears a dark fitted martial tunic with tightly bound sleeves and pant cuffs. His build is wiry and gaunt — prominent cheekbones, slightly sunken eyes. His hair is in a simple practical ponytail. His eyes are sharp and scanning, not fixed on one point. Chinese ink wash painting, fast cross-hatching with wider spacing on robe shadows. Grayscale ink, medium-dark tones. Vermillion red (#C41E1E) tiny touch on both short sword tips only. --no oil painting, 3D render, anime, heavy armor, long sword, vibrant colors, background

**反向提示（Stable Diffusion）：**
oil painting, 3D render, CGI, anime, manga, heavy, muscular, long sword, shield, colorful, background

**角色气质关键词：** 精悍、快攻突破、杀伐果断、风尘

---

### ASSET-182 — 贾天煞（魔道·黑风教）

| 字段 | 值 |
|-------|-------|
| 类别 | 精灵 / 2D 角色立绘 |
| 尺寸 (LOD-0) | 800×1120px |
| 尺寸 (LOD-1) | 200×280px，标准裁切 |
| 格式 | PNG RGBA8，透明背景 |
| 源格式 | PSD 分层源文件 |
| 文件命名 (LOD-0) | `char_jia_tiansha_portrait_full.png` |
| 文件命名 (LOD-1) | `char_jia_tiansha_realm1.png` |

**图层结构：**
1. 背景层（锁定透明）
2. 墨色主体层：黑风教制式黑袍 + 短刀 + 面容
3. 语义色·朱砂红层：无
4. 语义色·松石青层：无

**视觉描述：**
青年魔修，身着黑风教制式黑袍（灰度约 35%）。黑袍款式标准化——立领窄袖，无任何装饰——这是「量产型反派」的视觉定义。手持单把短刀——刀身为最朴素的铁刀造型。面容凶恶但不复杂——眉头拧锁呈「川」字纹，嘴角下撇。眼神从上往下斜视——典型的小喽啰「狗仗人势」表情。姿态微微佝偻（右倾 4°）。衣袍边缘有粗粝飞白（魔道阵营纹理）。墨色偏浓（灰度 35-45%）。这张立绘的视觉原则是「量产反派」——任何玩家第一眼就能辨认：这是可以打败的敌人。

**美术圣经锚点：**
- 六要素：法器锚点（朴素短刀）、衣袍语汇（制式黑袍无装饰）、姿态轴线（微佝偻 右倾 4°）、墨色基调（35-45%）、阵营纹理（魔道粗粝飞白）、眼神方向（俯视斜视凶恶）
- 原则 2「克制即表达」：贾天煞的「反派感」通过标准化的黑衣+没有个性的面容完成——不是「大魔王」，而是「可以被主角团击败的标准敌人」

**生成提示（Midjourney）：**
Full body portrait of a generic young male demonic cultivator thug, standing slightly hunched, plain white background. He wears a plain black uniform-style robe with a standing collar and tight sleeves — no decorations or patterns. He holds a simple unadorned short iron blade. His expression is a standard scowl — furrowed brows, downturned mouth, looking down his nose. Chinese ink wash painting, rough dry brush at robe edges. Grayscale ink only, medium-dark tones. No semantic colors. --no oil painting, 3D render, anime, handsome, ornate, decorated, distinctive, vibrant colors, background

**反向提示（Stable Diffusion）：**
oil painting, 3D render, CGI, anime, manga, handsome, decorated, ornate, distinctive, unique, colorful, background

**角色气质关键词：** 量产反派、喽啰、凶恶简单、可以打败

---

### ASSET-183 — 刘青松（青云剑宗·正道）

| 字段 | 值 |
|-------|-------|
| 类别 | 精灵 / 2D 角色立绘 |
| 尺寸 (LOD-0) | 800×1120px |
| 尺寸 (LOD-1) | 200×280px，标准裁切 |
| 格式 | PNG RGBA8，透明背景 |
| 源格式 | PSD 分层源文件 |
| 文件命名 (LOD-0) | `char_liu_qingsong_portrait_full.png` |
| 文件命名 (LOD-1) | `char_liu_qingsong_realm1.png` |

**图层结构：**
1. 背景层（锁定透明）
2. 墨色主体层：标准道袍 + 朴素长剑 + 面容
3. 语义色层：无

**视觉描述：**
青年男修，一切「标准」——标准道袍（灰度约 58%）、标准长剑（标准宽度和剑格）、标准道髻、标准站姿（微左倾 2°）。面部五官端正而普通——放在人堆里不会被注意。表情平静——不自信也不自卑。这张立绘的设计原则是「一切居中」——不偏不倚，没有特点正是其特点。与通用正道立绘的区别：刘青松的立绘更年轻（二十出头），面容更具体（有他自己的五官组合），但整体视觉存在感仍然极低。衣袍阴影使用正道排线。纯墨色。

**美术圣经锚点：**
- 六要素：法器锚点（标准长剑）、衣袍语汇（标准道袍）、姿态轴线（标准立姿 左倾 2°）、墨色基调（55-60%）、阵营纹理（正道排线）、眼神方向（平视平淡）
- 设计意图：刘青松是「普通」的视觉基准线——所有其他正道角色与他相比都「更有特点」

**生成提示（Midjourney）：**
Full body portrait of an utterly average young male Chinese cultivator, standing in a standard upright pose, plain white background. He wears exactly the standard Daoist robe, holds a standard straight sword, has a standard topknot hairstyle. His face is pleasant but completely unmemorable — average features, no scars, no distinctive marks. His expression is calm and neutral. Chinese ink wash painting, fine cross-hatching on robe shadows. Grayscale ink only, medium tones. No semantic colors. This character should look like the visual baseline for all other characters. --no oil painting, 3D render, anime, distinctive, unique, memorable, striking, colorful, background

**反向提示（Stable Diffusion）：**
oil painting, 3D render, CGI, anime, manga, distinctive, unique, memorable, striking, handsome, ugly, colorful, background

**角色气质关键词：** 普通、标准、视觉基准线、不被注意

---

### ASSET-184 — 陆夫人（魔道·黑煞教）

| 字段 | 值 |
|-------|-------|
| 类别 | 精灵 / 2D 角色立绘 |
| 尺寸 (LOD-0) | 800×1120px |
| 尺寸 (LOD-1) | 200×280px，标准裁切 |
| 格式 | PNG RGBA8，透明背景 |
| 源格式 | PSD 分层源文件 |
| 文件命名 (LOD-0) | `char_lu_furen_portrait_full.png` |
| 文件命名 (LOD-1) | `char_lu_furen_realm1.png` |

**图层结构：**
1. 背景层（锁定透明）
2. 墨色主体层：暗色长裙 + 面纱 + 面容
3. 语义色·朱砂红层：无
4. 语义色·松石青层：无

**视觉描述：**
中年女魔修，身着暗色长裙（灰度约 40%），裙身包裹严密——高领长袖，不暴露任何肌肤。面部下半以薄纱遮掩——面纱以极淡墨（灰度约 75%）半透明渲染，隐约可见下半张脸的轮廓。未遮掩的上半张脸——眼角微垂，眉头微蹙，眼神阴冷但不狠毒。双手藏于宽袖之内——加入了黑煞教「藏手为礼」的门规。姿态直立微前倾（右倾 5°）。衣袍边缘粗粝飞白（魔道纹理）。纯墨色。

**美术圣经锚点：**
- 六要素：法器锚点（无——面纱+藏手）、衣袍语汇（严密包裹长裙+面纱）、姿态轴线（直立微前倾 右倾 5° 藏手于袖）、墨色基调（40-50%）、阵营纹理（魔道粗粝飞白）、眼神方向（阴冷微垂）
- 原则 3「秩序辨真，气韵传神」：严密包裹+藏手=无法判断手中是否有武器——不可预测的危险

**生成提示（Midjourney）：**
Full body portrait of a middle-aged female demonic cultivator, standing with hands hidden inside her wide sleeves, plain white background. She wears an all-covering dark long dress with high collar and long sleeves. The lower half of her face is veiled in semi-transparent pale ink gauze. Her visible upper face shows slightly drooping eyes and a cold distant gaze. No visible weapon or artifact. Chinese ink wash painting, rough dry brush at robe edges. Grayscale ink only, medium-dark tones. No semantic colors. --no oil painting, 3D render, anime, exposed skin, seductive, young, colorful, background

**反向提示（Stable Diffusion）：**
oil painting, 3D render, CGI, anime, manga, exposed, seductive, young, colorful, revealing, background

**角色气质关键词：** 阴沉、隐秘、不可预测、黑煞教

---

### ASSET-185 — 李元化（丹霞谷·正道）

| 字段 | 值 |
|-------|-------|
| 类别 | 精灵 / 2D 角色立绘 |
| 尺寸 (LOD-0) | 800×1120px |
| 尺寸 (LOD-1) | 200×280px，标准裁切 |
| 格式 | PNG RGBA8，透明背景 |
| 源格式 | PSD 分层源文件 |
| 文件命名 (LOD-0) | `char_li_yuanhua_portrait_full.png` |
| 文件命名 (LOD-1) | `char_li_yuanhua_realm1.png` |

> **跨境界复用**：炼气投影→金丹共用此立绘。境界差异由卡框颜色+境界标签区分。

**图层结构：**
1. 背景层（锁定透明）
2. 墨色主体层：双层道袍 + 拂尘 + 面容
3. 语义色·朱砂红层：无
4. 语义色·松石青层：拂尘手柄处微光（≤1%）

**视觉描述：**
中年男修，面相成熟稳重——下颌有短须。身着双层道袍（灰度约 55%），外罩为比一般道袍更宽大的罩袍——便于同时庇护多位同伴时展开（「给相邻角色加攻」的视觉暗示）。右手持拂尘——拂尘白毫以淡墨飞白表现，手柄以浓墨线勾勒，松石青微光在手柄处——标识辅助性的灵力输出。左手自然垂于身侧——手心微张，如有无形的气要传递。姿态端正直立（左倾 2°）。面部以中浓墨线描——眼神温和但不失威严，嘴角有浅浅的「过来，我护着你」的微笑。衣袍阴影正道排线，宽袖有大量淡墨垂坠。

**美术圣经锚点：**
- 六要素：法器锚点（拂尘）、衣袍语汇（宽大双层罩袍）、姿态轴线（端正直立 左倾 2° 左手微张）、墨色基调（50-60%）、阵营纹理（正道排线）、眼神方向（温和注视浅笑）
- 与方灵素区分度：方灵素=丹师（丹炉+药篓），李元化=辅助者（拂尘+宽袍庇护）

**生成提示（Midjourney）：**
Full body portrait of a mature middle-aged male Chinese cultivator with a short beard, standing upright with a gentle expression, plain white background. He wears an especially wide double-layered Daoist robe — the outer layer spreads wide like protective wings. In his right hand he holds a horsetail whisk (拂尘) with pale ink fly-away bristles and a faint turquoise blue (#1A8A8A) glimmer at the handle. His left hand is slightly open at his side as if transmitting qi. His smile is warm and protective. Chinese ink wash painting, fine cross-hatching on robe shadows. Grayscale ink, medium tones. Turquoise blue only at whisk handle. --no oil painting, 3D render, anime, sword, aggressive, young, clean-shaven, colorful, background

**反向提示（Stable Diffusion）：**
oil painting, 3D render, CGI, anime, manga, sword, weapon, aggressive, young, clean-shaven, colorful, background

**角色气质关键词：** 成熟、可靠的前辈、庇护者、辅助核心

---

## 筑基期新增角色（8 张）

### ASSET-186 — 温碧霞（魔道·魅影阁）

| 字段 | 值 |
|-------|-------|
| 类别 | 精灵 / 2D 角色立绘 |
| 尺寸 (LOD-0) | 800×1120px |
| 尺寸 (LOD-1) | 200×280px，标准裁切 |
| 格式 | PNG RGBA8，透明背景 |
| 源格式 | PSD 分层源文件 |
| 文件命名 (LOD-0) | `char_wen_bixia_portrait_full.png` |
| 文件命名 (LOD-1) | `char_wen_bixia_realm2.png` |

**图层结构：**
1. 背景层（锁定透明）
2. 墨色主体层：曳地长裙 + 披帛 + 发簪 + 面容
3. 语义色·朱砂红层：唇部一抹红（≤0.5%——极少量的红色暗示女性角色的「队长」定位）
4. 语义色·松石青层：无

**视觉描述：**
青年女魔修，与汐音同出魅影阁但气质截然不同——温碧霞是「大姐头」而非「妖女」。身着曳地长裙（灰度约 50%），双臂挽着长披帛（以淡墨曲线表现披帛如水流泻）。披帛的流动线条是视觉焦点——从肩部沿手臂向下垂至地面。发髻高挽——以数支发簪固定，发型庄重而非妩媚。面容成熟大气——五官端正不媚，眼角平直不上挑，嘴角微扬。眼神温暖有力——看向的是「队友」而非「猎物」。姿态直立（右倾 2°）。衣袍边缘有轻微飞白（魔道纹理但比汐音克制得多）。纯墨色为主——仅在唇部用极淡的朱砂红点染（≤0.5%）。视觉信号：「跟这位姐姐走，不会吃亏」。

**美术圣经锚点：**
- 六要素：法器锚点（无专用法器——披帛是视觉焦点）、衣袍语汇（曳地长裙+长披帛流水线）、姿态轴线（直立大气 右倾 2°）、墨色基调（50-55%）、阵营纹理（魔道轻度飞白克制）、眼神方向（温暖注视同伴）
- 与汐音区分度：汐音=S弯妖媚散发，温碧霞=直立大气庄重发髻（「姐姐 vs 妹妹」）

**生成提示（Midjourney）：**
Full body portrait of a mature elegant female Chinese cultivator, standing tall with a confident warm expression, plain white background. She wears a floor-length dress with long flowing silk ribbons draped over both arms cascading down to the ground — the ribbons are the visual focal point. Her hair is in an elaborate updo with multiple hairpins. Her eyes are warm and look toward allies, not prey. Minimalist barely-visible vermillion red (#C41E1E) tint on lips only. Chinese ink wash painting, slight dry brush at dress hem only. Grayscale ink, medium tones. --no oil painting, 3D render, anime, seductive, S-curve pose, exposed, colorful, background

**反向提示（Stable Diffusion）：**
oil painting, 3D render, CGI, anime, manga, seductive, S-curve, exposed, young girl, colorful, background

**角色气质关键词：** 大气、大姐头、女队核心、温暖有力

---

### ASSET-187 — 王婵（魔道·血海殿）

| 字段 | 值 |
|-------|-------|
| 类别 | 精灵 / 2D 角色立绘 |
| 尺寸 (LOD-0) | 800×1120px |
| 尺寸 (LOD-1) | 200×280px，标准裁切 |
| 格式 | PNG RGBA8，透明背景 |
| 源格式 | PSD 分层源文件 |
| 文件命名 (LOD-0) | `char_wang_chan_portrait_full.png` |
| 文件命名 (LOD-1) | `char_wang_chan_realm2.png` |

**图层结构：**
1. 背景层（锁定透明）
2. 墨色主体层：血海殿制式血纹袍 + 血刃 + 面容
3. 语义色·朱砂红层：血刃刃纹（≤2%）
4. 语义色·松石青层：无

**视觉描述：**
青年女魔修，血海殿的中坚战力。身着血海殿制式长袍（灰度约 35%）——袍面有暗红色的血纹刺绣（以浓淡墨交替表现暗纹，不在语义色预算内）。手持一柄弯刃血刃——刀刃呈弧形如新月，刃身上流淌着朱砂红（#C41E1E）的血光纹（≤2%）。面容美艳但冷硬——五官精致但表情如铁。眼神锐利——看正道角色的眼神带有轻蔑。姿态微侧身（右倾 6°），一手持刃横于身前。衣袍边缘有显著飞白（魔道纹理）。墨色偏浓（灰度 35-45%）。视觉信号：「正道？不过是我刀下的猎物」。

**美术圣经锚点：**
- 六要素：法器锚点（弯刃血刃）、衣袍语汇（血纹袍制式战袍）、姿态轴线（微侧身横刃 右倾 6°）、墨色基调（35-45%）、阵营纹理（魔道显著飞白）、眼神方向（锐利轻蔑）
- 与墨渊区分度：墨渊=遮面暗黑恐怖感，王婵=直面冷硬战斗感

**生成提示（Midjourney）：**
Full body portrait of a coldly beautiful female demonic cultivator, standing in a slight side-facing combat stance with a curved blood-blade held across her body, plain white background. She wears a Blood Sea Hall uniform robe with subtle blood-pattern embroidery in dark ink. The curved blade has a vermillion red (#C41E1E) flowing blood gleam along its edge. Her expression is cold and contemptuous — beautiful but hard as iron. Chinese ink wash painting, prominent dry brush at robe edges. Grayscale ink, dark tones. Vermillion red only on blade edge. --no oil painting, 3D render, anime, warm, gentle, soft, colorful, background

**反向提示（Stable Diffusion）：**
oil painting, 3D render, CGI, anime, manga, warm, gentle, soft, smiling, colorful, background

**角色气质关键词：** 冷艳、正道克星、铁血女战士、血海殿

---

### ASSET-188 — 云煞老祖（分身）（魔道·魅影阁）

| 字段 | 值 |
|-------|-------|
| 类别 | 精灵 / 2D 角色立绘 |
| 尺寸 (LOD-0) | 800×1120px |
| 尺寸 (LOD-1) | 200×280px，标准裁切 |
| 格式 | PNG RGBA8，透明背景 |
| 源格式 | PSD 分层源文件 |
| 文件命名 (LOD-0) | `char_yunsha_laozu_portrait_full.png` |
| 文件命名 (LOD-1) | `char_yunsha_laozu_realm2.png` |

**图层结构：**
1. 背景层（锁定透明）
2. 墨色主体层：烟雾状半身 + 枯槁面容 + 云雾代足
3. 语义色·朱砂红层：眼眶中的暗红（≤1%）
4. 语义色·松石青层：无

**视觉描述：**
老年魔修，这是一具分身而非本体——下半身不是腿而是翻涌的煞气云雾（以浓淡墨交替渲染的不定型烟云）。上半身可见——枯槁老者面容，皮肤如干裂的树皮（以皴擦笔法表现）。眼窝深陷，眼眶中有暗红的朱砂红微光——分身的生命核心。双手为利爪形态——指甲长而弯，以浓墨勾线。身着残破的暗色长袍（灰度约 30%）——袍身有多处撕裂，裂口处有煞气向外涌出（淡墨渲染）。姿态悬浮——无足踏地，云雾承托。墨色极浓（灰度 25-35%）。视觉信号：「此非人，而是煞气之形」。

**美术圣经锚点：**
- 六要素：法器锚点（利爪）、衣袍语汇（残破暗袍+煞气云足）、姿态轴线（悬浮不定 右倾 8°）、墨色基调（25-35%）、阵营纹理（极度粗粝飞白+煞气渲染）、眼神方向（深陷黑暗中的暗红微光）
- 与墨渊区分度：墨渊=斗篷遮面厚重恐怖，云煞老祖=分身虚幻煞气飘渺

**生成提示（Midjourney）：**
Full body portrait of an ancient demonic cultivator's avatar — lower body is not legs but swirling miasma clouds in dark and light ink wash, floating, plain white background. Upper body shows a gaunt ancient face with skin like cracked bark in dry-brush texture. Deep sunken eye sockets with faint vermillion red (#C41E1E) glimmers. His hands are claw-like with long curved nails. He wears a torn dark robe with miasma seeping from the tears. Chinese ink wash painting, heavy rough dry brush, splashed ink technique, miasma clouds. Grayscale ink, very dark tones. Vermillion red only in eye sockets. --no oil painting, 3D render, anime, human legs, feet, healthy skin, young, colorful, background

**反向提示（Stable Diffusion）：**
oil painting, 3D render, CGI, anime, manga, human legs, feet, young, healthy, clean, colorful, background

**角色气质关键词：** 古老、非人、煞气之形、分身幻象

---

### ASSET-189 — 耿忠（正道·星斗宗）

| 字段 | 值 |
|-------|-------|
| 类别 | 精灵 / 2D 角色立绘 |
| 尺寸 (LOD-0) | 800×1120px |
| 尺寸 (LOD-1) | 200×280px，标准裁切 |
| 格式 | PNG RGBA8，透明背景 |
| 源格式 | PSD 分层源文件 |
| 文件命名 (LOD-0) | `char_geng_zhong_portrait_full.png` |
| 文件命名 (LOD-1) | `char_geng_zhong_realm2.png` |

**图层结构：**
1. 背景层（锁定透明）
2. 墨色主体层：星斗宗制式星纹袍 + 塔盾 + 面容
3. 语义色·朱砂红层：无
4. 语义色·松石青层：盾面星斗微光（≤1.5%）

**视觉描述：**
中年男修，星斗宗护法。体格魁梧——比石岩更宽更厚。身着星斗宗星纹袍（灰度约 50%），袍面有星斗图案——以极细的淡墨点排列成北斗七星的形状。双手持一面与人等高的塔盾——盾面以浓墨渲染金属质感，盾心刻有星斗宗的宗门徽记（以松石青微光点亮，≤1.5%）。盾缘以铆钉加固——成排的微型浓墨点。面容沧桑——脸颊有深刻的法令纹，胡渣散布。眼神坚定直视——「我死后，你们才能过」。姿态马步蹲裆——双腿如钉入地面。墨色中灰（灰度 45-55%）。

**美术圣经锚点：**
- 六要素：法器锚点（人高塔盾）、衣袍语汇（星纹袍）、姿态轴线（马步蹲裆稳如磐石）、墨色基调（45-55%）、阵营纹理（正道排线+星点）、眼神方向（坚定直视）
- 与石岩区分度：石岩=徒手挡伤（身体即盾），耿忠=塔盾护核（专业护卫）

**生成提示（Midjourney）：**
Full body portrait of a massive middle-aged male Chinese cultivator in a deep horse stance holding a person-height tower shield, plain white background. He wears a Star Sect robe with subtle Big Dipper constellation patterns in tiny pale ink dots. The tower shield is rendered in dark ink with metallic weight — a turquoise blue (#1A8A8A) star emblem glows at its center. His face is weathered with deep nasolabial folds and stubble. His gaze is unwaveringly determined. Chinese ink wash painting. Grayscale ink, medium tones. Turquoise blue only on shield emblem. --no oil painting, 3D render, anime, agile, slim, sword, colorful, background

**反向提示（Stable Diffusion）：**
oil painting, 3D render, CGI, anime, manga, slim, agile, sword, young, colorful, background

**角色气质关键词：** 铁壁、绝对护卫、一夫当关、星斗宗

---

### ASSET-190 — 乌煞（魔道·血煞教）

| 字段 | 值 |
|-------|-------|
| 类别 | 精灵 / 2D 角色立绘 |
| 尺寸 (LOD-0) | 800×1120px |
| 尺寸 (LOD-1) | 200×280px，标准裁切 |
| 格式 | PNG RGBA8，透明背景 |
| 源格式 | PSD 分层源文件 |
| 文件命名 (LOD-0) | `char_wusha_portrait_full.png` |
| 文件命名 (LOD-1) | `char_wusha_realm2.png` |

**图层结构：**
1. 背景层（锁定透明）
2. 墨色主体层：血煞教战袍 + 锁链镰刀 + 面容
3. 语义色·朱砂红层：镰刀刃血槽（≤2%）
4. 语义色·松石青层：无

**视觉描述：**
中年魔修，血煞教猎杀者——专门猎杀林渊的赏金杀手。身着血煞教战袍（灰度约 30%）——袍身有撕裂的布条状下摆。腰间挂着多条铁链——以断续浓墨粗线表现金属环。右手拖着长柄锁链镰刀——镰刀刃口上有一道朱砂红血槽（≤2%），链条缠绕在手臂上。面容粗犷——面部有战斗留下的刀疤（以淡墨不规则的细线横贯左颊）。表情是「猎人的专注」——盯着猎物（林渊）的方向。姿态微微弓身（右倾 6%）。墨色浓重（灰度 30-40%）。视觉信号：「林渊，我找到你了」。

**美术圣经锚点：**
- 六要素：法器锚点（锁链镰刀血槽）、衣袍语汇（撕裂战袍+铁链缠绕）、姿态轴线（弓身猎杀 右倾 6°）、墨色基调（30-40%）、阵营纹理（魔道撕裂飞白+铁链）、眼神方向（猎人专注盯猎物）
- 与贾天煞区分度：贾天煞=量产小喽啰，乌煞=有目标有装备的专业杀手

**生成提示（Midjourney）：**
Full body portrait of a rugged middle-aged male demonic cultivator hunter, slightly crouched in a stalking pose dragging a long chain-sickle, plain white background. He wears a torn battle robe with tattered strip hems. Iron chains wrap around his arm. The sickle blade has a vermillion red (#C41E1E) blood groove. A battle scar crosses his left cheek in pale irregular ink line. His expression is a hunter's focus — locked onto prey. Chinese ink wash painting, rough torn dry brush. Grayscale ink, dark tones. Vermillion red only on sickle blood groove. --no oil painting, 3D render, anime, clean, handsome, unmarred, colorful, background

**反向提示（Stable Diffusion）：**
oil painting, 3D render, CGI, anime, manga, clean, handsome, unscarred, young, colorful, background

**角色气质关键词：** 猎杀者、赏金杀手、林渊宿敌、血煞教

---

### ASSET-191 — 瑶光（魔道·轮回殿）

| 字段 | 值 |
|-------|-------|
| 类别 | 精灵 / 2D 角色立绘 |
| 尺寸 (LOD-0) | 800×1120px |
| 尺寸 (LOD-1) | 200×280px，标准裁切 |
| 格式 | PNG RGBA8，透明背景 |
| 源格式 | PSD 分层源文件 |
| 文件命名 (LOD-0) | `char_yaoguang_portrait_full.png` |
| 文件命名 (LOD-1) | `char_yaoguang_realm2.png` |

**图层结构：**
1. 背景层（锁定透明）
2. 墨色主体层：暗色短裙 + 长靴 + 双短匕 + 面容
3. 语义色·朱砂红层：无
4. 语义色·松石青层：右眼下的轮回泪痣微光（≤0.5%）

**视觉描述：**
少女魔修，沐瑶的搭档。与沐瑶的纯真反差——瑶光更成熟、更锐利。身着暗色短裙（灰度约 45%）配长靴——行动便利的实用主义者打扮。双手各握一把短匕——匕首交叉背于身后（这是一种「保护」而非「攻击」的姿态——她护着身后的沐瑶）。右眼下方有一颗泪痣——以松石青微光点缀（轮回殿成员的标记，≤0.5%）。发式为不对称短发——左侧长及肩、右侧短至耳。眼神警惕——视线总在沐瑶和周围环境之间切换。姿态微侧身（右倾 4%）。衣袍边缘有中度飞白。墨色中灰偏浓（灰度 40-50%）。

**美术圣经锚点：**
- 六要素：法器锚点（双短匕交叉背于身后）、衣袍语汇（短裙+长靴实用主义）、姿态轴线（微侧身护后 右倾 4°）、墨色基调（40-50%）、阵营纹理（魔道中度飞白）、眼神方向（警惕切换）
- 与沐瑶区分度：沐瑶=纯真少女前排，瑶光=锐利护卫后排——「双人组合流」的视觉对位

**生成提示（Midjourney）：**
Full body portrait of a teenage female demonic cultivator, standing slightly sideways with two short daggers crossed behind her back in a protective stance, plain white background. She wears a dark short dress with long boots — practical combat attire. Her hair is asymmetrical — left side shoulder-length, right side cropped short to ear. A tiny turquoise blue (#1A8A8A) beauty mark glimmers under her right eye — the Rebirth Hall member mark. Her eyes are alert, constantly scanning. Chinese ink wash painting, moderate dry brush at hem. Grayscale ink, medium-dark tones. Turquoise blue only on beauty mark. --no oil painting, 3D render, anime, innocent, childish, long dress, colorful, background

**反向提示（Stable Diffusion）：**
oil painting, 3D render, CGI, anime, manga, innocent, childish, long dress, colorful, background

**角色气质关键词：** 锐利、护卫者、沐瑶的影子、警觉

---

### ASSET-192 — 轮回殿主（分身）（魔道·轮回殿）

| 字段 | 值 |
|-------|-------|
| 类别 | 精灵 / 2D 角色立绘 |
| 尺寸 (LOD-0) | 800×1120px |
| 尺寸 (LOD-1) | 200×280px，标准裁切 |
| 格式 | PNG RGBA8，透明背景 |
| 源格式 | PSD 分层源文件 |
| 文件命名 (LOD-0) | `char_lunhui_dianzhu_portrait_full.png` |
| 文件命名 (LOD-1) | `char_lunhui_dianzhu_realm2.png` |

**图层结构：**
1. 背景层（锁定透明）
2. 墨色主体层：分身雾态形体 + 斗篷轮廓 + 面容
3. 语义色·朱砂红层：无
4. 语义色·松石青层：胸前的轮回殿标记（≤1%）

**视觉描述：**
轮回殿主的筑基期分身——非本体而是投影。形体边缘模糊——轮廓不是硬线而是淡墨的雾状渐变，如投影般虚幻。身着宽大斗篷（灰度约 35%），兜帽未戴而是垂于背后——露出中年男性的威严面容。胸前有轮回殿标记——以松石青（#1A8A8A）绘制的∞形轮回符号（≤1%）。双手微抬于胸前——手心相对，中间有淡墨的蓝色微光球（正在维持某种结界的姿态）。面容与沐瑶有相似之处（轮回殿的「家族面容」）但更年长、更威严。姿态如同站在门内——前后脚错开，一脚踏在前方、一脚留在后方，如跨在两个世界之间。墨色中灰（灰度 40-50%），但轮廓的雾状渐变让整体看起来比实际墨色更淡。

**美术圣经锚点：**
- 六要素：法器锚点（无——双手结界）、衣袍语汇（分身雾态轮廓+斗篷）、姿态轴线（跨两界之姿）、墨色基调（轮廓渐变虚化）、阵营纹理（魔道+轮回殿特殊处理——模糊边界）、眼神方向（威严俯视）
- 与云煞老祖（分身）区分度：云煞老祖=下半身煞气云雾狂暴，轮回殿主=全身轮廓虚化威严

**生成提示（Midjourney）：**
Full body portrait of a projection avatar of the Rebirth Hall Master — body edges are soft and blurred, not hard lines but mist-like gradients, plain white background. He wears a wide cloak with the hood down, revealing a middle-aged man's commanding face. A turquoise blue (#1A8A8A) infinity-symbol (∞) Rebirth Hall mark glows on his chest. His hands are raised chest-high, palms facing each other with a faint light-qi sphere between them. His stance straddles — one foot forward, one back, as if standing between two realms. Chinese ink wash painting, soft edge blending. Grayscale ink, medium tones with gradient edges. Turquoise blue only on chest mark. --no oil painting, 3D render, anime, solid outline, sharp edges, colorful, background

**反向提示（Stable Diffusion）：**
oil painting, 3D render, CGI, anime, manga, solid, sharp outline, defined edges, colorful, background

**角色气质关键词：** 威严、投影之身、轮回执掌者、跨两界

---

### ASSET-193 — 干蓝冰云（正道·极阴岛）

| 字段 | 值 |
|-------|-------|
| 类别 | 精灵 / 2D 角色立绘 |
| 尺寸 (LOD-0) | 800×1120px |
| 尺寸 (LOD-1) | 200×280px，标准裁切 |
| 格式 | PNG RGBA8，透明背景 |
| 源格式 | PSD 分层源文件 |
| 文件命名 (LOD-0) | `char_ganlan_bingyun_portrait_full.png` |
| 文件命名 (LOD-1) | `char_ganlan_bingyun_realm2.png` |

**图层结构：**
1. 背景层（锁定透明）
2. 墨色主体层：极阴岛冰蓝袍 + 冰刺法器 + 面容
3. 语义色·朱砂红层：无
4. 语义色·松石青层：冰刺尖端的寒气（≤1.5%）

**视觉描述：**
青年女修，极阴岛代表。身着极阴岛冰蓝袍（灰度约 50%）——袍面在光线下似有极淡的冰蓝色光泽（通过墨色的冷调处理而非实际色彩）。袍摆有冰晶状的装饰边缘——以留白+极淡墨线表现冰纹。双手各悬浮一根冰刺——冰刺以留白和淡墨线勾勒，呈半透明锥形。松石青寒气从冰刺尖端飘出——以极细的曲线表现。面容清秀但有一种「温度低」的疏离感——表情平静如冰面。头发以淡墨渲染，发色偏淡（也许是浅蓝发色，但在墨骨丹青中以极淡墨表现）。墨色偏淡冷（灰度 50-60%）。

**美术圣经锚点：**
- 六要素：法器锚点（悬浮冰刺）、衣袍语汇（冰蓝袍+冰晶装饰边）、姿态轴线（直立冷冽）、墨色基调（50-60%冷调）、阵营纹理（正道排线但更疏更冷）、眼神方向（冰面般的平静）
- 与月清霜区分度：月清霜=三层广袖+冰魄剑（高阶冰修），干蓝冰云=冰蓝袍+冰刺（中阶冰冻控制）

**生成提示（Midjourney）：**
Full body portrait of a young female ice cultivator from the Extreme Yin Island, standing cool and distant, plain white background. She wears an ice-blue tinted robe with frost-crystal decorative edges rendered in pale ink and negative space. Two ice spikes float above each palm — rendered as semi-transparent cones in faint ink outline. A turquoise blue (#1A8A8A) cold mist curls from the spike tips. Her expression is calm and cold as an ice surface. Her hair is rendered in very light ink suggesting pale hair. Chinese ink wash painting, cool ink tones, fine sparse cross-hatching. Grayscale ink, medium-light cool tones. Turquoise blue only on cold mist. --no oil painting, 3D render, anime, warm, fire, colorful, background

**反向提示（Stable Diffusion）：**
oil painting, 3D render, CGI, anime, manga, warm, fire, hot, colorful, background

**角色气质关键词：** 冰冷、冻结、极阴岛、控制者

---

## 金丹期新增角色（5 张）

### ASSET-194 — 枯骨老祖（分身）（魔道·碎星群岛）

| 字段 | 值 |
|-------|-------|
| 类别 | 精灵 / 2D 角色立绘 |
| 尺寸 (LOD-0) | 800×1120px |
| 尺寸 (LOD-1) | 200×280px，标准裁切 |
| 格式 | PNG RGBA8，透明背景 |
| 源格式 | PSD 分层源文件 |
| 文件命名 (LOD-0) | `char_kugu_laozu_portrait_full.png` |
| 文件命名 (LOD-1) | `char_kugu_laozu_realm3.png` |

**图层结构：**
1. 背景层（锁定透明）
2. 墨色主体层：骨架外露的躯体 + 残破法袍 + 骨杖
3. 语义色·朱砂红层：骨杖顶端的血珠（≤1%）
4. 语义色·松石青层：眼眶中的灵魂微光（≤1%）

**视觉描述：**
极为枯槁的老者魔修——身体消瘦到骨骼轮廓清晰可见（锁骨、肋骨、指关节以浓墨线突出表现），如活骷髅。身着残破的法袍（灰度约 35%）——法袍有多处撕裂和烧灼痕迹。右手拄着一根骨杖——骨杖以动物脊椎骨制成，杖顶嵌有一颗暗红色血珠（朱砂红，≤1%）。左手五指张开向前——如抓取什么。面容极度消瘦——皮肤紧贴颅骨，眼窝深陷。眼眶中有松石青灵魂微光——不死者的最后生命之火。姿态微弓（右倾 9°）——脊柱弯曲如老树的枯枝。墨色浓重干枯（灰度 30-40%），大量干笔皴擦表现枯槁。

**美术圣经锚点：**
- 六要素：法器锚点（脊椎骨杖血珠）、衣袍语汇（残破法袍+骨骼外露）、姿态轴线（微弓扭曲 右倾 9°）、墨色基调（30-40%干枯）、阵营纹理（魔道极度干笔皴擦）、眼神方向（眼眶中微光）
- 与云煞老祖区分度：云煞老祖=云雾煞气分身，枯骨老祖=骨感血肉实体

**生成提示（Midjourney）：**
Full body portrait of an emaciated ancient demonic cultivator, body so thin that bones are visible through skin — collarbone, ribs, knuckles prominent, plain white background. He wears a tattered burned robe. He leans on a staff made of spinal vertebrae with a vermillion red (#C41E1E) blood bead at its top. His left hand reaches forward with splayed fingers. His face is skull-like — skin stretched tight, eyes deeply sunken with a turquoise blue (#1A8A8A) soul-flicker in the sockets. Chinese ink wash painting, heavy dry-brush texture for gauntness. Grayscale ink, dark dry tones. Vermillion red bead on staff. Turquoise blue in eye sockets. --no oil painting, 3D render, anime, healthy, plump, young, colorful, background

**反向提示（Stable Diffusion）：**
oil painting, 3D render, CGI, anime, manga, healthy, plump, young, muscular, colorful, background

**角色气质关键词：** 枯槁、不死者、残年之力、碎星群岛

---

### ASSET-195 — 古长老（魔道·云蒙）

| 字段 | 值 |
|-------|-------|
| 类别 | 精灵 / 2D 角色立绘 |
| 尺寸 (LOD-0) | 800×1120px |
| 尺寸 (LOD-1) | 200×280px，标准裁切 |
| 格式 | PNG RGBA8，透明背景 |
| 源格式 | PSD 分层源文件 |
| 文件命名 (LOD-0) | `char_gu_zhanglao_portrait_full.png` |
| 文件命名 (LOD-1) | `char_gu_zhanglao_realm3.png` |

**图层结构：**
1. 背景层（锁定透明）
2. 墨色主体层：华贵长老袍 + 权杖 + 面容
3. 语义色·朱砂红层：权杖宝石红光（≤1.5%）
4. 语义色·松石青层：无

**视觉描述：**
中年魔修长老，云蒙势力的话事人。身着华贵的魔道长老袍（灰度约 35%）——袍面有繁复的暗色锦纹（以极细的浓淡墨交替表现刺绣纹理），领口和袖口有毛皮镶边（以皴擦淡墨表现皮草感）。右手持权杖——杖身为黑檀木色，杖顶嵌有暗红宝石（朱砂红，≤1.5%）。左手隐于袖中。面容是权谋者的脸——五官端正但眼神阴鸷，嘴角似笑非笑。姿态挺直（右倾 4%）——这是「居高临下」的姿态而非「前倾蓄势」。墨色中浓（灰度 30-40%），袍面织纹使用细密淡墨线。视觉信号：「老夫在，谁敢造次」。

**美术圣经锚点：**
- 六要素：法器锚点（宝石权杖）、衣袍语汇（华贵锦袍+皮草镶边）、姿态轴线（挺直居高临下 右倾 4°）、墨色基调（30-40%）、阵营纹理（魔道+锦衣纹理）、眼神方向（阴鸷似笑非笑）
- 与轮回殿主区分度：轮回殿主=投影威严，古长老=权谋世俗权力

**生成提示（Midjourney）：**
Full body portrait of a middle-aged demonic elder from Yunmeng, standing tall with an imperious bearing, plain white background. He wears an ornate elder's robe with complex dark brocade patterns in fine alternating ink lines and fur trim at collar and cuffs. He holds a scepter of dark ebony wood with a dark vermillion red (#C41E1E) gem at its head. His face is that of a political schemer — handsome but with cold calculating eyes and a half-smile that does not reach his eyes. Chinese ink wash painting, fine fabric texture lines. Grayscale ink, medium-dark tones. Vermillion red only on scepter gem. --no oil painting, 3D render, anime, humble, warm, friendly, colorful, background

**反向提示（Stable Diffusion）：**
oil painting, 3D render, CGI, anime, manga, humble, warm, friendly, poor, ragged, colorful, background

**角色气质关键词：** 权谋、居高临下、长老权威、云蒙

---

### ASSET-196 — 叶知秋（正道·东域）

| 字段 | 值 |
|-------|-------|
| 类别 | 精灵 / 2D 角色立绘 |
| 尺寸 (LOD-0) | 800×1120px |
| 尺寸 (LOD-1) | 200×280px，标准裁切 |
| 格式 | PNG RGBA8，透明背景 |
| 源格式 | PSD 分层源文件 |
| 文件命名 (LOD-0) | `char_ye_zhiqiu_portrait_full.png` |
| 文件命名 (LOD-1) | `char_ye_zhiqiu_realm3.png` |

**图层结构：**
1. 背景层（锁定透明）
2. 墨色主体层：东域游侠装束 + 宽刃剑 + 面容
3. 语义色·朱砂红层：无
4. 语义色·松石青层：佩玉微光（≤1%）

**视觉描述：**
青年男修，东域游侠——非宗门修士而是散修。身着游侠装束——不是统一道袍而是个人风格的布衣+皮甲护肩（灰度约 50%）。腰间挂着一块圆形佩玉——以松石青（#1A8A8A）微光点缀（东域散修的护身符，≤1%）。手持一柄宽刃剑——剑身比苏剑鸣的长剑更宽，剑格为简单的T形金属。面容潇洒——眉眼间有江湖的洒脱，眼神轻松含笑。姿态随意——一脚重心一脚虚点，剑斜扛于肩上。头发以布条随意束起——不加冠。墨色中灰（灰度 50-55%）。视觉信号：「林渊的搭档，比你想象中更可靠」。

**美术圣经锚点：**
- 六要素：法器锚点（宽刃剑肩扛）、衣袍语汇（布衣+皮甲护肩游侠风）、姿态轴线（随意洒脱 左倾 3°）、墨色基调（50-55%）、阵营纹理（正道排线但疏朗）、眼神方向（轻松含笑）
- 设计意图：叶知秋是林渊的「镜像搭档」——林渊=守势沉稳，叶知秋=洒脱不羁

**生成提示（Midjourney）：**
Full body portrait of a carefree young male wandering cultivator from the Eastern Domain, standing in a relaxed pose with a wide-blade sword resting casually on his shoulder, plain white background. He wears a personal-style cloth tunic with a leather shoulder guard — not a uniform robe. A circular jade pendant at his waist has a faint turquoise blue (#1A8A8A) glow. His expression is easygoing with a knowing smile. His hair is tied back loosely with a cloth strip. Chinese ink wash painting, loose cross-hatching. Grayscale ink, medium tones. Turquoise blue only on pendant. --no oil painting, 3D render, anime, uniform, formal, stiff, colorful, background

**反向提示（Stable Diffusion）：**
oil painting, 3D render, CGI, anime, manga, formal, stiff, uniform, Daoist robe, colorful, background

**角色气质关键词：** 潇洒、游侠、林渊搭档、江湖洒脱

---

### ASSET-197 — 万三姑（正道·魅影阁）

| 字段 | 值 |
|-------|-------|
| 类别 | 精灵 / 2D 角色立绘 |
| 尺寸 (LOD-0) | 800×1120px |
| 尺寸 (LOD-1) | 200×280px，标准裁切 |
| 格式 | PNG RGBA8，透明背景 |
| 源格式 | PSD 分层源文件 |
| 文件命名 (LOD-0) | `char_wansangu_portrait_full.png` |
| 文件命名 (LOD-1) | `char_wansangu_realm3.png` |

**图层结构：**
1. 背景层（锁定透明）
2. 墨色主体层：素雅长袍 + 净瓶 + 面容
3. 语义色·朱砂红层：无
4. 语义色·松石青层：净瓶中的澄澈灵液（≤1%）

**视觉描述：**
中年女修，正道中的「异数」——出身魅影阁却走正道。身着素雅长袍（灰度约 60%），袍身无任何装饰纹样——比一般正道更素。右手持一净瓶——瓶中盛有澄澈的灵液，以松石青（#1A8A8A）绘制灵液的微光（≤1%）。左手持一枝杨柳枝——杨柳以淡墨细线勾勒，几片长叶垂下。面容温和大度——拥有「净化一切debuff」能力的从容。眼神平和如古井。姿态直立平和（左倾 1°）。墨色淡雅（灰度 55-65%）。视觉信号：「什么污浊，一场洗去便是」。

**美术圣经锚点：**
- 六要素：法器锚点（净瓶+杨柳枝）、衣袍语汇（素雅无纹长袍）、姿态轴线（直立平和 左倾 1°）、墨色基调（55-65%淡雅）、阵营纹理（正道排线极疏极淡）、眼神方向（平和古井）
- 设计意图：柳媚儿（魅影阁魔道）=妖艳致命，万三姑（魅影阁出身但正道）=净化新生——同一出身两种选择

**生成提示（Midjourney）：**
Full body portrait of a serene middle-aged female cultivator, standing at peaceful ease, plain white background. She wears an unadorned plain light robe with no patterns. In her right hand she holds a pure-water vase — a turquoise blue (#1A8A8A) clear spirit liquid glimmers inside. In her left hand she holds a willow branch rendered in fine pale ink lines. Her expression is deeply calm and unruffled — the face of someone who can cleanse any affliction. Chinese ink wash painting, very light and sparse cross-hatching. Grayscale ink, light tones. Turquoise blue only in vase liquid. --no oil painting, 3D render, anime, ornate, decorated, seductive, colorful, background

**反向提示（Stable Diffusion）：**
oil painting, 3D render, CGI, anime, manga, ornate, decorated, seductive, young, colorful, background

**角色气质关键词：** 净化、从容、柳枝净瓶、debuff克星

---

### ASSET-198 — 血玉虫（魔道·血魂教）

| 字段 | 值 |
|-------|-------|
| 类别 | 精灵 / 2D 角色立绘 |
| 尺寸 (LOD-0) | 800×1120px |
| 尺寸 (LOD-1) | 200×280px，标准裁切 |
| 格式 | PNG RGBA8，透明背景 |
| 源格式 | PSD 分层源文件 |
| 文件命名 (LOD-0) | `char_xueyuchong_portrait_full.png` |
| 文件命名 (LOD-1) | `char_xueyuchong_realm3.png` |

**图层结构：**
1. 背景层（锁定透明）
2. 墨色主体层：虫甲纹理躯体 + 复眼面具 + 虫肢
3. 语义色·朱砂红层：体内暗红囊泡（≤2%）  
4. 语义色·松石青层：无

**视觉描述：**
非人——血玉虫是寄生在人体内的人造怪物，保留人形但全身被虫化甲壳覆盖。甲壳以紧密排列的墨色菱形纹表现（类似昆虫外骨骼的纹理）。面部戴着一个白骨骷髅面具——但面具上方的眼孔中露出的是昆虫的复眼（以密集的淡墨小网格表现）。胸腔位置透明化——隐约可见体内多个暗红色囊泡（朱砂红，≤2%）——这些囊泡就是「死后对全体造成伤害」的自爆源。双手已不是手而是虫肢——三根长而弯曲的骨刺。姿态半蹲（右倾 5°）——防御性的蜷缩。墨色中浓偏暗（灰度 35-45%）。视觉信号：「不要碰我——我死了对谁都没好处」。

**美术圣经锚点：**
- 六要素：法器锚点（虫肢骨刺）、衣袍语汇（虫化甲壳无衣袍）、姿态轴线（半蹲蜷缩 右倾 5°）、墨色基调（35-45%甲壳纹理）、阵营纹理（魔道——甲壳代替衣袍飞白）、眼神方向（复眼无瞳不可判断）
- 特殊处理：唯一一个「非人」角色——甲壳的几何纹理在墨骨丹青中是一个新的视觉词汇

**生成提示（Midjourney）：**
Full body portrait of a half-human half-insect monstrosity — humanoid form but body covered in insect carapace with diamond-shell patterns in dark ink, plain white background. A white bone skull-mask covers the face but compound insect eyes are visible through the eye holes as dense tiny light ink grid patterns. The chest cavity is semi-transparent showing multiple dark vermillion red (#C41E1E) pulsating sacs inside — the self-destruct source. Hands are replaced by three long curved bone-spurs each. Crouched in a defensive half-squat. Chinese ink wash painting, geometric shell texturing. Grayscale ink, medium-dark tones. Vermillion red only in internal sacs. --no oil painting, 3D render, anime, human hands, human face, normal skin, colorful, background

**反向提示（Stable Diffusion）：**
oil painting, 3D render, CGI, anime, manga, human hands, human face, normal, healthy, colorful, background

**角色气质关键词：** 非人、自爆者、生化怪物、血魂教

---

## 元婴期新增角色（4 张）

### ASSET-199 — 冰凤（元婴）（归墟之境·真灵·冰凤族）

| 字段 | 值 |
|-------|-------|
| 类别 | 精灵 / 2D 角色立绘 |
| 尺寸 (LOD-0) | 800×1120px |
| 尺寸 (LOD-1) | 200×280px，标准裁切 |
| 格式 | PNG RGBA8，透明背景 |
| 源格式 | PSD 分层源文件 |
| 文件命名 (LOD-0) | `char_bingfeng_portrait_full.png` |
| 文件命名 (LOD-1) | `char_bingfeng_realm4.png` |

**图层结构：**
1. 背景层（锁定透明）
2. 墨色主体层：冰凤羽衣 + 凤翼 + 冰羽 + 面容
3. 语义色·朱砂红层：无
4. 语义色·松石青层：冰翼边缘寒气 + 眉心灵光（≤2.5%——元婴真灵可较多使用松石青）

**视觉描述：**
元婴期真灵——冰凤族。人形但背后展开一对宽广的冰晶凤翼——凤翼以留白+极淡墨线勾勒羽片结构，翼边缘以松石青寒气渲染（≤2%）。身着冰凤羽衣——以层层叠叠的羽毛状布料构成，每层羽片以淡墨曲线勾勒边缘。银白色长发（以极淡墨+大量留白），发间有冰晶状的凤冠装饰。面容绝美而冰冷——与月清霜的「清冷透骨」不同，冰凤的冷是「神圣不可侵犯」的傲然。眼神平视但目光在观众头顶——「我在你之上的位面」。姿态直立悬浮——双足离地微浮。墨色极淡（灰度 65-75%），松石青的使用量为所有角色之最——标识元婴真灵的高阶身份。

**美术圣经锚点：**
- 六要素：法器锚点（冰晶凤翼）、衣袍语汇（凤羽衣+冰晶凤冠）、姿态轴线（直立悬浮 中立）、墨色基调（65-75%极淡）、阵营纹理（中立光滑晕染+羽片几何）、眼神方向（傲然俯视）
- 与银翎区分度：银翎=神圣温柔天人，冰凤=神圣傲然真灵王者
- 语义色许可：元婴真灵可使用松石青至 ≤2.5%——反映修为境界的提升

**生成提示（Midjourney）：**
Full body portrait of an ice phoenix true-spirit at Nascent Soul stage, floating with feet slightly off the ground, plain white background. A pair of wide crystalline ice-phoenix wings spread behind — rendered in negative space and palest ink outlines, with turquoise blue (#1A8A8A) cold mist at the wing edges. She wears a multi-layered phoenix-feather robe with each feather-layer outlined in pale ink curves. Her silver-white hair is adorned with an ice-crystal phoenix crown. Her face is supremely beautiful and coldly aloof — gaze slightly above the viewer. Chinese ink wash painting, smooth wet-ink blending. Grayscale ink, very light tones. Turquoise blue on wing edges and between eyebrows. --no oil painting, 3D render, anime, warm, fire phoenix, red, colorful, background

**反向提示（Stable Diffusion）：**
oil painting, 3D render, CGI, anime, manga, warm, fire, red phoenix, bird, colorful, background

**角色气质关键词：** 神圣、傲然、冰凤真灵、元婴王者

---

### ASSET-200 — 血海少主（魔道·血海殿·东域）

| 字段 | 值 |
|-------|-------|
| 类别 | 精灵 / 2D 角色立绘 |
| 尺寸 (LOD-0) | 800×1120px |
| 尺寸 (LOD-1) | 200×280px，标准裁切 |
| 格式 | PNG RGBA8，透明背景 |
| 源格式 | PSD 分层源文件 |
| 文件命名 (LOD-0) | `char_xuehai_shaozhu_portrait_full.png` |
| 文件命名 (LOD-1) | `char_xuehai_shaozhu_realm4.png` |

**图层结构：**
1. 背景层（锁定透明）
2. 墨色主体层：华贵少主袍 + 血海令旗 + 面容
3. 语义色·朱砂红层：令旗上的血海标记（≤2.5%——元婴魔道核心可较多使用朱砂红）
4. 语义色·松石青层：无

**视觉描述：**
青年魔修，血海殿少主——血海殿未来之主。身着华贵的少主袍（灰度约 30%）——袍面有血海波涛纹（以浓淡墨交替渲染出浪涛的纹理），领口为高立领配血玉扣。右手持血海令旗——令旗展开，旗面上有血海殿的宗门徽记，以朱砂红（#C41E1E）绘制血浪图案（≤2.5%——元婴期魔道核心角色的朱砂红使用量可放宽）。左手自然垂放于剑柄上——腰间佩剑但未出鞘。面容年轻但已沉淀了杀伐之气——五官端正英俊但眉宇间有压抑的暴戾。眼神锐利傲然——「血海殿的少主，从不低头看人」。姿态挺立（右倾 5°）。墨色浓重（灰度 25-35%），元婴期魔道的最强视觉存在感。视觉信号：「魔道之力，以我为尊」。

**美术圣经锚点：**
- 六要素：法器锚点（血海令旗）、衣袍语汇（少主华袍+血海波涛纹）、姿态轴线（挺立傲然 右倾 5°）、墨色基调（25-35%浓重）、阵营纹理（魔道波涛纹渲染）、眼神方向（锐利傲然）
- 语义色许可：元婴魔道核心角色可使用朱砂红至 ≤2.5%——反映修为境界的提升

**生成提示（Midjourney）：**
Full body portrait of the young master of the Blood Sea Hall, standing tall and imperious, plain white background. He wears an ornate young master's robe with blood-sea wave patterns in layered dark and light ink. A high standing collar with a blood-jade clasp. In his right hand he holds a command flag unfurled — the flag bears the Blood Sea Hall crest in vermillion red (#C41E1E) wave patterns. His left hand rests on a sheathed sword at his hip. His face is young and handsome but with restrained ferocity in his brow. He does not look down at anyone. Chinese ink wash painting, wave-pattern rendering. Grayscale ink, dark rich tones. Vermillion red on flag patterns. --no oil painting, 3D render, anime, humble, gentle, soft, colorful, background

**反向提示（Stable Diffusion）：**
oil painting, 3D render, CGI, anime, manga, humble, gentle, soft, weak, colorful, background

**角色气质关键词：** 少主、魔道骄子、血海未来之主、傲然

---

### ASSET-201 — 卫天寒（正道·卫家·东域）

| 字段 | 值 |
|-------|-------|
| 类别 | 精灵 / 2D 角色立绘 |
| 尺寸 (LOD-0) | 800×1120px |
| 尺寸 (LOD-1) | 200×280px，标准裁切 |
| 格式 | PNG RGBA8，透明背景 |
| 源格式 | PSD 分层源文件 |
| 文件命名 (LOD-0) | `char_wei_tianhan_portrait_full.png` |
| 文件命名 (LOD-1) | `char_wei_tianhan_realm4.png` |

**图层结构：**
1. 背景层（锁定透明）
2. 墨色主体层：卫家制式战袍 + 长枪 + 面容
3. 语义色·朱砂红层：枪缨一抹红（≤1%）
4. 语义色·松石青层：无

**视觉描述：**
青年男修，东域卫家子弟——世家出身而非宗门修士。身着卫家制式战袍（灰度约 45%）——袍面有卫家族徽（以浓墨线勾勒的盾形徽记）。双手持长枪——枪身笔直（以浓墨中锋表现），枪头为菱形，枪缨以朱砂红（≤1%）点缀。姿态笔直站立（左倾 3°）——军人世家出身，脊椎如枪杆般笔直。面容端正刚毅——眉头微锁，眼神正直坚定。头发以冠束起——比道髻更正式更规整。墨色中灰（灰度 45-55%）。视觉信号：「正道世家——对魔道绝不手软」。

**美术圣经锚点：**
- 六要素：法器锚点（长枪笔直）、衣袍语汇（制式战袍+族徽）、姿态轴线（脊椎如枪笔直 左倾 3°）、墨色基调（45-55%）、阵营纹理（正道排线刚正）、眼神方向（正直坚定）
- 与苏剑鸣区分度：苏剑鸣=灵动快攻剑客，卫天寒=沉稳刚毅枪兵

**生成提示（Midjourney）：**
Full body portrait of an upright young male cultivator from the Wei family clan, standing ramrod-straight with spine like a spear shaft, plain white background. He wears a Wei-family uniform battle robe with the clan shield crest in dark ink. He holds a long spear vertically — the shaft is dead straight in dark ink center-line, a diamond-shaped spearhead, and a vermillion red (#C41E1E) tassel at the neck. His face is square and resolute — brows slightly furrowed, gaze honest and determined. Hair in a formal cap — more regimented than a Daoist topknot. Chinese ink wash painting, rigid upright cross-hatching. Grayscale ink, medium tones. Vermillion red only on spear tassel. --no oil painting, 3D render, anime, curved, relaxed, loose, colorful, background

**反向提示（Stable Diffusion）：**
oil painting, 3D render, CGI, anime, manga, curved, relaxed, loose, slouched, colorful, background

**角色气质关键词：** 刚直、世家军人、对魔道专精、枪出如龙

---

### ASSET-202 — 余子童（魔道·轮回殿）

| 字段 | 值 |
|-------|-------|
| 类别 | 精灵 / 2D 角色立绘 |
| 尺寸 (LOD-0) | 800×1120px |
| 尺寸 (LOD-1) | 200×280px，标准裁切 |
| 格式 | PNG RGBA8，透明背景 |
| 源格式 | PSD 分层源文件 |
| 文件命名 (LOD-0) | `char_yu_zitong_portrait_full.png` |
| 文件命名 (LOD-1) | `char_yu_zitong_realm4.png` |

**图层结构：**
1. 背景层（锁定透明）
2. 墨色主体层：依附形态——半透明虚影 + 寄生丝线 + 面容
3. 语义色·朱砂红层：无
4. 语义色·松石青层：寄生丝线微光（≤1.5%）

**视觉描述：**
余子童不是战斗者而是依附者——他的立绘应该表现「依附在他人身上」的能力。身体呈半透明虚影——边缘模糊如灵魂（以极淡墨渲染，灰度约 75-80%）。从身体中延伸出多条细长的寄生丝线——丝线以极细的淡墨线表现，丝线末端有松石青的微小吸盘（≤1.5%）。这些丝线飘向观众方向——暗示它们要附着在某个「宿主」身上。面容是年幼的孩童——年龄约 10-12 岁，眼神纯真但令人不安（「纯真的恐怖」）。双手垂于身侧——手指上也有丝线延伸。姿态漂浮——无重力的悬浮。墨色极淡（灰度 70-80%），几乎融入留白。视觉信号：「我需要一个宿主……你愿意吗？」

**美术圣经锚点：**
- 六要素：法器锚点（寄生丝线吸盘）、衣袍语汇（半透明虚影无实体衣袍）、姿态轴线（漂浮无重力）、墨色基调（70-80%极淡虚影）、阵营纹理（魔道+虚幻——模糊轮廓代替飞白）、眼神方向（纯真扰人）
- 特殊处理：第一个「依附型」角色——以半透明和寄生丝线为视觉核心

**生成提示（Midjourney）：**
Full body portrait of an unsettling ghostly child cultivator — body is semi-transparent with soft blurred edges like a spirit projection, floating weightlessly, plain white background. Multiple thin parasitic threads extend from his body toward the viewer — rendered in extremely fine pale ink lines with tiny turquoise blue (#1A8A8A) suction-cup dots at thread tips. His face is that of a 10-12 year old child — innocent expression but deeply unsettling. More threads extend from his fingertips. Chinese ink wash painting, ethereal ghost-like transparency. Grayscale ink, extremely light tones (barely visible). Turquoise blue only on thread tips. --no oil painting, 3D render, anime, solid, opaque, adult, aggressive, colorful, background

**反向提示（Stable Diffusion）：**
oil painting, 3D render, CGI, anime, manga, solid, opaque, adult, muscular, aggressive, colorful, background

**角色气质关键词：** 寄生者、纯真恐怖、寻找宿主、轮回殿的异端

---

## 技术规范汇总（更新）

### 内存估算（更新）

| LOD 级别 | 单张内存 (RGBA8) | 数量 | 合计 |
|:--:|:--:|:--:|:--:|
| LOD-0 | ~3.4 MB | 38 | ~129 MB |
| LOD-1 | ~219 KB | 38 | ~8.3 MB |
| DXT5/BC3 压缩后 (LOD-0) | ~0.85 MB | 38 | ~32.3 MB |
| DXT5/BC3 压缩后 (LOD-1) | ~55 KB | 38 | ~2.1 MB |

> 峰值加载全部 38 张 LOD-0 + 38 张 LOD-1 ≈ 34.4 MB，仍在 2GB 预算之内。

### 立绘覆盖率

| 类别 | 数量 | 说明 |
|------|:--:|------|
| 核心角色专属 | 12 | ASSET-001~012 |
| 非核心独立角色 | 23 | ASSET-180~202 |
| 阵营通用 | 3 | ASSET-013~015 |
| **总立绘** | **38** | 覆盖全部独立角色 |
| 同名跨境界复用 | — | 境界差异由卡框+标签区分 |
| 完全无立绘的角色 | 0 | 所有角色卡均有对应的立绘或通用立绘 |
