---
name: test-helpers
description: "为项目测试套件生成特定于引擎的测试辅助库。读取现有测试模式，生成 tests/helpers/ 目录，内含针对项目系统定制的断言工具、工厂函数和模拟对象。减少新测试文件中的样板代码。"
argument-hint: "[system-name | all | scaffold]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Write

---

# 测试辅助工具 (Test Helpers)


当常见的 setup、teardown 和断言模式被抽象到辅助工具中时，编写测试用例会更快且更一致。本技能生成一个针对项目实际引擎、语言和系统定制的 `tests/helpers/` 库 —— 让每位开发者编写更少的样板代码，编写更多的断言。

**输出：** `tests/helpers/` 目录，包含引擎特定的辅助文件

**运行时机：**
- 在 `/test-setup` 搭建测试框架之后（首次）
- 当多个测试文件重复相同的 setup 样板代码时
- 当开始为新系统编写测试时

---

## 1. 解析参数 (Parse Arguments)

**模式：**
- `/test-helpers [system-name]` — 为特定系统生成辅助工具（例如 `/test-helpers combat`）
- `/test-helpers all` — 为所有包含测试文件的系统生成辅助工具
- `/test-helpers scaffold` — 仅生成基础辅助工具库（不包含系统特定的辅助工具）；首次运行时使用此模式
- 无参数 — 如果尚不存在辅助工具则运行 `scaffold`，否则运行 `all`

---

## 2. 检测引擎和语言 (Detect Engine and Language)

读取 `.claude/docs/technical-preferences.md` 并提取：
- `Engine:` 值
- `Language:` 值
- 测试部分中的 `Framework:` 值

如果引擎未配置："引擎未配置。请先运行 `/setup-engine`。"

---

## 3. 加载现有测试模式 (Load Existing Test Patterns)

扫描测试目录以查找已在使用的模式：

```
Glob pattern="tests/**/*_test.*" (all test files)
```

对于代表性样本（最多 5 个文件），读取测试文件并提取：
- Setup 模式（`before_each` / `setUp` / 测试夹具的编写方式）
- 常见断言模式（最常断言的内容）
- 对象创建模式（游戏对象或场景在测试中的实例化方式）
- 模拟/存根模式（依赖项的替换方式）

这确保生成的辅助工具匹配项目现有风格，而非通用模板。

同时读取：
- `design/gdd/systems-index.md` — 了解存在哪些系统
- 范围内的游戏设计文档 (GDD) — 了解需要测试的数据类型和值
- `docs/architecture/tr-registry.yaml` — 将需求映射到被测试的系统

---

## 4. 生成引擎特定的辅助工具 (Generate Engine-Specific Helpers)

### Godot 4 (GDUnit4 / GDScript)

**基础辅助工具** (`tests/helpers/game_assertions.gd`)：

```gdscript
## [项目名称] 测试的游戏特定断言工具。
## 使用领域特定辅助工具扩展 GdUnitAssertions。
##
## 用法：
##   var assert = GameAssertions.new()
##   assert.health_in_range(entity, 0, entity.max_health)

class_name GameAssertions
extends RefCounted

## 断言一个值在包含范围内 [min_val, max_val]。
## 用于游戏设计文档中定义了边界的任何公式输出。
static func assert_in_range(
    value: float,
    min_val: float,
    max_val: float,
    label: String = "value"
) -> void:
    assert(
        value >= min_val and value <= max_val,
        "%s %.2f is outside expected range [%.2f, %.2f]" % [label, value, min_val, max_val]
    )

## 断言在可调用块期间发出了一个信号。
## 用法：assert_signal_emitted(entity, "health_changed", func(): entity.take_damage(10))
static func assert_signal_emitted(
    obj: Object,
    signal_name: String,
    action: Callable
) -> void:
    var emitted := false
    obj.connect(signal_name, func(_args): emitted = true)
    action.call()
    assert(emitted, "Expected signal '%s' to be emitted, but it was not." % signal_name)

## 断言一个可调用块没有发出信号。
static func assert_signal_not_emitted(
    obj: Object,
    signal_name: String,
    action: Callable
) -> void:
    var emitted := false
    obj.connect(signal_name, func(_args): emitted = true)
    action.call()
    assert(not emitted, "Expected signal '%s' NOT to be emitted, but it was." % signal_name)

## 断言一个节点在父节点内的路径处存在。
static func assert_node_exists(parent: Node, path: NodePath) -> void:
    assert(
        parent.has_node(path),
        "Expected node at path '%s' to exist." % str(path)
    )
```

**工厂辅助工具** (`tests/helpers/game_factory.gd`)：

```gdscript
## 创建测试游戏对象的工厂函数。
## 返回配置为单元测试的最小对象（无需场景树）。
##
## 用法：var player = GameFactory.make_player(health: 100)

class_name GameFactory
extends RefCounted

## 创建一个用于测试的最小类玩家对象。
## 根据需要覆盖字段。
static func make_player(health: int = 100) -> Node:
    var player = Node.new()
    player.set_meta("health", health)
    player.set_meta("max_health", health)
    return player
```

**场景辅助工具** (`tests/helpers/scene_runner_helper.gd`)：

```gdscript
## 基于场景的集成测试工具。
## 封装 GdUnitSceneRunner 以用于常见模式。

class_name SceneRunnerHelper
extends GdUnitTestSuite

## 加载一个场景并等待一帧以完成 _ready()。
func load_scene_and_wait(scene_path: String) -> Node:
    var scene = load(scene_path).instantiate()
    add_child(scene)
    await get_tree().process_frame
    return scene
```

---

### Unity (NUnit / C#)

**基础辅助工具** (`tests/helpers/GameAssertions.cs`)：

```csharp
using NUnit.Framework;
using UnityEngine;

/// <summary>
/// [项目名称] 测试的游戏特定断言工具。
/// 使用领域特定辅助工具扩展 NUnit 的 Assert。
/// </summary>
public static class GameAssertions
{
    /// <summary>
    /// 断言一个值在包含范围内 [min, max]。
    /// 用于游戏设计文档公式部分中定义的任何公式输出。
    /// </summary>
    public static void AssertInRange(float value, float min, float max, string label = "value")
    {
        Assert.That(value, Is.InRange(min, max),
            $"{label} ({value:F2}) is outside expected range [{min:F2}, {max:F2}]");
    }

    /// <summary>断言在一个操作期间引发了 UnityEvent 或 C# 事件。</summary>
    public static void AssertEventRaised(ref bool wasCalled, System.Action action, string eventName)
    {
        wasCalled = false;
        action();
        Assert.IsTrue(wasCalled, $"Expected event '{eventName}' to be raised, but it was not.");
    }

    /// <summary>断言一个组件存在于 GameObject 上。</summary>
    public static void AssertHasComponent<T>(GameObject obj) where T : Component
    {
        var component = obj.GetComponent<T>();
        Assert.IsNotNull(component,
            $"Expected GameObject '{obj.name}' to have component {typeof(T).Name}.");
    }
}
```

**工厂辅助工具** (`tests/helpers/GameFactory.cs`)：

```csharp
using UnityEngine;

/// <summary>
/// 创建最小测试对象的工厂方法，无需加载场景。
/// </summary>
public static class GameFactory
{
    /// <summary>创建一个最小的 GameObject，带有所需名称，用于测试。</summary>
    public static GameObject MakeGameObject(string name = "TestObject")
    {
        var go = new GameObject(name);
        return go;
    }

    /// <summary>
    /// 创建一个类型为 T 的 ScriptableObject，用于数据驱动测试。
    /// 测试后使用 Object.DestroyImmediate 释放。
    /// </summary>
    public static T MakeScriptableObject<T>() where T : ScriptableObject
    {
        return ScriptableObject.CreateInstance<T>();
    }
}
```

---

### Unreal Engine (C++)

**基础辅助工具** (`tests/helpers/GameTestHelpers.h`)：

```cpp
#pragma once

#include "CoreMinimal.h"
#include "Misc/AutomationTest.h"

/**
 * [项目名称] 自动化测试的游戏特定断言宏和辅助工具。
 * 在需要领域特定断言的任何测试文件中包含。
 *
 * 用法：
 *   GAME_TEST_ASSERT_IN_RANGE(TestName, DamageValue, 10.0f, 50.0f, TEXT("Damage"));
 */

// 断言浮点值在包含范围 [Min, Max] 内
#define GAME_TEST_ASSERT_IN_RANGE(TestName, Value, Min, Max, Label) \
    TestTrue( \
        FString::Printf(TEXT("%s (%.2f) in range [%.2f, %.2f]"), Label, Value, Min, Max), \
        (Value) >= (Min) && (Value) <= (Max) \
    )

// 断言 UObject 指针有效（非空，未被垃圾回收）
#define GAME_TEST_ASSERT_VALID(TestName, Ptr, Label) \
    TestTrue( \
        FString::Printf(TEXT("%s is valid"), Label), \
        IsValid(Ptr) \
    )

// 断言一个 Actor 存在于世界中（成功生成）
#define GAME_TEST_ASSERT_SPAWNED(TestName, ActorPtr, ClassName) \
    TestNotNull( \
        FString::Printf(TEXT("Spawned actor of class %s"), TEXT(#ClassName)), \
        ActorPtr \
    )

/**
 * 创建最小测试世界的辅助工具。
 * 记得在 teardown 中调用 World->DestroyWorld(false)。
 */
namespace GameTestHelpers
{
    inline UWorld* CreateTestWorld(const FString& WorldName = TEXT("TestWorld"))
    {
        UWorld* World = UWorld::CreateWorld(EWorldType::Game, false);
        FWorldContext& WorldContext = GEngine->CreateNewWorldContext(EWorldType::Game);
        WorldContext.SetCurrentWorld(World);
        return World;
    }
}
```

---

## 5. 生成系统特定的辅助工具 (Generate System-Specific Helpers)

对于 `[system-name]` 或 `all` 模式，为每个系统生成一个辅助工具：

读取系统的游戏设计文档 (GDD) 以提取：
- 数据类型（实体类型、组件名称）
- 公式变量及其边界
- 边缘情况中提到的常见测试场景

生成 `tests/helpers/[system]_factory.[ext]`，包含该特定系统对象的工厂函数。

以 `combat` 系统（Godot/GDScript）为例的模式：

```gdscript
## 战斗 (Combat) 系统测试的工厂和断言辅助工具。
## 由 `/test-helpers combat` 在 [date] 生成。
## 基于：design/gdd/combat.md

class_name CombatTestFactory
extends RefCounted

const DAMAGE_MIN := 0
const DAMAGE_MAX := 999  # 来自游戏设计文档：伤害公式上限

## 为伤害公式测试创建最小攻击者对象。
static func make_attacker(attack: float = 10.0, crit_chance: float = 0.0) -> Node:
    var attacker = Node.new()
    attacker.set_meta("attack", attack)
    attacker.set_meta("crit_chance", crit_chance)
    return attacker

## 为伤害接收测试创建最小目标对象。
static func make_target(defense: float = 0.0, health: float = 100.0) -> Node:
    var target = Node.new()
    target.set_meta("defense", defense)
    target.set_meta("health", health)
    target.set_meta("max_health", health)
    return target

## 断言伤害输出在游戏设计文档指定的范围内。
static func assert_damage_in_bounds(damage: float) -> void:
    GameAssertions.assert_in_range(damage, DAMAGE_MIN, DAMAGE_MAX, "damage")
```

---

## 6. 写入输出 (Write Output)

呈现将要创建的内容的总结：

```
## 要创建的测试辅助工具 (Test Helpers to Create)

基础辅助工具 (引擎: [engine]):
- tests/helpers/game_assertions.[ext]
- tests/helpers/game_factory.[ext]
[引擎特定的额外内容]

系统辅助工具 ([mode]):
- tests/helpers/[system]_factory.[ext]  ← 来自 [system] 游戏设计文档
```

询问："我可以将这些辅助文件写入 `tests/helpers/` 吗？"

**绝不要覆盖现有文件。** 如果文件已存在，报告：
"跳过 `[path]` —— 已存在。如果您希望重新生成，请手动删除该文件。"

写入后：裁定：**完成 (COMPLETE)** —— 辅助文件已创建。

"辅助文件已创建。在测试中使用它们：
- Godot：`class_name` 会自动导入 —— 无需显式导入
- Unity：添加 `using` 指令或引用测试程序集
- Unreal：`#include \"tests/helpers/GameTestHelpers.h\"`"

---

## 协作协议 (Collaborative Protocol)

- **绝不要覆盖现有的辅助工具** —— 它们可能包含手写自定义内容。仅生成尚不存在的新文件
- **生成的代码是起点** —— 生成的工厂函数为简单起见使用元数据模式；代码存在后应适配实际的类结构
- **辅助工具应反映游戏设计文档** —— 辅助工具中的边界和常量应追溯到游戏设计文档的公式部分，而非臆造的值
- **写入前询问** —— 始终在创建 `tests/` 中的文件前确认

## 后续步骤 (Next Steps)

- 如果测试框架尚未搭建，运行 `/test-setup`。
- 使用 `/dev-story` 实现故事 —— 辅助工具可减少新测试文件中的样板代码。
- 运行 `/skill-test` 以验证可能需要辅助工具覆盖的其他技能。
