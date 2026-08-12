#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# This command never targets manus-guardian. The synthetic project id keeps
# Auth, Firestore, and Functions emulator data isolated from real Firebase.
npm --prefix firebase/functions run build
firebase emulators:exec \
  --only auth,firestore,functions \
  --project guardian-eye-emulator \
  "npm --prefix firebase/tests test && npm --prefix firebase/functions run test:emulator"
