# Linux test log (cangjie5_fluency)

Date: 2026-11-10. Host: Ubuntu 24.04 aarch64, no root, nothing installed system-wide.
Engine under test: Ubuntu `librime1t64` 1.10.0 + `librime-plugin-octagram` 1.10.0+dfsg1~git20230125
(NOT Weasel's librime; Weasel ships a newer librime, so behavior may differ in details).

All outputs below are copied from real runs (`testenv/final_eval.txt`, `testenv/final_keys.txt`).

## 1. Toolchain (no root)

```
cd rimebin/debs
apt-get download $(cat want.txt)          # 15 .deb files, 5.4 MB
for d in *.deb; do dpkg -x $d ../root; done
export LD_LIBRARY_PATH=$PWD/../root/usr/lib/aarch64-linux-gnu
ldd ../root/usr/bin/rime_deployer | grep "not found"     # -> nothing missing
```

Findings:
* `librime-bin` 1.10 has `rime_deployer`, `rime_dict_manager`, `rime_patch`, `rime_table_decompiler`
  but NO `rime_api_console`. So keys are driven through the exported legacy C API
  (RimeSetup / RimeSimulateKeySequence / RimeGetContext ...) with python ctypes:
  `weasel/docs/rime_driver.py` (this is the "alternative" the task allowed).
* Debian's librime only loads plugins from the hard-coded `/usr/lib/aarch64-linux-gnu/rime-plugins`
  (needs root). Workaround in the driver: `dlopen(librime-octagram.so, RTLD_GLOBAL)`, call
  `rime_require_module_octagram()` by hand and pass `modules = {"default","octagram"}`.
  Proof it loaded: log line `octagram.cc:29] use grammar: zh-hant-t-essay-bgw`.
  `--no-grammar` simply does not register the octagram module (= "model removed").
* The deployer itself does not need the plugin (grammar is runtime only).

## 2. Data (user data = `testenv/<name>/`, shared data = `testenv/shared/`)

```
gh api repos/rime/rime-cangjie/contents/cangjie5.base.dict.yaml --jq .content | base64 -d   # 219,115 B
gh api repos/rime/rime-essay/contents/essay.txt -H "Accept: application/vnd.github.raw"      # 5,887,319 B
gh api "repos/lotem/rime-octagram-data/contents/zh-hant-t-essay-bgw.gram?ref=hant" \
   -H "Accept: application/vnd.github.raw"                                                   # 41,415,724 B
gh api repos/rime/rime-prelude/contents/{default,key_bindings,punctuation,symbols}.yaml ...  # shared data
gh api repos/rime/rime-luna-pinyin/contents/{luna_pinyin.dict,luna_pinyin.schema,luna_quanpin.schema,pinyin}.yaml
gh api repos/lotem/rime-octagram-data/contents/grammar.yaml                                   # master branch, 775 B
```

(luna_pinyin / luna_quanpin are only needed for the backtick pinyin reverse lookup; Weasel bundles them.)

Build (3.3 s, 17 MB `cangjie5_fluency.table.bin`, no errors; deployer logs go to `<user>/log/`):

```
SHARED=$PWD/testenv/shared_nogy bash weasel/docs/build_test.sh fin2
real 0m3.578s   build exit=0
  cangjie5_fluency.prism.bin   743,792
  cangjie5_fluency.reverse.bin 181,944
  cangjie5_fluency.table.bin   17,464,416
```

`shared_nogy` = same as shared but WITHOUT `grammar.yaml`; the final schema still loads the model
(language is also set inline in the schema; build/…schema.yaml shows `grammar: language: "zh-hant-t-essay-bgw"`).

## 3. Test cases

Codes are looked up from `cangjie5.base.dict.yaml` by the driver (first non-`x` code of each
character; a 1-letter code gets a trailing space, e.g. 中 = `l ` -> keys `l oj` for 中午), the whole phrase
is typed continuously with no space/selection, and the TOP candidate (= the sentence shown in the buffer)
is compared with the intended text. No Return is pressed, so the user dictionary learns nothing.

```
USERDIR=testenv/fin2 SHARED=testenv/shared_nogy bash weasel/docs/run_eval.sh weasel/docs/sentences.txt --quiet --no-commit
USERDIR=testenv/fin2 SHARED=testenv/shared_nogy bash weasel/docs/run_eval.sh weasel/docs/hard.txt --quiet --no-commit
USERDIR=testenv/fin2 SHARED=testenv/shared_nogy bash weasel/docs/run_eval.sh weasel/docs/trace.txt --no-commit
```

### 3a. Accuracy, grammar ON vs OFF, and per-key buffer trace

```
### sentences.txt
== schema=cangjie5_fluency grammar=ON
SUMMARY grammar=ON ok=51 miss=0
== schema=cangjie5_fluency grammar=OFF
SUMMARY grammar=OFF ok=51 miss=0

### hard.txt
== schema=cangjie5_fluency grammar=ON
MISS want=一雙新鞋子 got=一隻新鞋子 keys='m ogeydhmltjggnd'
MISS want=佑你平安 got=知你平安 keys='okronfmfjjv'
MISS want=冇有人知道答案 got=有有人知道答案 keys='kbkbo okrythuhomrjvd'
MISS want=他把蘋果丟給困倦的弟弟 got=他把蘋果丟給果倦的弟弟 keys='opdqautyhcwdmgivfomrwdofquhapicnlhcnlh'
SUMMARY grammar=ON ok=36 miss=4
== schema=cangjie5_fluency grammar=OFF
MISS want=一雙新鞋子 got=一隻新鞋子 keys='m ogeydhmltjggnd'
MISS want=佑你平安 got=知你平安 keys='okronfmfjjv'
MISS want=冇有人知道答案 got=有有人知道答案 keys='kbkbo okrythuhomrjvd'
SUMMARY grammar=OFF ok=37 miss=3

### trace.txt
== schema=cangjie5_fluency grammar=ON
-- trace 板橋 keys='dhedhkb'
  after 'd': top='來'
  after 'h': top='才'
  after 'e': top='板'
  after 'd': top='才沐'
  after 'h': top='皮才'
  after 'k': top='板枖'
  after 'b': top='板橋'
-- trace 我們明天中午去板橋 keys='hqioanabmkl ojgidhedhkb'
  after 'h': top='的'
  after 'q': top='牛'
  after 'i': top='我'
  after 'o': top='牛庂'
  after 'a': top='牛庂是'
  after 'n': top='我們'
  after 'a': top='我僴'
  after 'b': top='我們明'
  after 'm': top='我僴且'
  after 'k': top='我們明天'
  after 'l': top='我們明天中'
  after ' ': top='我們明天中'
  after 'o': top='我們明天中午'
  after 'j': top='我們明天中午'
  after 'g': top='我們明天中午去'
  after 'i': top='我們明天中午去'
  after 'd': top='我們明天中午槷'
  after 'h': top='我們明天中午去才'
  after 'e': top='我們明天中午去皮'
  after 'd': top='我們明天中午去才沐'
  after 'h': top='我們明天中午去皮才'
  after 'k': top='我們明天中午去皮枖'
  after 'b': top='我們明天中午去板橋'
== schema=cangjie5_fluency grammar=OFF
-- trace 板橋 keys='dhedhkb'
  after 'd': top='來'
  after 'h': top='才'
  after 'e': top='板'
  after 'd': top='才沐'
  after 'h': top='板才'
  after 'k': top='板枖'
  after 'b': top='板橋'
-- trace 我們明天中午去板橋 keys='hqioanabmkl ojgidhedhkb'
  after 'h': top='的'
  after 'q': top='牛'
  after 'i': top='我'
  after 'o': top='牛庂'
  after 'a': top='牛庂是'
  after 'n': top='我們'
  after 'a': top='我僴'
  after 'b': top='我們明'
  after 'm': top='我僴且'
  after 'k': top='我們明天'
  after 'l': top='我們明天補'
  after ' ': top='我們明天中'
  after 'o': top='我們明天中午'
  after 'j': top='我們明天中午'
  after 'g': top='我們明天中午去'
  after 'i': top='我們明天中午去'
  after 'd': top='我們明天中午槷'
  after 'h': top='我們明天中午去才'
  after 'e': top='我們明天中午去皮'
  after 'd': top='我們明天中午去才沐'
  after 'h': top='我們明天中午去皮才'
  after 'k': top='我們明天中午去皮枖'
  after 'b': top='我們明天中午去板橋'
```

Reading the numbers (honest summary):

* In-vocabulary everyday sentences: 51/51 correct both with and without the model. essay.txt word
  weights alone are already enough for these, so the model adds nothing measurable here.
* "Hard" set (40 sentences containing characters that share one Cangjie code: 雙/隻, 佑/知, 冇/有, 困/果, ...):
  36/40 with the model, 37/40 without. The model did NOT help on this set; it flipped one sentence the wrong
  way (困倦 -> 果倦). The three misses common to both runs are true same-code collisions (雙/隻, 佑/知, 冇/有)
  where only character frequency decides; neither model nor word list can fix a character whose code is
  identical to a more frequent one (MS 新倉頡 has the same limit; the user picks the candidate).
* The model clearly changes the buffer while typing (see trace: after typing 我們明天中 the model-on buffer
  shows 中, model-off shows 補 for the same code prefix), and `板橋`/`去板橋` self-correct from 皮/才 intermediate
  forms to 板橋 once the last code is typed in both modes. Whether the model gives a net gain on real
  daily typing is NOT shown by this test set (small, written by the tester, mostly in-vocabulary).
* The only data point in favour of the model is the intermediate-buffer one above. Do not claim more.

### 3b. Candidates after typing a phrase continuously (model ON then OFF; both identical here)

```
== schema=cangjie5_fluency grammar=ON
-- 板橋  keys='dhedhkb'
  buffer: preedit='木竹水 木竹大月' candidates=['板橋', '板', '皮']
-- 中午  keys='l oj'
  buffer: preedit='中 人十' candidates=['中午', '中', '丨']
-- 已經  keys='suvfmvm'
  buffer: preedit='尸山 女火一女一' candidates=['已經', '己經', '妀', '媐', '已']
-- 恐怖  keys='mnppklb'
  buffer: preedit='一弓心 心大中月' candidates=['恐怖', '死', '恐', '丁']
-- 知道  keys='okrythu'
  buffer: preedit='人大口 卜廿竹山' candidates=['知道', '知', '佑']
-- 我們明天中午去板橋吃飯  keys='hqioanabmkl ojgidhedhkbronoihe'
  buffer: preedit='竹手戈 人日弓 日月 一大 中 人十 土戈 木竹水 木竹大月 口人弓 人戈竹水' candidates=['我們明天中午去板橋吃飯', '我們', '我', '牫', '牛']
-- 這個週末我想要去台北看電影  keys='yymrowjrybgrdjhqidupmwvgiirlmphqbumbwuafhhh'
  buffer: preedit='卜卜一口 人田十口 卜月土口 木十 竹手戈 木山心 一田女 土戈 戈口 中一心 竹手月山 一月田山 日火竹竹竹' candidates=['這個週末我想要去台北看電影', '這個週末', '這個', '這', '卞']
== schema=cangjie5_fluency grammar=OFF
-- 板橋  keys='dhedhkb'
  buffer: preedit='木竹水 木竹大月' candidates=['板橋', '板', '皮']
-- 中午  keys='l oj'
  buffer: preedit='中 人十' candidates=['中午', '中', '丨']
-- 已經  keys='suvfmvm'
  buffer: preedit='尸山 女火一女一' candidates=['已經', '己經', '妀', '媐', '已']
-- 恐怖  keys='mnppklb'
  buffer: preedit='一弓心 心大中月' candidates=['恐怖', '死', '恐', '丁']
-- 知道  keys='okrythu'
  buffer: preedit='人大口 卜廿竹山' candidates=['知道', '知', '佑']
-- 我們明天中午去板橋吃飯  keys='hqioanabmkl ojgidhedhkbronoihe'
  buffer: preedit='竹手戈 人日弓 日月 一大 中 人十 土戈 木竹水 木竹大月 口人弓 人戈竹水' candidates=['我們明天中午去板橋吃飯', '我們', '我', '牫', '牛']
-- 這個週末我想要去台北看電影  keys='yymrowjrybgrdjhqidupmwvgiirlmphqbumbwuafhhh'
  buffer: preedit='卜卜一口 人田十口 卜月土口 木十 竹手戈 木山心 一田女 土戈 戈口 中一心 竹手月山 一月田山 日火竹竹竹' candidates=['這個週末我想要去台北看電影', '這個週末', '這個', '這', '卞']
```

### 3c. Key behavior (model ON, `weasel/docs/keys_all.txt`, `--no-commit`)

"(auto-committed while typing: X)" = text that was committed to the application by that key sequence.

```
== schema=cangjie5_fluency grammar=ON
-- keys='`ban'
  buffer: preedit='`ban〔拼音〕' candidates=['辦', '版', '半', '班', '板']
-- keys="`ban'"
  buffer: preedit="`ban'〔拼音〕" candidates=['辦', '版', '半', '班', '板']
-- keys='dhe dhkb'
  buffer: preedit='木竹水 木竹大月' candidates=['板橋', '板', '皮', '才']
-- keys='dhedhkb'
  buffer: preedit='木竹水 木竹大月' candidates=['板橋', '板', '皮']
-- keys='dhedhkb!'
  (auto-committed while typing: '板橋！')
  buffer: (no composition)
-- keys='dhedhkb,'
  (auto-committed while typing: '板橋，')
  buffer: (no composition)
-- keys='dhedhkb-'
  buffer: preedit='板橋-' candidates=[]
-- keys='dhedhkb.'
  (auto-committed while typing: '板橋。')
  buffer: (no composition)
-- keys='dhedhkb;'
  buffer: preedit='板橋；' candidates=['；']
-- keys='dhedhkb='
  buffer: preedit='板橋=' candidates=[]
-- keys='dhedhkb?'
  (auto-committed while typing: '板橋？')
  buffer: (no composition)
-- keys='dhedhkbA'
  buffer: preedit='板橋A' candidates=[]
-- keys='dhedhkbAb'
  buffer: preedit='板橋Ab' candidates=[]
-- keys='dhedhkb{BackSpace}'
  buffer: preedit='木竹水 木竹大' candidates=['板枖', '板', '皮', '才']
-- keys='dhedhkb{BackSpace}{BackSpace}'
  buffer: preedit='木竹水 木竹' candidates=['皮才', '板', '皮']
-- keys='dhedhkb{Escape}'
  buffer: (no composition)
-- keys='dhedhkb.{Return}'
  (auto-committed while typing: '板橋。')
  buffer: (no composition)
-- keys='dhedhkb{Return}'
  (auto-committed while typing: '板橋')
  buffer: (no composition)
-- keys='dhedhkb{Shift_L}'
  buffer: preedit='木竹水 木竹大月' candidates=['板橋', '板', '皮']
-- keys='dhedhkb{space}'
  buffer: preedit='木竹水 木竹大月 ' candidates=['板橋', '板', '皮', '才']
-- keys='dhedhkb{space}dhe'
  buffer: preedit='木竹水 木竹大月 木竹水' candidates=['板橋板', '板橋', '板', '皮', '才']
-- keys='dhedhkb{space}{Return}'
  (auto-committed while typing: '板橋')
  buffer: (no composition)
-- keys='dhedhkb{space}{space}'
  (auto-committed while typing: '板橋 ')
  buffer: (no composition)
-- keys='dhedhkb.x'
  (auto-committed while typing: '板橋。')
  buffer: preedit='難' candidates=['的', '已', '板', '久', '曲']
-- keys='Hello'
  buffer: preedit='Hello' candidates=[]
-- keys='ldhe'
  buffer: preedit='中木竹水' candidates=['被']
-- keys='l oj'
  buffer: preedit='中 人十' candidates=['中午', '中', '丨']
-- keys='l oj{space}'
  buffer: preedit='中 人十 ' candidates=['中午', '中', '丨']
-- keys='l{space}oj'
  buffer: preedit='中 人十' candidates=['中午', '中', '丨']
```

Interpretation of 3c:
* Space with a non-empty buffer is inserted into the buffer (shown as a trailing blank); a second space
  commits the sentence and then a space (`板橋 `). Return commits the sentence. Space between codes is optional.
* `,` `.` `!` `?` commit the sentence plus the full-width punctuation (`板橋。`). `;` does not commit
  (it becomes a menu `；`), `-` and `=` are appended raw to the buffer (`板橋-`) and not committed.
* Uppercase letter after codes (`dhedhkbA`, `dhedhkbAb`): the letter is appended raw and the buffer shows
  `板橋A`, later letters stay raw too (same as eight04's difference #5). Uppercase at the start of an empty
  buffer (`Hello`) is NOT English: `H` is kept raw and `ello` are read as Cangjie codes. Use Shift to toggle
  中/西 (ascii_composer) instead.
* Backtick + pinyin reverse lookup works: `` `ban `` -> 辦 版 半 班 板 (only after the `abc` recognizer
  pattern was anchored with `^...$`; unanchored, the `abc` pattern also matched the `ban` suffix and
  reverse lookup produced Cangjie garbage).
* BackSpace removes one letter and the sentence is re-segmented; Escape clears.
* A single-letter code must be followed by a space (`l oj` = 中午; `ldhe` is read as 4 letters and gives 被).

## 4. Problems found and fixed during the run

1. `.` did not type 。 mid-sentence: default key_binder `paging_with_comma_period` made `.` page the menu.
   Fixed by building key_binder.bindings from key_bindings.yaml without the paging presets
   (`-` / `=` paging also removed).
2. Reverse lookup (backtick) broken -> anchored `abc` recognizer pattern.
3. `grammar:/hant?` is silently skipped when `grammar.yaml` is missing -> the model would silently be off.
   The schema now also sets `grammar/language` inline; verified with `shared_nogy` (no grammar.yaml).

## 5. Not tested / limits

* Weasel/Windows: nothing here ran on Windows. Weasel's librime is newer than 1.10; octagram bundling
  is only inferred from librime's release CI (see README).
* The interactive pieces (Weasel UI, Shift_L/Shift_R switch, Caps_Lock, TSF behavior) cannot be simulated
  with this driver (only RimeSimulateKeySequence key events).
* Test data was written by the tester; no statistically meaningful comparison vs MS 新倉頡.
* The user dictionary (learning) was deliberately kept out of the runs (`--no-commit`); in daily use
  user-word learning will also change results.
