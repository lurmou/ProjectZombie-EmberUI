import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.*;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.*;

/** Standalone Kahlua test runner for EmberUI Core, Widgets, and Shell. */
public class KahluaEmberUITest {
    public static void main(String[] args) throws Exception {
        String repoRoot = ".";
        String gameRoot = "D:/Software/GameApp/steam/steamapps/common/ProjectZomboid";
        List<String> files = new ArrayList<>();
        for (String arg : args) {
            if (arg.startsWith("--game-root=")) {
                gameRoot = arg.substring("--game-root=".length());
            } else if (arg.startsWith("--repo-root=")) {
                repoRoot = arg.substring("--repo-root=".length());
            } else if (!arg.startsWith("--")) {
                files.add(arg);
            }
        }
        if (files.isEmpty()) {
            files.add("emberui-core-test.lua");
        }

        Path repo = Path.of(repoRoot).toAbsolutePath().normalize();
        Path stdlib = Path.of(gameRoot, "stdlib.lua");
        if (!Files.exists(stdlib)) {
            throw new IllegalStateException("Missing PZ stdlib.lua at " + stdlib);
        }

        for (String file : files) {
            var platform = J2SEPlatform.getInstance();
            var env = platform.newTable();
            env.rawset("_G", env);
            se.krka.kahlua.stdlib.BaseLib.register(env);
            se.krka.kahlua.stdlib.StringLib.register(platform, env);
            se.krka.kahlua.stdlib.TableLib.register(platform, env);
            se.krka.kahlua.j2se.MathLib.register(platform, env);
            se.krka.kahlua.stdlib.CoroutineLib.register(platform, env);
            se.krka.kahlua.stdlib.OsLib.register(platform, env);

            var thread = new KahluaThread(platform, env);
            thread.debugOwnerThread = Thread.currentThread();
            KahluaUtil.setWorkerThread(env, thread);
            run(thread, env, stdlib);
            env.rawset("next", null);

            var pkg = platform.newTable();
            var loaded = platform.newTable();
            pkg.rawset("loaded", loaded);
            pkg.rawset("path", "");
            env.rawset("package", pkg);

            env.rawset("print", (JavaFunction) (frame, n) -> {
                System.out.println(String.valueOf(frame.get(0)));
                return 0;
            });

            Path modLua = repo.resolve("Contents/mods/EmberUI/42/media/lua");
            env.rawset("require", (JavaFunction) (frame, n) -> {
                String name = String.valueOf(frame.get(0));
                Object value = loaded.rawget(name);
                if (value == null) {
                    Path path = modLua.resolve("client").resolve(name + ".lua");
                    if (!Files.exists(path)) {
                        path = modLua.resolve("shared").resolve(name + ".lua");
                    }
                    if (!Files.exists(path)) {
                        throw new IllegalArgumentException("Missing Lua module: " + name + " (checked " + path + ")");
                    }
                    value = call(thread, env, path);
                    if (value == null) value = true;
                    loaded.rawset(name, value);
                }
                frame.push(value);
                return 1;
            });

            Path testPath = repo.resolve("tests/lua").resolve(file);
            run(thread, env, testPath);
            System.out.println("PASS installed Kahlua: " + file);
        }
    }

    private static Object call(KahluaThread thread, KahluaTable env, Path file) {
        try {
            return thread.call(LuaCompiler.loadstring(Files.readString(file, StandardCharsets.UTF_8), file.toString(), env), new Object[0]);
        } catch (Exception e) {
            throw new RuntimeException(file.toString(), e);
        }
    }

    private static void run(KahluaThread thread, KahluaTable env, Path file) throws Exception {
        Object[] res = thread.pcall(LuaCompiler.loadstring(Files.readString(file, StandardCharsets.UTF_8), file.toString(), env), new Object[0]);
        if (!Boolean.TRUE.equals(res[0])) {
            throw new AssertionError(file + " -> " + Arrays.toString(res));
        }
    }
}
