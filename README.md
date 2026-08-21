# Bible Search for Omarchy

An Omarchy Quattro bar widget with a book icon and an offline Bible-search panel. The panel is anchored to the bar widget rather than centered on the screen; search results can be copied directly to the clipboard.

## Install

The searchable WEBP corpus is bundled, so search works immediately. Install the optional terminal tools for browsing and paging:

```sh
omarchy pkg add ripgrep less
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

`browse` starts `fff` in the local book directory. `fff` is intentionally an explicit dependency: it keeps the plugin small, terminal-native, and useful for browsing the complete corpus without adding a second file-picker implementation to Quickshell.

## Data and privacy

- Search is local out of the box; queries are not sent to a search service.
- The normal install makes no network request. Network access is only used if the bundled corpus is missing and `setup` is run.
- The plugin stores data under `~/.local/share/omarchy-bible-search/` unless `BIBLE_SEARCH_HOME` is set.
- The unmodified WEBP text is bundled in `data/books/`. eBible.org identifies it as public domain; the source URL is retained in the CLI helper.
- The plugin does not use `sudo`, install background services, edit Omarchy’s packaged files, or start a second Quickshell process.

## Development and validation

Run these checks from the repository root on an Omarchy system:

```sh
bash -n bin/omarchy-bible-search
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
