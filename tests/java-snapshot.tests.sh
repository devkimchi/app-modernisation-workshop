#!/usr/bin/env bash
set -e

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEMPORARY="$ROOT/.test-output/java-snapshot.$$.$RANDOM"
mkdir -p "$TEMPORARY"
trap 'rm -rf -- "$TEMPORARY"' EXIT
PASSED=0

assert() {
    local name="$1"; shift
    if ! "$@"; then printf 'FAILED: %s\n' "$name" >&2; exit 1; fi
    PASSED=$((PASSED + 1))
}

new_fixture() {
    local fixture="$1"
    mkdir -p "$fixture/scripts" "$fixture/snapshots/java/03/web" "$fixture/snapshots/java/03/worker" "$fixture/java/web" "$fixture/java/worker"
    cp "$ROOT/scripts/apply-java-03-snapshot.sh" "$fixture/scripts/"
    printf 'snapshot\n' > "$fixture/snapshots/java/03/pom.xml"
    printf 'snapshot-web\n' > "$fixture/snapshots/java/03/web/marker.txt"
    printf 'snapshot-hidden\n' > "$fixture/snapshots/java/03/.snapshot-hidden"
    printf 'original\n' > "$fixture/java/pom.xml"
    printf 'original-web\n' > "$fixture/java/web/marker.txt"
}

success="$TEMPORARY/success"
new_fixture "$success"
(cd "$success" && bash scripts/apply-java-03-snapshot.sh) > "$TEMPORARY/success.log"
assert 'successful apply keeps original backup' test "$(cat "$success/java-03/pom.xml")" = original
assert 'successful apply copies snapshot files' test "$(cat "$success/java/pom.xml")" = snapshot
assert 'successful apply copies hidden files' test "$(cat "$success/java/.snapshot-hidden")" = snapshot-hidden
assert 'successful apply preserves snapshot source' test "$(cat "$success/snapshots/java/03/pom.xml")" = snapshot

existing_backup="$TEMPORARY/existing-backup"
new_fixture "$existing_backup"
mkdir "$existing_backup/java-03"
printf 'do-not-overwrite\n' > "$existing_backup/java-03/marker.txt"
if (cd "$existing_backup" && bash scripts/apply-java-03-snapshot.sh) > "$TEMPORARY/existing-backup.log" 2>&1; then
    printf '%s\n' 'FAILED: existing backup should be rejected' >&2
    exit 1
fi
assert 'existing backup is preserved' test "$(cat "$existing_backup/java-03/marker.txt")" = do-not-overwrite
assert 'existing application is unchanged after rejection' test "$(cat "$existing_backup/java/pom.xml")" = original

printf 'PASS: %s Java snapshot checks\n' "$PASSED"
