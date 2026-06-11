#!/usr/bin/env bash
# Autostart the Chrome PWA app windows on login. Each one self-routes to its home
# workspace via the assign rules in 50-assignments.conf — no workspace switching.
# Called from 70-autostart.conf.
#
# The general browsing window (class Google-chrome → ws10, left of Claude) is
# launched by browse-layout.sh so it lands in that workspace's sized layout slot.
# All windows share Chrome's Default profile (one browser process); the PWAs
# connect to it if it's already up, else spin it up themselves. i3 routes each
# PWA by its stable instance crx_<app-id>.
set -euo pipefail

CHROME=google-chrome

# Reboot kills Chrome uncleanly, so its next launch crash-restores the previous
# session's PWA windows — duplicating the three we launch below. Mark the prior
# exit clean (Chrome isn't running yet at login) so only our launches open.
# Pinned tabs are unaffected: they live in the separate pinned_tabs pref.
PREFS="$HOME/.config/google-chrome/Default/Preferences"
if ! pgrep -x chrome >/dev/null && [[ -f "$PREFS" ]]; then
  sed -i 's/"exit_type":"Crashed"/"exit_type":"Normal"/' "$PREFS"
fi

# PWA app windows (Default profile), routed by their crx_<app-id> instance:
#   YouTube Music → ws7   |   Hypar-Slack → ws9   |   Gather → ws9
"$CHROME" --profile-directory=Default --app-id=cinhimbnkkaeohfgghhklpknlkffjgod &  # YouTube Music
"$CHROME" --profile-directory=Default --app-id=cjegmahegccmkkneaindnbeppnipnadp &  # Hypar-Slack
"$CHROME" --profile-directory=Default --app-id=lbopdchpdedgklbinbhhgnglcghfdjid &  # Gather
