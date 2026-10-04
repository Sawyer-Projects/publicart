# publicart

Public pieces of ART, a personal AI operating system built around Claude Desktop and Claude
Code on macOS. Each top-level folder is one self-contained kit with its own README. Nothing
here carries anyone's accounts, machines or data: the kits describe how to build a thing, and
you build your own.

| folder | what it does |
|---|---|
| [`containers/`](containers/) | Run several Claude Desktop accounts side by side on one Mac, each with its own sign-in, sessions, coloured Dock icon and optional coloured window border. |

## Using a kit with Claude Code

Every kit is written so that a Claude Code session can set it up for you. Clone this repo, open
a Claude Code session in the kit's folder, and say what you want ("set me up a second Claude
container for my lab account"). The kit's `README.md` and `AGENTS.md` tell the session what to
do and what never to do.
