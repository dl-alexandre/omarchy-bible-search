# Bible Search for Omarchy

An Omarchy Quattro bar widget with a book icon and an offline Bible-search panel. The panel is anchored to the bar widget rather than centered on the screen; search results can be copied directly to the clipboard with visible success or error feedback.

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

The bar entry is a compact book icon. Click it to open the anchored search panel at the bar edge. The panel caps its height and becomes scrollable on smaller displays or with larger interface fonts.

No setup is required. The plugin ships with the public-domain WEBP VPL corpus as 66 local book files. If the bundled files are unavailable, the `setup` command can download a replacement into user data; no system files or elevated privileges are used.

In the panel, search by word, phrase, or reference. Common forms such as `John 3:16`, `Jn 3:16`, `1 Cor 13:4-7`, and `Psalm 23` are accepted; results use full canonical book names. The opening topic suggestions rotate through themed groups whenever the widget opens. **Daily verse** returns one stable verse for the local calendar day and traverses a full-cycle permutation of the bundled corpus, so no verse repeats until every verse has been selected once. Click a verse to copy it; the panel stays open and shows the result. **Open book** turns the selected chapter into a paginated reading view with a spine-based page turn, subtle paper lift, and edge shadow; click a verse to focus it, use the page controls or arrow keys to turn pages, and return to **Search** whenever you want.

Book View includes a compact **Library** for choosing any of the 66 books and its chapters without leaving the widget. It remembers the last reading position, keeps up to 30 saved verses and 12 recently opened chapters, and offers a Resume shortcut. **Save** toggles the focused verse in the saved list. A persisted **Reduced motion** preference replaces the page-turn animation with an immediate page change. **Read chapter** begins at the focused verse and follows the narration across pages; **Stop** remains available inside the reader. Terminal users can still open the bundled corpus in `fff` with the CLI `browse` command, but that developer-oriented action is not shown in the widget.

The reader is keyboard-driven as well as clickable. In Book View, press `B` to toggle Library, `Tab` or `Shift+Tab` to cycle its sections, arrows (or Vim directions) to move the visible cursor, Enter to open, `/` to filter books, `S` to save the focused verse, and `R` to resume the last position. In Saved, `X` removes the selected verse. Escape closes Library before it closes the panel.

If a local voice engine is installed, the panel also offers **Read aloud** for a verse and **Read chapter** for sequential chapter playback. The first visible verse is prepared silently and marked **Ready**; while it plays, one likely next verse is cached. The bounded cache never renders an entire result set or chapter. The **Read along** card keeps the current verse prominent, highlights the estimated spoken word, and collapses shortly after narration completes instead of duplicating the result card. Press `R` to read the selected verse and `Space` to pause or resume; arrows navigate and Enter copies. It prefers a locally installed Piper `en_US-ryan-medium` male neural voice, synthesizing private temporary WAV files and playing them through the current default audio sink before deleting them. Tuned `espeak-ng`, `espeak`, or `spd-say` remain automatic fallbacks.

The compact gear menu controls male neural versus system voice, 0.85×/1×/1.15× narration speed, automatic Daily loading, and reduced motion. These preferences persist locally. Suggestions adapt their first topic to the time of day while the remaining categories continue rotating for variety. Narration keeps reading when the anchored panel is hidden and does not contact a cloud speech service. Word highlighting remains estimated because the local engines do not expose word timing, but the estimate adapts to completed verse durations and retains that calibration between sessions.

## CLI

The plugin includes `bin/omarchy-bible-search` for scripting and terminal use. After installation, point to the copy inside the user-owned plugin directory:

```sh
BIBLE_SEARCH_BIN="$HOME/.config/omarchy/plugins/dev.alexandre.bible-search/bin/omarchy-bible-search"
"$BIBLE_SEARCH_BIN" search "be still"
"$BIBLE_SEARCH_BIN" chapter "John 3"
"$BIBLE_SEARCH_BIN" read GEN 1:1
"$BIBLE_SEARCH_BIN" browse
"$BIBLE_SEARCH_BIN" random
```

`browse` starts `fff` in the local book directory. `fff` is intentionally the only explicit optional dependency: it keeps the plugin small, terminal-native, and useful for browsing the complete corpus without adding a second file-picker implementation to Quickshell. Search uses ripgrep when available and otherwise falls back to the system `grep`.

## Data and privacy

- Search is local out of the box; queries are not sent to a search service.
- The normal install makes no network request. Network access is only used if the bundled corpus is missing and `setup` is run.
- The plugin stores data under `~/.local/share/omarchy-bible-search/` unless `BIBLE_SEARCH_HOME` is set.
- Reading position, saved verses, recent chapters, voice, speed, Daily-on-open, reduced-motion preference, and local narration timing calibration are stored in `reader-state.json` there using atomic writes.
- The unmodified WEBP text is bundled in `data/books/`. eBible.org identifies it as public domain; the source URL is retained in the CLI helper.
- If `setup` is used, the archive is capped at 16 MiB, checked as a ZIP, required to contain exactly one `engwebp_vpl.txt` member, and verified against SHA-256 `b6f55cc787b1201b68dcfde8a1216e1a61ae6b3cc38748456cf58bdb5e95fc1c`. eBible does not publish an independent checksum sidecar; this pin is the exact 4,281,529-byte artifact downloaded directly from the [eBible archive URL](https://ebible.org/Scriptures/engwebp_vpl.zip) on 2026-08-23. It detects later replacement or corruption, but cannot authenticate the origin of that initial download.
- The plugin requires no elevated privileges, installs no background services, edits no Omarchy-packaged files, and starts no second Quickshell process.

The remaining trust boundary is the user-owned Omarchy/Quickshell runtime and the existing local executables it invokes (`wl-copy`, `curl`, `sha256sum`, `unzip`, `awk`, `grep`, `find`, `shuf`, `fff`, `omarchy-launch-tui`, `espeak-ng`, `espeak`, `spd-say`, and the configured pager). The plugin passes search, clipboard, and narration text as direct process arguments and does not evaluate it as shell code. A live Omarchy session still runs plugin QML with the user’s session privileges; this repository does not sandbox that runtime.

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
