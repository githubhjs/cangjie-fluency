# 倉頡整句（cangjie5_fluency）— 小狼毫 Weasel 安裝說明

目標：全碼倉頡五代（不是速成），像微軟新倉頡一樣「整句輸入」：一路打下去不選字，緩衝區會隨著
你繼續輸入、用詞庫＋語言模型重新斷詞，所以「板橋」不會停在「皮橋」。

> 狀態：Linux（librime 1.10 + librime-octagram）測試通過，**尚未在 Windows 11 / 小狼毫實測**。
> 測試過程與真實輸出見 `docs/test-log.md`。

## 1. 檔案

| 檔案 | 放哪裡 |
|---|---|
| `cangjie5_fluency.schema.yaml` | `%APPDATA%\Rime\` |
| `cangjie5_fluency.dict.yaml` | `%APPDATA%\Rime\` |
| `default.custom.yaml` | `%APPDATA%\Rime\`（**已有自己的就不要覆蓋，見第 4 節合併**） |

`%APPDATA%\Rime` 通常是 `C:\Users\<你>\AppData\Roaming\Rime`（在檔案總管網址列貼上 `%APPDATA%\Rime` 即可）。
也可以在工具列的小狼毫圖示按右鍵 →「用戶文件夾」直接打開。

## 2. 還需要的三個資料檔

這個方案的詞庫是從「單字全碼表」＋詞彙表 `essay.txt` 自動組出來的，語言模型是八股文 `.gram`。

| 檔案 | 大小（實測） | 下載位置 | 放哪裡 |
|---|---|---|---|
| `cangjie5.base.dict.yaml` | 219,115 B（約 214 KB） | https://raw.githubusercontent.com/rime/rime-cangjie/master/cangjie5.base.dict.yaml | 小狼毫通常已內建（見下） |
| `essay.txt` | 5,887,319 B（約 5.6 MB） | https://raw.githubusercontent.com/rime/rime-essay/master/essay.txt | 小狼毫通常已內建（見下） |
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
這是從原始碼推論，**未在實際安裝檔內確認**（unverified）。

## 3. 小狼毫有沒有內建 librime-octagram？（語言模型外掛）

**未直接確認（unverified），但證據偏正面：**

* rime/librime 的 Windows 發佈 CI（`.github/workflows/release-ci.yml`）建置時加入的外掛為
  `hchunhui/librime-lua lotem/librime-octagram rime/librime-predict`。
* 小狼毫（rime/weasel）的 `get-rime.ps1` 直接下載 rime/librime 的發佈版 `rime.dll`，沒有自己另外挑外掛。
* 小狼毫最新發佈：`0.17.4.98`（2026-10-31，標 latest，疑似 nightly），穩定版 `0.17.4`（2025-06-04）。
  這兩版實際內含的 librime 版本我沒有核對。

我沒有在 Windows 安裝安裝檔去驗證 `rime.dll` 內是否真的含 octagram。**最可靠的驗證方式是部署後看日誌**：
日誌裡應該有 `octagram.cc:... use grammar: zh-hant-t-essay-bgw`。沒有這行 = 外掛或 .gram 沒載入
（方案仍可用，但等於沒有語言模型）。

## 4. default.custom.yaml 合併方式

`default.custom.yaml` 的 `patch: schema_list:` 會**整份取代**預設的方案清單。

* 你還沒有 `%APPDATA%\Rime\default.custom.yaml`：直接複製本資料夾的檔案即可。
* 你已經有：**不要覆蓋**。打開自己的檔案，在 `schema_list:` 底下加一行
  `    - schema: cangjie5_fluency`（放第一個 = 預設方案），其餘行保持原樣。
  如果你的檔案裡還沒有 `schema_list`，把本檔 `patch:` 下的整段貼進去。

## 5. 部署與切換

1. 把檔案放好後，在工具列小狼毫圖示按右鍵 → **重新部署**（或開始功能表 →「小狼毫輸入法」→「重新部署」）。
2. 第一次部署要編譯詞庫（Linux aarch64 約 3.3 秒、產生約 17 MB 的 table；Windows 時間未測），
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

## 7. 若部署失敗 / 編譯不過

1. 看日誌：`%TEMP%\rime.weasel.*`（例如 `%TEMP%\rime.weasel.<電腦名>.<使用者>.log.ERROR.*`、`...INFO.*`；
   在檔案總管網址列貼 `%TEMP%` 後搜尋 `rime.weasel`）。先看 ERROR / WARNING 檔，再看 INFO。
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

1. **空格鍵**：微軟新倉頡「緩衝區為空時直接輸出空白，否則空白進緩衝區」。本方案緩衝區有字時空格進緩衝區，
   連按兩次才上屏＋空白；與 MS 的實際行為是否逐項一致未驗證。（Windows 未測）
2. **大寫字母**：緩衝區有內容時打大寫字母，大寫與其後字母都以原樣留在緩衝區（`板橋Ab`），不會變成直接英文；
   空緩衝區打大寫字母會被當成字根輸入而亂碼。建議用 Shift 切英文。（Linux 測得；Windows 未測）
3. **符號**：`,` `.` `!` `?` 會上屏整句並輸出全形標點；`;` 變成候選、`-` `=` 原樣進緩衝區。
   其他半形符號是否都比照微軟，沒有逐一核對。（Windows 未測）
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
