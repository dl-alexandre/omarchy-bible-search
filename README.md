# Bible Search for Omarchy

An Omarchy Quattro bar widget with a book icon and an offline Bible-search panel. The panel is anchored to the bar widget rather than centered on the screen; search results can be copied directly to the clipboard.

## Install

The searchable WEBP corpus is bundled, so search works immediately. Install `fff` only if you want terminal browsing of the complete corpus:

```sh
omarchy pkg aur add fff
```

Then install the plugin from its public GitHub repository:

```sh
omarchy plugin add https://github.com/dl-alexandre/omarchy-bible-search.git --enable
```

To put it in the bar while testing:

```sh
omarchy plugin enable dev.alexandre.bible-search --section right
omarchy bar move dev.alexandre.bible-search --section right
```

The bar entry is a compact book icon. Click it to open the anchored search panel at the bar edge.

No setup is required. The plugin ships with the public-domain WEBP VPL corpus as 66 local book files. If the bundled files are unavailable, the `setup` command can download a replacement into user data; no system files or elevated privileges are used.

## CLI

The plugin includes `bin/omarchy-bible-search` for scripting and terminal use. After installation, point to the copy inside the user-owned plugin directory:

```sh
BIBLE_SEARCH_BIN="$HOME/.config/omarchy/plugins/dev.alexandre.bible-search/bin/omarchy-bible-search"
"$BIBLE_SEARCH_BIN" search "be still"
"$BIBLE_SEARCH_BIN" read GEN 1:1
"$BIBLE_SEARCH_BIN" browse
"$BIBLE_SEARCH_BIN" random
```

`browse` starts `fff` in the local book directory. `fff` is intentionally the only explicit optional dependency: it keeps the plugin small, terminal-native, and useful for browsing the complete corpus without adding a second file-picker implementation to Quickshell. Search uses ripgrep when available and otherwise falls back to the system `grep`.

## Data and privacy

- Search is local out of the box; queries are not sent to a search service.
- The normal install makes no network request. Network access is only used if the bundled corpus is missing and `setup` is run.
- The plugin stores data under `~/.local/share/omarchy-bible-search/` unless `BIBLE_SEARCH_HOME` is set.
- The unmodified WEBP text is bundled in `data/books/`. eBible.org identifies it as public domain; the source URL is retained in the CLI helper.
- If `setup` is used, the archive is capped at 16 MiB, checked as a ZIP, required to contain exactly one `engwebp_vpl.txt` member, and verified against SHA-256 `b6f55cc787b1201b68dcfde8a1216e1a61ae6b3cc38748456cf58bdb5e95fc1c`. eBible does not publish an independent checksum sidecar; this pin is the exact 4,281,529-byte artifact downloaded directly from the [eBible archive URL](https://ebible.org/Scriptures/engwebp_vpl.zip) on 2026-08-23. It detects later replacement or corruption, but cannot authenticate the origin of that initial download.
- The plugin requires no elevated privileges, installs no background services, edits no Omarchy-packaged files, and starts no second Quickshell process.

The remaining trust boundary is the user-owned Omarchy/Quickshell runtime and the existing local executables it invokes (`wl-copy`, `curl`, `sha256sum`, `unzip`, `awk`, `grep`, `find`, `shuf`, `fff`, and the configured pager). The plugin passes search results to `wl-copy` as direct argv and does not evaluate them as shell code. A live Omarchy session still runs plugin QML with the user’s session privileges; this repository does not sandbox that runtime.

## Development and validation

Run these checks from the repository root on an Omarchy system:

```sh
bash -n bin/omarchy-bible-search
bash tests/test-bible-search.sh
omarchy plugin validate .
qmllint -I "$OMARCHY_PATH/shell" BarWidget.qml Panel.qml
```

The marketplace requires a public GitHub repository with `manifest.json` at the root, a README, a license, safe install/removal behavior, and a current commit that passes its automated validation. After pushing the repository, use the marketplace’s **Publish a plugin** submission form.

## Remove

```sh
omarchy plugin remove dev.alexandre.bible-search --yes
```

The downloaded corpus is user data and is left in place so reinstalling the plugin does not require another download. Remove it separately only if wanted:

```sh
rm -rf ~/.local/share/omarchy-bible-search
```

## License

Plugin code is MIT licensed. The downloaded WEBP corpus remains under the public-domain dedication and attribution terms described by eBible.org.
