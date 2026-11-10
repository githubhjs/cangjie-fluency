#!/usr/bin/env python3
"""Tiny librime driver (ctypes) used for the Linux test run in docs/test-log.md.

librime-bin 1.10 on Ubuntu ships no rime_api_console, so this drives the
exported legacy C API (RimeSetup/RimeProcessKey/RimeGetContext...) directly.

usage:
  rime_driver.py --root RIMEBIN_ROOT --shared DIR --user DIR [--no-grammar]
                 [--schema cangjie5_fluency] [--base cangjie5.base.dict.yaml]
                 CASE [CASE ...]
CASE is either  phrase:板橋   (codes looked up in --base, typed continuously,
single-letter codes get a trailing space)  or  keys:dhe dhkb  (typed verbatim;
{space} {Return} {BackSpace} {Escape} {Shift_L} etc. allowed).
Prints the preedit + first-page candidates after typing, and what Return commits.
"""
import argparse, ctypes, os, sys
from ctypes import (c_int, c_char_p, c_void_p, POINTER, Structure, byref,
                    sizeof, c_uint32)


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


def load_codes(path):
    codes = {}
    started = False
    for line in open(path, encoding="utf-8"):
        line = line.rstrip("\n")
        if line == "...":
            started = True
            continue
        if not started or not line or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) < 2 or parts[1].startswith("x"):
            continue
        codes.setdefault(parts[0], parts[1])
    return codes


def phrase_to_keys(phrase, codes):
    out = ""
    for ch in phrase:
        c = codes[ch]
        out += c + (" " if len(c) == 1 else "")
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", required=True)
    ap.add_argument("--shared", required=True)
    ap.add_argument("--user", required=True)
    ap.add_argument("--schema", default="cangjie5_fluency")
    ap.add_argument("--base")
    ap.add_argument("--no-grammar", action="store_true")
    ap.add_argument("--log-dir", default="")
    ap.add_argument("--no-commit", action="store_true",
                    help="never press Return (avoids user-dict learning)")
    ap.add_argument("--quiet", action="store_true",
                    help="only print misses + summary for phrase: cases")
    ap.add_argument("cases", nargs="+")
    a = ap.parse_args()

    lib_dir = os.path.join(a.root, "usr/lib/aarch64-linux-gnu")
    rime = ctypes.CDLL(os.path.join(lib_dir, "librime.so.1"), mode=ctypes.RTLD_GLOBAL)
    mods = [b"default"]
    if not a.no_grammar:
        # Debian's librime only looks for plugins in /usr/lib/.../rime-plugins
        # (hard-coded, needs root); register the plugin module by hand instead.
        plug = ctypes.CDLL(os.path.join(lib_dir, "rime-plugins/librime-octagram.so"),
                           mode=ctypes.RTLD_GLOBAL)
        plug._Z28rime_require_module_octagramv()
        mods.append(b"octagram")
    arr = (c_char_p * (len(mods) + 1))(*mods, None)

    rime.RimeCreateSession.restype = ctypes.c_size_t
    rime.RimeProcessKey.argtypes = [ctypes.c_size_t, c_int, c_int]
    rime.RimeSimulateKeySequence.argtypes = [ctypes.c_size_t, c_char_p]
    rime.RimeGetContext.argtypes = [ctypes.c_size_t, POINTER(Context)]
    rime.RimeFreeContext.argtypes = [POINTER(Context)]
    rime.RimeGetCommit.argtypes = [ctypes.c_size_t, POINTER(Commit)]
    rime.RimeFreeCommit.argtypes = [POINTER(Commit)]
    rime.RimeSelectSchema.argtypes = [ctypes.c_size_t, c_char_p]
    rime.RimeClearComposition.argtypes = [ctypes.c_size_t]

    t = Traits()
    t.data_size = sizeof(Traits) - sizeof(c_int)
    t.shared_data_dir = a.shared.encode()
    t.user_data_dir = a.user.encode()
    t.app_name = b"rime.cangjie-fluency-test"
    t.distribution_name = b"test"
    t.modules = arr
    t.min_log_level = 0
    t.log_dir = (a.log_dir or os.path.join(a.user, "log")).encode()
    os.makedirs(t.log_dir.decode(), exist_ok=True)
    rime.RimeSetup(byref(t))
    rime.RimeInitialize(byref(t))
    sid = rime.RimeCreateSession()
    if not rime.RimeSelectSchema(sid, a.schema.encode()):
        print("!! select schema failed", file=sys.stderr)

    codes = load_codes(a.base) if a.base else {}

    def top_candidates():
        ctx = Context()
        ctx.data_size = sizeof(Context) - sizeof(c_int)
        if not rime.RimeGetContext(sid, byref(ctx)) or ctx.composition.length == 0:
            return None, []
        cands = [(ctx.menu.candidates[i].text or b"").decode()
                 for i in range(ctx.menu.num_candidates)]
        pre = ctx.composition.preedit.decode()
        rime.RimeFreeContext(byref(ctx))
        return pre, cands

    def snapshot(label):
        ctx = Context()
        ctx.data_size = sizeof(Context) - sizeof(c_int)
        if not rime.RimeGetContext(sid, byref(ctx)) or ctx.composition.length == 0:
            print(f"  {label}: (no composition)")
            return
        cands = []
        for i in range(ctx.menu.num_candidates):
            c = ctx.menu.candidates[i]
            cands.append((c.text or b"").decode())
        print(f"  {label}: preedit={ctx.composition.preedit.decode()!r} "
              f"candidates={cands}")
        rime.RimeFreeContext(byref(ctx))

    def commit_text():
        cm = Commit()
        cm.data_size = sizeof(Commit) - sizeof(c_int)
        txt = None
        if rime.RimeGetCommit(sid, byref(cm)):
            txt = cm.text.decode()
            rime.RimeFreeCommit(byref(cm))
        return txt

    print(f"== schema={a.schema} grammar={'OFF' if a.no_grammar else 'ON'}")
    ok = miss = 0
    for case in a.cases:
        kind, _, val = case.partition(":")
        if kind == "trace":
            keys = phrase_to_keys(val, codes)
            print(f"-- trace {val} keys={keys!r}")
            rime.RimeClearComposition(sid)
            for k in keys:
                rime.RimeSimulateKeySequence(sid, k.encode())
                pre, cands = top_candidates()
                print(f"  after {k!r}: top={cands[0] if cands else None!r}")
            rime.RimeClearComposition(sid)
            continue
        if kind == "phrase" and a.quiet:
            keys = phrase_to_keys(val, codes)
            rime.RimeClearComposition(sid)
            rime.RimeSimulateKeySequence(sid, keys.encode())
            pre, cands = top_candidates()
            top = cands[0] if cands else None
            if top == val:
                ok += 1
            else:
                miss += 1
                print(f"MISS want={val} got={top} keys={keys!r}")
            rime.RimeClearComposition(sid)
            continue
        if kind == "phrase":
            keys = phrase_to_keys(val, codes)
            print(f"-- {val}  keys={keys!r}")
        else:
            keys = val
            print(f"-- keys={keys!r}")
        rime.RimeClearComposition(sid)
        names = {'space': 0x20, 'Return': 0xff0d, 'BackSpace': 0xff08,
                 'Escape': 0xff1b, 'Shift_L': 0xffe1, 'Tab': 0xff09}
        toks, i = [], 0
        while i < len(keys):
            if keys[i] == '{' and '}' in keys[i:]:
                j = keys.index('}', i)
                toks.append(keys[i + 1:j]); i = j + 1
            else:
                toks.append(keys[i]); i += 1
        commits, passed = [], []
        for t in toks:
            if t in names:
                code, mask = names[t], 0
            else:
                code, mask = ord(t), (1 if t.isupper() else 0)
            handled = rime.RimeProcessKey(sid, code, mask)
            if not handled:
                passed.append(t)
            c = commit_text()
            if c:
                commits.append(c)
        if commits:
            print(f"  committed to app while typing: {commits!r}")
        if passed:
            print(f"  keys passed through to the app (not consumed): {passed!r}")
        snapshot("buffer")
        if not a.no_commit:
            rime.RimeSimulateKeySequence(sid, b"{Return}")
            print(f"  Return commits: {commit_text()!r}")
        rime.RimeClearComposition(sid)
    if a.quiet:
        print(f"SUMMARY grammar={'OFF' if a.no_grammar else 'ON'} ok={ok} miss={miss}")
    rime.RimeDestroySession(sid)
    rime.RimeFinalize()


if __name__ == "__main__":
    main()
