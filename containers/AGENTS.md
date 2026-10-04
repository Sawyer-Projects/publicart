# CONTAINERS — Agent Contract
Knowledge document: `README.md` in this directory. Read it before changing anything here.

## WHAT
A kit for running several Claude Desktop accounts side by side on one Mac. A container is a
small wrapper `.app` that sets three environment variables and a `--user-data-dir`, then execs
the one vendor `/Applications/Claude.app`. The kit builds containers (`make`), finds them
(`list`), audits them against the known failure modes (`check`), picks a colour by perceptual
distance (`suggest-hue`), and rings each container's windows in its colour through JankyBorders
(`borders`, driven by a Hammerspoon timer). Written for members of the lab to use on their own
Macs; `README.md` is their guide.

## VERBS
| verb | effect |
|---|---|
| `bin/claude-container make <Name> --hue <0-359\|auto>` | builds bundle, data dir, config dir with retention and `env` (lazy MCP connect, retry watchdog), recoloured icon, ad hoc signature, LaunchServices registration; refuses to overwrite anything |
| `bin/claude-container list` / `check` | discovery (any bundle carrying `ClaudeContainerHue`) / audit, exit 1 on a problem |
| `bin/claude-container borders` | one idempotent pass of per-window colours; `hammerspoon/claude-containers.lua` runs it every 5 s |
| `bin/claude-container suggest-hue` / `colour <hue>` | CIEDE2000-farthest free hue / border hex |
| `tests/selftest.sh` | hermetic proof: temp HOME, fake vendor app, no LaunchServices writes |

## HARD RULES
1. **No instance data in this directory.** No account names, emails, UUIDs, hostnames, colour
   assignments or anyone's container list. The kit describes how to build containers; it holds
   nobody's. Personal instances and their tooling live outside the repo.
2. **Discovery, never a list.** Every command finds containers from the bundles themselves. A
   hardcoded roster anywhere (borders, updates, skills) is the failure this kit exists to avoid:
   an unlisted container silently half-works.
3. **Never build over anything.** `make` refuses an existing bundle, data dir or config dir; an
   existing dir means an account already lives there.
4. **No rename verb** until one ships with a real backup (APFS clone) and a rewrite of `cwd` and
   `originCwd` in the renamed container's session records. A rename without both loses the
   container's scratch workspaces (README, "Never rename casually").
5. Nothing in this directory installs itself anywhere. It is run from a checkout.
6. The vendor app is never modified. Containers wrap it; they do not patch it.

## DONE
`tests/selftest.sh` exits 0, and `bin/claude-container check` is clean on a machine with
containers built by this kit.

## SURFACE
No MCP, no port, no service. A CLI run from a checkout, plus two config files a user copies
(`borders/bordersrc`, `hammerspoon/claude-containers.lua`).
