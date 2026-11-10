# data/: language model and word list shipped with the installers

| File | What it is | Source (unchanged) | SHA-256 |
|---|---|---|---|
| `zh-hant-t-essay-bgw.gram` | 八股文 language model for librime-octagram (Traditional Chinese, word level), 41,415,724 bytes | [lotem/rime-octagram-data](https://github.com/lotem/rime-octagram-data), branch `hant` | `0488ebd6688f900a39200f2b794f2f99bcbf1e8fc27280ae4a2324b08b1559c1` |
| `essay.txt` | rime-essay word list with frequencies, 5,887,319 bytes, used for phrase vocabulary and for the table weights | [rime/rime-essay](https://github.com/rime/rime-essay) at commit `054920de4f54c9e5994276a96a4fc2a35cb51aa3` | `3e8512ebaa6657e35961b1f5762060717c647e3bf471d5e3b86e783b4e934ffb` |

Both are licensed LGPL-3.0 by their authors (see their repositories); this repository's `LICENSE` is the same LGPL-3.0 text. They are kept here so that
every installer (Windows, macOS, Linux) installs from this repository only and gives the same result on every platform.

```sh
cd data && sha256sum -c SHA256SUMS
```
