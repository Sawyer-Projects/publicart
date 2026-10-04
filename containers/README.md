# Claude containers

Run several Claude Desktop accounts on one Mac at the same time: a work account, a lab
account, a personal one. Each gets its own Dock icon in its own colour, its own sign-in, its
own sessions and Claude Code history, and optionally a coloured ring around its windows so
you always know which account you are typing into.

Anthropic's app has no multi-account support. This kit does not modify the app. It builds a
small wrapper app per account that starts the one real Claude app with its own storage.

## How it works

```
Claude Work.app  (a 3-file wrapper in ~/Applications)
  launcher  ->  CLAUDE_DATA_DIR   = ~/Library/Application Support/Claude-Work
                CLAUDE_CONFIG_DIR = ~/.claude-work
            ->  exec /Applications/Claude.app ... --user-data-dir=<data dir>
```

| what | where | holds |
|---|---|---|
| data dir | `~/Library/Application Support/Claude-<Name>/` | the desktop sign-in, the session list, desktop MCP config, session scratch folders |
| config dir | `~/.claude-<name>/` | Claude Code transcripts, `settings.json` (retention and `env`), `CLAUDE.md`, skills, the Claude Code login |
| bundle | `~/Applications/Claude <Name>.app` | the launcher, a recoloured icon, `Info.plist` with the container's name and hue |

The name is permanent. Pick it once (see "Never rename casually").

## Requirements

- macOS, with Claude Desktop installed in `/Applications`.
- Xcode Command Line Tools (`xcode-select --install`): provides `python3`, `swiftc`, `codesign`.
- Optional, for window borders: [JankyBorders](https://github.com/FelixKratz/JankyBorders) and
  [Hammerspoon](https://www.hammerspoon.org).

## Make a container

```
bin/claude-container suggest-hue            # the most distinct colour still free
bin/claude-container make Work --hue auto   # or --hue 185; add --dry-run to preview
```

Then, in this order:

1. **Quit every Claude window and container**, then `open -a "Claude Work"` and sign in.
2. **Pick a folder in the composer before your first message** (see "Folders").
3. Drag `~/Applications/Claude Work.app` into the Dock.
4. `bin/claude-container check`

To use a container's account from Terminal: `CLAUDE_CONFIG_DIR=~/.claude-work claude`.

## Borders (optional)

Every container runs the same app, so macOS and JankyBorders see them all as "Claude". The
kit tells them apart by window id instead.

1. `brew install FelixKratz/formulae/borders`
2. `mkdir -p ~/.config/borders && cp borders/bordersrc ~/.config/borders/bordersrc`
3. `brew services start borders`
4. `cp hammerspoon/claude-containers.lua ~/.hammerspoon/` and add this line to
   `~/.hammerspoon/init.lua`, with the real path to your checkout:
   `require("claude-containers").start("/path/to/publicart/containers/bin/claude-container")`
5. Reload Hammerspoon. `bin/claude-container borders` does one pass by hand.

## Commands

| command | does |
|---|---|
| `make <Name> --hue <0-359\|auto> [--dry-run]` | build a container; refuses to overwrite anything |
| `list` | every container, its colour, whether it is running |
| `check` | audit for the problems below; exits 1 if it finds one |
| `borders` | colour each container's windows once (the Hammerspoon timer runs this) |
| `suggest-hue` | the free hue farthest, perceptually, from every colour in use |
| `colour <hue>` | the border colour for a hue |

## Rules learned the hard way

Each of these cost real work before it was written down.

- **Sign in alone.** `claude://` is one system-wide link handler. With two instances running,
  the sign-in callback can land in the wrong one and the new container waits forever.
- **Folders.** A new container has no recent folders, so a session opened without picking one
  starts in a throwaway scratch folder under the data dir. The app deletes a scratch folder
  once nothing refers to it. Never keep work you care about there; pick a real folder.
- **Never rename casually.** Session records store absolute paths under the data dir. Rename
  the folders and every session points at a folder that no longer exists; shortly after the
  next launch the app deletes the scratch folders nothing refers to any more. There is
  deliberately no rename command. If you must: quit that container, clone-copy all three
  locations first (`cp -c -R`, instant on APFS), move them, rewrite `cwd` and `originCwd` in
  every `local_*.json` under `<data dir>/claude-code-sessions/`, then re-sign the bundle.
- **Keep your history.** `make` writes `"cleanupPeriodDays": 3650` into the config dir's
  `settings.json`. Without it Claude Code prunes old transcripts on its default schedule.
- **Connect MCP servers lazily.** `make` also writes `MCP_DISCOVERY_CACHE=1` into that file's
  `env`. Without it every MCP server is probed at launch with a short timeout, and one that is
  slow to start is marked failed and stays failed for the whole session. `check` flags a config
  dir missing it.
- **Hold through usage limits.** `make` writes `CLAUDE_CODE_RETRY_WATCHDOG=1` too. A turn that
  hits a usage limit then waits and continues at the reset instead of ending on the limit card.
- **Nothing extra inside a bundle.** Do not leave a backup like `launcher.bak` in
  `Contents/MacOS`: `codesign` then refuses the whole bundle. Keep backups outside it.
- **A recoloured icon may not show.** The Dock can keep drawing the old icon through a
  relaunch and even a reboot. Remove the Dock tile and drag the app back in.
- **Updates.** With several containers running, a downloaded Claude update may wait until
  every instance has quit. Quit them all, reopen, and the update applies.
- **Choose colours by eye, not by angle.** Hue degrees mislead: greens and yellows crowd
  together and magenta sits close to purple. `suggest-hue` measures perceptual distance
  (CIEDE2000); `check` flags two containers that are hard to tell apart.
- **Containers separate accounts, not trust.** They all run as your macOS user. A session in
  one container can read and write another container's files, including its `CLAUDE.md` and
  `settings.json`, and the Claude Code login token is visible to your own user's processes.
  Do not put a container you do not trust on the same user account.
- **Back up the dot-folders.** `~/.claude-<name>/` is hidden, and some backup tools skip hidden
  folders by default. Back up the config dir and the whole data dir, scratch folders included.

## Remove a container

Quit it, remove its Dock tile, then move its bundle, data dir and config dir to the Trash.
Nothing else refers to it: every command discovers containers from the bundles.

## Develop

`tests/selftest.sh` builds throwaway containers in a temp home against a fake vendor app and
checks every rule above that can be checked. It must pass before any change is committed.
`lib/winmap.swift` is the window lister the borders use; it is compiled on first use.
