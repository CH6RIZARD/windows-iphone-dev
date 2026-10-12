#!/bin/bash
# Usage: xtool-login.sh <apple-id> <password>
# Runs xtool login in a pseudo-terminal fed by /tmp/xin; send answers with: echo 123456 > /tmp/xin
source ~/.local/share/swiftly/env.sh; export PATH="$HOME/.local/bin:$PATH"
rm -f /tmp/xin /tmp/xout; mkfifo /tmp/xin
exec 3<>/tmp/xin
script -qfc "xtool auth login -m password -u $(printf %q "$1") -p $(printf %q "$2")" /tmp/xout <&3
