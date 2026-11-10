# cangjie3_fluency Linux test log

Date: 2026-11-10. Same harness as docs/test-log.md (Ubuntu aarch64, librime 1.10 + librime-octagram via
`docs/rime_driver.py`). Linux only, nothing run on Windows/Weasel.

The table is PIME's `mscj3.cin` (downloaded to `testenv/dl3/`, git-ignored). It is NOT in the repo (license unknown).
Default branch of EasyIME/PIME verified with `gh api repos/EasyIME/PIME --jq .default_branch` = `master`;
URL used: https://raw.githubusercontent.com/EasyIME/PIME/master/python/cinbase/cin/mscj3.cin (202,819 bytes, 22,216 lines).

## 1. Converter (tools/cin2rime.py)

```
python3 -I tools/cin2rime.py testenv/dl3/mscj3.cin testenv/dl3/cangjie3.base.dict.yaml
chardef_entries: 22182
multi_char_skipped: 0
duplicates_skipped: 8        # e.g. (鲈,nmys) appears twice in the .cin
malformed_skipped: 0
written: 22174
distinct_chars: 21010
```

Notes / what had to be fixed in the converter:
* The .cin has one line `zxaa U+3000` (ideographic space). Python's `str.split()`/.NET `Trim()` treat U+3000 as
  whitespace, so the line looked malformed. The converter therefore splits/strips on ASCII space/tab/CR only
  and keeps it as an entry (21,010 distinct characters = 21,009 + U+3000).
* No uppercase codes, no empty codes, no codes outside a-z were found; rime compiled the table without errors.
* 30 codes start with `x` in the 3rd-gen table (not an X-prefix scheme like 5th gen); they are ordinary entries.

### Weights: the spec'd `100000 - rank` hurts sentence accuracy; `--essay` fixes it

First version, weight = 100000 - rank per code (all characters ~100000). Measured (model ON / OFF):

| table weights | sentences.txt (51) ON / OFF | hard.txt (40) ON / OFF |
|---|---|---|
| 100000 - rank (plain) | 51 / 47 | 37 / 31 |
| essay frequency, clamped to keep .cin order (`--essay`) | 51 / 51 | 37 / 37 |
| (reference) cangjie5_fluency v1 with the 5th-gen table | 51 / 51 | 36 / 37 |

Cause: explicit weights replace the essay.txt frequencies that cangjie5.base gets automatically. With every
character weighing ~100000, rare characters win ties in sentence building, e.g. `nnm` = 孑 beat `nn`+`m` = 了+一,
and `我欠你` came out as `牛之你`. The grammar model repairs most of it, but not without the model.
Fix: with `--essay essay.txt` the weight is the character's essay.txt frequency (min 1), clamped to be below the
previous candidate of the same code, so the .cin order is still kept (佑 okr 1357 > 知 okr 1356) and word frequency
information survives. install.ps1 does this automatically when essay.txt is available (it is installed by the
same script); without essay.txt it falls back to 100000 - rank and warns. All results below use `--essay`.

## 2. PowerShell converter vs Python: byte-identical

`Convert-CinToRime` is the function in install.ps1, extracted and run with pwsh (`~/.local/bin/pwsh`):

```
python3 -I tools/cin2rime.py mscj3.cin py_plain.yaml
python3 -I tools/cin2rime.py mscj3.cin py_essay.yaml --essay essay.txt
pwsh -NoProfile -File conv_test.ps1 mscj3.cin ps_plain.yaml
pwsh -NoProfile -File conv_test.ps1 mscj3.cin ps_essay.yaml essay.txt      # 0.4 s for 22k lines
cmp py_plain.yaml ps_plain.yaml   -> PLAIN_IDENTICAL
cmp py_essay.yaml ps_essay.yaml   -> ESSAY_IDENTICAL   (sha256 3fa5729ac8083893d4ea9f2c8edeb2d8ad74d9ebb921bedfc4d8d5138ba30def)
```

install.ps1 itself was also run end to end (pwsh, fake WeaselDeployer.exe, `-Cangjie3 -NoModel -NoDeploy`,
real downloads): fresh folder -> default.custom.yaml created with cangjie3_fluency FIRST then cangjie5_fluency;
existing `schema_list` [cangjie5_fluency, luna_pinyin] (backup made) -> cangjie3_fluency inserted first; re-run -> every file
"up to date", default.custom.yaml "already lists everything needed"; the installed cangjie3.base.dict.yaml was
byte-identical to the Python output (plain mode, since no essay.txt was in the temp folder at that time; the essay
mode was verified separately above). `grep -P '[^\x00-\x7F]' install.ps1` finds nothing (ASCII only).
Not tested: Windows PowerShell 5.1 (only pwsh 7 on this machine).

## 3. Build (both schemas in one user dir)

```
bash weasel/docs/build_c3.sh c3e          # PLAIN=1 for the 100000-rank table
real 0m4.9s   build exit=0
  cangjie3_fluency.table.bin 15,186,340  prism 688,936  (cangjie5: table 17,464,416, prism 743,792)
```

## 4. Results with the 3rd-generation table (cangjie3_fluency, codes looked up from the generated table)

Commands:

```
export SHARED=$PWD/testenv/shared_nogy USERDIR=$PWD/testenv/c3e BASE=$PWD/testenv/dl3/cangjie3.base.dict.yaml
bash weasel/docs/run_eval.sh weasel/docs/sentences.txt --quiet --no-commit --schema cangjie3_fluency
bash weasel/docs/run_eval.sh weasel/docs/hard.txt      --quiet --no-commit --schema cangjie3_fluency
bash weasel/docs/run_eval.sh weasel/docs/trace.txt     --no-commit --schema cangjie3_fluency
bash weasel/docs/run_keys.sh cangjie3_fluency c3e weasel/docs/keys_c3.txt   (and cangjie5_fluency)
```

### 4a/4b. Accuracy and trace (model ON then OFF per block)

```
### sentences (cangjie3_fluency, 3rd-gen codes)
== schema=cangjie3_fluency grammar=ON
SUMMARY grammar=ON ok=51 miss=0
== schema=cangjie3_fluency grammar=OFF
SUMMARY grammar=OFF ok=51 miss=0
### hard (cangjie3_fluency, 3rd-gen codes)
== schema=cangjie3_fluency grammar=ON
MISS want=一雙新鞋子 got=一隻新鞋子 keys='m ogeydhmltjggnd'
MISS want=佑你平安 got=知你平安 keys='okronfmfjjv'
MISS want=冇有人知道答案 got=有有人知道答案 keys='kbkbo okrythuhomrjvd'
SUMMARY grammar=ON ok=37 miss=3
== schema=cangjie3_fluency grammar=OFF
MISS want=一雙新鞋子 got=一隻新鞋子 keys='m ogeydhmltjggnd'
MISS want=佑你平安 got=知你平安 keys='okronfmfjjv'
MISS want=冇有人知道答案 got=有有人知道答案 keys='kbkbo okrythuhomrjvd'
SUMMARY grammar=OFF ok=37 miss=3
### trace
== schema=cangjie3_fluency grammar=ON
-- trace 板橋 keys='dhedhkb'
  after 'd': top='來'
  after 'h': top='才'
  after 'e': top='皮'
  after 'd': top='才沐'
  after 'h': top='皮才'
  after 'k': top='皮枖'
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
== schema=cangjie3_fluency grammar=OFF
-- trace 板橋 keys='dhedhkb'
  after 'd': top='來'
  after 'h': top='才'
  after 'e': top='皮'
  after 'd': top='才沐'
  after 'h': top='皮才'
  after 'k': top='皮枖'
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
### show
== schema=cangjie3_fluency grammar=ON
-- 板橋  keys='dhedhkb'
  buffer: preedit='木竹水 木竹大月' candidates=['板橋', '皮', '板']
-- 中午  keys='l oj'
  buffer: preedit='中 人十' candidates=['中午', '中', '丨']
-- 已經  keys='suvfmvm'
  buffer: preedit='尸山 女火一女一' candidates=['已經', '己經', '妀', '媐', '己']
-- 恐怖  keys='mnppklb'
  buffer: preedit='一弓心 心大中月' candidates=['恐怖', '死', '恐', '丁', '乛']
-- 知道  keys='okrythu'
  buffer: preedit='人大口 卜廿竹山' candidates=['知道', '佑', '知']
-- 我們明天中午去板橋吃飯  keys='hqioanabmkl ojgidhedhkbronoihe'
  buffer: preedit='竹手戈 人日弓 日月 一大 中 人十 土戈 木竹水 木竹大月 口人弓 人戈竹水' candidates=['我們明天中午去板橋吃飯', '我們', '我', '牫', '牛']
-- 這個週末我想要去台北看電影  keys='yymrowjrybgrdjhqidupmwvgiirlmphqbumbwuafhhh'
  buffer: preedit='卜卜一口 人田十口 卜月土口 木十 竹手戈 木山心 一田女 土戈 戈口 中一心 竹手月山 一月田山 日火竹竹竹' candidates=['這個週末我想要去台北看電影', '這個週末', '這個', '這', '卞']
== schema=cangjie3_fluency grammar=OFF
-- 板橋  keys='dhedhkb'
  buffer: preedit='木竹水 木竹大月' candidates=['板橋', '皮', '板']
-- 中午  keys='l oj'
  buffer: preedit='中 人十' candidates=['中午', '中', '丨']
-- 已經  keys='suvfmvm'
  buffer: preedit='尸山 女火一女一' candidates=['已經', '己經', '妀', '媐', '己']
-- 恐怖  keys='mnppklb'
  buffer: preedit='一弓心 心大中月' candidates=['恐怖', '死', '恐', '丁', '乛']
-- 知道  keys='okrythu'
  buffer: preedit='人大口 卜廿竹山' candidates=['知道', '佑', '知']
-- 我們明天中午去板橋吃飯  keys='hqioanabmkl ojgidhedhkbronoihe'
  buffer: preedit='竹手戈 人日弓 日月 一大 中 人十 土戈 木竹水 木竹大月 口人弓 人戈竹水' candidates=['我們明天中午去板橋吃飯', '我們', '我', '牫', '牛']
-- 這個週末我想要去台北看電影  keys='yymrowjrybgrdjhqidupmwvgiirlmphqbumbwuafhhh'
  buffer: preedit='卜卜一口 人田十口 卜月土口 木十 竹手戈 木山心 一田女 土戈 戈口 中一心 竹手月山 一月田山 日火竹竹竹' candidates=['這個週末我想要去台北看電影', '這個週末', '這個', '這', '卞']
```

Both blocks above: the 板橋 trace ends in `板橋` and the long sentence ends in `我們明天中午去板橋` with and
without the model (with the plain 100000-rank table it ended in `去皮橋` with the model on).
The 3 misses on hard.txt are the same same-code collisions as v1 (雙/隻, 佑/知, 冇/有).

### 4c/4d. Compatibility cases, cangjie3_fluency first, then cangjie5_fluency (same keys)

```
== schema=cangjie3_fluency grammar=ON
-- keys='mwyl'
  buffer: preedit='一田卜中' candidates=['面']
-- keys='mwsl'
  buffer: preedit='mwsl' candidates=[]
-- keys='lmyyy'
  buffer: preedit='中一卜卜卜' candidates=['非', '卝']
-- keys='lmsy'
  buffer: preedit='中一 尸卜' candidates=['丄习', '丄']
-- keys='ohs'
  buffer: preedit='人竹尸' candidates=['作']
-- keys='oos'
  buffer: preedit='人人 尸' candidates=['仌區', '仌', '从']
-- keys='okr'
  buffer: preedit='人大口' candidates=['佑', '知']
-- keys='xokr'
  buffer: preedit='xokr' candidates=[]
-- keys='dhedhkb'
  buffer: preedit='木竹水 木竹大月' candidates=['板橋', '皮', '板']
-- keys='l oj'
  buffer: preedit='中 人十' candidates=['中午', '中', '丨']
== schema=cangjie5_fluency grammar=ON
-- keys='mwyl'
  buffer: preedit='mwyl' candidates=[]
-- keys='mwsl'
  buffer: preedit='一田尸中' candidates=['面']
-- keys='lmyyy'
  buffer: preedit='中一卜 卜卜' candidates=['卝卞', '卝']
-- keys='lmsy'
  buffer: preedit='中一尸卜' candidates=['非']
-- keys='ohs'
  buffer: preedit='人竹 尸' candidates=['入駐', '入局', '入耳', '入聖', '入羣']
-- keys='oos'
  buffer: preedit='人人尸' candidates=['作']
-- keys='okr'
  buffer: preedit='人大口' candidates=['知', '佑']
-- keys='xokr'
  buffer: preedit='難人大口' candidates=['佑']
-- keys='dhedhkb'
  buffer: preedit='木竹水 木竹大月' candidates=['板橋', '板', '皮']
-- keys='l oj'
  buffer: preedit='中 人十' candidates=['中午', '中', '丨']
```

What this shows:
* 面: `mwyl` -> 面 in cangjie3_fluency; in cangjie5_fluency `mwyl` gives nothing (raw), `mwsl` gives 面.
  In cangjie3_fluency `mwsl` is raw.
* 非: `lmyyy` -> 非 (3rd gen); `lmsy` -> 非 in cangjie5_fluency only (cangjie3 gives other characters).
* 作: `ohs` -> 作 (3rd gen); in cangjie5_fluency `oos` -> 作 and `ohs` becomes 入… words.
* 知 / 佑 share `okr` in 3rd gen: first candidate is 佑 (the order of mscj3.cin), 知 is the second candidate on the
  same page, so both are reachable by choosing the second candidate (or by typing the word, e.g. 知道 is
  produced correctly in sentences). cangjie5_fluency lists 知 first and reaches 佑 via `xokr` (難 prefix); `xokr` does
  nothing in cangjie3_fluency (no X-prefix scheme in 3rd gen).
* (d) Typing a 3rd-gen code for a character whose 5th-gen code differs yields the 3rd-gen character in
  cangjie3_fluency and not in cangjie5_fluency (面 mwyl, 非 lmyyy, 作 ohs: see the two blocks).

Limits: tester-written sentences, Linux librime 1.10 only, no Windows run. Whether the 3rd-gen table in
`mscj3.cin` equals Windows XP's new Cangjie exactly was not verified (only that the 4 compatibility characters match
the codes the owner gave).
