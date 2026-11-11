# cangjie-fluency

全碼倉頡的「整句輸入」Rime 方案：**預設是倉頡三代（Windows XP 新倉頡的碼表），可選倉頡五代**，目標是接近微軟新倉頡的手感：連續打完整串碼，緩衝區會自動修正，不必逐字選字。

Sentence-style full Cangjie input schema for Rime (Weasel on Windows): **3rd generation by default (the table behind Windows XP's 新倉頡), 5th generation optional**, aiming at the feel of Microsoft 新倉頡.

- `weasel/` — 方案檔（`cangjie5_fluency` v1、實驗性 `_v2`）、繁中安裝說明 `README.zh-TW.md`、Linux 測試記錄與測試腳本
- `docs/item4-analysis.md` — 空白鍵、符號、大寫字母與微軟新倉頡差異的原始碼分析（英文）
- `lua/` — 空緩衝區直接送字的 Lua 處理器草稿（**未測試**）
- `docs/rime-quick-2-comment*.md` — 送給 rime/rime-quick#2 的留言

Contents (English):

- `weasel/` — schema files (`cangjie5_fluency` v1, experimental `_v2`), the Traditional Chinese install guide `README.zh-TW.md`, Linux test logs and test scripts
- `docs/item4-analysis.md` — source-code analysis of how the space key, symbols and capital letters differ from Microsoft 新倉頡 (in English)
- `lua/` — draft Lua processor that sends characters straight through when the buffer is empty (**untested**)
- `docs/rime-quick-2-comment*.md` — comments posted to rime/rime-quick#2

**其他平台 / Other platforms:** Linux（fcitx5-rime、fcitx-rime、ibus-rime）→ [githubhjs/cangjie-fluency-linux](https://github.com/githubhjs/cangjie-fluency-linux)；
macOS（鼠鬚管 Squirrel）→ [githubhjs/cangjie-fluency-macos](https://github.com/githubhjs/cangjie-fluency-macos)。兩者都是從本倉庫下載方案檔，只多一個安裝腳本。

Linux (fcitx5-rime, fcitx-rime, ibus-rime) → [githubhjs/cangjie-fluency-linux](https://github.com/githubhjs/cangjie-fluency-linux); macOS (Squirrel) → [githubhjs/cangjie-fluency-macos](https://github.com/githubhjs/cangjie-fluency-macos). Both download the schema files from this repository and only add an installer script.

## 一鍵安裝（Windows 10/11，需要能裝軟體的管理員權限） / One-click install

在 PowerShell 貼一行（用一般使用者執行，只有裝小狼毫那一步會跳 UAC）：

```powershell
irm https://raw.githubusercontent.com/githubhjs/cangjie-fluency/main/install.ps1 | iex
```

Paste one line into PowerShell (run it as a normal user; only the Weasel installation step shows a UAC prompt):

```powershell
irm https://raw.githubusercontent.com/githubhjs/cangjie-fluency/main/install.ps1 | iex
```

或到 [Releases](https://github.com/githubhjs/cangjie-fluency/releases) 下載壓縮包，解壓縮後雙擊 `install.bat`。

Or download the zip from [Releases](https://github.com/githubhjs/cangjie-fluency/releases), unzip it and double-click `install.bat`.

腳本會：安裝小狼毫（用 winget，沒裝才裝）→ 下載缺的碼表與語言模型 → 複製方案 → 保守合併 `default.custom.yaml`（先備份）→ 重新部署。
**預設安裝三代倉頡 `cangjie3_fluency`**（Windows XP 內建的新倉頡是三代的修改版），並放在方案清單第一個，Weasel 原本的方案接在後面、不會被拿掉。
裝完按 `Ctrl+`` 或 `F4` 切到 `cangjie3_fluency`。可用 `-DryRun` 先看它會做什麼。重複執行是安全的：內容相同的檔案不會重複備份或覆蓋。

The script: installs Weasel (via winget, only if it is missing) → downloads the missing code table and language model → copies the schema → conservatively merges `default.custom.yaml` (backed up first) → redeploys.
**By default it installs the 3rd-generation Cangjie schema `cangjie3_fluency`** (the new Cangjie built into Windows XP is a modified 3rd generation) and lists it first in the schema list; Weasel's original schemas stay after it and are not removed.
When it finishes, press `Ctrl+`` or `F4` and switch to `cangjie3_fluency`. Use `-DryRun` to see first what it would do. Re-running is safe: files with identical content are not backed up or overwritten again.

要加參數時，`irm | iex` 傳不了參數，用這個寫法（等於下載後執行）：

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/githubhjs/cangjie-fluency/main/install.ps1))) -Cangjie5
```

`irm | iex` cannot pass parameters; to add parameters use the form above (it downloads the script and then runs it).

| 參數 / Parameter | 作用 / Effect |
|---|---|
| （不加） / (none) | 三代 `cangjie3_fluency` / 3rd generation `cangjie3_fluency` |
| `-Cangjie5` | 另外裝五代 `cangjie5_fluency` / also install the 5th generation `cangjie5_fluency` |
| `-NoCangjie3` | 不裝三代，改裝五代（舊版的預設行為） / do not install the 3rd generation, install the 5th instead (the old default) |
| `-WithV2` | 再加實驗性的 v2（排在 v1 後面，不會變成預設；會一併裝五代） / also add the experimental v2 (listed after v1, never the default; installs the 5th generation too) |
| `-NoSweep` | 不安裝倉頡滑行面板（預設會安裝） / do not install Cangjie Sweep Pad (installed by default) |
| `-PadRef <tag>` | 指定倉頡滑行面板版本（預設 v0.3.0） / specify Sweep Pad release tag (default: v0.3.0) |
| `-Uninstall` | 移除倉頡滑行面板與捷徑 / remove Sweep Pad and shortcut |
| `-NoModel` / `-DryRun` / `-NoDeploy` | 不下載語言模型／只顯示不做／只複製檔案不部署 / do not download the language model / only show, change nothing / copy files only, do not deploy |

三代碼表 `tables/mscj3.cin` 就放在本倉庫（來源、雜湊與使用說明見 `tables/README.md`），安裝時在你的電腦上轉換成 Rime 格式；語言模型與詞表也都在本倉庫（`data/`）。**安裝時只從本倉庫取檔，不需要連到任何第三方**（小狼毫本身除外，見下）。五代碼表約兩成的字碼與三代不同，詳見 `weasel/README.zh-TW.md` 第 6c 節。

The 3rd-generation table `tables/mscj3.cin` is kept in this repository (source, hash and usage notes are in `tables/README.md`) and is converted to Rime format on your computer during installation; the language model and word list are also in this repository (`data/`). **The installer fetches files only from this repository and needs no third party** (except Weasel itself, see below). About 20% of the 5th-generation codes differ from the 3rd generation; see section 6c of `weasel/README.zh-TW.md`.

進階：也可以用東風破（[plum](https://github.com/rime/plum)）`rime-install githubhjs/cangjie-fluency`（Windows 需要 plum 的 bootstrap 包，內含 git、7z）。
**但只適合從沒自訂過方案清單的人，其他人請用上面的一行安裝：**
- plum 會把 `default.custom.yaml` 的內容直接附加在檔案後面。從小狼毫方案選單產生的那種檔案沒有結尾換行，附加後 YAML 會壞掉，
  而且畫面上沒有任何錯誤；就算沒壞，你原本的清單也會被小狼毫的預設清單取代（Windows 實測：原有的方案消失）。
- 小狼毫自帶的 `rime-install-config.bat` 會強制改用登錄檔裡的使用者資料夾，所以 `rime_dir=` 不能讓你先在暫存資料夾試跑，
  它會直接改到你真正的設定。**用之前請先備份 `%APPDATA%\Rime\default.custom.yaml`。**
**腳本在 Linux 的 PowerShell 上驗證過邏輯，Windows 上的完整流程尚待實測。**

Advanced: you can also use Plum (東風破, [plum](https://github.com/rime/plum)): `rime-install githubhjs/cangjie-fluency` (on Windows this needs plum's bootstrap package, which contains git and 7z).
**But it is only suitable for people who never customised their schema list; everyone else should use the one-line install above:**
- plum appends the content of `default.custom.yaml` directly to the end of the file. A file generated from Weasel's schema menu has no trailing newline, so after appending the YAML is broken, and nothing on screen reports an error; even when it is not broken, your original list is replaced by Weasel's default list (tested on Windows: the schemas you had disappeared).
- Weasel's own `rime-install-config.bat` forces the user folder from the registry, so `rime_dir=` cannot be used to try it out in a temporary folder first; it edits your real configuration directly. **Back up `%APPDATA%\Rime\default.custom.yaml` before using it.**
**The script's logic was verified under PowerShell on Linux; the complete flow on Windows still needs testing.**

## 狀態 / Status

- 已測：**Windows 11 + 小狼毫 0.17.4**（v1、v2 都測過；三代版部署成功）、**macOS 26 + 鼠鬚管 1.1.2**（本人實際打字確認）、Linux（librime 1.10 + librime-octagram；ibus-rime 經 IBus API 實機測 10/10）。建議日常用 v1（預設是三代 `cangjie3_fluency`），理由見 `docs/xp-behavior-notes.md`。
- 語言模型：我們的測試句（51 句日常句、40 句同碼難句、91 句整句、34 個同碼字詞組如「手感／手怠」「頻率／顏率」）有無模型的結果幾乎相同，因為這些詞在詞表 `essay.txt` 已有詞頻；我們還沒找到能量出模型差異的案例（數字見 `weasel/docs/test-log.md`）。
- 單字碼要接空白（例如「中午」打 `l oj`）。
- 語言模型檔 `data/zh-hant-t-essay-bgw.gram`（41,415,724 B）**已附在本倉庫**，安裝腳本直接從這裡取得並核對 SHA-256。

English:

- Tested: **Windows 11 + Weasel 0.17.4** (both v1 and v2 tested; the 3rd-generation schema deployed successfully), **macOS 26 + Squirrel 1.1.2** (typing confirmed by the owner in person), Linux (librime 1.10 + librime-octagram; ibus-rime tested 10/10 on a real machine through the IBus API). Using v1 for daily work is recommended (the default is the 3rd-generation `cangjie3_fluency`); reasons in `docs/xp-behavior-notes.md`.
- Language model: on our test sentences (51 everyday sentences, 40 hard same-code sentences, 91 whole sentences, 34 same-code word groups such as 「手感／手怠」「頻率／顏率」) the results with and without the model are almost identical, because these words already have frequencies in the word list `essay.txt`; we have not yet found a case that measures a difference from the model (numbers in `weasel/docs/test-log.md`).
- A single-key code must be followed by a space (for example 「中午」 is typed `l oj`).
- The language model file `data/zh-hant-t-essay-bgw.gram` (41,415,724 B) is **included in this repository**; the installer fetches it from here and checks its SHA-256.

## 來源與授權 / Credits and license

- 基於 [rime/rime-cangjie](https://github.com/rime/rime-cangjie) 的《五倉世紀版》碼表、[rime/rime-quick](https://github.com/rime/rime-quick) 以及 eight04 在 [rime-quick#2](https://github.com/rime/rime-quick/issues/2) 提出的 `quick5_fluency` 原型。
- 倉頡輸入法本身由朱邦復先生創製，他已公開放棄專利權。
- 授權：LGPL-3.0（與上游 rime-quick、rime-cangjie 一致），見 `LICENSE`。

English:

- Based on the 《五倉世紀版》 code table of [rime/rime-cangjie](https://github.com/rime/rime-cangjie), on [rime/rime-quick](https://github.com/rime/rime-quick), and on the `quick5_fluency` prototype proposed by eight04 in [rime-quick#2](https://github.com/rime/rime-quick/issues/2).
- The Cangjie input method itself was created by Mr. Chu Bong-Foo (朱邦復), who has publicly waived his patent rights.
- Licence: LGPL-3.0 (same as upstream rime-quick and rime-cangjie), see `LICENSE`.

## 鄰鍵容錯（隨附，預設不啟用）/ Adjacent-key typo tolerance (included, not the default)

安裝時會一併裝入「鄰鍵容錯」方案 `cangjie3_fuzzy`（有選五代時還有 `cangjie5_fuzzy`），排在清單第二位；預設方案仍是 `cangjie3_fluency`。打錯一個相鄰按鍵（例如把 `yhmbc` 打成 `yhmbv`）時，也會列出「顏」，正確的候選永遠排在最前面。
選項：`-NoFuzzy` 不裝；`-FuzzyRange narrow|normal|wide` 範圍（左右相鄰／再加斜向〔預設〕／再多一圈）；`-FuzzyDefault` 讓它排第一。
想要它變成預設方案（不必按 Ctrl+` 或 F4 切換），請改用獨立專案 **cangjie-fuzzy-windows**（同樣內含完整的 cj*fluency，一行指令安裝）。依據與預設值：<https://github.com/githubhjs/cangjie-fuzzy-core/blob/main/DEFAULTS.md>

The adjacent-key schema `cangjie3_fuzzy` (and `cangjie5_fuzzy` with Cangjie 5) is installed too, listed second; `cangjie3_fluency` stays the default. When one key is wrong and it is a physical neighbour (`yhmbv` for `yhmbc`) the intended character is offered as well, and exact candidates always come first.
Options: `-NoFuzzy` skip it; `-FuzzyRange narrow|normal|wide` range (left/right only / plus diagonals (default) / one more ring); `-FuzzyDefault` list it first.
To make it the default schema (no Ctrl+` / F4 needed) use the separate project **cangjie-fuzzy-windows** (it contains the full cj*fluency too; one-line install). Evidence for the defaults: the DEFAULTS.md linked above.

## 倉頡滑行輸入面板（隨附） / Cangjie Sweep Pad (included)

Windows 安裝程式預設會一併安裝「倉頡滑行輸入面板」（[cangjie-fuzzy-core](https://github.com/githubhjs/cangjie-fuzzy-core) 的 `cangjie_sweep_pad.py`），提供滑鼠／觸控在虛擬鍵盤上滑行或點擊輸入倉頡碼的功能。

- **安裝位置**：`%LOCALAPPDATA%\cangjie-sweep`
- **啟動方式**：從「開始」功能表開啟「Cangjie Sweep 倉頡滑行」，或執行安裝資料夾內的 `cangjie-sweep.bat`。
- **系統需求**：Python 3.8 以上且支援 tkinter（若無 Python，可執行 `winget install Python.Python.3.12` 安裝；若未偵測到 Python，Rime 方案本身仍會順利安裝完成）。
- **重要事項**：使用滑行面板向目標軟體送字時，**目標應用程式內的作用中輸入法必須是小狼毫（Weasel / Rime）**。
- **選項**：可傳入 `-NoSweep` 略過安裝，或 `-PadRef <tag>` 指定版本。

English:

The Windows installer installs the "Cangjie Sweep Pad" (`cangjie_sweep_pad.py` from [cangjie-fuzzy-core](https://github.com/githubhjs/cangjie-fuzzy-core)) by default, providing mouse and touch glide/click typing on an on-screen keyboard.

- **Location**: `%LOCALAPPDATA%\cangjie-sweep`
- **How to launch**: Open "Cangjie Sweep 倉頡滑行" from the Start Menu, or run `cangjie-sweep.bat` in the install folder.
- **Prerequisites**: Python 3.8+ with tkinter (install via `winget install Python.Python.3.12`; if Python is missing, the Rime schema installation still succeeds).
- **IMPORTANT**: When typing via the Sweep Pad, **Weasel (Rime) MUST be the active input method in your target application**.
- **Options**: Pass `-NoSweep` to skip installing the pad, or `-PadRef <tag>` to pin a specific release version.

## Changelog / 更新紀錄

- **v0.6.1** — Sweep Pad v0.3.0: tolerance for backtracks. / 滑行輸入板 v0.3.0：容許回頭滑行。
- **v0.6.0** — Sweep Pad added; default on, `-NoSweep` to skip. / 新增倉頡滑行輸入板；預設安裝，加 `-NoSweep` 可略過。
