#!/bin/bash
# Build an APK with a clean, verifiable version stamp — WITHOUT leaving
# the working tree dirty or generating stamp commits.
#
# How: the stamp is written to lib/core/build_stamp.dart and passed as
# --build-name/--build-number (overriding pubspec at build time), the APK
# is built, then both files are restored to their committed placeholders.
# The committed tree never carries a build number; each APK's number is
# derivable: <commit-count of last non-stamp commit>.
set -euo pipefail
cd "$(dirname "$0")/.."

SHA=$(git rev-parse --short HEAD)
COUNT=$(git rev-list --count HEAD)
NAME="1.0.$COUNT"

python3 - "$SHA" "$COUNT" <<'PYEOF'
import sys
sha, count = sys.argv[1], sys.argv[2]
open('lib/core/build_stamp.dart', 'w').write(f'''//! GENERATED at build time by tool/build_apk.sh — do not edit by hand.
/// The committed placeholder is restored after the build.
library;

/// Git short SHA of the commit this build was made from.
const String buildSha = '{sha}';

/// Git commit count at build time (matches the Android versionCode).
const int buildNumber = {count};
''')
PYEOF

flutter build apk --debug --build-name="$NAME" --build-number="$COUNT" "$@"

# Restore placeholders: the tree stays clean; no stamp commits.
git restore pubspec.yaml lib/core/build_stamp.dart
echo "built $NAME+$COUNT from $SHA (tree restored clean)"
