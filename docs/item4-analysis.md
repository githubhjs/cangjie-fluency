# Space / symbol / uppercase behaviour: analysis for a full-Cangjie fluency schema

Scope: items 3, 4, 5 of the numbered list in rime/rime-quick#2 (eight04). The lead's
"items 2-4" correspond to the issue's numbers 3 (space), 4 (other half-width symbols),
5 (uppercase). The issue's own item 2 ("space may be used to separate characters, not
required") is a feature, not a difference to fix.

Source basis: librime tag **1.13.1** (the version inside Weasel 0.17.4), cross-checked
against 1.10.0 (what ran in the Linux tests) and master. For `editor.cc`, `speller.cc`,
`recognizer.cc`, `matcher.cc`, `abc_segmentor.cc`, `fallback_segmentor.cc` and
`ascii_composer.cc` the 1.10.0 -> 1.13.1 diffs are tiny and unrelated (BeginEditing,
namespace args, a modifier-toggle fix). `punctuator.cc` differs (digit-separator feature,
see risks). Paths are `src/rime/gear/<file>.cc` in https://github.com/rime/librime .

Only source for what Microsoft New Cangjie does: eight04's issue text. A web search
found no MS documentation of buffer/space/uppercase behaviour. Everything about MS
behaviour below is therefore "per the issue author, unverified".

## 0. Key facts about the processor chain

Order in the schema: `ascii_composer, recognizer, key_binder, speller, punctuator,
selector, navigator, fluency_editor`. First non-noop wins.

- `FluidEditor` (editor.cc ctor): binds `space -> Confirm`; `char_handler_ = AddToInput`.
  `Editor::ProcessKeyEvent` calls `char_handler_` for ANY key with 0x20 < ch < 0x7f, even when the
  buffer is empty, so unhandled digits/uppercase/symbols are pushed into the buffer instead of
  reaching the application. `Editor::Confirm` = `ConfirmCurrentSelection() || Commit()`.
- `_auto_commit` is false for FluidEditor (`Editor(ticket, false)`), so
  `ConcreteEngine::OnSelect` (engine.cc) does `composition().Forward()` instead of committing:
  a confirmed segment stays in the buffer.
- Released `ascii_composer.cc` (1.10.0 - 1.17.0) does nothing with uppercase letters.
  Master (after 74bd5dc4, 2026-09-18, unreleased) added `ascii_composer/inline_uppercase`
  (default false), which switches to inline ASCII: the opposite of what item 5 wants.

## Item 3: space (issue #3)

Cause. With quick5_fluency's config, space is routed through `Punctuator::ProcessKeyEvent`
(`punctuator/use_space: true`). Entry `' ': {commit: ' '}` -> `AutoCommitPunct` -> `ctx->Commit()`:
buffer committed, then space. Entry `' ': ' '` (plain) -> `ConfirmUniquePunct` ->
`ConfirmCurrentSelection` -> stays in buffer, but then an EMPTY buffer also keeps the space
(needs Enter). Lotem's "config cannot condition on buffer emptiness" is true for the punctuator route.

Config-only? **Yes, via a different route** (tested). `Speller::ProcessKeyEvent` (speller.cc) takes
space when `speller/use_space: true` and space is in `speller/delimiter`:
`expecting_an_initial()` returns true at caret 0 or after a delimiter, so an empty buffer gives
kNoop and the space reaches the app; after a letter it does `PushInput(' ')`.
Keys: `speller/use_space: true`, `speller/delimiter: " ;'"`; remove `punctuator/use_space` and the
`' '` half_shape entry. A 2nd consecutive space returns kNoop from the speller and hits
`FluidEditor` space = Confirm (confirms the first segment; Return then commits). Tested (t1, t3, t8).
Weasel: `Speller` is identical in 1.10.0/1.13.1/master except unrelated auto-select code. Verified on
1.10.0 Linux; same code path at 1.13.1 by diff; not run on Weasel.

Lua? Optional (partial): the `space` switch of `cangjie_fluency.lua` does the same without
`speller/use_space`, and adds `double_space: ignore`. C++ plugin: no.
Recommended: config route (zero code). Risk: the `abc_segmentor` delimiter test is
`k != j` in 1.13.1 (`k != 0` on master), i.e. a delimiter cannot start a later segment; irrelevant
for space-after-letter, relevant after literals (see item 5). Behaviour of repeated spaces in MS: unverified.

## Item 4: other half-width symbols (issue #4)

Cause. Same punctuator mechanics: `{commit: x}` (default `punctuation.yaml` has these for
`, . ? ; : !` etc.) -> `AutoCommitPunct` commits buffer+symbol; plain-value or list entries
(`( ) < > " ' # ...`) -> `ConfirmUniquePunct`/`PairPunct`/alternate, which keep the symbol IN
the buffer (tested: `dhe(dhkb` -> 板（橋). With an empty buffer those same entries also stay
in the buffer (tested: `(` -> buffer "（", `1` -> buffer "1", `#` -> buffer "#"), because of
`Editor::AddToInput`.

Config-only? **Yes for "buffer has content -> append"**: turn `{commit: x}` entries into plain
values (`half_shape: {',': '，', '.': '。', '?': '？', '!': '！', ':': '：'}`), tested (t8).
The reason the issue's `ascii_style` plain entries misbehaved is the EMPTY-buffer case.
**No for "empty buffer -> straight to application"**: no key selects on buffer state.

Lua? **Yes**: `empty_direct` in `cangjie_fluency.lua` replays the key via `engine:process_key`
and commits the resulting buffer (`(`->`（`, `,`->`，`, `1`->`1`, `A`->`A`; tested). Optional
`symbols: append` pushes the key itself (also works for `, .`; tested in t7). C++ plugin: no.
Risks: (1) `append` pushes raw characters, so segmentation must be `abc_segmentor`-based; with
the matcher-based `abc: "^[a-z]+( [a-z]+)* ?$"` pattern the tail after a raw symbol becomes raw
text (tested t4: `dhe(dhkb` -> `板（dhkb`). (2) Excluded by default from `symbol_chars`: `` ` ' ; `` and
digits (reverse lookup / delimiters / candidate selection), `- = , .` (stock paging keys).
(3) 1.13.1 punctuator adds `punctuator/digit_separators` logic (`ConvertDigitSeparator`,
after a committed digit): replay still goes through it; not tested. (4) With `ascii_punct` on,
the punctuator returns kNoop for everything and `AddToInput` handles symbols; not tested.

## Item 5: uppercase (issue #5)

Cause (tested + source). `default.yaml` (imported by `recognizer: import_preset: default`)
contains `recognizer/patterns/uppercase: "[A-Z][-_+.'0-9A-Za-z]*$"` (plus `email`, `url`).
`Recognizer::ProcessKeyEvent` (recognizer.cc) runs BEFORE speller/punctuator: if
`input + ch` matches a pattern at the current segment it does `PushInput(ch)` and returns
kAccepted. So after an uppercase letter every following key matching `[-_+.'0-9A-Za-z]` is
swallowed as literal text; `Matcher` tags the span `uppercase`, which no translator handles, so
`fallback`/raw text is committed. Adding `A` to `punctuator/half_shape` cannot help because the
punctuator never sees the key. Second trap in quick5_fluency's design: with `abc_segmentor` removed,
chinese segments exist only via the `abc` recognizer pattern; `RecognizerPatterns::GetMatch` uses
leftmost `boost::regex_search` and requires `end == input.length()`, so once any non `[a-z ]` char is
in the buffer the tail cannot be re-tagged `abc` (tested t1: still `板Adhkb` even without the
`uppercase` pattern).

Config-only? **Yes for "uppercase kept in buffer, Chinese continues"** (tested t3/t8):
(a) do not `import_preset: default` into `recognizer` (list only `reverse_lookup`), and
(b) use stock `abc_segmentor` (after `matcher`) instead of the `abc` pattern.
Result: `dheAdhkb` -> `板A橋`. **No for "empty buffer + uppercase goes straight to app"**
(`A` alone sits in the buffer; same `AddToInput` cause as item 4).

Lua? **Yes**: `uppercase: literal` (needs (a)+(b)) or `uppercase: commit` (commit buffer, then
letter via `engine:commit_text`; works with ANY segmentation; tested t4: `dheAdhkb` -> commit
`板A`, then `橋` composing). Placed before `recognizer`, so recognizer's uppercase pattern no
longer matters for composing input. What MS does with the buffer on an uppercase letter: only the
issue text (lowercase letters stay in the Chinese buffer); whether the uppercase letter itself
stays in the buffer or is committed: **unverified**. C++ plugin: no.
Risks: Weasel sends Shift+A as keycode 0x41 + shift mask (tested both ways on Linux; Weasel itself
unverified). `good_old_caps_lock: true` makes ascii_composer reject caps-on letters before the Lua
processor sees them. Do not use `{Shift_L}` press/release in tests (toggles `commit_text`).

## Is a C++ plugin needed?

No for items 3-5 as scoped: everything verified is reachable with config plus an optional
~150-line Lua processor. A C++ change would only be justified for upstreaming a
generic feature (e.g. an editor `char_handler` that depends on buffer emptiness, or an
`editor/direct_commit_when_empty` option).

## Availability on Windows 11 Weasel (verified by inspecting binaries)

- Weasel 0.17.4 (2025-06-04, https://github.com/rime/weasel/releases/tag/0.17.4): I downloaded
  `weasel-0.17.4.0-installer.exe`, unpacked it with 7z; its `rime.dll` contains the strings
  `lua_processor`, `lua_gears.cc`, `plugins\octagram\...`, `predict_translator`, `1.13.1`, and
  `$LuaVersion: Lua 5.4.7`. So librime 1.13.1 + librime-lua + octagram + predict are built in.
- The installer's `data/` has NO `.gram` file (only `essay.txt`, `luna_pinyin_fluency.schema.yaml`,
  cangjie5 etc.): the language model must be added (plum `lotem/rime-octagram-data@hant`).
- Mechanism: Weasel's CI (`ci.yml`) runs `get-rime.ps1 -use dev`, which downloads the librime release
  asset `rime-<hash>-Windows-msvc-x64.7z`; librime's `release-ci.yml` builds Windows with
  `rime_plugins: hchunhui/librime-lua lotem/librime-octagram rime/librime-predict`.
  I also unpacked librime 1.17.0 `rime-33e7814-Windows-msvc-x64.7z`: `version-info.txt` lists the
  three plugins, `rime.dll` contains lua + octagram strings.
  Links: https://github.com/rime/librime/releases/tag/1.17.0 ,
  https://github.com/rime/librime/blob/master/.github/workflows/release-ci.yml
- Weasel 0.17.4's librime 1.13.1 predates 1.17.0 features (multi-sentence candidates, trimming
  leading delimiters). Weasel nightly ("latest") is newer; not inspected.
- Lua files go in `%APPDATA%\Rime\lua\`. Not tested on Windows: all runtime tests here are Linux.

## Test log (Linux aarch64, librime 1.10.0, librime-plugin-lua 1.10.0+git20230917)

Harness: `lua/test_driver.py` (ctypes over the C API, feeds keys one by one, reports commits,
keys the app would receive, and the final buffer); schema variants generated by
`rimebin2/testenv/mkvariants.py`; base = sibling `cangjie5_fluency` schema with octagram.

| Variant | Change | Result |
|---|---|---|
| t0_base | quick5_fluency design | space/`,` commit buffer; `dheAdhkb` -> `板Adhkb`; `dhe  dhkb` 2nd space commits `板 ` |
| t1 | `speller/use_space`, no punct space, no uppercase pattern | item 3 OK; item 5 still `板Adhkb` |
| t3 | t1 + `abc_segmentor`, no recognizer import | item 3 OK; `dheAdhkb` -> `板A橋` |
| t8 | t3 + plain-valued `, . ? ! :` | all non-empty-buffer cases OK; `A`, `(`, `,` alone stay in buffer |
| t4 | Lua, uppercase=commit, symbols=append, matcher schema | space, empty_direct, uppercase OK; symbol tail raw (see item 4 risk 1) |
| t5/t7 | Lua + abc_segmentor, literal, append | all cases OK incl. `,` `.` `?`; `{Shift+A}` and plain `A` same |
| t6 | Lua defaults-off for uppercase/symbols | space + empty_direct OK, uppercase unchanged (still bug) |

Not tested: Windows/Weasel, `ascii_punct` on, full_shape on, Caps Lock, long-run commit ordering
in real applications, user-dictionary learning side effects.

## What to tell upstream (rime-quick#2) / what a librime PR would need

Items 3-5 do not need a plugin: space can be made MS-like by `speller/use_space: true` with space
in `speller/delimiter` (the speller already yields to the app when the buffer is empty); symbols
append when their punctuator entries are plain values instead of `{commit: x}`; the "uppercase
turns the rest into English" bug is the `uppercase` pattern that `recognizer: import_preset: default`
pulls in from default.yaml (recognizer processor runs before the punctuator), plus the leftmost
`regex_search` limitation of an unanchored/anchored `abc` pattern once non-letters are in the buffer;
use `abc_segmentor` and an explicit `recognizer/patterns` list. The one thing config cannot do is
make digits, uppercase letters and symbols go straight to the app when the buffer is empty,
because `FluidEditor`'s `char_handler: add_to_input` fires regardless of buffer state; a ~150-line
librime-lua processor (draft: `lua/cangjie_fluency.lua`) covers it. A librime PR would be small:
in `Editor::ProcessKeyEvent` (editor.cc) add an `editor/char_handler` variant (or option) that
calls `DirectCommit` when `!ctx->IsComposing()` and `AddToInput` otherwise, plus tests; no new
plugin is required. Dictionary differences (item 1, e.g. 麵) are data, not code.
