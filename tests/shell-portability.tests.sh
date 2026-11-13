#!/usr/bin/env bash
if [ -z "${BASH_VERSION:-}" ]; then
    printf '%s\n' '[FAIL] ./tests/shell-portability.tests.sh로 실행하세요.' >&2
    return 2 2>/dev/null || exit 2
fi
set -e
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
mkdir -p "$ROOT/.test-output"
fixture="$ROOT/.test-output/portability.$$.$RANDOM"
(umask 077; mkdir "$fixture")
trap 'rm -rf -- "$fixture"' EXIT

# portability-patterns-begin
cat > "$fixture/forbidden" <<'PATTERNS'
(^|[^[:alnum:]_])(mapfile|readarray|coproc|BASHPID|EPOCHSECONDS|EPOCHREALTIME)([^[:alnum:]_]|$)
(declare|local|typeset)[[:space:]]+-[^[:space:]]*[Ang]
\$\{[[:alnum:]_]+(\[[^]]+\])?([,][,]?|\^\^?|@[QEPAaKkUuLl])[^}]*\}
\[\[[[:space:]]+-v[[:space:]]
;;&|;&|\|&|&>>
wait[[:space:]]+-n
\{[[:alpha:]_][[:alnum:]_]*\}[<>]
shopt.*(globstar|lastpipe|inherit_errexit)
\[[[:space:]]*-[0-9]+[[:space:]]*\]
%[(][^)]*[)]T
set[[:space:]]+-[[:alpha:]]*u
set[[:space:]]+-o[[:space:]]+nounset
sed[[:space:]]+-i|readlink[[:space:]]+-f|(^|[^[:alnum:]_])realpath([^[:alnum:]_]|$)|date[[:space:]]+-d
grep[[:space:]]+-P|stat[[:space:]]+-[cf]|sort[[:space:]]+-V|find.*-printf
xargs[[:space:]]+-r|(^|[^[:alnum:]_])timeout([^[:alnum:]_]|$)|head[[:space:]]+-n[[:space:]]+-[0-9]+
(^|[^[:alnum:]_])tac([^[:alnum:]_]|$)|base64[[:space:]]+-w
PATTERNS
# portability-patterns-end

for script in "$ROOT"/scripts/*.sh "$ROOT"/tests/*.sh; do
    relative="${script#"$ROOT/"}"
    bash -n "$script"
    IFS= read -r first < "$script"
    [[ "$first" == '#!/usr/bin/env bash' ]] || { printf 'FAIL: shebang %s\n' "$relative"; exit 1; }
    awk '/^# portability-patterns-begin$/ { skip=1; next }
        /^# portability-patterns-end$/ { skip=0; next }
        !skip && !/^[[:space:]]*#/ { print }' "$script" > "$fixture/code"
    if LC_ALL=C grep -En -f "$fixture/forbidden" "$fixture/code"; then
        printf 'FAIL: nonportable syntax in %s\n' "$relative" >&2; exit 1
    fi
    case "$relative" in
        tests/*) ;;
        scripts/*)
            awk -v file="$relative" '
                /^[a-zA-Z_][a-zA-Z_0-9]*\(\)/ { fn=$1; sub(/\(\).*/, "", fn) }
                /^[[:space:]]*#/ { next }
                /(^|[^[:alnum:]_])(brew|sw_vers|apt-get|apt-cache|dpkg-query|sha256sum)([^[:alnum:]_]|$)/ {
                    if (fn !~ /^(check_homebrew|ensure_homebrew|prepare_sdkman_dependencies|microsoft_apt_candidate|azd_file_hash|azd_package_owned|install_linux_azd|update_azure_tool|linux_install_supported|install_linux_gh|install_modernize|install_missing_tools)$/) {
                        print "FAIL: OS-specific command outside allowed function: " file ":" NR
                        failed=1
                    }
                }
                END { exit failed }' "$script"
            ;;
    esac
    expected=100755
    [[ "$relative" != scripts/use-java.sh ]] || expected=100644
    mode=$(git -C "$ROOT" ls-files -s -- "$relative")
    mode="${mode%% *}"
    [[ "$mode" == "$expected" ]] || { printf 'FAIL: Git mode %s expected %s: %s\n' "$mode" "$expected" "$relative" >&2; exit 1; }
done
zsh -n "$ROOT/scripts/use-java.sh"

mkdir "$fixture/bin"
for command_name in uname dirname curl git brew; do
    printf '#!/bin/sh\nprintf "unexpected command\\n" >> "$GUARD_LOG"\nexit 1\n' > "$fixture/bin/$command_name"
    chmod +x "$fixture/bin/$command_name"
done
for script in check-prerequisites install-prerequisites download-sample; do
    for shell in sh zsh; do
        interpreter=$(command -v "$shell")
        if [[ "$shell" == sh && -n "$("$interpreter" -c 'printf "%s" "${BASH_VERSION:-}"')" ]]; then
            output=$("$interpreter" "$ROOT/scripts/$script.sh" --help)
            [[ "$output" == "./scripts/$script.sh"* ]] || {
                printf 'FAIL: Bash-backed sh execution %s\n' "$script"; exit 1;
            }
            continue
        fi
        : > "$fixture/guard-log"
        if output=$(GUARD_LOG="$fixture/guard-log" PATH="$fixture/bin:$PATH" "$interpreter" "$ROOT/scripts/$script.sh" --help 2>&1); then
            printf 'FAIL: %s accepted %s\n' "$script" "$shell"; exit 1
        fi
        [[ "$output" == *'[FAIL]'* && "$output" == *"./scripts/$script.sh"* && ! -s "$fixture/guard-log" ]] || {
            printf 'FAIL: early shell guard: %s %s\n%s\n' "$script" "$shell" "$output"; exit 1;
        }
    done
    output=$("$ROOT/scripts/$script.sh" --help)
    [[ "$output" == "./scripts/$script.sh"* ]] || { printf 'FAIL: direct execution %s\n' "$script"; exit 1; }
done
printf 'PASS: Bash %s portability, Git modes, shell guards and direct execution\n' "$BASH_VERSION"
