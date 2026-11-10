# tables/: Cangjie code tables (.cin)

| File | What it is | Used by the installer |
|---|---|---|
| `mscj3.cin` | **Cangjie 3rd generation** ("微倉三"), the table behind Microsoft's Cangjie / new Cangjie (Windows XP style). 21,010 characters | **Yes**: converted to `cangjie3.base.dict.yaml` (default schema `cangjie3_fluency`) |
| `mscj3-ext.cin` | The same 3rd generation with the extended character sets (Ext-A, Ext-B, HKSCS) | Not yet (kept for completeness and a later extended-charset option) |
| `cangjie5.base.dict.yaml` | The 5th-generation base table of rime-cangjie (《五倉世紀版》 from 倉頡之友), pinned commit `fcb3d7dd94ac1304663d575727d24d8107f6b082`; its header says GPL, the repository LGPL-3.0 | Yes: `cangjie5_fluency` (optional 5th generation) |
| `cj5.cin` | **Cangjie 5th generation** ("倉五"). Its own header says: "This file comes from http://www.chinesecj.com" (倉頡之友) | Not yet (the 5th-generation schema uses the rime-cangjie table) |

## Provenance

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

## Verify

```sh
cd tables && sha256sum -c SHA256SUMS
```
