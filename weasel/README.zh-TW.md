# 倉頡整句（cangjie5_fluency）— 小狼毫 Weasel 安裝說明

目標：全碼倉頡五代（不是速成），像微軟新倉頡一樣「整句輸入」：一路打下去不選字，緩衝區會隨著
你繼續輸入、用詞庫＋語言模型重新斷詞，所以「板橋」不會停在「皮橋」。

> 狀態：Linux（librime 1.10 + librime-octagram）測試通過。
> **Windows 11 + 小狼毫 0.17.4 已實測（2026-11-10）**：部署成功、`dhedhkb` → `板橋`、日誌有 `use grammar`。
> 見第 10 節。Linux 測試過程與真實輸出見 `docs/test-log.md`。

## 1. 檔案

| 檔案 | 放哪裡 |
|---|---|
| `cangjie5_fluency.schema.yaml` | `%APPDATA%\Rime\` |
| `cangjie5_fluency_v2.schema.yaml`（選用，實驗版，見第 6b 節） | `%APPDATA%\Rime\` |
| `cangjie5_fluency.dict.yaml` | `%APPDATA%\Rime\` |
| `default.custom.yaml` | `%APPDATA%\Rime\`（**已有自己的就不要覆蓋，見第 4 節合併**） |

`%APPDATA%\Rime` 通常是 `C:\Users\<你>\AppData\Roaming\Rime`（在檔案總管網址列貼上 `%APPDATA%\Rime` 即可）。
也可以在工具列的小狼毫圖示按右鍵 →「用戶文件夾」直接打開。

## 2. 還需要的三個資料檔

這個方案的詞庫是從「單字全碼表」＋詞彙表 `essay.txt` 自動組出來的，語言模型是八股文 `.gram`。

| 檔案 | 大小（實測） | 下載位置 | 放哪裡 |
|---|---|---|---|
| `cangjie5.base.dict.yaml` | 219,115 B（約 214 KB） | https://raw.githubusercontent.com/rime/rime-cangjie/master/cangjie5.base.dict.yaml | `%APPDATA%\Rime\`（**小狼毫 0.17.4 不內建，必須自己下載**，見下） |
| `essay.txt` | 5,887,319 B（約 5.6 MB） | https://raw.githubusercontent.com/rime/rime-essay/master/essay.txt | 小狼毫 0.17.4 已內建（`data\essay.txt`，6,330,573 B，版本不同但可用） |
| `zh-hant-t-essay-bgw.gram` | 41,415,724 B（約 39.5 MiB） | https://github.com/lotem/rime-octagram-data/raw/hant/zh-hant-t-essay-bgw.gram（注意是 **hant 分支**） | `%APPDATA%\Rime\`（**小狼毫不內建，必須自己下載**；不要 commit 進 git，已列入 `.gitignore`） |
| `grammar.yaml`（選用） | 775 B | https://raw.githubusercontent.com/lotem/rime-octagram-data/master/grammar.yaml | `%APPDATA%\Rime\`；本方案已把同樣設定寫在 schema 內，缺這個檔也能用 |

### 檢查小狼毫是否已內建前兩個檔

PowerShell：

```powershell
# 安裝路徑依版本而異（常見 C:\Program Files (x86)\Rime\weasel-<版本>\data），所以兩個地方都找：
Get-ChildItem "C:\Program Files*\Rime","$env:APPDATA\Rime" -Recurse -Include cangjie5.base.dict.yaml,essay.txt -ErrorAction SilentlyContinue | Select FullName,Length
```

找不到（或大小差很多）就從上表網址下載，放進 `%APPDATA%\Rime\`。

依據：小狼毫內建的「預設配方」（rime/plum 的 `preset-packages.conf`）包含 `cangjie`、`essay`、`prelude`、
`luna-pinyin`、`quick` 等，所以理論上 `data\` 內會有 `cangjie5.base.dict.yaml` 和 `essay.txt`。

**實測（小狼毫 0.17.4，2026-11-10）：這個推論只對一半。** `data\` 內有 `essay.txt`，但**沒有**
`cangjie5.base.dict.yaml`（只有舊式單檔的 `cangjie5.dict.yaml`、`cangjie5.schema.yaml`、`cangjie5_express.schema.yaml`）。
0.15.0 也一樣沒有。所以 `cangjie5.base.dict.yaml` 一定要自己下載放進 `%APPDATA%\Rime\`，否則詞庫編不起來。

## 3. 小狼毫有沒有內建 librime-octagram？（語言模型外掛）

**實測確認（小狼毫 0.17.4，2026-11-10）：有內建。** `rime.dll` 內含 `octagram.cc` 字串，
切換到「倉頡整句」後日誌出現 `octagram.cc:29] use grammar: zh-hant-t-essay-bgw`。
注意：這行**部署時不會出現**，要等實際在某個程式裡切到這個方案開始打字（建立 session）才會印出。

以下是實測前從原始碼找到的依據：

* rime/librime 的 Windows 發佈 CI（`.github/workflows/release-ci.yml`）建置時加入的外掛為
  `hchunhui/librime-lua lotem/librime-octagram rime/librime-predict`。
* 小狼毫（rime/weasel）的 `get-rime.ps1` 直接下載 rime/librime 的發佈版 `rime.dll`，沒有自己另外挑外掛。
* 小狼毫最新發佈：`0.17.4.98`（2026-10-31，標 latest，疑似 nightly），穩定版 `0.17.4`（2025-06-04）。
  這兩版實際內含的 librime 版本我沒有核對。

我沒有在 Windows 安裝安裝檔去驗證 `rime.dll` 內是否真的含 octagram。**最可靠的驗證方式是部署後看日誌**：
日誌裡應該有 `octagram.cc:... use grammar: zh-hant-t-essay-bgw`。沒有這行 = 外掛沒載入。
**但這行在 `.gram` 檔不存在時也會印出**（Linux 實測：後面會接一行 `failed to load grammar database`），
所以要同時確認「有 `use grammar`」和「**沒有** `failed to load grammar`」才算語言模型真的載入。
（沒載入時方案仍可用，但等於沒有語言模型。）

## 4. default.custom.yaml 合併方式

`default.custom.yaml` 的 `patch: schema_list:` 會**整份取代**預設的方案清單。

* 你還沒有 `%APPDATA%\Rime\default.custom.yaml`：直接複製本資料夾的檔案即可。
* 你已經有：**不要覆蓋**。打開自己的檔案，在 `schema_list:` 底下加一行
  `    - schema: cangjie5_fluency`（放第一個 = 預設方案），其餘行保持原樣。
  如果你的檔案裡還沒有 `schema_list`，把本檔 `patch:` 下的整段貼進去。

## 5. 部署與切換

1. 把檔案放好後，在工具列小狼毫圖示按右鍵 → **重新部署**（或開始功能表 →「小狼毫輸入法」→「重新部署」）。
2. 第一次部署要編譯詞庫（Linux aarch64 約 3.3 秒、產生約 17 MB 的 table；Windows 11 筆電上整個部署約 33 秒，
   `cangjie5_fluency.table.bin` 17,466,708 B），
   完成會跳出「部署完成」類通知。
3. 切換方案：按 `Ctrl` + 反引號鍵（鍵盤左上角 1 左邊那顆）或 `F4` 打開方案選單，選「倉頡整句」。
4. 改過 yaml 或換了 .gram 都要再「重新部署」一次。

## 6. 打法（跟微軟新倉頡一樣的地方）

* 直接一路打字根，不用選字、不用空格：`dhedhkb` → 緩衝區 `板橋`。繼續打會自動重新斷詞修正前面的字。
* **只有一個字根的字，後面要接空格**（例如「中」= `l`，「中午」打 `l oj`）；其他字碼之間空格可有可無。
* 空格：緩衝區有字時，空格只是加進緩衝區；連按兩次空格 = 上屏並輸出一個空格。Enter = 上屏整句。
* `，` `。` `！` `？`（鍵盤 `,` `.` `!` `?`）會把整句上屏並接標點。
* Backspace 退一個字根（並重新斷詞）、Esc 清空。
* 同碼字（如 雙/隻、佑/知）只能靠詞頻，錯了用上下鍵或 `PageDown` 換候選。
* 反查：打 `` ` `` 後輸入拼音（例如 `` `ban `` → 辦 版 半 班 板）。需要 `luna_pinyin` / `luna_quanpin`，小狼毫內建。
* Shift（左）：切換中／西文，並把緩衝區文字上屏；右 Shift 把緩衝區以英文字母上屏。

## 6b. v1 與 v2 該用哪個？（以下全部只在 Linux librime 1.10 測過，Windows 未測）

| 行為 | v1 `cangjie5_fluency`（建議先用） | v2 `cangjie5_fluency_v2`（實驗） |
|---|---|---|
| 空格，緩衝區空 | 上屏一個空格 | 空格直接交給應用程式（效果相同） |
| 空格，緩衝區有字 | 進緩衝區 | 進緩衝區 |
| 連按兩次空格 | 整句上屏＋空格 | **只確認整句，不上屏**，還要再按 Enter |
| `, . ? ! :` | 整句上屏＋全形標點（立刻） | 全形標點**附加在緩衝區**，要 Enter 才一起上屏；緩衝區空時打 `，` 也是留在緩衝區 |
| `;` | 變成候選 `；` | 當成分隔符（顯示 `·`） |
| 大寫字母在碼之後 | 大寫與其後所有字母都原樣留在緩衝區（`板橋Ab`） | 大寫原樣留下，**之後的小寫繼續當倉頡碼**（`板橋A月`） |
| 空緩衝區打 `Hello` | `Hello` 原樣留在緩衝區（Enter 上屏） | `H` 留下，`ello` 被當倉頡碼（亂碼） |
| `dheAdhkb` | `板Adhkb`（A 之後不再轉換） | `板A` + 倉頡 `dhkb`；首選是「才有」，`橋` 是第二候選（不是 `板A橋`） |
| 數字／符號，緩衝區空 | 進緩衝區（`1` `(` `#` 都不會直達應用程式） | 同 v1 |
| 句子正確率、斷詞、反查、BackSpace、Return | 與 v2 完全相同（91 句測試結果逐項一致） | 同左 |

v2 修改的設定：`speller/use_space: true`（拿掉 punctuator 的空格）、`half_shape` 標點改成純值、
`recognizer` 不再 `import_preset: default`（它的 `uppercase` 規則會吞掉大寫之後的按鍵）、
改用內建 `abc_segmentor`。

建議：**日常先用 v1**（標點會立刻上屏，較不容易出意外）。v2 是為了更接近「標點留在緩衝區、大寫後可繼續打中文」，
但標點必須靠 Enter 上屏這點對日常打字是明顯的行為改變，且是否更接近微軟新倉頡**未驗證**。
作者（XP 新倉頡老使用者）的回憶：XP 的標點確實留在虛線區內，但他**不喜歡**這樣，因為相關詞常常跨不過逗號句號，
標點應該切斷整句上下文。這正是 v1 的行為，所以 v1 是預設建議（見 `docs/xp-behavior-notes.md`，內容是個人回憶，不是微軟文件）。
v2 沒有造成辨識正確率退步，但上表的行為差異請你實際試過再決定。

## 6c. 三代倉頡版本 cangjie3_fluency（Windows XP 新倉頡的碼表）

**為什麼**：Windows XP 內建的「新倉頡」是改良過的**三代**倉頡，本專案預設的 cangjie5_fluency 用五代碼表，
約兩成的字碼不同（例如「面」三代 `mwyl`、五代 `mwsl`；「作」三代 `ohs`、五代 `oos`；「非」三代 `lmyyy`、五代 `lmsy`）。
五代對同碼的第二個字會加 X（難）前綴，三代沒有：「知」「佑」三代同碼 `okr`，佑排第一、知是第二個候選。

**安裝**：在 PowerShell 執行

```powershell
.\install.ps1 -Cangjie3
```

腳本會安裝 `cangjie3_fluency`（引擎行為與 v1 `cangjie5_fluency` 相同，只換碼表），並把它放在
`default.custom.yaml` 方案清單的**第一個**（已有清單則插入第一項）。

**碼表來源**：PIME 專案的 `mscj3.cin`
（https://raw.githubusercontent.com/EasyIME/PIME/master/python/cinbase/cin/mscj3.cin，約 200 KB）。
這個檔案**沒有授權聲明，所以不在本專案內**：安裝時才從 PIME 下載，在你的電腦上轉換成
`cangjie3.base.dict.yaml`（轉換器 `tools/cin2rime.py`；install.ps1 內有逐位元組相同輸出的 PowerShell 版）。
轉換時會用 essay.txt 的字頻當權重，同碼字仍維持 .cin 的順序。若沒有 essay.txt，句子正確率會明顯下降
（Linux 測試，不載入語言模型時：一般 51 句 47/51、困難組 40 句 31/40；有 essay.txt 權重則為 51/51、37/40）。

**測試狀態**：只在 Linux（librime 1.10）測過；PowerShell 轉換只在 pwsh 7 測過，Windows PowerShell 5.1 與小狼毫實機都沒測。
詳見 `docs/test-log-cangjie3.md`。三代碼表是否與 Windows XP 新倉頡完全一致**未驗證**（只核對了面、非、作、知／佑）。

## 7. 若部署失敗 / 編譯不過

1. 看日誌：**小狼毫 0.17.4 放在資料夾 `%TEMP%\rime.weasel\`**（例如
   `%TEMP%\rime.weasel\rime.weasel.<電腦名>.<使用者>.log.INFO.<日期>-<時間>.<pid>.log`）；
   舊版（0.15.0 實測）則是直接放在 `%TEMP%\rime.weasel.*`。先看 ERROR / WARNING 檔，再看 INFO。
   PowerShell 一行找語言模型：
   `Select-String -Path "$env:TEMP\rime.weasel\*.log" -Pattern 'use grammar|failed to load grammar' | Select -Last 5`
   （有 `use grammar` 且其後**沒有** `failed to load grammar database` 才算載入成功；缺 `.gram` 時兩行都會出現）
   * WARNING 檔有數百行 `Encode failure` 和 `duplicate word definition` 是正常的（essay 內碼表沒有的字詞被略過）。
   * `nonexistent config file '...\grammar.yaml'` 也是正常的（選用檔，見第 2 節）。
2. 常見原因：
   * `missing input file` / `cangjie5.base` 找不到 → 第 2 節的 `cangjie5.base.dict.yaml` 沒放好。
   * `essay.txt` 找不到：詞庫只剩單字，整句效果很差 → 補上 essay.txt。
   * INFO 檔沒有 `use grammar: zh-hant-t-essay-bgw` → `.gram` 沒放進 `%APPDATA%\Rime\`、檔名打錯，
     或這版小狼毫沒內含 octagram。
   * YAML 縮排用了 Tab：一律用空格。檔案要存成 UTF-8（無 BOM 或有 BOM 皆可，勿用 ANSI/Big5）。
3. 清掉舊的編譯結果再重新部署：關閉小狼毫 → 刪除 `%APPDATA%\Rime\build\` → 重新部署。
4. 想比較有無語言模型：Linux 上的做法是不載入 octagram 外掛（見 `docs/test-log.md`），詞庫權重照常運作；
   在 Windows 上「刪掉 .gram 會怎樣」我沒測過（未測，可能只是警告，也可能整句失效），請先備份再試。
5. 想自訂：新增 `%APPDATA%\Rime\cangjie5_fluency.custom.yaml`，schema 末尾已掛上
   `cangjie5_fluency.custom:/patch?`，不需要改原檔。

## 8. 跟微軟新倉頡仍有的差異（全部 **Windows 上未測**）

1. **空格鍵**：微軟新倉頡「緩衝區為空時直接輸出空白，否則空白進緩衝區」（依 eight04 的描述，未獨立驗證）。
   v1、v2 皆是：緩衝區有字時空格進緩衝區、空時輸出空白；連按兩次空格 v1 上屏＋空白、v2 只確認。（Linux 測得；Windows 未測）
2. **大寫字母**：v1 大寫與其後字母都原樣留在緩衝區（`板橋Ab`，issue #2 第 5 點的現象仍在）；
   v2 大寫後的小寫會繼續轉成中文（第 5 點算是解掉），但空緩衝區打 `Hello` 會變亂碼；
   兩版的空緩衝區大寫字母都不會直達應用程式。想打英文請用 Shift 切換。（Linux 測得；Windows 未測）
3. **符號**：v1 `,` `.` `!` `?` `:` 立刻上屏整句＋全形標點；v2 標點附加在緩衝區（issue 第 4 點的訴求），
   但空緩衝區的符號／數字兩版都不會直達應用程式（留在緩衝區，Enter 上屏）。`-` `=` 兩版都原樣進緩衝區。
   其他半形符號是否都比照微軟，沒有逐一核對。（Linux 測得；Windows 未測）
4. **字典差異**：碼表是《五倉世紀》（rime-cangjie），不是微軟新倉頡自己的表；例如「麵」在這裡是 `jemwl`
   （「麪」`jemls`），eight04 也回報過「麵」這類字與微軟不一樣。同碼字排序是依 essay.txt 詞頻，不是微軟的排序。（未測）
5. **語言模型效果**：Linux 小測試（91 句）中加了八股文模型並沒有讓最終結果變好（詞頻本身已經夠用，
   少數同碼字衝突兩邊都會錯），只在輸入中途的緩衝區顯示上看得到差異。實際日常打字好不好用要靠你實測。
6. **使用者詞庫學習**：Rime 會學習你上屏的詞，可能把偶發的錯字學進去，和微軟的行為不同。（未測）
7. **`fluency_editor` 的行為**：Return 上屏整句、Ctrl+Return 上屏原始字母、Shift+Return 上屏預編碼文字。（Linux 只驗證了 Return）

## 9. 來源與致謝

* 方案設計取自 eight04 在 rime/rime-quick issue #2 提出的 `quick5_fluency`（fluency_editor、不使用
  abc_segmentor、`abc` recognizer pattern、單碼補空格、punctuator 空格處理）。
* 碼表 rime/rime-cangjie；詞彙 rime/rime-essay；語言模型 lotem/rime-octagram-data（`hant` 分支）。

## 10. Windows 實測紀錄（2026-11-10）

環境：Windows 11 Pro 10.0.26300、小狼毫由 0.15.0 升級到 **0.17.4**（`weasel-0.17.4.0-installer.exe`，
12,431,118 B，SHA-256 `CF509534A8F5F8AF9C98ED7CBB8F135439F145A8CBE7E50EDE42BB5B5AB45C29`，官方安裝檔本來就沒有數位簽章）、
Windows Terminal 1.24.2610.1001。只測 v1（`cangjie5_fluency`）。

| 項目 | 結果 |
|---|---|
| `cangjie5.base.dict.yaml` 內建？ | **否**，自己下載（219,115 B） |
| `essay.txt` 內建？ | 是（`data\essay.txt`，6,330,573 B） |
| `.gram` | 自己下載，41,415,724 B（與上表一致） |
| `default.custom.yaml` | 與原有檔案合併（`cangjie5_fluency` 加在第一個），沒有覆蓋 |
| 部署 | `WeaselDeployer.exe /deploy` exit 0，約 33 秒，無 ERROR |
| octagram | 日誌 `octagram.cc:29] use grammar: zh-hant-t-essay-bgw` ✅ |
| `dhedhkb` | `板橋` ✅ |

### 升級後 Windows Terminal 閃退（已知原因：升級時 Terminal 還開著）

升級後第一次在一個**升級前就開著（已跑 8 天）**的 Windows Terminal 裡切到小狼毫打字，Terminal 立刻閃退。
重新開一個 Terminal 之後就正常。

* 事件檢視器：`WindowsTerminal.exe`、faulting module `ucrtbase.dll`、例外碼 `0xc0000409`（fail-fast，
  實際是未被接住的 C++ 例外 → `terminate()` → `abort()`）。
* 用 cdb 看 `%LOCALAPPDATA%\CrashDumps\WindowsTerminal.exe.<pid>.dmp`：例外由 Terminal 進程內載入的
  小狼毫 TSF 模組 `C:\Windows\System32\weasel.dll`（0.17.4）丟出，是 boost::archive 的
  **`unsupported version`**，發生在反序列化 server 傳來的 `weasel::UIStyle` 時，也就是輸入法前端與
  WeaselServer 之間的資料格式版本對不上。
* 結論：在其他程式還開著（已載入舊版輸入法）的情況下原地升級小狼毫，那些舊程式內的輸入法狀態會和新版
  server 衝突。**升級小狼毫後請登出再登入（或重開機）**，至少要把升級前就開著、用過小狼毫的程式全部重開。
