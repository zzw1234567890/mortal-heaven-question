
# 技能测试规格：/content-audit（内容审计）

## 技能概述（Skill Summary）

`/content-audit` 读取 `design/gdd/` 中的游戏设计文档（Game Design Document, GDD），检查其中指定的所有内容项（敌人、物品、关卡等）是否在 `assets/` 中得到落实。它生成一个缺口表：内容类型（Content Type）→ 指定数量（Specified Count）→ 已找到数量（Found Count）→ 缺失项（Missing Items）。不调用任何主管关卡（Director Gate）。该技能在未经用户批准的情况下不会写入文件。裁决结果（Verdict）：COMPLETE（完整）、GAPS FOUND（发现缺口）或 MISSING CRITICAL CONTENT（缺少关键内容）。

---

## 静态断言（结构）（Static Assertions）

由 `/skill-test static` 自动验证 —— 无需测试夹具。

- [ ] 具有所需的前置元数据字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 具有 ≥2 个阶段标题
- [ ] 包含裁决关键词：COMPLETE、GAPS FOUND、MISSING CRITICAL CONTENT
- [ ] 不需要"May I write"用语（只读输出；写入为可选报告）
- [ ] 具有下一步交接说明（审查缺口表后的操作建议）

---

## 主管关卡检查（Director Gate Checks）

无。内容审计是一项只读分析技能；不调用任何关卡。

---

## 测试用例（Test Cases）

### 用例 1：正常路径 —— 所有指定内容均已存在

**测试夹具（Fixture）：**
- `design/gdd/enemies.md` 指定 4 种敌人类型：Grunt、Sniper、Tank、Boss
- `assets/art/characters/` 包含文件夹：`grunt/`、`sniper/`、`tank/`、`boss/`
- `design/gdd/items.md` 指定 3 种物品类型；全部在 `assets/data/items/` 中找到

**输入：** `/content-audit`

**预期行为：**
1. 技能读取 `design/gdd/` 中的所有 GDD
2. 技能扫描 `assets/` 中的每个指定内容项
3. 所有 4 种敌人类型和 3 种物品类型均被找到
4. 缺口表显示：所有行的已找到数量 = 指定数量，无缺失项
5. 裁决结果为 COMPLETE

**断言：**
- [ ] 缺口表涵盖 GDD 中发现的所有内容类型
- [ ] 每行显示指定数量和已找到数量
- [ ] 当数量匹配时无缺失项
- [ ] 裁决结果为 COMPLETE
- [ ] 不写入任何文件

---

### 用例 2：发现缺口 —— 资产中缺少敌人类型

**测试夹具：**
- `design/gdd/enemies.md` 指定 3 种敌人类型：Grunt、Sniper、Boss
- `assets/art/characters/` 仅包含：`grunt/`、`sniper/`（Boss 文件夹缺失）

**输入：** `/content-audit`

**预期行为：**
1. 技能读取 GDD —— 发现指定了 3 种敌人类型
2. 技能扫描 `assets/art/characters/` —— 仅找到 2 种
3. 敌人的缺口表行：指定 3，找到 2，缺失：Boss
4. 裁决结果为 GAPS FOUND

**断言：**
- [ ] 缺口表行按名称将"Boss"标识为缺失项
- [ ] 指定数量（3）和已找到数量（2）均显示
- [ ] 当任何内容项缺失时，裁决结果为 GAPS FOUND
- [ ] 技能不假定资产稍后会被添加 —— 它现在立即标记

---

### 用例 3：未找到 GDD 内容规格 —— 给出指导

**测试夹具：**
- `design/gdd/` 仅包含 `core-loop.md`，该文件没有内容清单部分
- 不存在其他包含内容规格的 GDD

**输入：** `/content-audit`

**预期行为：**
1. 技能读取所有 GDD —— 未找到内容清单部分
2. 技能输出："在 GDD 中未找到内容规格 —— 请先运行 /design-system 来定义内容列表"
3. 不生成缺口表
4. 裁决结果为 GAPS FOUND（没有规格无法确认完整性）

**断言：**
- [ ] 当没有 GDD 内容规格时，技能不生成缺口表
- [ ] 输出建议运行 `/design-system`
- [ ] 裁决结果反映了无法确认完整性的状态

---

### 用例 4：边界情况 —— 资产格式不符合目标平台要求

**测试夹具：**
- `design/gdd/audio.md` 指定音频资产格式为 OGG
- `assets/audio/sfx/jump.wav` 存在（WAV 格式，非 OGG）
- `assets/audio/sfx/land.ogg` 存在（正确格式）
- `technical-preferences.md` 指定音频格式：OGG

**输入：** `/content-audit`

**预期行为：**
1. 技能读取 GDD 音频规格和技术偏好中的格式要求
2. 技能发现 `jump.wav` —— 存在但格式错误
3. 音频的缺口表行：指定 2，找到 2（按名称），但 `jump.wav` 被标记为 FORMAT ISSUE（格式问题）
4. 裁决结果为 GAPS FOUND（格式合规性是内容完整性的一部分）

**断言：**
- [ ] 当格式被指定时，技能根据 GDD 或技术偏好检查资产格式
- [ ] `jump.wav` 被标记为 FORMAT ISSUE，并注明预期格式（OGG）
- [ ] 在缺口表中，格式问题与内容缺失加以区分
- [ ] 当存在格式问题时，裁决结果为 GAPS FOUND

---

### 用例 5：关卡合规性 —— 只读；无关卡；缺口表供人工审查

**测试夹具：**
- GDD 指定 10 个内容项；在资产中找到 9 个；1 个缺失
- `review-mode.txt` 包含 `full`

**输入：** `/content-audit`

**预期行为：**
1. 技能读取 GDD 并扫描资产；生成缺口表
2. 无论审核模式如何，均不调用任何主管关卡
3. 技能以只读输出形式向用户展示缺口表
4. 裁决结果为 GAPS FOUND
5. 技能提供写入审计报告的选项，但不自动写入

**断言：**
- [ ] 在任何审核模式下均不调用主管关卡
- [ ] 缺口表在未自动写入任何文件的情况下展示
- [ ] 提供可选报告写入但不强制
- [ ] 技能不修改任何资产文件

---

## 协议合规性（Protocol Compliance）

- [ ] 在生成缺口表之前读取 GDD 和资产目录
- [ ] 缺口表显示内容类型（Content Type）、指定数量（Specified Count）、已找到数量（Found Count）、缺失项（Missing Items）
- [ ] 未经用户明确批准不写入文件
- [ ] 不调用任何主管关卡
- [ ] 裁决结果为以下之一：COMPLETE、GAPS FOUND、MISSING CRITICAL CONTENT

---

## 覆盖范围说明（Coverage Notes）

- MISSING CRITICAL CONTENT 裁决结果（相对于 GAPS FOUND）在缺失项在 GDD 中被标记为关键内容时触发；此处未进行明确测试，但遵循相同的检测路径。
- `assets/` 目录不存在的情况未进行测试；该技能将对所有指定项产生 MISSING CRITICAL CONTENT 裁决结果。
