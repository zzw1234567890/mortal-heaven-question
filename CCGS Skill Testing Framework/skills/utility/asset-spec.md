# 技能测试规格：/asset-spec


## 技能概述 (Skill Summary)

`/asset-spec` 根据设计需求生成每个资源 (per-asset) 的视觉规格文档。它读取相关的 GDD、艺术圣经 (art bible) 和设计系统，生成一份结构化的资源规格表，定义：尺寸、动画状态（如适用）、调色板参考、风格说明、技术约束（格式、文件大小预算）和可交付物检查清单。

规格表在"May I write"询问后写入 `assets/specs/[asset-name]-spec.md`。如果规格已存在，技能会提议更新。当一次调用请求多个资源时，每个资源会单独进行"May I write"询问。不设总监关卡 (director gates)。当所有请求的规格都已写入时，裁决结果为 COMPLETE。

---

## 静态断言 (Structural)

由 `/skill-test static` 自动验证——无需测试夹具。

- [ ] 拥有必需的前置元字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 有 ≥2 个阶段标题
- [ ] 包含裁决关键词：COMPLETE
- [ ] 包含"May I write"协作协议语言（每个资源）
- [ ] 有下一步交接（例如，分派给美术师，或稍后运行 `/asset-audit`）

---

## 总监关卡检查 (Director Gate Checks)

无。`/asset-spec` 是一个设计文档工具。技术美术 (Technical Artist) 可以单独审查规格，但这并非本技能内的关卡。

---

## 测试用例 (Test Cases)

### 用例 1：正常路径 (Happy Path) —— 具有完整 GDD 和艺术圣经的敌人精灵规格

**测试夹具：**
- `design/gdd/enemies.md` 存在，定义了多种敌人变体
- `design/art-bible.md` 存在，包含调色板和风格说明
- 尚无针对"goblin-enemy"的现有资源规格

**输入：** `/asset-spec goblin-enemy`

**预期行为：**
1. 技能读取敌人 GDD 和艺术圣经
2. 技能为哥布林敌人精灵生成规格：
   - 尺寸：从引擎默认值推断或从 GDD 明确获取
   - 动画状态：空闲 (idle)、行走 (walk)、攻击 (attack)、受伤 (hurt)、死亡 (death)
   - 调色板参考：链接到艺术圣经的调色板部分
   - 风格说明：来自艺术圣经的角色设计规则
   - 技术约束：格式 (PNG)、大小预算
   - 可交付物检查清单
3. 技能询问"是否可以写入 `assets/specs/goblin-enemy-spec.md`？"
4. 批准后写入文件；裁决结果为 COMPLETE

**断言：**
- [ ] 所有 6 个规格组件均存在（尺寸、动画、调色板、风格、技术、检查清单）
- [ ] 调色板参考链接到艺术圣经（不重复）
- [ ] 动画状态来自 GDD（不是凭空编造）
- [ ] "May I write"以正确路径询问
- [ ] 裁决结果为 COMPLETE

---

### 用例 2：未找到艺术圣经 (No Art Bible Found) —— 带有占位符风格说明和依赖标记的规格

**测试夹具：**
- `design/gdd/player.md` 存在
- `design/art-bible.md` 不存在

**输入：** `/asset-spec player-sprite`

**预期行为：**
1. 技能读取玩家 GDD 但找不到艺术圣经
2. 技能生成带有占位符风格说明的规格："依赖缺口 (DEPENDENCY GAP)：未找到艺术圣经——风格说明为占位符"
3. 调色板部分使用："待定 (TBD)——详见创建后的艺术圣经"
4. 技能询问"是否可以写入 `assets/specs/player-sprite-spec.md`？"
5. 文件使用占位符和依赖标记写入；裁决结果为 COMPLETE（附带建议性说明）

**断言：**
- [ ] 针对缺失的艺术圣经标记了 DEPENDENCY GAP
- [ ] 规格仍然生成（未被阻塞）
- [ ] 风格说明包含占位符标记，而非自创风格
- [ ] 裁决结果为 COMPLETE（附带建议性说明）

---

### 用例 3：资源规格已存在 (Asset Spec Already Exists) —— 提议更新

**测试夹具：**
- `assets/specs/goblin-enemy-spec.md` 已存在
- 自规格编写以来 GDD 已更新（新增了攻击动画）

**输入：** `/asset-spec goblin-enemy`

**预期行为：**
1. 技能检测到现有规格文件
2. 技能报告："goblin-enemy 的资源规格已存在——正在检查更新"
3. 技能对比 GDD 与现有规格，发现：GDD 中新增了"charge-attack"动画状态但规格中没有
4. 技能呈现差异："发现 1 个新的动画状态——提议更新规格"
5. 技能询问"是否可以更新 `assets/specs/goblin-enemy-spec.md`？"（不是覆盖）
6. 规格更新；裁决结果为 COMPLETE

**断言：**
- [ ] 检测到现有规格并提供了"更新"路径
- [ ] 显示 GDD 与现有规格之间的差异
- [ ] 使用"May I update"语言（不是"May I write"）
- [ ] 保留现有规格内容；仅应用差异
- [ ] 裁决结果为 COMPLETE

---

### 用例 4：请求多个资源 (Multiple Assets Requested) —— 每个资源单独 May-I-Write

**测试夹具：**
- GDD 和艺术圣经存在
- 用户请求 3 个资源的规格：goblin-enemy、orc-enemy、treasure-chest

**输入：** `/asset-spec goblin-enemy orc-enemy treasure-chest`

**预期行为：**
1. 技能按顺序生成所有 3 个规格
2. 对于每个资源，技能显示草稿并单独询问"是否可以写入 `assets/specs/[name]-spec.md`？"
3. 用户可以批准全部 3 个或跳过个别资源
4. 所有已批准的规格均写入；裁决结果为 COMPLETE

**断言：**
- [ ] "May I write"被询问 3 次（每个资源一次），而不是一次性完成
- [ ] 用户可以拒绝一个资源而不阻塞其他资源
- [ ] 所有 3 个已批准资源的规格文件均已写入
- [ ] 当所有已批准的规格写入后，裁决结果为 COMPLETE

---

### 用例 5：总监关卡检查 (Director Gate Check) —— 无关卡；asset-spec 是设计工具

**测试夹具：**
- GDD 和艺术圣经存在

**输入：** `/asset-spec goblin-enemy`

**预期行为：**
1. 技能生成并写入资源规格
2. 未生成任何总监代理
3. 输出中不出现关卡 ID

**断言：**
- [ ] 未调用任何总监关卡
- [ ] 未出现关卡跳过消息
- [ ] 无需任何关卡检查，裁决结果为 COMPLETE

---

## 协议合规性 (Protocol Compliance)

- [ ] 在生成规格之前读取 GDD、艺术圣经和设计系统
- [ ] 包含所有 6 个规格组件（尺寸、动画、调色板、风格、技术、检查清单）
- [ ] 使用 DEPENDENCY GAP 注释标记缺失的依赖（艺术圣经、GDD）
- [ ] 每个资源询问"May I write"（或"May I update"）
- [ ] 处理多个资源时分别进行写入确认
- [ ] 当所有已批准的规格写入后，裁决结果为 COMPLETE

---

## 覆盖说明 (Coverage Notes)

- 音频资源规格（音效、音乐）遵循相同的结构，但使用不同的字段（时长、采样率、循环），未单独测试。
- UI 资源规格（图标、按钮状态）遵循相同的流程，其交互状态要求与 UX 规格对齐。
- GDD 也缺失的情况（GDD 和艺术圣经均不存在）未单独测试；规格将生成，同时标记两个依赖缺口。
