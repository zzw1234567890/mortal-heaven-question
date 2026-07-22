---
paths:
  - "assets/shaders/**"
---


# 着色器代码标准 (Shader Code Standards)

`assets/shaders/` 中的所有着色器文件必须遵循以下标准，以保持视觉质量、性能和跨平台兼容性。

## 命名约定
- 文件命名：`[type]_[category]_[name].[ext]`
  - `spatial_env_water.gdshader` (Godot)
  - `SG_Env_Water` (Unity Shader Graph)
  - `M_Env_Water` (Unreal Material)
- 使用指示材质用途的描述性名称
- 使用着色器类型前缀：`spatial_`、`canvas_`、`particles_`、`post_`

## 代码质量
- 所有 uniforms/参数必须有描述性名称和适当的提示
- 对相关参数进行分组（Godot：`group_uniforms`，Unity：`[Header]`，Unreal：Category）
- 对非显而易见的计算添加注释（尤其是数学密集部分）
- 不使用魔数 —— 使用命名常量或文档化的 uniform 值
- 在每个着色器文件顶部包含作者和用途注释

## 性能要求
- 为每个着色器记录目标平台和复杂度预算
- 在不需要完全精度的移动端使用适当的精度：`half`/`mediump`
- 尽量减少片元着色器中的纹理采样
- 避免片元着色器中的动态分支 —— 使用 `step()`、`mix()`、`smoothstep()`
- 循环内不得进行纹理读取
- 模糊效果使用两遍方法（先水平后垂直）

## 跨平台
- 在最低规格目标硬件上测试着色器
- 为较低质量等级提供回退/简化版本
- 记录着色器目标使用的渲染管线（Forward/Deferred、URP/HDRP、Forward+/Mobile/Compatibility）
- 不在同一目录中混合来自不同渲染管线的着色器

## 变体管理
- 尽量减少着色器变体 —— 每个变体都是一个单独编译的着色器
- 记录所有关键字/变体及其用途
- 尽可能使用功能剥离以减少构建大小
- 记录并监控每个着色器的总变体数量
