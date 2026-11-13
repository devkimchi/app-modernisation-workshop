#!/usr/bin/env bash

if [ -z "${BASH_VERSION:-}" ] && [ -z "${ZSH_VERSION:-}" ]; then
    printf '%s\n' '[FAIL] Run source ../scripts/use-java.sh --jdk 8|25 in Bash or Zsh.' >&2
    return 2 2>/dev/null || exit 2
fi
if [ -n "${BASH_VERSION:-}" ]; then
    if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
        printf '%s\n' '[FAIL] Run source ../scripts/use-java.sh --jdk 8|25 in the current shell.' >&2
        exit 2
    fi
else
    case "$ZSH_EVAL_CONTEXT" in
        *:file) ;;
        *) printf '%s\n' '[FAIL] Run source ../scripts/use-java.sh --jdk 8|25 in the current shell.' >&2; exit 2 ;;
    esac
fi

_workshop_use_java() {
    local major='' sdkman_dir="${SDKMAN_DIR:-$HOME/.sdkman}" candidate identifier runtime compiler runtime_major compiler_major
    if [[ $# -ne 2 || "$1" != --jdk ]]; then
        printf '%s\n' '[FAIL] Usage: source ../scripts/use-java.sh --jdk 8|25' >&2
        return 2
    fi
    major="$2"
    case "$major" in
        8|25) ;;
        *) printf '%s\n' '[FAIL] Specify 8 or 25 as the --jdk value.' >&2; return 2 ;;
    esac
    if [[ ! -f ./mvnw ]]; then
        printf '%s\n' '[FAIL] Run this from the sample app root. No mvnw file was found in the current directory.' >&2
        return 1
    fi

    if [[ ! -r "$sdkman_dir/bin/sdkman-init.sh" ]]; then
        printf '[FAIL] SDKMAN initialization file not found: %s/bin/sdkman-init.sh\n' "$sdkman_dir" >&2
        return 1
    fi
    if ! source "$sdkman_dir/bin/sdkman-init.sh"; then
        printf '%s\n' '[FAIL] Failed to initialize SDKMAN.' >&2
        return 1
    fi

    identifier=$(
        if [[ -n "${ZSH_VERSION:-}" ]]; then setopt local_options no_nomatch; fi
        for candidate in "$sdkman_dir"/candidates/java/"$major".*; do
            [[ -x "$candidate/bin/java" && -x "$candidate/bin/javac" ]] || continue
            runtime=$("$candidate/bin/java" -version 2>&1) || continue
            if ! compiler=$("$candidate/bin/javac" -version 2>&1); then
                compiler=$("$candidate/bin/javac" --version 2>&1) || continue
            fi
            case "$runtime" in (*-ea*) continue ;; (*'version "'*) runtime="${runtime#*version \"}"; runtime="${runtime%%\"*}" ;; (*) continue ;; esac
            case "$compiler" in (*-ea*) continue ;; ('javac '*) compiler="${compiler#javac }" ;; (*) continue ;; esac
            case "$runtime" in (1.*) runtime="${runtime#1.}" ;; esac
            case "$compiler" in (1.*) compiler="${compiler#1.}" ;; esac
            runtime_major="${runtime%%.*}"
            compiler_major="${compiler%%.*}"
            if [[ "$runtime_major" == "$major" && "$compiler_major" == "$major" ]]; then
                printf '%s\n' "${candidate##*/}"
                break
            fi
        done
    )

    if [[ -z "$identifier" ]]; then
        printf '[FAIL] No runnable SDKMAN JDK %s was found. Check the installed JDKs and SDKMAN_DIR.\n' "$major" >&2
        return 1
    fi
    if ! sdk use java "$identifier"; then
        printf '[FAIL] Could not switch to JDK %s (%s) with SDKMAN.\n' "$major" "$identifier" >&2
        return 1
    fi
    export JAVA_HOME="$sdkman_dir/candidates/java/$identifier"
    export PATH="$JAVA_HOME/bin:$PATH"
    hash -r
    printf '[PASS] Selected SDKMAN JDK %s: %s\n' "$major" "$identifier"
}

_workshop_show_versions() {
    local result="$1"
    unset -f _workshop_use_java _workshop_show_versions
    (( result == 0 )) || return "$result"
    printf '[INFO] java -version\n'
    if java -version; then
        :
    else
        result=$?
        printf '[FAIL] java -version failed.\n' >&2
        return "$result"
    fi
    printf '[INFO] javac -version\n'
    if javac -version; then
        :
    else
        result=$?
        printf '[FAIL] javac -version failed.\n' >&2
        return "$result"
    fi
}

if _workshop_use_java "$@"; then
    _workshop_show_versions 0
else
    _workshop_show_versions "$?"
fi
return $?
