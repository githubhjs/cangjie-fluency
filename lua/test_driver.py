#!/usr/bin/env python3
"""ctypes test driver for lua/cangjie_fluency.lua (Linux, librime 1.10 + librime-lua).

Derived from the idea of weasel/docs/rime_driver.py (not modified there).
Feeds keys one at a time through RimeProcessKey so we can see (a) what got
committed, (b) which keys librime did NOT handle (i.e. would be delivered to the
application by the frontend), (c) the final preedit/candidates.

Key syntax: plain chars, or {Name} / {Mod+Name}: {space} {Return} {BackSpace}
{Escape} {Shift+A} {Shift+comma}.  Example:  "abc{space}{Shift+A}de{Return}"

  LD_LIBRARY_PATH=<root>/usr/lib/aarch64-linux-gnu test_driver.py --root <root> \
      --shared S --user U --schema cangjie5_fluency_lua  "keys:abc{space}de"
"""
import argparse, ctypes, os, sys
from ctypes import (c_int, c_char_p, c_void_p, POINTER, Structure, byref,
                    sizeof)

NAMES = {"space": 0x20, "Return": 0xff0d, "BackSpace": 0xff08,
         "Escape": 0xff1b, "Tab": 0xff09, "comma": ord(","), "period": ord("."),
         "Shift_L": 0xffe1}
MODS = {"Shift": 1, "Control": 4, "Alt": 8, "Release": 1 << 30}


class Traits(Structure):
    _fields_ = [("data_size", c_int), ("shared_data_dir", c_char_p),
                ("user_data_dir", c_char_p), ("distribution_name", c_char_p),
                ("distribution_code_name", c_char_p),
                ("distribution_version", c_char_p), ("app_name", c_char_p),
                ("modules", POINTER(c_char_p)), ("min_log_level", c_int),
                ("log_dir", c_char_p), ("prebuilt_data_dir", c_char_p),
                ("staging_dir", c_char_p)]


class Composition(Structure):
    _fields_ = [("length", c_int), ("cursor_pos", c_int), ("sel_start", c_int),
                ("sel_end", c_int), ("preedit", c_char_p)]


class Candidate(Structure):
    _fields_ = [("text", c_char_p), ("comment", c_char_p), ("reserved", c_void_p)]


class Menu(Structure):
    _fields_ = [("page_size", c_int), ("page_no", c_int), ("is_last_page", c_int),
                ("highlighted_candidate_index", c_int), ("num_candidates", c_int),
                ("candidates", POINTER(Candidate)), ("select_keys", c_char_p)]


class Context(Structure):
    _fields_ = [("data_size", c_int), ("composition", Composition),
                ("menu", Menu), ("commit_text_preview", c_char_p),
                ("select_labels", POINTER(c_char_p))]


class Commit(Structure):
    _fields_ = [("data_size", c_int), ("text", c_char_p)]


def tokenize(s):
    i = 0
    while i < len(s):
        if s[i] == "{":
            j = s.index("}", i)
            body = s[i + 1:j]
            mask = 0
            while "+" in body[:-1] and body.split("+")[0] in MODS:
                m, body = body.split("+", 1)
                mask |= MODS[m]
            code = NAMES.get(body, ord(body) if len(body) == 1 else None)
            if code is None:
                raise SystemExit("unknown key " + body)
            yield (body if mask == 0 else "+".join([k for k, v in MODS.items() if mask & v] + [body])), code, mask
            i = j + 1
        else:
            ch = s[i]
            # plain uppercase letter: send as Shift+letter like a real keyboard
            # only when asked via --shift-upper (default: no modifier, like
            # RimeSimulateKeySequence)
            yield ch, ord(ch), 0
            i += 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", required=True)
    ap.add_argument("--shared", required=True)
    ap.add_argument("--user", required=True)
    ap.add_argument("--schema", required=True)
    ap.add_argument("--no-grammar", action="store_true")
    ap.add_argument("--no-lua", action="store_true")
    ap.add_argument("--shift-upper", action="store_true",
                    help="send plain uppercase chars with the Shift modifier (Weasel style)")
    ap.add_argument("--option", action="append", default=[],
                    help="name=0/1 set_option after schema select")
    ap.add_argument("cases", nargs="+")
    a = ap.parse_args()

    lib_dir = os.path.join(a.root, "usr/lib/aarch64-linux-gnu")
    rime = ctypes.CDLL(os.path.join(lib_dir, "librime.so.1"), mode=ctypes.RTLD_GLOBAL)
    mods = [b"default"]
    if not a.no_grammar:
        plug = ctypes.CDLL(os.path.join(lib_dir, "rime-plugins/librime-octagram.so"),
                           mode=ctypes.RTLD_GLOBAL)
        plug._Z28rime_require_module_octagramv()
        mods.append(b"octagram")
    if not a.no_lua:
        plug = ctypes.CDLL(os.path.join(lib_dir, "rime-plugins/librime-lua.so"),
                           mode=ctypes.RTLD_GLOBAL)
        plug._Z23rime_require_module_luav()
        mods.append(b"lua")
    arr = (c_char_p * (len(mods) + 1))(*mods, None)

    rime.RimeCreateSession.restype = ctypes.c_size_t
    rime.RimeProcessKey.argtypes = [ctypes.c_size_t, c_int, c_int]
    rime.RimeProcessKey.restype = c_int
    rime.RimeGetContext.argtypes = [ctypes.c_size_t, POINTER(Context)]
    rime.RimeFreeContext.argtypes = [POINTER(Context)]
    rime.RimeGetCommit.argtypes = [ctypes.c_size_t, POINTER(Commit)]
    rime.RimeFreeCommit.argtypes = [POINTER(Commit)]
    rime.RimeSelectSchema.argtypes = [ctypes.c_size_t, c_char_p]
    rime.RimeClearComposition.argtypes = [ctypes.c_size_t]
    rime.RimeSetOption.argtypes = [ctypes.c_size_t, c_char_p, c_int]

    t = Traits()
    t.data_size = sizeof(Traits) - sizeof(c_int)
    t.shared_data_dir = a.shared.encode()
    t.user_data_dir = a.user.encode()
    t.app_name = b"rime.cangjie-fluency-lua-test"
    t.distribution_name = b"test"
    t.modules = arr
    t.min_log_level = 0
    t.log_dir = os.path.join(a.user, "log").encode()
    os.makedirs(t.log_dir.decode(), exist_ok=True)
    rime.RimeSetup(byref(t))
    rime.RimeInitialize(byref(t))
    rime.RimeStartMaintenance(0)
    rime.RimeJoinMaintenanceThread()
    sid = rime.RimeCreateSession()
    if not rime.RimeSelectSchema(sid, a.schema.encode()):
        print("!! select schema failed", file=sys.stderr)
    for o in a.option:
        k, v = o.split("=")
        rime.RimeSetOption(sid, k.encode(), int(v))

    def commit_text():
        cm = Commit()
        cm.data_size = sizeof(Commit) - sizeof(c_int)
        txt = None
        if rime.RimeGetCommit(sid, byref(cm)):
            txt = cm.text.decode()
            rime.RimeFreeCommit(byref(cm))
        return txt

    def snapshot():
        ctx = Context()
        ctx.data_size = sizeof(Context) - sizeof(c_int)
        if not rime.RimeGetContext(sid, byref(ctx)) or ctx.composition.length == 0:
            return "(empty)"
        cands = [(ctx.menu.candidates[i].text or b"").decode()
                 for i in range(min(ctx.menu.num_candidates, 4))]
        s = f"preedit={ctx.composition.preedit.decode()!r} cands={cands}"
        rime.RimeFreeContext(byref(ctx))
        return s

    for case in a.cases:
        kind, _, val = case.partition(":")
        rime.RimeClearComposition(sid)
        commit_text()
        out = []  # what the application would receive, in order
        for name, code, mask in tokenize(val):
            if a.shift_upper and mask == 0 and len(name) == 1 and name.isupper():
                mask = 1
            handled = rime.RimeProcessKey(sid, code, mask)
            c = commit_text()
            if c is not None:
                out.append(f"[commit {c!r}]")
            if not handled:
                out.append(f"<app gets {name!r}>")
        print(f"-- {val}")
        print(f"   app-visible: {' '.join(out) if out else '-'}")
        print(f"   buffer: {snapshot()}")
        rime.RimeProcessKey(sid, 0xff0d, 0)
        c = commit_text()
        print(f"   Return -> {c!r}")
        rime.RimeClearComposition(sid)
    rime.RimeDestroySession(sid)
    rime.RimeFinalize()


if __name__ == "__main__":
    main()
