# 技能测试规格：/launch-checklist


## 技能概述 (Skill Summary)

`/launch-checklist` 生成并评估完整的发布就绪检查清单，涵盖：法律合规性（EULA、隐私政策、ESRB/PEGI 分级）、平台认证状态、商店页面完整性（截图、描述、元数据）、构建验证（版本标签、可复现构建）、分析和崩溃报告配置，以及首次运行体验验证。

该技能生成检查清单报告，在"May I write"询问后写入 `production/launch/launch-checklist-[date].md`。如果存在之前的发布检查清单，它会将新结果与旧结果进行对比，以突出显示新解决和新阻塞的项目。不设总监关卡 (director gates)——`/team-release` 负责编排完整的发布管线。裁决结果为：LAUNCH READY、LAUNCH BLOCKED 或 CONCERNS。

---

## 静态断言 (Structural)

由 `/skill-test static` 自动验证——无需测试夹具。

- [ ] 拥有必需的前置元字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 有 ≥2 个阶段标题
- [ ] 包含裁决关键词：LAUNCH READY、LAUNCH BLOCKED、CONCERNS
- [ ] 在编写检查清单前包含"May I write"协作协议语言
- [ ] 有下一步交接（例如，`/team-release` 或 `/day-one-patch`）

---

## 总监关卡检查 (Director Gate Checks)

无。`/launch-checklist` 是一个就绪度审计工具。完整的发布管线由 `/team-release` 管理。

---

## 测试用例 (Test Cases)

### 用例 1：正常路径 (Happy Path) —— 所有检查清单项已验证，状态为 LAUNCH READY

**测试夹具：**
- 法律文件存在：`production/legal/` 中的 EULA、隐私政策
- 平台认证：在生产说明中标记为已提交且已批准
- 商店页面资产：截图、描述、元数据均存在于 `production/store/` 中
- 构建：版本标签 `v1.0.0` 存在，可复现构建已确认
- 崩溃报告：已在 `technical-preferences.md` 中配置

**输入：** `/launch-checklist`

**预期行为：**
1. 技能检查所有检查清单类别
2. 所有项目通过验证检查
3. 技能生成检查清单报告，所有项目标记为 PASS
4. 技能询问"是否可以写入 `production/launch/launch-checklist-2026-04-06.md`？"
5. 批准后写入报告；裁决结果为 LAUNCH READY

**断言：**
- [ ] 检查了所有检查清单类别（法律、平台、商店、构建、分析、UX）
- [ ] 报告中的所有项目都带有 PASS 标记
- [ ] 裁决结果为 LAUNCH READY
- [ ] "May I write" 使用正确的带日期文件名询问

---

### 用例 2：平台认证未提交 (Platform Certification Not Submitted) —— LAUNCH BLOCKED

**测试夹具：**
- 所有其他检查清单项目通过
- 平台认证部分："未提交"（未找到提交记录）

**输入：** `/launch-checklist`

**预期行为：**
1. 技能检查所有项目
2. 平台认证检查失败：无提交记录
3. 技能报告："LAUNCH BLOCKED——平台认证未提交"
4. 明确指出缺少认证的具体平台
5. 裁决结果为 LAUNCH BLOCKED

**断言：**
- [ ] 裁决结果为 LAUNCH BLOCKED（而非 CONCERNS）
- [ ] 平台认证被识别为阻塞项
- [ ] 指定了缺失的平台名称
- [ ] 报告中仍然显示所有其他通过的项目

---

### 用例 3：需要手动检查 (Manual Check Required) —— CONCERNS 裁决

**测试夹具：**
- 所有关键检查清单项目通过
- 首次运行体验项目："需要手动检查——必须有人体验前 5 分钟并验证教程完成流程"
- 商店截图项目："需要手动检查——美术团队必须验证截图质量与当前构建匹配"

**输入：** `/launch-checklist`

**预期行为：**
1. 技能检查所有项目
2. 2 个项目被标记为需要人工验证
3. 技能报告："CONCERNS——2 个项目在发布前需要手动验证"
4. 列出两个项目，附有需要手动验证的内容说明
5. 裁决结果为 CONCERNS（非 LAUNCH BLOCKED，因为这些是建议性的）

**断言：**
- [ ] 裁决结果为 CONCERNS（非 LAUNCH READY 或 LAUNCH BLOCKED）
- [ ] 两个手动检查项目均列出，附带验证说明
- [ ] 技能不会因 MANUAL CHECK 项目而自动阻塞

---

### 用例 4：存在之前的检查清单 (Previous Checklist Exists) —— 对比差异

**测试夹具：**
- `production/launch/launch-checklist-2026-03-25.md` 存在，包含之前的结果：
  - 2 个项目曾被 BLOCKED（平台认证、崩溃报告）
  - 1 个项目有 MANUAL CHECK
- 新检查清单：平台认证现在为 PASS，崩溃报告现在为 PASS，手动检查仍开放；1 个新项目被标记（EULA 最后更新日期）

**输入：** `/launch-checklist`

**预期行为：**
1. 技能找到之前的检查清单并加载以进行比较
2. 技能生成新的检查清单并进行比较：
   - 新解决："平台认证——曾是 BLOCKED，现在为 PASS"
   - 新解决："崩溃报告——曾是 BLOCKED，现在为 PASS"
   - 仍然开放：手动检查（未改变）
   - 新问题：EULA 最后更新日期（不在之前的检查清单中）
3. 差异在报告中突出显示
4. 裁决结果为 CONCERNS（手动检查 + 新的 EULA 问题）

**断言：**
- [ ] 差异部分显示新解决的项目
- [ ] 差异部分显示新问题（之前的检查清单中不存在）
- [ ] 来自之前检查清单的仍然开放的项目被记录为持续存在
- [ ] 裁决反映当前状态（而非之前的状态）

---

### 用例 5：总监关卡检查 (Director Gate Check) —— 无关卡；launch-checklist 是审计工具

**测试夹具：**
- 所有检查清单依赖项存在

**输入：** `/launch-checklist`

**预期行为：**
1. 技能运行完整检查清单并写入报告
2. 未生成任何总监代理
3. 输出中不出现关卡 ID

**断言：**
- [ ] 未调用任何总监关卡
- [ ] 未出现关卡跳过消息
- [ ] 裁决结果为 LAUNCH READY、LAUNCH BLOCKED 或 CONCERNS——无关卡裁决

---

## 协议合规性 (Protocol Compliance)

- [ ] 检查所有必需的类别（法律、平台、商店、构建、分析、UX）
- [ ] 硬性失败时标记为 LAUNCH BLOCKED（未完成的认证、缺失的法律文件）
- [ ] 需要手动验证的建议性项目标记为 CONCERNS
- [ ] 当存在之前的检查清单时与之进行比较
- [ ] 在创建检查清单报告之前询问"May I write"
- [ ] 裁决结果为 LAUNCH READY、LAUNCH BLOCKED 或 CONCERNS

---

## 覆盖说明 (Coverage Notes)

- 地区特定合规性（GDPR 数据处理、针对 13 岁以下受众的 COPPA）会进行检查，但具体要求未在测试断言中列举。
- 商店页面完整性检查（截图、描述）依赖于 `production/store/` 中文件的存在性；无法验证视觉质量。
- 构建可复现性检查验证版本标签和构建配置的存在性，但不实际执行构建过程。
