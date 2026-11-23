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
    local fixture="$1" version="$2"
    mkdir -p "$fixture/scripts" "$fixture/snapshots/java/$version/web" "$fixture/snapshots/java/$version/worker" "$fixture/java/web" "$fixture/java/worker"
    cp "$ROOT/scripts/apply-java-$version-snapshot.sh" "$fixture/scripts/"
    printf 'snapshot\n' > "$fixture/snapshots/java/$version/pom.xml"
    printf 'snapshot-web\n' > "$fixture/snapshots/java/$version/web/marker.txt"
    printf 'snapshot-hidden\n' > "$fixture/snapshots/java/$version/.snapshot-hidden"
    printf 'original\n' > "$fixture/java/pom.xml"
    printf 'original-web\n' > "$fixture/java/web/marker.txt"
}

for version in 03 04-1; do
    success="$TEMPORARY/$version-success"
    new_fixture "$success" "$version"
    (cd "$success" && bash "scripts/apply-java-$version-snapshot.sh") > "$TEMPORARY/$version-success.log"
    assert "$version successful apply keeps original backup" test "$(cat "$success/java-$version/pom.xml")" = original
    assert "$version successful apply copies snapshot files" test "$(cat "$success/java/pom.xml")" = snapshot
    assert "$version successful apply copies hidden files" test "$(cat "$success/java/.snapshot-hidden")" = snapshot-hidden
    assert "$version successful apply preserves snapshot source" test "$(cat "$success/snapshots/java/$version/pom.xml")" = snapshot

    existing_backup="$TEMPORARY/$version-existing-backup"
    new_fixture "$existing_backup" "$version"
    mkdir "$existing_backup/java-$version"
    printf 'do-not-overwrite\n' > "$existing_backup/java-$version/marker.txt"
    if (cd "$existing_backup" && bash "scripts/apply-java-$version-snapshot.sh") > "$TEMPORARY/$version-existing-backup.log" 2>&1; then
        printf 'FAILED: %s existing backup should be rejected\n' "$version" >&2
        exit 1
    fi
    assert "$version existing backup is preserved" test "$(cat "$existing_backup/java-$version/marker.txt")" = do-not-overwrite
    assert "$version app is unchanged after rejection" test "$(cat "$existing_backup/java/pom.xml")" = original
done

printf 'PASS: %s Java snapshot checks\n' "$PASSED"
