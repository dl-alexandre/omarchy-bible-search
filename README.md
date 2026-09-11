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

Bundled public-domain WEBP in `data/books/`. `setup` only runs if that corpus is missing: 16 MiB cap, one `engwebp_vpl.txt` ZIP member, SHA-256 `b6f55cc787b1201b68dcfde8a1216e1a61ae6b3cc38748456cf58bdb5e95fc1c`.

## Tests

```sh
bash -n bin/omarchy-bible-search
bash tests/test-bible-search.sh
```
