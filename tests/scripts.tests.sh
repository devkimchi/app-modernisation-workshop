#!/usr/bin/env bash
set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$ROOT/scripts/check-prerequisites.sh"
source "$ROOT/scripts/download-sample.sh"
mkdir -p "$ROOT/.test-output"
TEMPORARY=$(mktemp -d "$ROOT/.test-output/bash.XXXXXXXX")
trap 'rm -rf -- "$TEMPORARY"' EXIT
PASSED=0

assert() {
    local name="$1"; shift
    if ! "$@"; then printf 'FAILED: %s\n' "$name" >&2; exit 1; fi
    PASSED=$((PASSED + 1))
}

bash -n "$ROOT/scripts/check-prerequisites.sh"
bash -n "$ROOT/scripts/download-sample.sh"
unset AZD_CONTAINER_RUNTIME
assert 'default engine' test "$(resolve_engine '')" = docker
assert 'explicit engine' test "$(resolve_engine podman)" = podman
export AZD_CONTAINER_RUNTIME=podman
assert 'configured engine' test "$(resolve_engine '')" = podman
if resolve_engine docker >/dev/null 2>&1; then exit 1; else PASSED=$((PASSED + 1)); fi
if resolve_engine nerdctl >/dev/null 2>&1; then exit 1; else PASSED=$((PASSED + 1)); fi
unset AZD_CONTAINER_RUNTIME
assert 'azd minimum' minimum_version 'azd version 1.37.3 (commit abc)' 1.37.3
if minimum_version 1.37.2 1.37.3; then exit 1; else PASSED=$((PASSED + 1)); fi
if minimum_version 22.0.0-rc.1 22.0.0; then exit 1; else PASSED=$((PASSED + 1)); fi

CALLS="$TEMPORARY/calls"
STOPPED=0
probe() {
    printf '%s\n' "$*" >> "$CALLS"
    PROBE_CODE=0; PROBE_TEXT=''
    case "$2" in
        --version) PROBE_TEXT="$1 version 5.4.0" ;;
        info) if (( STOPPED )); then PROBE_CODE=1; else PROBE_TEXT=linux; fi ;;
        build) PROBE_TEXT=--platform ;;
        buildx) PROBE_CODE=127 ;;
    esac
}
CHECK_FAILURES=0
check_container podman
assert 'podman without docker' test "$CHECK_FAILURES" = 0
if grep -q '^docker ' "$CALLS"; then exit 1; else PASSED=$((PASSED + 1)); fi
: > "$CALLS"
STOPPED=1
CHECK_FAILURES=0
check_container docker
assert 'stopped docker fails' test "$CHECK_FAILURES" -gt 0
if grep -q '^podman ' "$CALLS"; then exit 1; else PASSED=$((PASSED + 1)); fi
source "$ROOT/scripts/check-prerequisites.sh"

export SDKMAN_DIR="$TEMPORARY/sdkman"
mkdir -p "$SDKMAN_DIR/bin"
printf 'sdk() { echo "SDKMAN fixture"; }\n' > "$SDKMAN_DIR/bin/sdkman-init.sh"
for v in 8 21 25; do
    mkdir -p "$SDKMAN_DIR/candidates/java/$v-test/bin"
    if [[ "$v" == 8 ]]; then version=1.8.0_400; else version="$v"; fi
    printf '#!/usr/bin/env bash\nprintf '\''openjdk version "%s"\\n'\'' >&2\n' "$version" > "$SDKMAN_DIR/candidates/java/$v-test/bin/java"
    printf '#!/usr/bin/env bash\nprintf '\''javac %s\\n'\''\n' "$version" > "$SDKMAN_DIR/candidates/java/$v-test/bin/javac"
    chmod +x "$SDKMAN_DIR/candidates/java/$v-test/bin/"*
done
CHECK_FAILURES=0
check_java_sdks
assert 'all SDKMAN majors' test "$CHECK_FAILURES" = 0
mv "$SDKMAN_DIR/candidates/java/25-test" "$TEMPORARY/moved-jdk"
CHECK_FAILURES=0
check_java_sdks
assert 'missing JDK fails' test "$CHECK_FAILURES" = 1

if safe_destination "$ROOT" "$ROOT" >/dev/null 2>&1; then exit 1; else PASSED=$((PASSED + 1)); fi
if safe_destination "$ROOT/docs/child" "$ROOT" >/dev/null 2>&1; then exit 1; else PASSED=$((PASSED + 1)); fi
if [[ "$ROOT/DOCS" -ef "$ROOT/docs" ]]; then
    if safe_destination "$ROOT/DOCS/child" "$ROOT" >/dev/null 2>&1; then exit 1; else PASSED=$((PASSED + 1)); fi
fi
if safe_destination "$HOME" "$ROOT" >/dev/null 2>&1; then exit 1; else PASSED=$((PASSED + 1)); fi
if safe_destination '//server/share/app' "$ROOT" >/dev/null 2>&1; then exit 1; else PASSED=$((PASSED + 1)); fi
if safe_destination 'C:\workshops\app' "$ROOT" >/dev/null 2>&1; then exit 1; else PASSED=$((PASSED + 1)); fi
mkdir "$TEMPORARY/existing"
printf preserve > "$TEMPORARY/existing/.hidden"
if safe_destination "$TEMPORARY/existing" "$ROOT" >/dev/null 2>&1; then exit 1; else PASSED=$((PASSED + 1)); fi
assert 'preserve existing' test "$(cat "$TEMPORARY/existing/.hidden")" = preserve

UPSTREAM="$TEMPORARY/upstream"
mkdir -p "$UPSTREAM/asset-manager/.mvn/wrapper" "$UPSTREAM/asset-manager/web" "$UPSTREAM/asset-manager/worker"
for f in pom.xml mvnw .gitignore .mvn/wrapper/maven-wrapper.properties web/test worker/test; do
    printf fixture > "$UPSTREAM/asset-manager/$f"
done
chmod +x "$UPSTREAM/asset-manager/mvnw"
printf '#!/usr/bin/env bash\nexit 0\n' > "$UPSTREAM/asset-manager/mvnw"
printf 'Fixture license\n' > "$UPSTREAM/LICENSE"
printf 'Fixture notice\n' > "$UPSTREAM/NOTICE.md"
printf 'Fixture alternate license\n' > "$UPSTREAM/license-MIT.txt"
printf 'Fixture copyright\n' > "$UPSTREAM/COPYRIGHT"
printf '<project><properties><java.version>1.8</java.version></properties></project>\n' > "$UPSTREAM/asset-manager/pom.xml"
git init --quiet "$UPSTREAM"
git -C "$UPSTREAM" config core.autocrlf false
git -C "$UPSTREAM" add .
git -C "$UPSTREAM" update-index --chmod=+x asset-manager/mvnw
git -C "$UPSTREAM" -c user.name=Fixture -c user.email=fixture@example.invalid commit --quiet -m $'Fixture\n\nCo-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>'
COMMIT=$(git -C "$UPSTREAM" rev-parse HEAD)
TARGET="$TEMPORARY/download with spaces"
download_sample "$TARGET" "$UPSTREAM" "$COMMIT" asset-manager java "$ROOT"
assert 'flattened Maven project' test -f "$TARGET/pom.xml"
assert 'wrapper files preserved' test -f "$TARGET/.mvn/wrapper/maven-wrapper.properties"
assert 'executable wrapper' test -x "$TARGET/mvnw"
assert 'hidden files preserved' test -f "$TARGET/.gitignore"
assert 'license preserved' test -f "$TARGET/UPSTREAM-LICENSE"
assert 'metadata commit' grep -q "$COMMIT" "$TARGET/upstream-source.json"
assert 'metadata repository' grep -Fq "\"repository\": \"$UPSTREAM\"" "$TARGET/upstream-source.json"
assert 'metadata subdirectory' grep -Fq '"subdirectory": "asset-manager"' "$TARGET/upstream-source.json"
assert 'license metadata' grep -Fq '"licenseFileFound": true' "$TARGET/upstream-source.json"
for name in LICENSE NOTICE.md license-MIT.txt COPYRIGHT; do
    assert "notice bytes preserved: $name" cmp "$UPSTREAM/$name" "$TARGET/UPSTREAM-$name"
done
for name in pom.xml mvnw .gitignore .mvn/wrapper/maven-wrapper.properties web/test worker/test; do
    assert "source bytes unchanged: $name" cmp "$UPSTREAM/asset-manager/$name" "$TARGET/$name"
done
assert 'independent Git directory' test -d "$TARGET/.git"
assert 'new Git repository has no origin' test -z "$(git -C "$TARGET" remote)"
if safe_destination "$TARGET" "$ROOT" >/dev/null 2>&1; then exit 1; else PASSED=$((PASSED + 1)); fi
for name in upstream-source.json UPSTREAM-NOTICE.md; do
    printf 'preserve upstream content\n' > "$UPSTREAM/asset-manager/$name"
    git -C "$UPSTREAM" add .
    git -C "$UPSTREAM" -c user.name=Fixture -c user.email=fixture@example.invalid commit --quiet -m $'Fixture collision\n\nCo-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>'
    collision_commit=$(git -C "$UPSTREAM" rev-parse HEAD)
    if bash -c 'source "$1/scripts/download-sample.sh"; download_sample "$2" "$3" "$4" asset-manager java "$1"' _ "$ROOT" "$TEMPORARY/$name" "$UPSTREAM" "$collision_commit"; then
        printf 'FAILED: source collision accepted: %s\n' "$name" >&2; exit 1
    else PASSED=$((PASSED + 1)); fi
    assert "collision not published: $name" test ! -e "$TEMPORARY/$name"
    rm -- "$UPSTREAM/asset-manager/$name"
done

# Failures run in a separate shell so Bash conditional calls cannot disable errexit.
if bash -c 'source "$1/scripts/download-sample.sh"; download_sample "$2" "$3" "$4" asset-manager java "$1"' _ "$ROOT" "$TEMPORARY/failed" "$UPSTREAM" 0000000000000000000000000000000000000000; then
    printf 'FAILED: bad commit accepted\n' >&2; exit 1
else PASSED=$((PASSED + 1)); fi
assert 'failed download not published' test ! -e "$TEMPORARY/failed"
assert 'temporary paths cleaned' test -z "$(find "$TEMPORARY" -maxdepth 1 -name '.workshop-download.*' -print)"
printf 'PASS: %s Bash assertions\n' "$PASSED"
