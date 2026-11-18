# EmberUI Core (`EmberUI` v1.1.0)

独立、零 GC、支持主题切换与插槽扩展的 Project Zomboid B42 UI 框架底座，供 `EmberRoutesV2` 及其他 B42 模组复用。

## 目录结构

```text
EmberUI/
├── build.ps1                                 # 一键构建、i18n校验、Kahlua双模式编译、单测、OpenGL画廊与打包
├── Contents/mods/EmberUI/42/
│   ├── mod.info                              # Mod ID: EmberUI, modversion=1.1.0, versionMin=42.21.0
│   └── media/
│       ├── lua/shared/Translate/{CN,EN}/IG_UI.json
│       ├── lua/client/EmberUI.lua            # 顶层门面
│       ├── lua/client/EmberUI/Core/          # Chrome, Clock, Failsafe, FocusManager, Layout*, PageLifecycle, Runtime, SpringDriver, State, Text, Theme, TooltipManager, UICache, Viewport
│       ├── lua/client/EmberUI/Shell/         # UI (DSL), SlotRegistry
│       └── lua/client/EmberUI/Widgets/       # WindowHost, ModalDialog, ToastManager, HoverCard, ChoiceMenu, CardPanel, SplitView, TabBar, FilterChips, Field, SearchInput, StepperInput, Dropdown, ToggleSwitch, CachedList, OrderList, BulkBar, PickSet, ListFilter, FormValidator, ScrollContainer, ScrollView, StatMeter, RadialDial, SemanticBadge, StatusVisual, InlineAlert, InlineCardDrawer, EmptyState, SkeletonView, Avatar3DView
│       └── ui/EmberUI/{CHROME,ICON}/         # 9-slice 贴图与 32x32 抗锯齿矢量图标
├── tests/
│   ├── java/{KahluaCompileTest,KahluaEmberUITest}.java
│   └── lua/emberui-core-test.lua
└── tools/
    ├── check_i18n.py
    ├── preview-ui.ps1
    └── ui-preview/{PreviewFrame,PreviewGallery}.java
```

## 核心架构特性（v1.1.0）

1. **B42 原生输入与浮层契约**：
   - `ToastManager` 采用紧致包围盒 + 无弹幕自动从 `UIManager` 卸载（`isPointOver/isMouseOver` 恒返 `false`），不吞噬游戏鼠标悬停与右键瞄准。
   - `WindowHost` / `ModalDialog` / `ChoiceMenu` 启用 `setWantKeyEvents(true)` 并实现 `isKeyConsumed(key)` + `GameKeyboard.eatKeyPress(key)`，防止按 `ESC` 时穿透触发原版暂停菜单。
   - `FocusManager` 提供 `Tab / Shift+Tab` 焦点环、`bindTextEntry`（输入框按 `ESC` 脱焦不穿透）、`unfocusTree`（关窗自动清理 `Core.currentTextEntryBox`）及 LIFO `ShortcutScope`。
2. **零帧延迟布局与会话闭环**：
   - `LayoutHost:prerender()` 在 `UIElement.render()` 遍历子控件前前置冲洗脏布局，消除 B42 `100ms` `UIManager.doTick` 闪烁并在游戏暂停态即时生效。
   - `Runtime` 统一托管 `OnMainMenuEnter`（LIFO 强制关窗、释放悬浮层/焦点/缓存、保留静态槽位并清除会话能力）与 `OnResolutionChange`（窗口夹紧与模态框重居中）。
   - `PageLifecycle.attachExternalScope(page, ctxScope)` 支持与 `EmberRoutesV2` Cordis 微内核 `ctx:scope(label)` 双向绑定销毁。
3. **Zero-GC 热路径**：
   - `Theme.applyPreset` / `Theme.customize` 就地修改色值表，持色引用零分配实时响应换肤。
   - `Text.truncate` 缓存裁剪结果；`Viewport.draw` 支持静态回调参数；`CachedList.reconcile` 在非结构性更新时零表分配原地刷新。

## 构建与验收

```powershell
# 全量校验（隔离审计 + i18n + Kahlua Debug/Release 双编译 + 97 项单测 + OpenGL 全组件视觉画廊 + 打包）
powershell -ExecutionPolicy Bypass -File .\build.ps1

# 仅生成 OpenGL 视觉画廊截图（输出至 build/ui-preview/gallery-*.png）
powershell -ExecutionPolicy Bypass -File .\tools\preview-ui.ps1
```
