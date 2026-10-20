# 资产规范 — system：combat-entities（敌方/Boss/NPC 实体立绘）

> **来源**：`design/assets/entity-inventory.md`（视觉母清单——30 敌方原型 + 6 Boss + 9 NPC 的完整视觉描述，本 spec **引用不复制**其视觉概述，逐条以 E01/B01/NPC-001 编号锚定）、`design/art/art-bible.md` §5.2（三重区分系统）+ §5.3（表情姿势）+ §4.9（浅绛淡彩）+ §8（资产标准）
> **美术圣经**：design/art/art-bible.md
> **生成日期**：2026-10-20
> **审查模式**：Solo（视觉描述已由 entity-inventory.md 完整定义并经 AD-PHASE-GATE 审定——本 spec 只补技术参数、正式编号、命名与生成管线，无需代理复审）
> **状态**：45 个实体已规范（30 敌方 + 6 Boss + 9 NPC）/ 0 个已批准 / 0 个生产中 / 0 个完成

---

## 技术参数（全组共用）

| 参数 | 值 |
|------|-----|
| LOD-0 | 800×1120px PNG（透明或淡墨背景）——**仅 Boss 与任务/剧情 NPC 需要**（entity-inventory §5.2：约 21 张） |
| LOD-1 | 200×280px PNG——**全部实体需要**（战斗精灵/卡面规格，约 57 张含 Boss 多阶段变体） |
| LOD-2 | 64×90px PNG——从 LOD-1 裁切生成（全部实体，约 57 张） |
| 生成工作分辨率 | 即梦 1:1 2K（≈2048×2048），与角色立绘管线同（见 character-portrait SOP：缩 800×1120 + 裁 LOD-1） |
| 格式 | PNG RGBA8，sRGB；源候选件暂存 `C:/Users/Administrator/Downloads/jimeng_entities/` |
| 上色 | 浅绛淡彩（§4.9）六色相；敌方淡彩饱和度同角色立绘口径（S≤25% L≥70%） |
| 命名根目录 | `assets/characters/enemies/`（敌方+Boss）与 `assets/characters/npcs/`（NPC），见下 |
| Godot 导入 | 同角色立绘预设（§8.2.2——lossless、无 mipmap） |
| 视觉约束 | 全部按 §5.2.1 三重区分（纹理降密 30%/顶部裂口边框）+ §5.2.2 威胁三级（L3 淡墨 50-65%/L2 中墨 35-50%/L1+ 浓墨 20-35% + 边框 1.5/2/3px + 裂口 2/4/8px——裂口与边框由 UI 运行时叠加，不烘焙进图） |

**命名约定**（snake_case，§8.1.2）：

| 实体 | LOD-0 | LOD-1 | LOD-2 |
|------|-------|-------|-------|
| 敌方 | （无） | `assets/characters/enemies/[enemy_id].png` 200×280 | `[enemy_id]_avatar.png` 64×90 |
| Boss（每阶段独立图） | `boss_[id]_p[n]_full.png` 800×1120 | `boss_[id]_p[n].png` 200×280 | `boss_[id]_p[n]_avatar.png` |
| NPC | `npc_[id]_full.png`（仅任务/剧情） | `npc_[id].png` 200×280 | `npc_[id]_avatar.png` |

`enemy_id`/`boss_id`/`npc_id` 采用「类型_名称」拼音，如 `enemy_stone_ape`、`boss_moyuan`、`npc_shopkeeper`。

---

## 一、敌方原型（30 个，ASSET-282~311）

> 视觉描述见 `entity-inventory.md` §2 各行（E01~E30）——原型名/阵营/视觉概述/灰度/纹理/姿态全以该表为准。下表只列编号映射与文件命名。

| ID | 源 | 原型 | enemy_id | LOD-1+2 | 优先级 |
|----|----|------|----------|:--:|:--:|
| ASSET-282 | E01 | 青云外门弟子 | `enemy_qingyun_disciple` | ✓ | MVP |
| ASSET-283 | E02 | 散修·夺宝修士 | `enemy_sanxiu_plunderer` | ✓ | MVP |
| ASSET-284 | E03 | 妖兽·石猿 | `enemy_stone_ape` | ✓ | MVP |
| ASSET-285 | E04 | 血蝠群 | `enemy_blood_bats` | ✓ | VS |
| ASSET-286 | E05 | 墨渊麾下·魔修 | `enemy_moyuan_cultist` | ✓ | MVP |
| ASSET-287 | E06 | 丹霞试炼傀儡 | `enemy_danxia_puppet` | ✓ | VS |
| ASSET-288 | E07 | 苍玄巡卫 | `enemy_cangxuan_patrol` | ✓ | MVP |
| ASSET-289 | E08 | 魔道·探子 | `enemy_demonic_scout` | ✓ | VS |
| ASSET-290 | E09 | 古战场残魂 | `enemy_battlefield_wraith` | ✓ | MVP |
| ASSET-291 | E10 | 海盗散修 | `enemy_pirate_sanxiu` | ✓ | VS |
| ASSET-292 | E11 | 苍玄执事 | `enemy_cangxuan_steward` | ✓ | MVP |
| ASSET-293 | E12 | 海妖兽·巨钳蟹 | `enemy_giant_crab` | ✓ | VS |
| ASSET-294 | E13 | 万古殿守卫 | `enemy_wangu_guard` | ✓ | VS |
| ASSET-295 | E14 | 西域沙匪 | `enemy_desert_bandit` | ✓ | VS |
| ASSET-296 | E15 | 慕兰斥候 | `enemy_mulan_scout` | ✓ | VS |
| ASSET-297 | E16 | 万古殿执念体 | `enemy_wangu_obsession` | ✓ | MVP |
| ASSET-298 | E17 | 西域妖兽·沙蝎王 | `enemy_sand_scorpion` | ✓ | VS |
| ASSET-299 | E18 | 正魔老兵·执念 | `enemy_veteran_echo` | ✓ | VS |
| ASSET-300 | E19 | 西域宗门弟子 | `enemy_xiyu_disciple` | ✓ | VS |
| ASSET-301 | E20 | 慕兰战士 | `enemy_mulan_warrior` | ✓ | VS |
| ASSET-302 | E21 | 归墟巡游者 | `enemy_guixu_wanderer` | ✓ | VS |
| ASSET-303 | E22 | 西域长老 | `enemy_xiyu_elder` | ✓ | VS |
| ASSET-304 | E23 | 慕兰萨满 | `enemy_mulan_shaman` | ✓ | VS |
| ASSET-305 | E24 | 归墟守护者 | `enemy_guixu_guardian` | ✓ | VS |
| ASSET-306 | E25 | 浮云陆散仙 | `enemy_floating_immortal` | ✓ | FV |
| ASSET-307 | E26 | 万妖谷·妖兵 | `enemy_demon_soldier` | ✓ | FV |
| ASSET-308 | E27 | 古魔残影 | `enemy_ancient_demon_echo` | ✓ | FV |
| ASSET-309 | E28 | 万妖谷·妖将 | `enemy_demon_general` | ✓ | FV |
| ASSET-310 | E29 | 古魔近卫 | `enemy_ancient_demon_guard` | ✓ | FV |
| ASSET-311 | E30 | 归墟·上古邪修 | `enemy_ancient_evil_cultivator` | ✓ | FV |

**LOD 分配**（entity-inventory §5.2）：普通敌方 17 个仅 LOD-1/2；精英 13 个同。**全部无 LOD-0**。

**多形态原型**：E26 妖兵（狼/虎/熊 3 头部变体）——LOD-1 出 3 张变体 `enemy_demon_soldier_wolf/tiger/bear`，计为 ASSET-307 的子交付物，不另立编号。

---

## 二、Boss 实体（6 个，ASSET-312~317）

> 视觉与阶段差分描述见 `entity-inventory.md` §3 各节（B01~B06，含阶段 1/2/3 差分、转换动画、本命绑定视觉）。每个阶段独立成图。

| ID | 源 | Boss | boss_id | 阶段数 | LOD-0 张数 | LOD-1 张数 |
|----|----|------|---------|:--:|:--:|:--:|
| ASSET-312 | B01 | 墨渊·夺舍体（炼气） | `boss_moyuan` | 2 | 2 | 2 |
| ASSET-313 | B02 | 正魔怨灵（筑基） | `boss_wraith_aggregate` | 2 | 2 | 2 |
| ASSET-314 | B03 | 万古殿·殿灵（金丹） | `boss_wangu_spirit` | 2 | 2 | 2 |
| ASSET-315 | B04 | 慕兰大萨满（元婴） | `boss_mulan_shaman` | 2 | 2 | 2 |
| ASSET-316 | B05 | 古魔·残躯（化神·终战） | `boss_ancient_demon` | 3 | 3 | 3 |
| ASSET-317 | B06 | 天劫化身（全境界） | `boss_tribulation` | 4 变体 | 4（筑基/金丹/元婴/化神各 1；元婴/化神若 2 阶段则 +2） | 4 |

**Boss LOD-0 合计**：2+2+2+2+3+4(+2) ≈ 15-17 张（与 entity-inventory §3.7 估算 18 一致——天劫化身双阶段按需追加）。

**Boss 特有视觉规则**（§5.2.2 Boss 设计协议 + entity-inventory §3）：
- L1+ 浓墨（灰度 20-35%；古魔·残躯 15-30% 为全游戏最深）
- 边框 3px + 顶部裂口 8px 由 **UI 运行时叠加**——立绘本身不画边框
- 本命绑定光点（朱砂红 2-3px）、阶段转换的黑雾/裂纹差分按 entity-inventory 各节
- **禁止琉璃金**（§5.2.3——Boss 无金色）；天劫化身是唯一例外允许大量语义色（琉璃金+松石青雷光）

---

## 三、NPC 实体（9 个，ASSET-318~326）

> 视觉描述见 `entity-inventory.md` §4 各表。

| ID | 源 | NPC | npc_id | LOD-0 | 优先级 |
|----|----|-----|--------|:--:|:--:|
| ASSET-318 | NPC-001 | 坊市掌柜（通用） | `npc_shopkeeper` | — | MVP |
| ASSET-319 | NPC-002 | 碎星商会·分会长 | `npc_guild_chief` | — | VS |
| ASSET-320 | NPC-003 | 丹霞谷·炼丹师 | `npc_alchemist` | — | VS |
| ASSET-321 | NPC-004 | 云澜城·告示牌老人 | `npc_notice_elder` | — | VS |
| ASSET-322 | NPC-005 | 苍玄古道·神秘旅人 | `npc_mysterious_traveler` | — | VS |
| ASSET-323 | NPC-006 | 碎星群岛·船夫 | `npc_boatman` | — | FV |
| ASSET-324 | NPC-007 | 青云剑宗·传功长老 | `npc_qingyun_elder` | ✓ | MVP |
| ASSET-325 | NPC-008 | 丹霞谷·李元化 | `npc_li_yuanhua` | ✓ | VS |
| ASSET-326 | NPC-009 | 玄冰宫·守阁长老 | `npc_xuanbing_elder` | ✓ | FV |

**注意**：
- NPC-008 李元化与角色卡 ASSET-185 为**不同资产**（entity-inventory §6.2）——NPC 版需按 §5.2.1 NPC 规则重绘（晕染稀薄 20%、边框淡化 50%、放松姿态），非立绘复用
- Bark NPC 不需要独立立绘（§4.4）——复用对应实体 LOD-2

---

## 四、生成管线 SOP（即梦）

沿用角色立绘管线（`character-portrait-pipeline` 记忆 + `.dreamina_cli/mortal-heaven-question.md` §2）：

1. **取 prompt 素材**：entity-inventory 对应行的视觉概述（衣着/墨色/纹理/姿态/法器）→ 拼入角色立绘同款英文 prompt 骨架（水墨写意 + 浅绛淡彩 S≤25% L≥70% + 六要素描述 + 负向词 oil/3D/anime/vibrant）
2. **提交**：`dreamina text2image --prompt="…" --ratio=1:1 --resolution_type=2k --poll=120`（**prompt ≤1600 字符**——先 `wc -m`）
3. **缩放**：Python+Pillow——2048² → 800×1120（LOD-0，仅 Boss/剧情 NPC）→ 裁切 200×280（LOD-1）→ 64×90（LOD-2 从 LOD-1 头部裁）
4. **验证**：由用户负责（不做自动视觉验证）
5. **落盘**：`.import` 经 `godot --headless --import` 补齐

**生成顺序（按优先级）**：
- **MVP 13 实体**：ASSET-282/283/284/286/288/290/292/297（8 敌方）+ 312/313/317（3 Boss）+ 318/324（2 NPC）——先出 LOD-1/LOD-2；Boss LOD-0 优先 312（墨渊）+ 317（筑基天劫）
- **VS 16 敌方 + 2 Boss + 5 NPC** 后续分批
- **FV 6 敌方 + 1 Boss + 2 NPC** 最后

---

## 五、验收锚点

- **三重区分测试**（§5.2.1）：灰度去文字下，盟友/敌方/NPC 判断正确率 100%
- **威胁排序测试**（§5.2.2）：Boss/精英/普通并排灰度呈现，仅凭边框粗细+墨色排序正确率 100%
- **表情铁律**（§5.3.1）：敌方=克制敌意；Boss=嘴角一侧极微挑起（2-3px 当量）；禁止露齿/咆哮/狰狞
- **LOD-1 0.5s 测试**（§5.4.3）：法器轮廓+阵营纹理可辨
- **灰度化淡彩自检**（§4.9）：去饱和后仍是合格墨色画
