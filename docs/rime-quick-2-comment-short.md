我也是新倉頡使用者，打的是完整倉頡（不是速成），所以照 eight04 的 `quick5_fluency` 改了全碼版，只匯入 `cangjie5.base`，在 Linux（librime 1.10 + octagram）測過，**Windows 小狼毫還沒測**。

- 連續打完整串碼不空白、不選字，緩衝區會逐步修正：「板橋」依序 板才 → 皮才 → 板枖 → **板橋**。
- 我自己寫的 51 句日常句子，有沒有八股文語言模型都是 51/51；40 句同碼難句 36/40（有模型）對 37/40（沒模型）。在我的測試句上模型差別很小，樣本小，僅供參考。
- 對 eight04 設定的三個修正：預設 `key_binder` 會讓 `.` 翻頁（打不出「。」）；`abc` pattern 要加頭尾限制，否則反引號拼音反查失效；`grammar:/hant?` 找不到 `grammar.yaml` 會無聲略過，我把 `grammar/language` 直接寫進方案。
- 關於 #3/#4/#5：`speller/use_space: true`、符號在 `half_shape` 寫成一般值（不用 `{commit: x}`）、拿掉 `recognizer` 的 `import_preset: default` 並改用內建 `abc_segmentor`，在我的測試裡有內容時的空白、符號、大寫可以處理（代價是符號要按 Enter）。**空緩衝區時**的數字、符號、大寫仍會被收進緩衝區，我想只能靠 Lua 或改 librime。
- 我找不到微軟新倉頡「連按兩次空白」與「大寫字母留在緩衝區或直接上屏」的官方說明，有 Windows 新倉頡的人若能確認會很有幫助。

想請教：這種全碼版 `fluency` 方案適合放進 `rime-cangjie` 當選用方案嗎？適合的話我可以整理成 PR；需要的話我再貼完整設定與測試句。
