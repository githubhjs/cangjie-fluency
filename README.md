# cangjie-fluency

全碼倉頡的「整句輸入」Rime 方案：**預設是倉頡三代（Windows XP 新倉頡的碼表），可選倉頡五代**，目標是接近微軟新倉頡的手感：連續打完整串碼，緩衝區會自動修正，不必逐字選字。

Sentence-style full Cangjie input schema for Rime (Weasel on Windows): **3rd generation by default (the table behind Windows XP's 新倉頡), 5th generation optional**, aiming at the feel of Microsoft 新倉頡.

- `weasel/` — 方案檔（`cangjie5_fluency` v1、實驗性 `_v2`）、繁中安裝說明 `README.zh-TW.md`、Linux 測試記錄與測試腳本
- `docs/item4-analysis.md` — 空白鍵、符號、大寫字母與微軟新倉頡差異的原始碼分析（英文）
- `lua/` — 空緩衝區直接送字的 Lua 處理器草稿（**未測試**）
- `docs/rime-quick-2-comment*.md` — 送給 rime/rime-quick#2 的留言

**其他平台 / Other platforms:** Linux（fcitx5-rime、fcitx-rime、ibus-rime）→ [githubhjs/cangjie-fluency-linux](https://github.com/githubhjs/cangjie-fluency-linux)；
macOS（鼠鬚管 Squirrel）→ [githubhjs/cangjie-fluency-macos](https://github.com/githubhjs/cangjie-fluency-macos)。兩者都是從本倉庫下載方案檔，只多一個安裝腳本。

## 一鍵安裝（Windows 10/11，需要能裝軟體的管理員權限） / One-click install

在 PowerShell 貼一行（用一般使用者執行，只有裝小狼毫那一步會跳 UAC）：

```powershell
irm https://raw.githubusercontent.com/githubhjs/cangjie-fluency/main/install.ps1 | iex
```

或到 [Releases](https://github.com/githubhjs/cangjie-fluency/releases) 下載壓縮包，解壓縮後雙擊 `install.bat`。

腳本會：安裝小狼毫（用 winget，沒裝才裝）→ 下載缺的碼表與語言模型 → 複製方案 → 保守合併 `default.custom.yaml`（先備份）→ 重新部署。
**預設安裝三代倉頡 `cangjie3_fluency`**（Windows XP 內建的新倉頡是三代的修改版），並放在方案清單第一個，Weasel 原本的方案接在後面、不會被拿掉。
裝完請**登出再登入**（或重開機），再按 `Ctrl+`` 或 `F4` 切到 `cangjie3_fluency`。可用 `-DryRun` 先看它會做什麼。重複執行是安全的：內容相同的檔案不會重複備份或覆蓋。

要加參數時，`irm | iex` 傳不了參數，用這個寫法（等於下載後執行）：

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/githubhjs/cangjie-fluency/main/install.ps1))) -Cangjie5
```

| 參數 | 作用 |
|---|---|
| （不加） | 三代 `cangjie3_fluency` |
| `-Cangjie5` | 另外裝五代 `cangjie5_fluency` |
| `-NoCangjie3` | 不裝三代，改裝五代（舊版的預設行為） |
| `-WithV2` | 再加實驗性的 v2（排在 v1 後面，不會變成預設；會一併裝五代） |
| `-NoModel` / `-DryRun` / `-NoDeploy` | 不下載語言模型／只顯示不做／只複製檔案不部署 |

三代碼表（PIME 的 `mscj3.cin`）**不在本倉庫裡**（檔案沒有授權說明），安裝時由腳本從 PIME 下載並轉換。五代碼表約兩成的字碼與三代不同，詳見 `weasel/README.zh-TW.md` 第 6c 節。

進階：也可以用東風破（[plum](https://github.com/rime/plum)）`rime-install githubhjs/cangjie-fluency`（Windows 需要 plum 的 bootstrap 包，內含 git、7z）。
**但只適合從沒自訂過方案清單的人，其他人請用上面的一行安裝：**
- plum 會把 `default.custom.yaml` 的內容直接附加在檔案後面。從小狼毫方案選單產生的那種檔案沒有結尾換行，附加後 YAML 會壞掉，
  而且畫面上沒有任何錯誤；就算沒壞，你原本的清單也會被小狼毫的預設清單取代（Windows 實測：原有的方案消失）。
- 小狼毫自帶的 `rime-install-config.bat` 會強制改用登錄檔裡的使用者資料夾，所以 `rime_dir=` 不能讓你先在暫存資料夾試跑，
  它會直接改到你真正的設定。**用之前請先備份 `%APPDATA%\Rime\default.custom.yaml`。**
**腳本在 Linux 的 PowerShell 上驗證過邏輯，Windows 上的完整流程尚待實測。**

## 狀態 / Status

- Linux（librime 1.10 + librime-octagram）與 **Windows 11 + 小狼毫 0.17.4**（只測 v1，部署成功、`dhedhkb` → `板橋`）都測過；v2 尚未在 Windows 測。建議日常用 v1，理由見 `docs/xp-behavior-notes.md`。
- 語言模型在我們的測試句上效果很小（51 句日常句 51/51 有無模型相同）；詳見 `weasel/docs/test-log.md`。
- 單字碼要接空白（例如「中午」打 `l oj`）。
- 語言模型檔 `zh-hant-t-essay-bgw.gram`（約 39.5 MB）不在本倉庫，下載方式見 `weasel/README.zh-TW.md`。

## 來源與授權 / Credits and license

- 基於 [rime/rime-cangjie](https://github.com/rime/rime-cangjie) 的《五倉世紀版》碼表、[rime/rime-quick](https://github.com/rime/rime-quick) 以及 eight04 在 [rime-quick#2](https://github.com/rime/rime-quick/issues/2) 提出的 `quick5_fluency` 原型。
- 倉頡輸入法本身由朱邦復先生創製，他已公開放棄專利權。
- 授權：LGPL-3.0（與上游 rime-quick、rime-cangjie 一致），見 `LICENSE`。
