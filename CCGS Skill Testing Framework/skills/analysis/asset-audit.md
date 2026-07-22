
# 技能测试规格：/asset-audit（资产审计）

## 技能概述（Skill Summary）

`/asset-audit` 对 `assets/` 目录进行审计，检查命名约定合规性、缺失元数据以及格式/大小问题。它根据 `technical-preferences.md` 中定义的约定和预算读取资产文件。不调用任何主管关卡（Director Gate）。该技能在未经用户批准的情况下不会写入文件。裁决结果（Verdict）：COMPLIANT（合规）、WARNINGS（警告）或 NON-COMPLIANT（不合规）。

---

## 静态断言（结构）（Static Assertions）

由 `/skill-test static` 自动验证 —— 无需测试夹具。

- [ ] 具有所需的前置元数据字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 具有 ≥2 个阶段标题
- [ ] 包含裁决关键词：COMPLIANT、WARNINGS、NON-COMPLIANT
- [ ] 不需要"May I write"用语（只读；可选报告需经批准）
- [ ] 具有下一步交接说明（审计结果后的操作建议）

---

## 主管关卡检查（Director Gate Checks）

无。资产审计是一项只读分析技能；不调用任何关卡。

---

## 测试用例（Test Cases）

### 用例 1：正常路径 —— 所有资产遵循命名约定

**测试夹具（Fixture）：**
- `technical-preferences.md` 指定命名约定：`snake_case`，例如 `enemy_grunt_idle.png`
- `assets/art/characters/` 包含：`enemy_grunt_idle.png`、`enemy_sniper_run.png`
- `assets/audio/sfx/` 包含：`sfx_jump_land.ogg`、`sfx_item_pickup.ogg`
- 所有文件均在大小预算内（纹理 ≤2MB，音频 ≤500KB）

**输入：** `/asset-audit`

**预期行为：**
1. 技能从 `technical-preferences.md` 读取命名约定和大小预算
2. 技能递归扫描 `assets/`
3. 所有文件符合 `snake_case` 约定；均在预算内
4. 审计表显示所有行 PASS
5. 裁决结果为 COMPLIANT

**断言：**
- [ ] 审计涵盖艺术和音频资产目录
- [ ] 每个文件均按命名约定和大小预算进行检查
- [ ] 合规时所有行显示 PASS
- [ ] 裁决结果为 COMPLIANT
- [ ] 不写入任何文件

---

### 用例 2：不合规 —— 纹理超出大小预算

**测试夹具：**
- `assets/art/environment/` 包含 5 个纹理文件
- 3 个纹理文件各为 4MB（预算：≤2MB）
- 2 个纹理文件在预算内

**输入：** `/asset-audit`

**预期行为：**
1. 技能从 `technical-preferences.md` 读取大小预算（纹理为 2MB）
2. 技能扫描 `assets/art/environment/` —— 发现 3 个超限纹理
3. 审计表列出每个超限文件及其实际大小和预算
4. 裁决结果为 NON-COMPLIANT
5. 技能建议对标记的文件进行压缩或降低分辨率

**断言：**
- [ ] 所有 3 个超限文件均按名称列出，并附有实际大小和预算大小
- [ ] 当任何文件超出预算时，裁决结果为 NON-COMPLIANT
- [ ] 对超限文件给出优化建议
- [ ] 预算内的文件也一并列出（显示 PASS）以保证完整性

---

### 用例 3：格式问题 —— 音频格式错误

**测试夹具：**
- `technical-preferences.md` 指定音频格式：OGG
- `assets/audio/music/theme_main.wav` 存在（WAV 格式）
- `assets/audio/sfx/sfx_footstep.ogg` 存在（正确的 OGG 格式）

**输入：** `/asset-audit`

**预期行为：**
1. 技能读取音频格式要求：OGG
2. 技能扫描 `assets/audio/` —— 发现 `theme_main.wav` 格式错误
3. 审计表将 `theme_main.wav` 标记为 FORMAT ISSUE（格式问题）（应为 OGG，实际为 WAV）
4. `sfx_footstep.ogg` 显示 PASS
5. 裁决结果为 WARNINGS（格式问题可纠正）

**断言：**
- [ ] `theme_main.wav` 被标记为 FORMAT ISSUE，并注明预期格式和实际格式
- [ ] 对于可纠正的格式问题，裁决结果为 WARNINGS（而非 NON-COMPLIANT）
- [ ] 格式正确的资产显示为 PASS
- [ ] 技能不修改或转换任何资产文件

---

### 用例 4：资产缺失 —— GDD 引用的资产在 assets/ 中不存在

**测试夹具：**
- `design/gdd/enemies.md` 引用了 `enemy_boss_idle.png`
- `assets/art/characters/boss/` 目录为空 —— 文件不存在

**输入：** `/asset-audit`

**预期行为：**
1. 技能读取 GDD 引用以查找预期资产（与 `/content-audit` 范围交叉引用）
2. 技能扫描 `assets/art/characters/boss/` —— 未找到文件
3. 审计表将 `enemy_boss_idle.png` 标记为 MISSING ASSET（资产缺失）
4. 裁决结果为 NON-COMPLIANT（缺少关键美术资产）

**断言：**
- [ ] 技能检查 GDD 引用以识别预期资产
- [ ] 缺失资产被标记为 MISSING ASSET，并注明 GDD 引用来源
- [ ] 当关键资产缺失时，裁决结果为 NON-COMPLIANT
- [ ] 技能不创建或添加占位资产

---

### 用例 5：关卡合规性 —— 无关卡；可单独咨询技术美术师

**测试夹具：**
- 2 个文件存在命名约定违规（使用了 CamelCase 而非 snake_case）
- `review-mode.txt` 包含 `full`

**输入：** `/asset-audit`

**预期行为：**
1. 技能扫描资产并发现 2 个命名违规
2. 无论审核模式如何，均不调用任何主管关卡
3. 裁决结果为 WARNINGS
4. 输出提示："建议让技术美术师（Technical Artist）审查命名约定"
5. 技能展示发现结果；提供可选的审计报告写入
6. 如果用户选择写入："我可以写入 `production/qa/asset-audit-[date].md` 吗？"

**断言：**
- [ ] 在任何审核模式下均不调用主管关卡
- [ ] 建议（而非强制）咨询技术美术师
- [ ] 在任何写入提示之前先展示发现结果表
- [ ] 可选的审计报告在写入前询问"May I write"

---

## 协议合规性（Protocol Compliance）

- [ ] 读取 `technical-preferences.md` 中的命名约定、格式和大小预算
- [ ] 递归扫描 `assets/` 目录
- [ ] 审计表显示文件名、检查类型、预期值、实际值和结果
- [ ] 不修改任何资产文件
- [ ] 不调用任何主管关卡
- [ ] 裁决结果为以下之一：COMPLIANT、WARNINGS、NON-COMPLIANT

---

## 覆盖范围说明（Coverage Notes）

- 元数据检查（例如，Godot `.import` 文件中缺失的纹理导入设置）未在此处明确测试；它们遵循相同的 FORMAT ISSUE 标记模式。
- `/asset-audit` 和 `/content-audit` 之间的交互（两者均检查 GDD 引用与资产的对照）是设计上的有意重叠；`/asset-audit` 侧重于合规性，而 `/content-audit` 侧重于完整性。
