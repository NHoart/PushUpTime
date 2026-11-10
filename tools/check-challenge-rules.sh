#!/bin/bash
# Baut und startet die ausführbaren Challenge-Prüfungen.
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p build/checks
swiftc -parse-as-library -O -o build/checks/ChallengeChecks \
  Shared/PushUpShared.swift \
  Shared/ChallengeRules.swift \
  PushUpTime/ChallengeStats.swift \
  PushUpTime/ShortcutRules.swift \
  PushUpTime/AppModel.swift \
  tools/ChallengeChecks.swift

./build/checks/ChallengeChecks
