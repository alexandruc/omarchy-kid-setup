# Adding a child account to Omarchy — findings, setup, and next steps

**Date:** 2026-10-21
**System:** Omarchy 4.0.6 (package `omarchy-settings`), Arch Linux, Hyprland on Wayland, SDDM greeter
**Account created:** `edi` (uid 1001, home `/home/edi`, no sudo)

---

## 1. Conclusions — how Omarchy handles user accounts

### There is no built-in "add user" command

`omarchy commands` exposes no user/group management. Omarchy is built around a
single user: the ISO installer creates one account, and every per-user config
path is seeded from that one home directory. Adding a second account is
entirely possible, but it is "do it by hand" territory.

### The pieces that make a second account work

| Piece | What it does | Why it matters |
|---|---|---|
| `/etc/skel` | Contains the full Omarchy + Hyprland user config set: `hypr/*.lua`, `omarchy/shell.json`, the menu extension, terminal configs, `.bashrc` | `useradd -m` copies it, so a new user gets a working desktop for free |
| `omarchy-provision-user` | The "finalize a new Omarchy user" script: theme, keyring, XDG dirs, GTK bookmarks, default browser, `install/user/all.sh` | This is what the installer runs for the owner. Normally triggered automatically |
| `omarchy-provision-first-run` | Runs `omarchy-provision-user` plus the light first-login steps (user units, notifications, welcome card) | Triggered from `hypr/autostart.lua` → so it fires on the new user's first login |
| `~/.config/hypr/hyprland.lua` (from skel) | `require("default.hypr.omarchy")` → pulls in `default.hypr.autostart` | This is why the shell, bar and first-run hook all start for a second user with no extra work |

### Privilege model

- The owner's own account is a member of `wheel` **only** — no `video`, `render`,
  `input` or `audio` groups. Device access comes from systemd-logind's seat ACLs
  at login, not from group membership. A second account therefore needs no
  extra groups to get sound, video and input working.
- `wheel` is the only thing that grants root. Omarchy also drops narrow
  per-command rules in `/etc/sudoers.d/` (`50-asdcontrol`, `omarchy-dns`,
  `omarchy-theme-browser`, `omarchy-tzupdate`). These are `%wheel`-scoped, so a
  non-`wheel` user inherits nothing.
  - `50-asdcontrol` contains the line `ALL ALL=(ALL) !/usr/bin/asdcontrol`,
    which *looks* like a blanket grant. It is not: verified empirically that
    `sudo id` as `edi` is rejected with "user edi is not allowed to execute
    '/usr/bin/id' as root", even with the correct password.

### Login manager

- SDDM, with `/etc/sddm.conf.d/autologin.conf` pointing at `houseofchica`.
- SDDM's `Relogin` option defaults to **false**, so autologin happens only at
  boot. After a manual logout the greeter appears and a second user can be
  picked — no config change needed.
- The session file `omarchy.desktop` ships in `/usr/local/share/wayland-sessions/`
  (from the `omarchy-settings` package), and it launches the session through
  `uwsm`. Pick **"Omarchy (Hyprland uwsm)"** in the greeter to match the
  owner's session.

---

## 2. What was done for `edi`

### Account creation

```bash
useradd -m -s /bin/bash -c "Edi" edi     # deliberately NOT -G wheel
```

Home seeded from `/etc/skel`, so `~/.config/hypr`, `~/.config/omarchy`,
terminal configs and dotfiles all came across.

### Omarchy user setup (seeded manually, headless)

Run as `edi`, with `HOME`/`XDG_*` pointed at the new home:

- `OMARCHY_THEME_HEADLESS=1 omarchy-theme-set tokyo-night` — the theme's
  generated files (alacritty.toml, foot.ini, shell.toml, hyprland.lua, …) land
  in `~/.local/state/omarchy/current/theme/`, and every terminal config in
  `~/.config/` just `include`s from there, so the whole desktop is themed.
- btop theme symlink, GNOME keyring, XCompose, git identity
  (`user.name = Edi`), Chromium native-messaging hosts
- XDG user dirs (`Downloads`, `Pictures`, `Videos`) and GTK bookmarks
- App launchers copied from `$OMARCHY_PATH/applications/*.desktop` — **not**
  via `omarchy-refresh-applications`, because that also runs
  `install/user/mise.sh`
- Default browser `chromium.desktop`, mail handler `HEY.desktop`

### Deliberately skipped

| Skipped | Reason | How to add it later |
|---|---|---|
| `install/user/mise.sh` | Installs the whole AI-agent toolchain — codex, claude, crush, gemini, gh, copilot, opencode, playwright, pi, omp, grok, mus, hunk, ghui (~1.5 GB in `~/.local/share/mise`) | `sudo -iu edi omarchy-provision-user --force` |
| `install/user/mise-work.sh` (Node download) | Not needed for a desktop account | same as above |
| `omarchy-theme-set-pi --activate` | Agent-related | same as above |

Because the agent install was skipped, the `finalize-user` done-marker was set
manually (`omarchy-done mark finalize-user`). Without it, the first login would
have run `omarchy-provision-user` and pulled in the whole toolchain. The
remaining first-run steps (user systemd units, GNOME theme, speaker tuning,
welcome/wifi notifications) still run normally at first login.

### Verification performed

```
id edi                        → uid=1001(edi) gid=1001(edi) groups=1001(edi)      # no wheel
sudo id as edi               → "user edi is not allowed to execute '/usr/bin/id'"  # denied
~/.config/hypr/hyprland.lua   → requires default.hypr.omarchy                       # shell + first-run hook active
shell.json idle              → screensaver 150, lock 300 (5 min)                   # inherited from skel
theme.name                    → tokyo-night
```

---

## 3. Immediate next steps

```bash
# 1. Set a password the child can actually type
sudo passwd edi

# 2. Install the greeter theme that lets you pick the account
sudo ./install-sddm-multiuser-theme.sh

# 3. Log out, click the user you want at the greeter, and log in.
```

The temporary password (also in `/root/omarchy-user-edi.password`, mode 600) was
printed during setup. Replace it — it lives in the chat transcript otherwise.

The stock Omarchy greeter has **no user chooser** — it can only log in as the
last user. See section 4 for the fix.

### Managing the account later

```bash
sudo passwd edi                       # reset the password
sudo usermod -aG wheel edi            # grant admin (not recommended for a child)
sudo usermod -G '' edi                # revoke admin
sudo userdel -r edi                   # delete the account and its home
sudo -iu edi                          # become edi to test their session
```

---

## 4. Choosing the account at the greeter

### The problem

After logging out there is no user chooser. The greeter shows the Omarchy
theme, which is a **password box with no user list** — by design, because
Omarchy assumes a single user.

`/usr/share/sddm/themes/omarchy/Main.qml` does this:

```qml
property string currentUser: userModel.lastUser
...
sddm.login(root.currentUser, password.text, root.sessionIndex)
```

`userModel.lastUser` is the user who logged in last, so the greeter can only
ever log in as that one account. There is no way to pick anyone else from the
UI, and `Relogin` is `false` by default, so you do get a greeter after a
logout — just not one that can choose.

### The fix

A drop-in replacement theme, `omarchy-multiuser`, in
`sddm-theme-omarchy-multiuser/` in this directory. Same look, plus a clickable
row of user names above the password field (arrow keys switch between them).
It lives in its own directory rather than as a patch to
`/usr/share/sddm/themes/omarchy`, because `omarchy-refresh-sddm` and the
plymouth theme refresh rewrite that directory from the packaged defaults; this
one symlinks the shared PNG assets instead, so it stays in sync.

```bash
sudo ./install-sddm-multiuser-theme.sh            # install
sudo ./install-sddm-multiuser-theme.sh --uninstall # back to stock
```

The installer writes:

| File | Purpose |
|---|---|
| `/usr/share/sddm/themes/omarchy-multiuser/` | The theme (`Main.qml`, `metadata.desktop`, `theme.conf`, symlinked assets) |
| `/etc/sddm.conf.d/zz-multiuser.conf` | `[Theme] Current=omarchy-multiuser` |

`zz-multiuser.conf` sorts after `99-omarchy-login.conf`, which is what sets
`Current=omarchy`; sddm reads every file in `/etc/sddm.conf.d` in
alphabetical order and the last one wins.

**No sddm restart is needed.** `Seat::createDisplay()` in the sddm daemon
calls `mainConfig.load()`, which reloads the config whenever the files change
— and the greeter is started as part of that path. The new theme appears the
next time the greeter comes up.

### What was verified

The theme was run against the real greeter (`sddm-greeter-qt6 --test-mode`)
with temporary `console.log` instrumentation, and the output was read back
from the journal:

```
THEMEDEBUG count=2 lastUser=houseofchica
THEMEDEBUG user[0] name=edi          real=Edi
THEMEDEBUG user[1] name=houseofchica real=
THEMEDEBUG chip index=0 row=0 uname=[edi]          text=[  edi]
THEMEDEBUG chip index=1 row=1 uname=[houseofchica] text=[  houseofchica]
```

No QML errors in the journal.

### One gotcha in the sddm user model

`UserModel::data()` (sddm 0.21, `src/greeter/UserModel.cpp`) implements
**no** `Qt::DisplayRole`. The roles are:

```cpp
enum UserRoles {
    NameRole     = Qt::UserRole + 1,   // "name"
    RealNameRole = Qt::UserRole + 2,   // "realName"
    HomeDirRole, IconRole, NeedsPasswordRole
};
```

So `userModel.data(idx, Qt.DisplayRole)` returns an empty variant and a
`ComboBox { model: userModel }` with the default `textRole` shows blank
entries. Use `textRole: "name"`, or the role number directly:

```qml
userModel.data(userModel.index(row, 0), Qt.UserRole + 1)
```

`index()` and `data()` are `Q_INVOKABLE` on `QAbstractItemModel`, so they are
callable from QML. The users are sorted by name, and `userModel.count`,
`userModel.lastUser` and `userModel.lastIndex` are all `Q_PROPERTY`s.

### If you would rather not install a theme

The `maldives` theme that ships with sddm has a plain username text box:

```bash
echo -e '[Theme]\nCurrent=maldives' | sudo tee /etc/sddm.conf.d/zz-multiuser.conf
```

Type `edi` into it, then the password. You lose the Omarchy look.

---

## 5. The script

`add-omarchy-user.sh` in this directory does all of the above for any account:

```bash
sudo ./add-omarchy-user.sh <username> [full-name]
OMARCHY_THEME=tokyo-night sudo ./add-omarchy-user.sh <username> [full-name]
```

It is re-runnable: if the account already exists it skips creation and
continues with the setup.

### Two bugs worth remembering

1. **`SIGPIPE` under `set -o pipefail`.** `tr -dc 'A-Za-z0-9' </dev/urandom | head -c 20`
   makes `head` exit early, `tr` dies with a broken pipe, and with
   `pipefail` the whole pipeline fails. Fixed by reading a fixed number of
   bytes first: `head -c 128 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | cut -c1-20`.
2. **git and the current working directory.** Under `pkexec` the cwd is `/root`,
   and git's repository discovery walks into `/root/.git` and fails with
   `fatal: error reading '/root/.git'` — which silently broke
   `git config --global user.name` (the installer's `git.sh` exits 0 anyway
   because its last statement is a false `if`). Fixed with
   `env --chdir="$home"`.

---

## 6. Suggestions for further hardening

Pick only what is worth the friction. The account already locks the screen
after 5 minutes of idle time.

### Enforced (root-owned, cannot be undone by the child)

- **Screen-time cap.** A root-owned systemd system unit with
  `loginctl terminate-session` after N minutes of a session, triggered on
  `systemd-logind`'s session start. Needs a systemd path rule, not a user unit.
- **Read-only user config.** `chown root:root` + `chmod 444` on
  `/home/edi/.config/omarchy/shell.json` and
  `/home/edi/.config/omarchy/extensions/omarchy-menu.jsonc` so the idle
  timeout and the menu contents cannot be edited from inside the session.
  The trade-off: `omarchy refresh shell` stops working for that user.
- **Hide the terminal and coding tools.** Override the built-in menu rows with
  `"when": "false"` in the child's
  `~/.config/omarchy/extensions/omarchy-menu.jsonc` (the extension file can
  reuse a built-in id and hide it). Combine with the read-only trick above to
  make it stick.
- **A separate browser profile with a content blocker.** Chromium's managed
  policies live in `/etc/chromium/policies/managed/` and are machine-wide, so a
  kid-specific `URLBlocklist` would also apply to the owner's account. A
  per-profile extension is the clean route. Note that Chromium is installed
  system-wide, so the child can still launch it directly.

### Advisory (the child can undo it)

- `omarchy dns Cloudflare` — system-wide, not per-user, but it blocks malware
  and phishing domains for everyone.
- A short `idle.lock` in the child's `shell.json`.
- A kid-friendly Chromium profile, Google Family Link or a signed-in child
  account inside the browser.

### Things Omarchy does not provide

There are no built-in parental controls, no per-user quotas, and no multi-user
installer. Upstream discussion (basecamp/omarchy#532, "Support Multiple Users")
confirms this is a known gap, so anything beyond the above is custom work.

---

## 7. Reference: file locations

| Path | What |
|---|---|
| `/etc/skel` | Seed for every new home (the Omarchy/Hyprland user configs) |
| `/usr/bin/omarchy-provision-user` | Per-user Omarchy finalization |
| `/usr/bin/omarchy-provision-first-run` | First-login sequence |
| `/usr/share/omarchy/install/user/` | The installer's per-user setup scripts |
| `/usr/share/omarchy/install/user/mise.sh` | The AI-agent toolchain install (the heavy one) |
| `/etc/sddm.conf.d/autologin.conf` | SDDM autologin (`User=`, `Session=`, `Relogin=`) |
| `/usr/local/share/wayland-sessions/omarchy.desktop` | The "Omarchy (Hyprland uwsm)" session |
| `/etc/sudoers.d/` | Narrow root grants; all `%wheel`-scoped |
| `~/.config/omarchy/shell.json` | Bar layout + `idle.screensaver` / `idle.lock` |
| `~/.config/omarchy/extensions/omarchy-menu.jsonc` | Menu rows; can override built-ins |
| `~/.local/state/omarchy/done/` | Done-markers (`finalize-user`, `first-run-user`) |
| `/usr/share/sddm/themes/omarchy/Main.qml` | The stock greeter theme — password only, no user list |
| `/usr/share/sddm/themes/omarchy-multiuser/` | The replacement theme with a user chooser |
| `/etc/sddm.conf.d/zz-multiuser.conf` | Selects `omarchy-multiuser` as the greeter theme |
