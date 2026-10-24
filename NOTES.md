# Notes for changing the theme

Edit the files in this repo, then run `python3 install.py` again (or, for palette and QML changes only, `python3 desktop/apply-palette.py` from the repo, which then becomes the copy ii points at). The installed files under `~/.config` get overwritten on every run.

## How it fits together

- `apply-palette.py` is the core. It reads the palette, writes every color file (ii's `colors.json`, Hyprland, hyprlock, fuzzel, kitty, GTK, a KDE color scheme), patches ii's QML (radius 0, sharp icons, no shadows, square notification icons) and copies in the replacement bar and sidebar. Then it reloads what can reload live.
- Rounding is 0 everywhere, but ii also uses `Appearance.rounding.*` as padding and margins, and dialogs pad their content by their own radius. Those spots get fixed spacing back (`SPACE` in `apply-palette.py`); without it dialogs and list items have no inner padding.
- In the QML files, a quoted `"{{token}}"` becomes `(TickerTokens.t["token"] ?? "transparent")`. `TickerTokens` reads `ticker-tokens.json` at runtime and watches it, which is why a palette switch needs no shell restart. The fallback exists because bindings run once before the file is read; without it the log fills with QColor warnings.
- Matte state lives in `~/.local/state/tickerline/` (`matte`, `night`). The matte palette is active when either is on. ii's Night Light calls the script through a one-line hook in `services/Hyprsunset.qml`.
- `install.py` does the one-time parts: downloads, kitty/fuzzel/ii config values, fontconfig, GTK and KDE font settings, and the Hyprland file in `custom/`.

## Quickshell

- New or renamed QML files only load on a full restart: `pkill -x qs`, then `hyprctl dispatch 'hl.dsp.exec_cmd("qs -c ii")'`. After a failed reload it can keep running a stale compiled copy, and the errors then point at code that no longer exists. When errors make no sense, restart. The log is at `qs -c ii log`.
- Names that broke loading or behavior in ii components:
  - a property called `active` on a MouseArea component
  - `data`, which every Item already has
  - an id called `bottom`, which child items shadow
  - inline component names that match ii widgets (like `NotificationGroup`); the ones here start with `Ticker`
- An inline component can't be a ListView delegate; write the delegate inline.
- ii's `StyledToolTip` stays visible inside a MouseArea. Use `extraVisibleCondition: false` with `alternativeVisibleCondition: <hover>`.
- After a Qt update, Quickshell has to be rebuilt (its log says "built against Qt ..."). `makepkg` reuses an existing package file unless you pass `-f`.

## Sidebar AI (Claude Code)

- `ClaudeCodeApiStrategy.qml` plugs into ii's `ApiStrategy` interface. It throws away the curl script ii builds and returns a `claude -p --output-format stream-json --verbose --include-partial-messages` call instead, so ii's request process, chat UI and saved chats keep working unchanged.
- One sidebar chat is one Claude session. The strategy keeps the `session_id` from the `init` event and passes `--resume` on later turns, so it only sends the newest message. `/clear` and loading a saved chat start a new session.
- Tool permissions come from `~/.claude/settings.json`. Claude Code also allows read-only commands like `ls` by itself. A headless run can't ask, so denied calls end up in the `result` event's `permission_denials`. The strategy shows them as a `command` block, which gives it ii's Approve and Reject buttons. Approve adds an `--allowedTools` rule (the exact command for Bash, the tool name otherwise) for the rest of the session and resumes with "Approved. Go ahead."
- The mode dropdown reuses ii's tool setting (`ai.tool`). For the Claude models, `Ai.tools.claude` maps each mode name to a `--permission-mode` value: ask = `default`, edits = `acceptEdits`, plan = `plan`, full = `bypassPermissions`. A tool name left over from another model (like `functions`) runs as ask.
- ii writes each request to `/tmp/quickshell/ai/request.sh` and used to run that file. The write is asynchronous, so bash sometimes ran the previous request and the reply answered the message before. The script now goes straight to `bash -c`; the file is still written, for debugging.
- The CLI waits 3 seconds for stdin and then prints a warning into the reply, so the script gives it `< /dev/null`.
- The summary shortcut calls `qs -c ii ipc call sidebarLeft summarize "<text>"` (an IPC function added to `SidebarLeft.qml`). `tickerline.lua` unbinds ii's version first; that works because it loads after ii's keybinds.
- The CLI runs in `$HOME` and loads your user hooks and skills like any other session. Every turn counts against the same usage limits as your other sessions.
- `policies.weeb = 0` hides the Anime tab. `ai.extraModels` is set to `[]` because ii brings back its OpenRouter default model when the key is missing.

## Units and syntax

- kitty padding is in points: 12 pt = 16 px.
- fuzzel scales fonts by the screen's real DPI unless `dpi-aware=no`.
- hyprlock (hyprlang) treats `#` as a comment, so colors inside label text are written `##RRGGBB`.
- hyprlang also reads double curly braces as a math expression. A value containing them (like a playerctl `--format` string) is silently dropped, and the label shows "Sample Text". Empty or space-only command output does the same; print a no-break space instead.
- hyprlock draws shapes over labels and the input field unless those have a higher `zindex`.

## KDE and GTK

- `plasma-apply-colorscheme` does nothing if a scheme with the same name is already active, so each palette variant has its own scheme name.
- Running KDE apps only reload icons after the `org.kde.KIconLoader.iconChanged` D-Bus signal; the script sends it.
- The file chooser in download dialogs is the KDE portal. After an icon theme change it needs `systemctl --user restart plasma-xdg-desktop-portal-kde`.
- GTK apps read `gtk.css` only at startup.

## GRUB

The boot theme's numbers were checked against real renders in QEMU, and three of them differ from what you'd expect:

- **Highlight size:** GRUB draws the 9-slice borders outside `item_height`. With 8 px slices, `item_height = 48` gives a 64 px bar, and `item_spacing = 24` keeps the 72 px row pitch so rows sit between the dotted guides in the background.
- **Highlight position:** `item_padding` shifts the whole list, so it's 0. The menu `width` loses 2 px when GRUB computes the highlight, so it's 834 to end at x 1376.
- **Icon inset:** GRUB places the icon right after the left border slice. The left slices (`select_nw/w/sw.png`) are 20 px wide to get the mockup's 20 px gap; the right ones are 8 px.
- **SemiBold font:** `grub-mkfont` only knows Regular and Bold, so the SemiBold file needs `-n "IBM Plex Mono SemiBold"`. Its GRUB name is then `IBM Plex Mono SemiBold Regular 22`. If a font name in `theme.txt` doesn't match, GRUB falls back to its default font without an error. `strings file.pf2 | grep -m1 Plex` shows a file's name.

`grub/preview.sh` boots the theme in QEMU and saves a screenshot as `grub/shot.png`. Pass key names to press first, like `./preview.sh "down down"`.
