# Microsoft 新倉頡 (Windows XP) behaviour: notes from an experienced user

Source: the repository owner's own recollection (not Microsoft documentation; none was found).
Recorded 2026-11-10 after Windows 11 + Weasel 0.17.4 testing of `cangjie5_fluency` (v1).

| Question | Owner's answer |
|---|---|
| After the code of one character, what does the space key do? | The code turns into the character and stays in the underlined (dotted) composition area. |
| What happens when `，` or `。` is typed inside the underlined sentence? | In XP it stays inside the underlined area. The owner does **not** like this: related words often cannot cross a comma or full stop, so the punctuation should end the sentence-making unit. |
| How is the finished sentence committed? | Enter. |

## Consequences for this project

- `cangjie5_fluency` (v1) is the recommended schema: punctuation commits the buffer and then types the full-width mark, which cuts the language-model context at `，` and `。` as the owner prefers.
- `cangjie5_fluency_v2` appends punctuation to the buffer and needs Enter. That is closer to what XP did, but it is the behaviour the owner dislikes. Keep it as an experiment only.
- Space inside the buffer acts as a code separator in v1, which matches "this character's code is finished".
- Still open: empty-buffer digits, symbols and uppercase letters reach the buffer instead of the application (needs the Lua processor in `lua/`, untested on Windows).
