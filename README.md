# Bible Search

Offline World English Bible lookup. The bar widget searches, copies, loads today’s verse, and **reads the chapter in the panel**. **Window** (optional) opens the GPU reader (`gpu-ui --manual --book`).

## Install

The plugin ships an x86-64 `bin/gpu-ui`. Search, Daily, Copy, and in-panel **Book** do not need it; **Window** does.

```sh
omarchy plugin add https://github.com/dl-alexandre/omarchy-bible-search.git --enable
omarchy plugin enable dev.alexandre.bible-search --section right
omarchy restart shell
```

QML does not apply until that restart. `doctor` should print `STATUS	gpu-ui	…/bin/gpu-ui`. Override with `GPU_UI_BIN` or `link-ui` if you rebuild the runtime.

The Odin source for the reader lives next to the plugin in the retained-gpu-ui tree; it is not a git repo yet. Rebuild there, then copy `build/gpu-ui` over `bin/gpu-ui` to refresh the packaged reader.

## CLI

```sh
bin/omarchy-bible-search search "John 3:16"
bin/omarchy-bible-search chapter "John 3"
bin/omarchy-bible-search daily
bin/omarchy-bible-search doctor
bin/omarchy-bible-search link-ui
bin/omarchy-bible-search read GEN 1:1
bin/omarchy-bible-search browse
bin/omarchy-bible-search speak "In the beginning"
```

In the bar: type to search, click a result to copy, **Daily** for today’s verse, **Book** to read that chapter in the overlay (Esc returns to search). **Window** floats the GPU reader.

Search uses ripgrep when available, otherwise `grep`. Daily is `day-of-year % verse-count`.

## Data

Bundled public-domain WEBP in `data/books/`. `setup` only runs if that corpus is missing: 16 MiB cap, one `engwebp_vpl.txt` ZIP member, SHA-256 `b6f55cc787b1201b68dcfde8a1216e1a61ae6b3cc38748456cf58bdb5e95fc1c`.

## Tests

```sh
bash -n bin/omarchy-bible-search
bash tests/test-bible-search.sh
```
