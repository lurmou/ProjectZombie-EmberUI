import java.awt.image.BufferedImage;
import java.io.*;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.*;
import javax.imageio.ImageIO;
import org.json.JSONObject;
import org.lwjgl.opengl.GL11;
import org.lwjglx.opengl.Display;
import org.lwjglx.opengl.DisplayMode;
import org.lwjglx.opengl.PixelFormat;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.JavaFunction;
import se.krka.kahlua.vm.KahluaTable;
import zombie.DummySoundManager;
import zombie.GameWindow;
import zombie.Lua.LuaEventManager;
import zombie.Lua.LuaHookManager;
import zombie.Lua.LuaManager;
import zombie.SoundManager;
import zombie.ZomboidFileSystem;
import zombie.core.Core;
import zombie.core.Languages;
import zombie.core.SceneShaderStore;
import zombie.core.SpriteRenderer;
import zombie.core.Translator;
import zombie.core.VBO.GLVertexBufferObject;
import zombie.core.fonts.AngelCodeFont;
import zombie.core.opengl.RenderThread;
import zombie.core.random.RandLua;
import zombie.core.random.RandStandard;
import zombie.core.textures.Texture;
import zombie.core.textures.TextureAssetManager;
import zombie.core.textures.TextureID;
import zombie.core.textures.TextureIDAssetManager;
import zombie.ui.PreviewFrame;
import zombie.ui.TextManager;
import zombie.ui.UIManager;

/**
 * Offline native OpenGL (LWJGL) framebuffer visual gallery for EmberUI v1.1.0.
 * Renders all core widgets & overlays across CN/EN and the 3 built-in themes (github, ae2, classic).
 */
public final class PreviewGallery {
    private static final int WIDTH = 1280;
    private static final int HEIGHT = 760;

    public static void main(String[] args) {
        int code = 0;
        try {
            run(Path.of(args[0]).toAbsolutePath(), Path.of(args[1]).toAbsolutePath());
        } catch (Throwable t) {
            t.printStackTrace();
            code = 1;
        }
        System.exit(code);
    }

    private static void run(Path repo, Path outDir) throws Exception {
        Files.createDirectories(outDir);
        ZomboidFileSystem.instance.setCacheDir(outDir.resolve("cache").toString());
        try {
            Display.init();
            Display.setDisplayMode(new DisplayMode(WIDTH, HEIGHT));
            Display.create(new PixelFormat(32, 0, 24, 8, 0));

            ZomboidFileSystem.instance.init();
            Path modDir = repo.resolve("Contents/mods/EmberUI");
            ZomboidFileSystem.instance.setModIdToDir("EmberUI", modDir.toString());
            ZomboidFileSystem.instance.loadMod("EmberUI");

            TextureIDAssetManager.instance.create(TextureID.ASSET_TYPE, GameWindow.assetManagers);
            TextureAssetManager.instance.create(Texture.ASSET_TYPE, GameWindow.assetManagers);
            GameWindow.LoadTexturePack("UI", 2);
            GameWindow.LoadTexturePack("UI2", 2);
            GameWindow.setTexturePackLookup();

            GLVertexBufferObject.init();
            Core.getInstance().initGlobalShader();
            Display.makeCurrent();
            SpriteRenderer.instance.create();
            Core.getInstance().setScreenSize(WIDTH, HEIGHT);
            Languages.instance.init();
            RandStandard.INSTANCE.init();
            RandLua.INSTANCE.init();
            SoundManager.instance = new DummySoundManager();

            renderScene(repo, outDir, "CN", "github");
            renderScene(repo, outDir, "EN", "github");
            renderScene(repo, outDir, "CN", "ae2");
            renderScene(repo, outDir, "CN", "classic");
        } finally {
            if (Display.isCreated()) {
                try {
                    RenderThread.invokeOnRenderContext(() -> {
                        Set<AngelCodeFont> fonts = new HashSet<>();
                        Collections.addAll(fonts, TextManager.instance.enumToFont);
                        Collections.addAll(fonts, TextManager.instance.normal);
                        fonts.remove(null);
                        for (AngelCodeFont f : fonts) f.destroy();
                        TextureAssetManager.instance.destroy();
                        TextureIDAssetManager.instance.destroy();
                    });
                } finally {
                    Display.destroy();
                }
            }
        }
    }

    private static void waitForAssets() throws Exception {
        long deadline = System.nanoTime() + 20_000_000_000L;
        while (GameWindow.fileSystem.hasWork() || TextManager.instance.isAnyFontLoading()) {
            GameWindow.fileSystem.updateAsyncTransactions();
            Display.processMessages();
            if (System.nanoTime() > deadline) throw new IllegalStateException("Asset load timed out");
            Thread.sleep(10);
        }
    }

    private static void renderScene(Path repo, Path outDir, String lang, String themeId) throws Exception {
        Translator.setLanguage(Languages.instance.getByName(lang));
        TextManager.instance.Init();
        waitForAssets();

        UIManager.clearArrays();
        LuaEventManager.Reset();
        LuaHookManager.Reset();
        LuaManager.init();

        Path transFile = repo.resolve("Contents/mods/EmberUI/42/media/lua/shared/Translate/" + lang + "/IG_UI.json");
        JSONObject dict = new JSONObject(Files.readString(transFile, StandardCharsets.UTF_8));

        Object origGetText = LuaManager.env.rawget("getText");
        LuaManager.env.rawset("getText", (JavaFunction) (frame, count) -> {
            String key = String.valueOf(frame.get(0));
            if (dict.has(key)) {
                String v = dict.getString(key);
                for (int i = 1; i < count; i++) {
                    v = v.replace("%" + i, String.valueOf(frame.get(i)));
                }
                return frame.push(v);
            }
            Object[] a = new Object[count];
            for (int i = 0; i < count; i++) a[i] = frame.get(i);
            return frame.push(LuaManager.thread.call(origGetText, a));
        });
        LuaManager.env.rawset("getTextOrNull", (JavaFunction) (frame, count) -> {
            String key = String.valueOf(frame.get(0));
            if (dict.has(key)) {
                String v = dict.getString(key);
                for (int i = 1; i < count; i++) {
                    v = v.replace("%" + i, String.valueOf(frame.get(i)));
                }
                return frame.push(v);
            }
            return frame.push(null);
        });

        Map<String, Object> loaded = new HashMap<>();
        Path modLua = repo.resolve("Contents/mods/EmberUI/42/media/lua");
        LuaManager.env.rawset("require", (JavaFunction) (frame, count) -> {
            String mod = String.valueOf(frame.get(0));
            if (loaded.containsKey(mod)) return frame.push(loaded.get(mod));
            Path source = null;
            for (String side : List.of("shared", "client")) {
                Path base = (mod.equals("EmberUI") || mod.startsWith("EmberUI/")) ? modLua : Path.of("media/lua");
                Path sideDir = base.resolve(side);
                Path cand = sideDir.resolve(mod + ".lua").toAbsolutePath().normalize();
                if (Files.isRegularFile(cand)) { source = cand; break; }
                if (!(mod.equals("EmberUI") || mod.startsWith("EmberUI/")) && Files.isDirectory(sideDir)) {
                    try (var ds = Files.newDirectoryStream(sideDir)) {
                        for (Path sub : ds) {
                            if (Files.isDirectory(sub)) {
                                Path subCand = sub.resolve(mod + ".lua").toAbsolutePath().normalize();
                                if (Files.isRegularFile(subCand)) { source = subCand; break; }
                            }
                        }
                    } catch (IOException ignored) {}
                    if (source != null) break;
                }
            }
            if (source == null) throw new IllegalArgumentException("Missing Lua module: " + mod);
            try (Reader r = Files.newBufferedReader(source, StandardCharsets.UTF_8)) {
                Object[] res = LuaManager.thread.pcall(LuaCompiler.loadis(r, source.toString(), LuaManager.env), new Object[0]);
                if (!Boolean.TRUE.equals(res[0])) {
                    throw new IllegalStateException("Lua error in " + mod + ": " + (res.length > 1 ? res[1] : ""));
                }
                Object val = res.length > 1 ? res[1] : true;
                if (val == null) val = true;
                loaded.put(mod, val);
                return frame.push(val);
            } catch (IOException e) {
                throw new UncheckedIOException(e);
            }
        });

        pcallLua("ISInventoryPage = ISInventoryPage or {}; ISWorldObjectContextMenu = ISWorldObjectContextMenu or {}; "
                + "require 'env'; require 'TimedActions/ISBaseTimedAction'; require 'ISUI/Gamepad/JoyPadSetup'; "
                + "require 'ISUI/ISRichTextPanel'; require 'ISUI/ISToolTip'; require 'ISUI/ISTextEntryBox'");

        LuaManager.env.rawset("print", (JavaFunction) (frame, count) -> {
            StringBuilder sb = new StringBuilder();
            for (int i = 0; i < count; i++) {
                if (i > 0) sb.append('\t');
                sb.append(String.valueOf(frame.get(i)));
            }
            System.out.println(sb);
            return 0;
        });

        String sceneCode = buildSceneLua(lang, themeId);
        pcallLua(sceneCode);
        waitForAssets();

        // Pump 8 frames so NinePatchTextures async-finish loading and SpringDrivers settle cleanly
        for (int frame = 0; frame < 8; frame++) {
            Display.processMessages();
            GameWindow.fileSystem.updateAsyncTransactions();
            final int fIdx = frame;
            RenderThread.invokeOnRenderContext(() -> {
                GL11.glViewport(0, 0, WIDTH, HEIGHT);
                GL11.glClearColor(0.08f, 0.10f, 0.13f, 1f);
                GL11.glDisable(GL11.GL_SCISSOR_TEST);
                GL11.glDisable(GL11.GL_STENCIL_TEST);
                GL11.glClear(GL11.GL_COLOR_BUFFER_BIT | GL11.GL_STENCIL_BUFFER_BIT);
                GL11.glEnable(GL11.GL_BLEND);
                GL11.glBlendFunc(GL11.GL_SRC_ALPHA, GL11.GL_ONE_MINUS_SRC_ALPHA);

                SpriteRenderer r = SpriteRenderer.instance;
                r.prePopulating();
                PreviewFrame.resetStencilDepth();
                r.glDoStartFrame(WIDTH, HEIGHT, 1, -1);
                r.StartShader(SceneShaderStore.defaultShaderId, -1);

                PreviewFrame.flushPendingUI();
                for (var el : new ArrayList<>(UIManager.getUI())) {
                    if (el.isVisible()) {
                        el.update();
                        el.render();
                    }
                }

                r.glDoEndFrame();
                r.pushFrameDown();
                r.acquireStateForRendering(() -> false);
                r.postRender();

                if (fIdx == 7) {
                    capturePng(outDir.resolve("gallery-" + lang + "-" + themeId + ".png"));
                }
                Display.update();
            });
            Display.sync(30);
        }
    }

    private static String buildSceneLua(String lang, String themeId) {
        boolean cn = "CN".equals(lang);
        Map<String, String> tx = new LinkedHashMap<>();
        tx.put("winTitle", cn ? "EmberUI v1.1.0 组件画廊 (" + themeId + ")" : "EmberUI v1.1.0 Widget Gallery (" + themeId + ")");
        tx.put("tabA", cn ? "表单与输入" : "Forms");
        tx.put("tabB", cn ? "列表与状态" : "Lists");
        tx.put("tabC", cn ? "扩展槽位" : "Slots");
        tx.put("searchPh", cn ? "搜索物资、配方或居民..." : "Search items, recipes or NPCs...");
        tx.put("fieldName", cn ? "据点名称" : "Outpost");
        tx.put("fieldStock", cn ? "库存下限" : "Min Stock");
        tx.put("fieldAuto", cn ? "自动搬运" : "Auto Haul");
        tx.put("fieldErr", cn ? "名称至少需要 3 个字符" : "At least 3 characters required");
        tx.put("cardControls", cn ? "交互控件" : "Controls");
        tx.put("cardTelemetry", cn ? "状态与仪表" : "Telemetry");
        tx.put("cardLists", cn ? "列表与骨架屏" : "Lists & Skeleton");
        tx.put("alertTitle", cn ? "B42 原生输入契约就绪" : "B42 Native Input Ready");
        tx.put("alertMsg", cn ? "ESC 键消费、Toast 自动卸载与零帧布局刷新已启用。" : "ESC key consumption, tight Toast bounds and 0-frame flush active.");
        tx.put("btnPrimary", cn ? "保存配置" : "Save");
        tx.put("btnSecondary", cn ? "重置" : "Reset");
        tx.put("btnDisabled", cn ? "已锁定" : "Locked");
        tx.put("toastMsg", cn ? "主题切换成功：" + themeId : "Theme applied: " + themeId);
        tx.put("hoverTitle", cn ? "木工工作台" : "Carpentry Bench");
        tx.put("hoverBadge", cn ? "运行中" : "ACTIVE");
        tx.put("hoverKey1", cn ? "当前工种" : "Assigned");
        tx.put("hoverVal1", cn ? "锯木工 (2/2)" : "Sawyer (2/2)");
        tx.put("hoverKey2", cn ? "仓储负载" : "Load");
        tx.put("hoverVal2", "68%");
        tx.put("hoverBody", cn ? "HoverCard 悬浮卡片采用 Zero-GC 预排版，不遮挡下层交互。" : "Zero-GC prepared HoverCard without blocking underlying clicks.");
        tx.put("optA", cn ? "主仓库 - 综合分区" : "Main Warehouse - General");
        tx.put("optB", cn ? "冷库 - 生鲜食材" : "Cold Storage - Perishables");
        tx.put("chipAll", cn ? "全部" : "All");
        tx.put("chipFood", cn ? "食物" : "Food");
        tx.put("chipMed", cn ? "医疗" : "Med");
        tx.put("dialTitle", cn ? "负载" : "LOAD");
        tx.put("order1", cn ? "1. 紧急医疗与绷带" : "1. Emergency Medical");
        tx.put("order2", cn ? "2. 食物与饮用水" : "2. Food & Water");
        tx.put("order3", cn ? "3. 建筑木板与钉子" : "3. Planks & Nails");
        tx.put("row1", cn ? "Base.Axe — 消防斧 x3" : "Base.Axe — Fire Axe x3");
        tx.put("row2", cn ? "Base.Plank — 木板 x48" : "Base.Plank — Plank x48");
        tx.put("row3", cn ? "Base.Bandage — 绷带 x15" : "Base.Bandage — Bandage x15");
        tx.put("modalTitle", cn ? "独立模组确认" : "Standalone Confirm");
        tx.put("modalBody", cn ? "EmberUI 已解耦 V1 仓库并作为独立基础库运行。" : "EmberUI runs standalone, decoupled from V1.");
        LuaManager.env.rawset("_GAL_T", (JavaFunction) (frame, count) -> frame.push(tx.getOrDefault(String.valueOf(frame.get(0)), "")));

        return """
            local T = _GAL_T
            local EmberUI = require "EmberUI"
            local UI = EmberUI.UI
            local Theme = EmberUI.Theme
            Theme.applyPreset("%s")

            local win = EmberUI.WindowHost:new(24, 58, 920, 650, {
                title = T("winTitle"),
                resizable = true,
            })
            win:initialise()
            win:instantiate()
            win:addToUIManager()

            local tabs = UI.TabBar({
                { id = "forms", label = T("tabA"), icon = "gear", badge = 6 },
                { id = "lists", label = T("tabB"), icon = "box", badge = 3 },
                { id = "slots", label = T("tabC"), icon = "star", disabled = false },
            }, "forms", nil, { variant = "underline", h = 30 })

            local chips = UI.FilterChips({
                { id = "all", label = T("chipAll"), count = 24, mark = "active" },
                { id = "food", label = T("chipFood"), count = 12, mark = "done" },
                { id = "med", label = T("chipMed"), count = 3, alert = true, mark = "blocked" },
            }, "all", nil, { h = 26 })
            chips:setSelected("all", true)

            local search = UI.SearchInput(T("searchPh"), win, nil, { h = 26, text = "Axe" })
            local dd = UI.Dropdown(win, nil, {
                h = 26,
                options = {
                    { id = "main", label = T("optA") },
                    { id = "cold", label = T("optB") },
                },
                selected = "main",
            })

            local fName = EmberUI.Field:new(0, 0, 360, 44, {
                label = T("fieldName"),
                type = "input",
                value = "A",
                labelWidth = 96,
                rules = { required = true, min = 3, message = T("fieldErr") },
            })
            fName:validate()

            local fStock = EmberUI.Field:new(0, 0, 360, 28, {
                label = T("fieldStock"),
                type = "stepper",
                value = 24,
                min = 1,
                max = 200,
                labelWidth = 96,
            })

            local fSwitch = EmberUI.Field:new(0, 0, 360, 28, {
                label = T("fieldAuto"),
                type = "switch",
                value = true,
                labelWidth = 96,
            })

            local btnDis = UI.Button(T("btnDisabled"), win, nil, { w = 88, h = 26 })
            Theme.enable(btnDis, false, false)

            local leftCard = UI.CardPanel({
                title = T("cardControls"),
                badge = "v1.1.0",
                hostProps = { direction = "column", gap = 8, padding = 6 },
            }, UI.Column({ gap = 8 }, {
                UI.Item(chips, { basis = 26 }),
                UI.Item(search, { basis = 26 }),
                UI.Item(dd, { basis = 26 }),
                UI.Item(fName, { basis = 44 }),
                UI.Item(fStock, { basis = 28 }),
                UI.Item(fSwitch, { basis = 28 }),
                UI.Item(UI.Row({ gap = 8 }, {
                    UI.Button(T("btnPrimary"), win, nil, { primary = true, w = 96, h = 26 }),
                    UI.Button(T("btnSecondary"), win, nil, { w = 78, h = 26 }),
                    UI.Item(btnDis, { basis = 88 }),
                }), { basis = 28 }),
                UI.Alert(T("alertMsg"), "info", { title = T("alertTitle"), h = 54 }),
            }))

            local avatar = EmberUI.Widgets.Avatar3DView:new(0, 0, 68, 68)
            avatar:setPortrait({ name = "ER" })
            avatar.injuryAlert = true

            local meter1 = UI.StatMeter(0.76, { mode = "health", label = "HP 76%%", h = 18 })
            local meter2 = UI.StatMeter(0.68, { mode = "load", label = "LOAD 68%%", h = 18 })
            local meter3 = UI.StatMeter(1.00, { mode = "progress", label = "READY 100%%", h = 18 })

            local dialPanel = ISPanel:new(0, 0, 100, 96)
            dialPanel.background = false
            dialPanel.prerender = function(self)
                EmberUI.Widgets.RadialDial.draw(self, 48, 48, 42, 0.68, { mode = "load", title = T("dialTitle") })
            end

            local skeletonPanel = ISPanel:new(0, 0, 200, 56)
            skeletonPanel.background = false
            skeletonPanel.prerender = function(self)
                EmberUI.Widgets.SkeletonView.card(self, 0, 0, self.width, self.height)
            end

            local cachedList = UI.List({ h = 84 })
            EmberUI.Widgets.CachedList.fill(cachedList, { T("row1"), T("row2"), T("row3") }, function(s) return s end)

            local orderList = EmberUI.OrderList:new(0, 0, 200, 102, {
                items = { T("order1"), T("order2"), T("order3") },
            })

            local picks = EmberUI.PickSet.new()
            picks:add("1"); picks:add("2")
            local bulkBar = EmberUI.BulkBar:new(0, 0, 380, 32, {
                pickSet = picks,
                allIds = { "1", "2", "3" },
                actions = { { id = "go", label = T("btnPrimary"), primary = true, width = 76 } },
            })

            local teleCard = UI.CardPanel({
                title = T("cardTelemetry"),
                badge = "LIVE",
                basis = 244,
                hostProps = { direction = "column", gap = 6, padding = 4 },
            }, UI.Column({ gap = 6 }, {
                UI.Item(UI.Row({ gap = 8, align = "center" }, {
                    UI.Item(avatar, { basis = 68 }),
                    UI.Item(UI.Column({ gap = 5, justify = "center" }, {
                        UI.Item(meter1, { basis = 18 }),
                        UI.Item(meter2, { basis = 18 }),
                        UI.Item(meter3, { basis = 18 }),
                    }), { grow = 1, alignSelf = "stretch" }),
                    UI.Item(dialPanel, { basis = 96 }),
                }), { basis = 96 }),
                UI.Item(UI.Row({ gap = 6 }, {
                    UI.Badge("READY", { h = 22 }),
                    UI.Badge("ACTIVE", { h = 22 }),
                    UI.Badge("UPDATING", { h = 22 }),
                    UI.Badge("WARNING", { h = 22 }),
                    UI.Badge("ERROR", { h = 22 }),
                }), { basis = 24 }),
                UI.Item(skeletonPanel, { basis = 56 }),
            }))

            local listsCard = UI.CardPanel({
                title = T("cardLists"),
                grow = 1,
                hostProps = { direction = "column", gap = 6, padding = 4 },
            }, UI.Column({ gap = 6 }, {
                UI.Item(cachedList, { basis = 84 }),
                UI.Item(orderList, { basis = 102 }),
                UI.Item(bulkBar, { basis = 32 }),
            }))

            local rightCol = UI.Column({ gap = 8 }, {
                teleCard,
                listsCard,
            })

            local split = UI.SplitView(leftCard, rightCol, { ratio = 0.48, minFirst = 260, minSecond = 280, grow = 1 })

            win:setContentSpec(UI.Column({ padding = 10, gap = 8 }, {
                UI.Item(tabs, { basis = 30 }),
                split,
            }))

            -- Floating overlays rendered alongside main window (non-overlapping right column)
            EmberUI.Widgets.ToastManager.success(T("toastMsg"), 5000)

            local hoverPanel = ISPanel:new(964, 58, 294, 150)
            hoverPanel.background = false
            local preparedHover = EmberUI.HoverCard.prepare({
                title = T("hoverTitle"),
                badge = { label = T("hoverBadge"), color = Theme.status.READY, bg = Theme.badgeBg },
                rows = {
                    { key = T("hoverKey1"), value = T("hoverVal1") },
                    { key = T("hoverKey2"), value = T("hoverVal2"), color = Theme.gold },
                },
                body = T("hoverBody"),
            }, 294)
            hoverPanel.prerender = function(self)
                EmberUI.HoverCard.drawPrepared(self, 0, 0, preparedHover)
            end
            hoverPanel:initialise()
            hoverPanel:addToUIManager()

            -- EmptyState preview card on right side
            local emptyPanel = ISPanel:new(964, 224, 294, 180)
            emptyPanel.background = false
            emptyPanel.prerender = function(self)
                EmberUI.Chrome.roundedRect(self, 0, 0, self.width, self.height, Theme.window, Theme.border, false, 9)
                EmberUI.Widgets.EmptyState.draw(self, { x = 8, y = 8, width = self.width - 16, height = self.height - 16 }, {
                    icon = "box",
                    title = T("modalTitle"),
                    hint = T("modalBody"),
                    action = T("btnPrimary"),
                })
            end
            emptyPanel:initialise()
            emptyPanel:addToUIManager()

            -- Compact inline modal preview card on bottom-right
            local modalPreview = ISPanel:new(964, 420, 294, 150)
            modalPreview.background = false
            modalPreview.prerender = function(self)
                EmberUI.Chrome.shadow(self, 0, 0, self.width, self.height, 0.45)
                EmberUI.Chrome.roundedRect(self, 0, 0, self.width, self.height, Theme.window, Theme.border, false, 9)
                EmberUI.Chrome.titleBar(self, 1, 1, self.width - 2, 26, Theme.titleBar, Theme.titleAccent, Theme.border, 9)
                Theme.text(self, T("modalTitle"), 10, 6, Theme.gold)
                local lines = EmberUI.Core.Text.wrapLimited(T("modalBody"), self.width - 24, UIFont.Small, 3)
                for i = 1, #lines do
                    Theme.text(self, lines[i], 12, 38 + (i - 1) * 18, Theme.textColor)
                end
            end
            modalPreview:initialise()
            modalPreview:addToUIManager()
            """.formatted(themeId);
    }

    private static void pcallLua(String code) throws IOException {
        Object[] res = LuaManager.thread.pcall(LuaCompiler.loadis(new StringReader(code), "preview-gallery", LuaManager.env), new Object[0]);
        if (!Boolean.TRUE.equals(res[0])) {
            throw new IllegalStateException("Lua error: " + (res.length > 1 ? res[1] : "") + (res.length > 2 ? "\n" + res[2] : ""));
        }
    }

    private static void capturePng(Path file) {
        try {
            ByteBuffer pixels = ByteBuffer.allocateDirect(WIDTH * HEIGHT * 4);
            GL11.glReadPixels(0, 0, WIDTH, HEIGHT, GL11.GL_RGBA, GL11.GL_UNSIGNED_BYTE, pixels);
            BufferedImage img = new BufferedImage(WIDTH, HEIGHT, BufferedImage.TYPE_INT_ARGB);
            for (int y = 0; y < HEIGHT; y++) {
                for (int x = 0; x < WIDTH; x++) {
                    int i = ((HEIGHT - 1 - y) * WIDTH + x) * 4;
                    int argb = ((pixels.get(i + 3) & 255) << 24)
                            | ((pixels.get(i) & 255) << 16)
                            | ((pixels.get(i + 1) & 255) << 8)
                            | (pixels.get(i + 2) & 255);
                    img.setRGB(x, y, argb);
                }
            }
            ImageIO.write(img, "png", file.toFile());
            System.out.println("[PreviewGallery] Captured " + file);
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }
}
