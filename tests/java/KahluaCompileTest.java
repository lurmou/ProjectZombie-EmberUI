import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.*;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.Prototype;

/** Compiles all EmberUI Lua files under both Core.debug=false and Core.debug=true. */
public class KahluaCompileTest {
    private static int maxLocals;
    private static String largest;

    private static void inspect(Prototype p, Path file) {
        int count = p.locvars == null ? 0 : p.locvars.length;
        if (count > maxLocals) {
            maxLocals = count;
            largest = file.toString();
        }
        if (p.prototypes != null) {
            for (Prototype child : p.prototypes) {
                inspect(child, file);
            }
        }
    }

    public static void main(String[] args) throws Exception {
        Path root = Path.of(args.length > 0 ? args[0] : "Contents/mods/EmberUI/42/media/lua");
        List<Path> files;
        try (var walk = Files.walk(root)) {
            files = walk.filter(Files::isRegularFile)
                        .filter(p -> p.toString().endsWith(".lua"))
                        .sorted()
                        .toList();
        }
        if (files.isEmpty()) {
            throw new IllegalArgumentException("No Lua sources found under: " + root);
        }
        boolean original = zombie.core.Core.debug;
        int failures = 0;
        try {
            for (boolean debug : new boolean[]{false, true}) {
                zombie.core.Core.debug = debug;
                int failed = 0;
                for (Path file : files) {
                    try {
                        var closure = LuaCompiler.loadstring(
                            Files.readString(file, StandardCharsets.UTF_8),
                            file.toString(),
                            J2SEPlatform.getInstance().newTable()
                        );
                        if (debug) {
                            inspect(closure.prototype, file);
                        }
                    } catch (Exception e) {
                        failed++;
                        System.out.println("FAIL debug=" + debug + " " + file + ": " + e);
                    }
                }
                failures += failed;
                System.out.println("COMPILE debug=" + debug + ": " + files.size() + " files, " + failed + " failures");
            }
        } finally {
            zombie.core.Core.debug = original;
        }
        System.out.println("Largest debug local-name table: " + maxLocals + " in " + largest);
        if (failures > 0) {
            throw new AssertionError("EmberUI Lua compilation failures: " + failures);
        }
    }
}
