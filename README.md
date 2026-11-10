# cangjie-fluency

全碼倉頡五代（倉頡）的「整句輸入」Rime 方案，目標是接近微軟新倉頡的手感：連續打完整串碼，緩衝區會自動修正，不必逐字選字。

Full Cangjie 5 sentence-style input schema for Rime (Weasel on Windows), aiming at the feel of Microsoft 新倉頡.

- `weasel/` — 方案檔（`cangjie5_fluency` v1、實驗性 `_v2`）、繁中安裝說明 `README.zh-TW.md`、Linux 測試記錄與測試腳本
- `docs/item4-analysis.md` — 空白鍵、符號、大寫字母與微軟新倉頡差異的原始碼分析（英文）
- `lua/` — 空緩衝區直接送字的 Lua 處理器草稿（**未測試**）
- `docs/rime-quick-2-comment*.md` — 送給 rime/rime-quick#2 的留言

## 狀態 / Status

- 只在 Linux（librime 1.10 + librime-octagram）測過；**Windows 小狼毫尚未實測**。
- 語言模型在我們的測試句上效果很小（51 句日常句 51/51 有無模型相同）；詳見 `weasel/docs/test-log.md`。
- 單字碼要接空白（例如「中午」打 `l oj`）。
- 語言模型檔 `zh-hant-t-essay-bgw.gram`（約 39.5 MB）不在本倉庫，下載方式見 `weasel/README.zh-TW.md`。

## 來源與授權 / Credits and license

- 基於 [rime/rime-cangjie](https://github.com/rime/rime-cangjie) 的《五倉世紀版》碼表、[rime/rime-quick](https://github.com/rime/rime-quick) 以及 eight04 在 [rime-quick#2](https://github.com/rime/rime-quick/issues/2) 提出的 `quick5_fluency` 原型。
- 倉頡輸入法本身由朱邦復先生創製，他已公開放棄專利權。
- 授權：LGPL-3.0（與上游 rime-quick、rime-cangjie 一致），見 `LICENSE`。
