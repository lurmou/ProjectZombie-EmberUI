# EmberUI v1.1.0 开发使用说明书

> 适用范围：Project Zomboid B42 所有依赖 `EmberUI` 的业务模组（如 `EmberRoutesV2`）。
> 源码入口：[EmberUI.lua](../Contents/mods/EmberUI/42/media/lua/client/EmberUI.lua) ｜ 布局 DSL：[UI.lua](../Contents/mods/EmberUI/42/media/lua/client/EmberUI/Shell/UI.lua)

---

## 1. 模组接入与依赖声明

1. **在业务模组 `42/mod.info` 中声明前置依赖**：
   ```ini
   require=\ZombieBuddy,\EmberUI
   ```
2. **Lua 端引入门面**（禁止 `require` 内部未公开的私有实现细节）：
   ```lua
   local EmberUI = require "EmberUI"
   local UI = EmberUI.UI
   local Theme = EmberUI.Theme
   ```
3. **可选主题预设**：`Theme.applyPreset("ae2")` / `"github"` / `"classic"`（支持运行期就地切换，0 分配刷新所有控件持色引用）。

---

## 2. 窗口外壳（`WindowHost`）与生命周期闭环

不要裸继承 `ISCollapsableWindow`，直接使用 `EmberUI.WindowHost`，自动获得圆角阴影、主题标题栏截断、分辨率夹紧、`OnMainMenuEnter` 自动回收与 **`ESC` 键防穿透**（`isKeyConsumed` + `eatKeyPress`）。

```lua
local win = EmberUI.WindowHost:new(x, y, width, height, {
    title = getText("IGUI_ER_PanelTitle"),
    resizable = false,
    closeOnEscape = true,
    scope = optionalCordisScope, -- 可选：直接双向绑定 Cordis ctx:scope(...)
    onClose = function(self)
        -- 关窗对称清理回调（释放外部开关如 disableWorldMenu 等）
    end,
    hostProps = { direction = "column", padding = 12, gap = 8 },
})
win:initialise()
win:instantiate()
win:addToUIManager()

-- 通过 WindowHost:setContentSpec 装配声明式布局树（自动接入 Failsafe 与激活作用域）
win:setContentSpec(UI.Column({ padding = 12, gap = 8 }, { ... }))
```

### 双向作用域绑定（`PageLifecycle.attachExternalScope`）
若业务侧使用 Cordis 微内核 `ctx:scope(label)`：
- 传入 `WindowHost` 的 `opts.scope` 或调用 `win:attachScope(extScope)`；
- 玩家点击关闭或按 `ESC` 关窗时，自动调用 `extScope:dispose()`；
- 退回主菜单触发 `extScope:dispose()` 时，自动关闭窗口，无重入死循环。

---

## 3. 声明式布局 DSL（`EmberUI.UI`）

所有控件均由 `UI.*` 工厂创建，**禁止手动硬算 `x / y` 绝对坐标**。

### 3.1 容器与排版原语
| API | 职责 | 常用参数 (`props`) |
| :--- | :--- | :--- |
| `UI.Column(props, children)` | 纵向弹性容器 | `{ padding = 12, gap = 8, align = "stretch" }` |
| `UI.Row(props, children)` | 横向弹性容器 | `{ padding = 0, gap = 6, align = "center" }` |
| `UI.Item(child, props)` | 为子控件/子容器附加弹性约束 | `{ basis = 24, grow = 0 }` 或 `{ grow = 1 }` |
| `UI.Spacer(grow)` | 纯几何弹性空白占位（无原生控件） | `grow` 默认 `1` |
| `UI.FormRow(label, control, action, opts)` | 标准表单行（标签 + 控件 + 可选按钮） | `{ labelWidth = 120, actionWidth = 64, height = 24, gap = 8 }` |
| `UI.CardPanel(opts, childrenSpec)` | 带标题/徽章的分组卡片 | `{ title = "...", badge = "...", collapsible = false }` |

### 3.2 常用业务控件
| 控件 | 签名 | 关键方法 / 说明 |
| :--- | :--- | :--- |
| **文本标签** | `UI.Label(text, opts)` | `{ w, h, font, color, muted, align = "left"\|"center"\|"right", wrap, maxLines, truncate = true }`；动态更新调 `lbl:setText(str)` / `lbl:setColor(col)`（同文本跳过重测） |
| **按钮** | `UI.Button(title, target, fn, opts)` | `{ w, h = 24, primary = true, active = false, theme = true }`；启用/禁用调 `btn:setEnable(bool)` |
| **输入框** | `UI.TextInput(value, target, onChange, opts)` | `{ w, h = 24, placeholder, onlyNumbers, maxLength, focusGroup }`；内置圆角主题与 `ESC` 脱焦不穿透 |
| **搜索框** | `UI.SearchInput(placeholder, target, onChange, opts)` | `{ w, h = 24, text }` |
| **下拉框** | `UI.Dropdown(target, onChange, opts)` | `{ w, h = 24, options = {{ id, label }}, selected }` |
| **步进器** | `UI.Stepper(init, min, max, steps, onChange, opts)` | 数值微调（如高低库存阈值） |
| **进度/负载条** | `UI.StatMeter(fraction, opts)` | `{ w, h = 16, tone }`；动态更新数值不新建表 |
| **语义徽章** | `UI.Badge(statusOrLabel, opts)` | `badge:setBadge(statusKey, customLabel)` |
| **提示横幅** | `UI.Alert(msg, kind, opts)` | `kind`: `"info"\|"success"\|"warning"\|"danger"`；`alert:setAlert(msg, kind, title)` |
| **高阶列表** | `UI.List(opts)` | `{ w, h, owner, itemheight, style, emptyState, well = true }` |

---

## 4. `CachedList` 零 GC 列表更新（关键规范）

常规列表刷新**严禁每次 `list:clear()` 后全量重建**，统一使用 `CachedList.reconcile`：

```lua
local CachedList = require "EmberUI/Widgets/CachedList"

-- 仅当 cacheRevision 变化或结构增删时按 stableKey 原地修补条目
CachedList.reconcile(
    list,
    rows,
    function(row) return row.leftText .. "  " .. row.rightText end, -- caption(row)
    function(row) return row.key end,                                -- stableKey(row)
    true,                                                            -- preserveAnchor
    snapshotRevision                                                 -- cacheRevision
)
```

若需要左右分栏自定义绘制（如左侧 `[分类] 物品名` + 右侧彩色数量），可传入 `opts.style = { prepare = function(list, row, label) ... end, draw = function(list, y, entry) ... end }`。

---

## 5. 开发红线与常见避坑

1. **禁止在 `prerender / render` 建表或改布局树**：所有文本格式化与列表 `reconcile` 放在 `projectIfDirty()`（脏检查早退）中；`LayoutHost:prerender()` 会在需要时自动前置冲洗脏几何，暂停态（`Space`）下亦即时生效。
2. **全局世界交互窗口**：若窗口打开期间需要屏蔽世界右键菜单（如 `ZoneEditorPanel` 拖框划区），请在 `onClose` 中对称恢复（或交给 Cordis `ctx:acquireGlobalFlag`）。
3. **双语与脱机预览**：所有用户可见字符串必须走 `Translate/{CN,EN}` 并通过 `check_i18n.py`；修改界面布局后必须跑脱机 OpenGL 截图核验 CN / EN 无压字与裁剪溢出。
5. **均分横向按钮务必写 `basis = 0, grow = 1`**：`UI.Button` 默认宽 `100`，若 `UI.Row` 内多枚按钮只写 `{ grow = 1 }` 而未置 `basis = 0`，窄窗口会因 `4 * 100 > 可用宽` 触发 `INSUFFICIENT_SPACE` 排版失败。
