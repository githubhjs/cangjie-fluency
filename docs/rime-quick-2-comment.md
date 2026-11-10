我也是新倉頡使用者，想要的是同一種「整句打完自動修正」的手感，而且我打的是完整倉頡，不是速成。所以照 eight04 的 `quick5_fluency` 改了一份全碼版，在 Linux（librime 1.10 + librime-octagram）上做了測試，補充幾點，希望對後面的人有幫助。**以下都只在 Linux 測過，Windows / 小狼毫上還沒測。**

### 全碼倉頡版

- 碼表只匯入 `cangjie5.base`（不加速成的 `derive` 規則），其餘沿用 eight04 的 `fluency_editor`、單字碼補空白、去掉 `abc_segmentor`。
- 連續打完整串碼不空白、不選字，緩衝區會逐步修正：「板橋」依序 板才 → 皮才 → 板枖 → **板橋**。
- 我自己寫的 51 句日常句子：有沒有語言模型都是 51/51；40 句同碼難句：36/40（有模型）對 37/40（沒模型）。所以在我的測試句上，八股文模型幾乎沒有可量測的差別，只有打到一半的緩衝區看得到。樣本小、句子是我自己寫的，請當參考。

### 對 eight04 設定的三個修正

1. 預設 `key_binder` 的 `paging_with_comma_period` 會讓 `.` 翻頁，打不出「。」，我把逗號句號與減號等號翻頁拿掉。
2. `recognizer/patterns/abc` 沒有頭尾限制時會讓拼音反查（反引號）失效，改成 `^[a-z]+( [a-z]+)* ?$`。
3. `grammar:/hant?` 在找不到 `grammar.yaml` 時會無聲略過，我把 `grammar/language` 直接寫進方案。

### 關於 #3、#4、#5

想補充一個和「光靠設定做不到」不太一樣的觀察（同樣只是 Linux 實測）：

- 空白（#3）：`speller/use_space: true`，`delimiter` 含空白，並拿掉 punctuator 的空白項，則空緩衝區的空白直接給應用程式，有內容時空白進緩衝區。
- 符號（#4）：把 `, . ? ! :` 在 `half_shape` 寫成一般值而不是 `{commit: x}`，有內容時符號會進緩衝區。代價是需要按 Enter 才上屏。
- 大寫（#5）：`recognizer` 的 `import_preset: default` 會匯入 `uppercase` 規則並先吞掉後面的鍵。拿掉它並改用內建 `abc_segmentor`，碼後面接大寫字母時大寫可以留在緩衝區。
- 仍然沒解決：**空緩衝區時**的數字、符號、大寫字母，會被 `Editor::AddToInput` 收進緩衝區，不會直接給應用程式。這部分我想只能靠 Lua（`librime-lua` 與 `engine:process_key`）或改 librime 的 `char_handler`；Lua 版我寫了草稿，目前只在 Debian 的 librime-lua 上跑過。
- 還有：我找不到微軟新倉頡「連按兩次空白」和「大寫字母本身留在緩衝區還是直接上屏」的官方說明，所以不確定這幾個行為要做成什麼樣才算一致。如果有人手邊有 Windows 新倉頡，能幫忙確認的話最好。

### 想請教

1. 這種全碼版 `fluency` 方案適合放在 `rime-cangjie` 當一個選用方案嗎？如果適合，我可以整理成 PR。
2. 「麵」這類字典差異，應該改碼表還是另外做補充表？

附上我整理的設定與測試記錄（Linux 測試腳本、句子集與結果）可以提供。
