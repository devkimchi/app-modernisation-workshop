#!/usr/bin/env bash

if [ -z "${BASH_VERSION:-}" ]; then
    printf '%s\n' '[FAIL] Run ./scripts/apply-java-04-2-snapshot.sh.' >&2
    return 2 2>/dev/null || exit 2
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
WORKSHOP_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
APP_ROOT="$WORKSHOP_ROOT/java"
SNAPSHOT="$WORKSHOP_ROOT/snapshots/java/04-2"
BACKUP="$WORKSHOP_ROOT/java-04-2"

fail() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 1
}

if [[ "$(pwd -P)" != "$WORKSHOP_ROOT" ]]; then
    fail 'Run this script from the workshop repository root.'
fi
if [[ ! -d "$APP_ROOT" || -L "$APP_ROOT" || ! -f "$APP_ROOT/pom.xml" || ! -d "$APP_ROOT/web" || ! -d "$APP_ROOT/worker" ]]; then
    fail 'The Java application directory is missing or does not have the expected structure.'
fi
if [[ ! -d "$SNAPSHOT" || ! -f "$SNAPSHOT/pom.xml" || ! -d "$SNAPSHOT/web" || ! -d "$SNAPSHOT/worker" ]]; then
    fail 'The Java 04-2 snapshot is missing or does not have the expected structure.'
fi
if [[ -e "$BACKUP" || -L "$BACKUP" ]]; then
    fail 'The java-04-2 backup already exists. It will not be overwritten.'
fi

STAGING="$(mktemp -d "$WORKSHOP_ROOT/.java-snapshot-04-2.XXXXXX")" || fail 'Could not create a temporary directory.'
cleanup() {
    if [[ -d "$STAGING" ]]; then rm -rf -- "$STAGING" || printf '%s\n' '[FAIL] Could not remove the temporary snapshot directory.' >&2; fi
}
trap cleanup EXIT

if ! cp -Rp "$SNAPSHOT/." "$STAGING/"; then
    fail 'Could not copy the Java 04-2 snapshot. The existing application is unchanged.'
fi
if ! mv -- "$APP_ROOT" "$BACKUP"; then
    fail 'Could not move the existing application to java-04-2.'
fi
if ! mv -- "$STAGING" "$APP_ROOT"; then
    if mv -- "$BACKUP" "$APP_ROOT"; then
        fail 'Could not apply the snapshot. The original application has been restored.'
    fi
    fail 'Could not apply the snapshot or restore the original application. The original remains in java-04-2.'
fi

printf '%s\n' '[PASS] The original Java application is backed up in java-04-2.'
printf '%s\n' '[PASS] The Java 04-2 snapshot is now the java application.'
