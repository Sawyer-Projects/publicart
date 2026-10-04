#!/bin/bash
# Hermetic self-test for claude-container. Touches nothing outside a temp dir: fake HOME,
# fake Applications folder, fake vendor app, no LaunchServices registration. Exit 0 = pass.
set -uo pipefail
KIT="$(cd "$(dirname "$0")/.." && pwd)"; CLI="$KIT/bin/claude-container"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export HOME="$T/home" APPS_DIR="$T/home/Applications" CLAUDE_APP="$T/Vendor/Claude.app" CC_NO_REGISTER=1 CC_STATE="$T/state"
mkdir -p "$APPS_DIR" "$CLAUDE_APP/Contents/MacOS" "$CLAUDE_APP/Contents/Resources"
REAL_ICON="/Applications/Claude.app/Contents/Resources/electron.icns"
[ -f "$REAL_ICON" ] || { echo "SKIP: needs Claude Desktop installed for a real .icns to recolour"; exit 0; }
cp "$REAL_ICON" "$CLAUDE_APP/Contents/Resources/electron.icns"
/usr/libexec/PlistBuddy -c 'Add :CFBundleIconFile string electron' "$CLAUDE_APP/Contents/Info.plist" >/dev/null
# The fake vendor binary reports what a container hands it.
printf '#!/bin/bash\necho "CONFIG=$CLAUDE_CONFIG_DIR"\necho "SECURE=$CLAUDE_SECURESTORAGE_CONFIG_DIR"\nfor a in "$@"; do echo "ARG=$a"; done\n' > "$CLAUDE_APP/Contents/MacOS/Claude"
chmod 755 "$CLAUDE_APP/Contents/MacOS/Claude"

pass=0; fail=0
ok(){ if eval "$2" >/dev/null 2>&1; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL: $1"; fi; }
A="$APPS_DIR/Claude Alpha.app"

ok "make builds a container"                "'$CLI' make Alpha --hue 200"
ok "bundle has launcher and icon"           "[ -x \"$A/Contents/MacOS/launcher\" ] && [ -s \"$A/Contents/Resources/AppIcon.icns\" ]"
ok "Info.plist carries name and hue"        "'$CLI' list | awk '\$1==\"Alpha\"{print \$2}' | grep -qx 200"
ok "bundle id is not Anthropic's"           "/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' \"$A/Contents/Info.plist\" | grep -qx local.claude-container.alpha"
ok "no URL handler declared"                "! /usr/libexec/PlistBuddy -c 'Print :CFBundleURLTypes' \"$A/Contents/Info.plist\""
ok "signature verifies"                     "codesign --verify --deep \"$A\""
ok "retention written"                      "/usr/bin/python3 -c 'import json;assert json.load(open(\"$HOME/.claude-alpha/settings.json\"))[\"cleanupPeriodDays\"]==3650'"
ok "env settings written"                  "/usr/bin/python3 -c 'import json;e=json.load(open(\"$HOME/.claude-alpha/settings.json\"))[\"env\"];assert e[\"MCP_DISCOVERY_CACHE\"]==\"1\" and e[\"CLAUDE_CODE_RETRY_WATCHDOG\"]==\"1\"'"
PROBE="$("$A/Contents/MacOS/launcher" --probe 2>&1)"
ok "launcher sets CLAUDE_CONFIG_DIR"        "echo \"\$PROBE\" | grep -qx 'CONFIG=$HOME/.claude-alpha'" 
ok "launcher sets secure-storage dir"       "echo \"\$PROBE\" | grep -qx 'SECURE=$HOME/.claude-alpha'"
ok "launcher passes its own data dir"       "echo \"\$PROBE\" | grep -qxF 'ARG=--user-data-dir=$HOME/Library/Application Support/Claude-Alpha'"
ok "launcher forwards extra arguments"      "echo \"\$PROBE\" | grep -qx 'ARG=--probe'"
ok "refuses to overwrite an existing one"   "! '$CLI' make Alpha --hue 100"
ok "refuses a same-name-other-case one"     "! '$CLI' make ALPHA --hue 100"
ok "refuses an existing config dir"         "mkdir -p '$HOME/.claude-gamma' && ! '$CLI' make Gamma --hue 100"
ok "rejects a bad name"                     "! '$CLI' make 'my box' --hue 100 && ! '$CLI' make 9lives --hue 100"
ok "rejects a bad hue"                      "! '$CLI' make Delta --hue 360 && ! '$CLI' make Delta --hue red"
ok "dry run writes nothing"                 "'$CLI' make Epsilon --hue 90 --dry-run && [ ! -e '$APPS_DIR/Claude Epsilon.app' ]"
ok "auto hue picks a distinct colour"       "'$CLI' make Beta --hue auto"
BH="$(/usr/libexec/PlistBuddy -c 'Print :ClaudeContainerHue' "$APPS_DIR/Claude Beta.app/Contents/Info.plist" 2>/dev/null || echo x)"
ok "auto hue is far from Alpha and orange"  "/usr/bin/python3 -c 'import sys; h=float(\"$BH\"); d=lambda a,b: min(abs(a-b),360-abs(a-b)); sys.exit(not (d(h,200)>40 and d(h,15)>40))'"
ok "list shows both"                        "[ \"\$('$CLI' list | tail -n +2 | wc -l | tr -d ' ')\" = 2 ]"
ok "check is clean"                         "'$CLI' check"
touch "$A/Contents/MacOS/launcher.bak"
ok "check catches a stray file in MacOS"    "! '$CLI' check && { '$CLI' check || true; } | grep -q 'extra files'"
rm "$A/Contents/MacOS/launcher.bak"
printf '{"cleanupPeriodDays": 3650}' > "$HOME/.claude-alpha/settings.json"
ok "check catches missing MCP env"          "! '$CLI' check && { '$CLI' check || true; } | grep -q 'MCP_DISCOVERY_CACHE'"
printf '{"cleanupPeriodDays": 30}' > "$HOME/.claude-alpha/settings.json"
ok "check catches short retention"          "{ '$CLI' check || true; } | grep -q 'under a year'"
ok "colour maths is stable"                 "[ \"\$('$CLI' colour 185)\" = 24d0e0 ]"
echo "selftest: $pass passed, $fail failed"; [ "$fail" = 0 ]
