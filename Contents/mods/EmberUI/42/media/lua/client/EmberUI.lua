--[[
    EmberUI.lua - Top-Level Public Facade for EmberUI Core Mod
    Usage:
      local EmberUI = require "EmberUI"
      local UI, Theme, State = EmberUI.UI, EmberUI.Theme, EmberUI.State
    Or direct fine-grained requires:
      local TabBar = require "EmberUI/Widgets/TabBar"
]]

local Core = {
    Clock = require "EmberUI/Core/Clock",
    Theme = require "EmberUI/Core/Theme",
    Chrome = require "EmberUI/Core/Chrome",
    State = require "EmberUI/Core/State",
    PageLifecycle = require "EmberUI/Core/PageLifecycle",
    FocusManager = require "EmberUI/Core/FocusManager",
    Failsafe = require "EmberUI/Core/Failsafe",
    Runtime = require "EmberUI/Core/Runtime",
    UICache = require "EmberUI/Core/UICache",
    Text = require "EmberUI/Core/Text",
    Viewport = require "EmberUI/Core/Viewport",
    SpringDriver = require "EmberUI/Core/SpringDriver",
    TooltipManager = require "EmberUI/Core/TooltipManager",
    LayoutNode = require "EmberUI/Core/LayoutNode",
    LayoutSolver = require "EmberUI/Core/LayoutSolver",
    Layout = require "EmberUI/Core/Layout",
    LayoutHost = require "EmberUI/Core/LayoutHost",
}

local Widgets = {
    StatusVisual = require "EmberUI/Widgets/StatusVisual",
    SemanticBadge = require "EmberUI/Widgets/SemanticBadge",
    WindowHost = require "EmberUI/Widgets/WindowHost",
    CardPanel = require "EmberUI/Widgets/CardPanel",
    TabBar = require "EmberUI/Widgets/TabBar",
    ToggleSwitch = require "EmberUI/Widgets/ToggleSwitch",
    SplitView = require "EmberUI/Widgets/SplitView",
    BulkBar = require "EmberUI/Widgets/BulkBar",
    Field = require "EmberUI/Widgets/Field",
    FormValidator = require "EmberUI/Widgets/FormValidator",
    CachedList = require "EmberUI/Widgets/CachedList",
    ScrollContainer = require "EmberUI/Widgets/ScrollContainer",
    ScrollView = require "EmberUI/Widgets/ScrollView",
    HoverCard = require "EmberUI/Widgets/HoverCard",
    ChoiceMenu = require "EmberUI/Widgets/ChoiceMenu",
    OrderList = require "EmberUI/Widgets/OrderList",
    PickSet = require "EmberUI/Widgets/PickSet",
    ListFilter = require "EmberUI/Widgets/ListFilter",
    FilterChips = require "EmberUI/Widgets/FilterChips",
    StepperInput = require "EmberUI/Widgets/StepperInput",
    SearchInput = require "EmberUI/Widgets/SearchInput",
    Dropdown = require "EmberUI/Widgets/Dropdown",
    InlineAlert = require "EmberUI/Widgets/InlineAlert",
    ModalDialog = require "EmberUI/Widgets/ModalDialog",
    ToastManager = require "EmberUI/Widgets/ToastManager",
    StatMeter = require "EmberUI/Widgets/StatMeter",
    RadialDial = require "EmberUI/Widgets/RadialDial",
    SkeletonView = require "EmberUI/Widgets/SkeletonView",
    EmptyState = require "EmberUI/Widgets/EmptyState",
    Avatar3DView = require "EmberUI/Widgets/Avatar3DView",
    InlineCardDrawer = require "EmberUI/Widgets/InlineCardDrawer",
}

local Shell = {
    SlotRegistry = require "EmberUI/Shell/SlotRegistry",
    UI = require "EmberUI/Shell/UI",
}

local EmberUI = {
    VERSION = "1.1.0",
    Core = Core,
    Widgets = Widgets,
    Shell = Shell,
    -- Ergonomic top-level shortcuts
    UI = Shell.UI,
    SlotRegistry = Shell.SlotRegistry,
    Theme = Core.Theme,
    Chrome = Core.Chrome,
    State = Core.State,
    PageLifecycle = Core.PageLifecycle,
    FocusManager = Core.FocusManager,
    Failsafe = Core.Failsafe,
    Runtime = Core.Runtime,
    LayoutHost = Core.LayoutHost,
    WindowHost = Widgets.WindowHost,
    TabBar = Widgets.TabBar,
    ToggleSwitch = Widgets.ToggleSwitch,
    SplitView = Widgets.SplitView,
    BulkBar = Widgets.BulkBar,
    Field = Widgets.Field,
    PickSet = Widgets.PickSet,
    HoverCard = Widgets.HoverCard,
    ChoiceMenu = Widgets.ChoiceMenu,
    OrderList = Widgets.OrderList,
    SemanticBadge = Widgets.SemanticBadge,
    StatusVisual = Widgets.StatusVisual,
}

return EmberUI
