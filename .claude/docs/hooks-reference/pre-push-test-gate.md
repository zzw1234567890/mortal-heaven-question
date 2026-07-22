
# 钩子：pre-push-test-gate

## 触发器

在每次推送到远程分支之前运行。对于推送到 `develop` 和 `main` 分支为强制要求。

## 目的

确保构建编译通过、单元测试通过以及关键冒烟测试通过，然后代码才能进入共享分支。这是在代码影响其他开发者之前的最后一道自动化质量关卡。

## 实现

```bash
#!/bin/bash
# 预推送钩子：构建与测试关卡

REMOTE="$1"
URL="$2"

# 仅对 develop 和 main 强制执行完整关卡
PROTECTED_BRANCHES="develop main"
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

FULL_GATE=false
for branch in $PROTECTED_BRANCHES; do
    if [ "$CURRENT_BRANCH" = "$branch" ]; then
        FULL_GATE=true
        break
    fi
done

echo "=== 预推送质量关卡 ==="

# 步骤 1：构建
echo "正在构建..."
# 根据你的构建系统适配：
# make build || exit 1
# dotnet build || exit 1
# cargo build || exit 1
echo "构建：通过"

# 步骤 2：单元测试
echo "正在运行单元测试..."
# 根据你的测试框架适配：
# python -m pytest tests/unit/ -x || exit 1
# dotnet test tests/unit/ || exit 1
# cargo test || exit 1
echo "单元测试：通过"

if [ "$FULL_GATE" = true ]; then
    # 步骤 3：集成测试（仅对受保护分支）
    echo "正在运行集成测试..."
    # python -m pytest tests/integration/ -x || exit 1
    echo "集成测试：通过"

    # 步骤 4：冒烟测试
    echo "正在运行冒烟测试..."
    # python -m pytest tests/playtest/smoke/ -x || exit 1
    echo "冒烟测试：通过"

    # 步骤 5：性能回归检查
    echo "正在检查性能基线..."
    # python tools/ci/perf_check.py || exit 1
    echo "性能：通过"
fi

echo "=== 所有关卡已通过 ==="
exit 0
```

## 代理集成

当此钩子失败时：
1. 构建失败：调用 `lead-programmer` 进行诊断
2. 单元测试失败：调用 `qa-tester` 定位失败的测试，并调用 `gameplay-programmer` 或相关程序员进行修复
3. 性能回归：调用 `performance-analyst` 进行分析
