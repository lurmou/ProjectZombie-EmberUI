import json
import os
import re
import sys

def main():
    repo = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    mod_root = os.path.join(repo, "Contents", "mods", "EmberUI", "42")
    cn_path = os.path.join(mod_root, "media", "lua", "shared", "Translate", "CN", "IG_UI.json")
    en_path = os.path.join(mod_root, "media", "lua", "shared", "Translate", "EN", "IG_UI.json")

    with open(cn_path, "r", encoding="utf-8") as f:
        cn = json.load(f)
    with open(en_path, "r", encoding="utf-8") as f:
        en = json.load(f)

    cn_keys = set(cn.keys())
    en_keys = set(en.keys())
    if cn_keys != en_keys:
        print(f"ERROR: CN/EN key mismatch: only_cn={sorted(cn_keys - en_keys)}, only_en={sorted(en_keys - cn_keys)}")
        return 1

    bad_fmt = []
    bad_fmt_re = re.compile(r"%[dfs]")
    for lang, data in (("CN", cn), ("EN", en)):
        for k, v in data.items():
            if bad_fmt_re.search(v):
                bad_fmt.append((lang, k, v))
    if bad_fmt:
        print(f"ERROR: Prohibited printf placeholders (%d/%f/%s) found: {bad_fmt}")
        return 1

    lua_root = os.path.join(mod_root, "media", "lua")
    key_re = re.compile(r"IGUI_EmberUI_[A-Za-z0-9_]+")
    missing = []
    for dp, _, fns in os.walk(lua_root):
        for fn in fns:
            if not fn.endswith(".lua"):
                continue
            p = os.path.join(dp, fn)
            with open(p, "r", encoding="utf-8") as f:
                txt = f.read()
            for k in key_re.findall(txt):
                if k not in en and not k.endswith("_"):
                    missing.append((fn, k))

    if missing:
        print(f"ERROR: Missing i18n keys referenced in Lua: {missing}")
        return 1

    print(f"PASS check_i18n: {len(en)} symmetric CN/EN keys verified, 0 missing references.")
    return 0

if __name__ == "__main__":
    sys.exit(main())
