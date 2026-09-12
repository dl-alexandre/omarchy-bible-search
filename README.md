# Bible Search

Offline World English Bible lookup. The bar widget searches, copies, loads today’s verse, and reads the chapter in the panel.

## Install

```sh
omarchy plugin add https://github.com/dl-alexandre/omarchy-bible-search.git --enable
omarchy plugin enable dev.alexandre.bible-search --section right
omarchy restart shell
```

QML does not apply until that restart.

## Voice

Reading aloud stays on the machine. The panel already uses whatever local engine it finds, in this order:

1. Optional Piper neural voice (plugin-local install, Settings → Neural).
2. Whatever is already on `PATH`: `espeak-ng`, `espeak`, `spd-say` (speech-dispatcher), or `flite`. Settings → System uses this.
3. `BIBLE_TTS_BIN` — path or command name of your own CLI. It must accept `tool -- TEXT` like espeak, unless it is `spd-say` or `flite`.

There is no GPU reader and no shipped ELF.

## CLI

```sh
bin/omarchy-bible-search search "John 3:16"
bin/omarchy-bible-search chapter "John 3"
bin/omarchy-bible-search daily
bin/omarchy-bible-search doctor
bin/omarchy-bible-search voice-status
bin/omarchy-bible-search read GEN 1:1
bin/omarchy-bible-search speak "In the beginning"
```

In the bar: type to search, click a result to copy, **Daily** for today’s verse, **Book** to read that chapter in the overlay (Esc returns to search).

Search uses ripgrep when available, otherwise `grep`. Daily is `day-of-year % verse-count`.

## Data

Bundled public-domain WEBP in `data/books/`. `setup` only runs if that corpus is missing. It requires Python 3 and curl, caps the download at 16 MiB and the decompressed corpus at 64 MiB, accepts exactly one `engwebp_vpl.txt` ZIP member, and checks SHA-256 `b6f55cc787b1201b68dcfde8a1216e1a61ae6b3cc38748456cf58bdb5e95fc1c`.

Setup uses owner-checked, no-follow directory descriptors for the full transaction, exclusive random staging names, bounded streaming, and descriptor-relative rename/cleanup. This protects against another user racing a writable ancestor or staging path. The Omarchy shell remains an unsandboxed user process: a process running as the same user, root, or a compromised curl/Python/runtime environment is outside this boundary. The pinned archive hash detects later replacement or corruption but does not authenticate the initial download’s origin.

## Security checks

The focused test suite covers checksum, curl, ZIP-member, size-limit, symlink, writable-ancestor, archive-traversal, and staging-cleanup failures, plus a successful secure install. The plugin does not install services or use sudo.

## Tests

```sh
bash -n bin/omarchy-bible-search
python3 -m py_compile bin/omarchy-bible-search-setup.py
bash tests/test-bible-search.sh
```
