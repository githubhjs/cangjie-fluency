# tables/: Cangjie code tables (.cin) / 倉頡碼表（.cin）

| 檔案 | 說明 | 安裝程式是否使用 |
|---|---|---|
| `mscj3.cin` | **倉頡三代**（「微倉三」），微軟倉頡／新倉頡（Windows XP 風格）背後的碼表。共 21,010 個字 | **使用**：轉換成 `cangjie3.base.dict.yaml`（預設方案 `cangjie3_fluency`） |
| `mscj3-ext.cin` | 同樣是三代，另含擴充字集（Ext-A、Ext-B、HKSCS） | 尚未使用（為完整性保留，供日後的擴充字集選項使用） |
| `cangjie5.base.dict.yaml` | rime-cangjie 的五代基礎碼表（取自倉頡之友的《五倉世紀版》），固定在 commit `fcb3d7dd94ac1304663d575727d24d8107f6b082`；檔頭註明 GPL，本倉庫為 LGPL-3.0 | 使用：`cangjie5_fluency`（選用的五代） |
| `cj5.cin` | **倉頡五代**（「倉五」）。檔頭自述：「This file comes from http://www.chinesecj.com」（倉頡之友） | 尚未使用（五代方案使用 rime-cangjie 的碼表） |

| File | What it is | Used by the installer |
|---|---|---|
| `mscj3.cin` | **Cangjie 3rd generation** ("微倉三"), the table behind Microsoft's Cangjie / new Cangjie (Windows XP style). 21,010 characters | **Yes**: converted to `cangjie3.base.dict.yaml` (default schema `cangjie3_fluency`) |
| `mscj3-ext.cin` | The same 3rd generation with the extended character sets (Ext-A, Ext-B, HKSCS) | Not yet (kept for completeness and a later extended-charset option) |
| `cangjie5.base.dict.yaml` | The 5th-generation base table of rime-cangjie (《五倉世紀版》 from 倉頡之友), pinned commit `fcb3d7dd94ac1304663d575727d24d8107f6b082`; its header says GPL, the repository LGPL-3.0 | Yes: `cangjie5_fluency` (optional 5th generation) |
| `cj5.cin` | **Cangjie 5th generation** ("倉五"). Its own header says: "This file comes from http://www.chinesecj.com" (倉頡之友) | Not yet (the 5th-generation schema uses the rime-cangjie table) |

## Provenance / 來源

- 原樣取自 [EasyIME/PIME](https://github.com/EasyIME/PIME) 的 `python/cinbase/cin/` 目錄，固定在 commit
  `e6e4529ed69dea11171365054b8134f5866fe33f`。每個檔案的 SHA-256 都記在 `SHA256SUMS`。
- 倉頡輸入法由朱邦復先生創製。依本倉庫擁有者的立場，**三代與五代倉頡碼皆可免費使用（royalty-free）**：朱邦復先生於 1982 年公開放棄倉頡輸入法的專利權
  （公開聲明；見中文維基百科〈倉頡輸入法〉條目的記載），且此輸入法已內建於大多數作業系統。
- 檔頭：`mscj3.cin` 除了碼表定義之外沒有檔頭文字；`cj5.cin` 註明來自 chinesecj.com（倉頡之友）；`mscj3-ext.cin` 註明原始 txt 碼表為 Charles Law、
  單行碼表為 Ejsoon，修訂者為 ArthurMcArthur（2017-01-08）。三者都沒有載明授權條款，所以這裡沒有可轉載的逐檔授權文字。這些檔案是依擁有者的決定
  原樣收入本倉庫，讓安裝結果可重現，也不必依賴第三方會變動的 `master` 分支。產生出來的 `cangjie3.base.dict.yaml`（權重取自 essay 詞表）**不會**提交進倉庫；
  安裝程式會在你的電腦上用 `tools/cin2rime.py` 建出它。

English:

- Obtained unchanged from [EasyIME/PIME](https://github.com/EasyIME/PIME), directory `python/cinbase/cin/`, at the pinned commit
  `e6e4529ed69dea11171365054b8134f5866fe33f`. SHA-256 of every file is in `SHA256SUMS`.
- The Cangjie input method was created by Chu Bong-Foo (朱邦復). On the owner's position, **the 3rd and 5th generation Cangjie codes are
  royalty-free**: Chu Bong-Foo publicly waived the patent rights of the Cangjie input method in 1982 (public notice; see the Chinese
  Wikipedia article on 倉頡輸入法, which records it), and the method is built into most operating systems.
- Headers: `mscj3.cin` has no header text beyond the table definition; `cj5.cin` credits chinesecj.com (倉頡之友); `mscj3-ext.cin` credits
  the original txt table to Charles Law, the single-line table to Ejsoon and revisions to ArthurMcArthur (2017-01-08). None of them
  states a licence, so there is no per-file licence text to reproduce here. The files are included in this repository at the owner's
  decision, unchanged, so that installs are reproducible and do not depend on a third party's moving `master` branch. The generated `cangjie3.base.dict.yaml` (weights from the essay word list) is **not** committed; the
  installer builds it on your machine with `tools/cin2rime.py`.

## Verify / 驗證

核對雜湊（指令見下）/ Check the hashes (command below):

```sh
cd tables && sha256sum -c SHA256SUMS
```
