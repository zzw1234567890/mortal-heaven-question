
# 钩子：pre-commit-code-quality

## 触发器

在每次会修改 `src/` 中文件的提交之前运行。

## 目的

在代码进入版本控制之前强制执行编码标准。捕获样式违规、缺少文档、过于复杂的方法，以及本应为数据驱动的硬编码值。

## 实现

```bash
#!/bin/bash
# 预提交钩子：代码质量检查
# 根据你的语言和工具适配具体的检查项

CODE_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep -E '^src/')

EXIT_CODE=0

if [ -n "$CODE_FILES" ]; then
    for file in $CODE_FILES; do
        # 检查游戏玩法代码中的硬编码魔法数字
        if [[ "$file" == src/gameplay/* ]]; then
            # 查找可能是平衡性数值的数字字面量
            # 根据你的语言调整正则表达式模式
            if grep -nE '(damage|health|speed|rate|chance|cost|duration)[[:space:]]*[:=][[:space:]]*[0-9]+' "$file"; then
                echo "警告：$file 可能包含硬编码的游戏玩法数值。请使用数据文件。"
                # 仅警告，不阻塞
            fi
        fi

        # 检查没有指定负责人的 TODO/FIXME
        if grep -nE '(TODO|FIXME|HACK)[^(]' "$file"; then
            echo "警告：$file 包含没有负责人标签的 TODO/FIXME。请使用 TODO(名字) 格式。"
        fi

        # 运行特定语言的 linter（取消注释相应的行）
        # 对于 GDScript：gdlint "$file" || EXIT_CODE=1
        # 对于 C#：dotnet format --check "$file" || EXIT_CODE=1
        # 对于 C++：clang-format --dry-run -Werror "$file" || EXIT_CODE=1
    done

    # 对修改过的系统运行单元测试
    # 取消注释并根据你的测试框架适配
    # python -m pytest tests/unit/ -x --quiet || EXIT_CODE=1
fi

exit $EXIT_CODE
```

## 代理集成

当此钩子失败时：
1. 样式违规：使用格式化工具自动修复，或调用 `lead-programmer`
2. 硬编码值：调用 `gameplay-programmer` 将这些值外部化
3. 测试失败：调用 `qa-tester` 进行诊断，并调用 `gameplay-programmer` 进行修复
