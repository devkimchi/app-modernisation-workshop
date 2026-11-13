#!/usr/bin/env bash

if [ -z "${BASH_VERSION:-}" ] && [ -z "${ZSH_VERSION:-}" ]; then
    printf '%s\n' '[FAIL] Bash 또는 Zsh에서 source ../scripts/use-java.sh --jdk 8|25로 실행하세요.' >&2
    return 2 2>/dev/null || exit 2
fi
if [ -n "${BASH_VERSION:-}" ]; then
    if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
        printf '%s\n' '[FAIL] 현재 셸에서 source ../scripts/use-java.sh --jdk 8|25로 실행하세요.' >&2
        exit 2
    fi
else
    case "$ZSH_EVAL_CONTEXT" in
        *:file) ;;
        *) printf '%s\n' '[FAIL] 현재 셸에서 source ../scripts/use-java.sh --jdk 8|25로 실행하세요.' >&2; exit 2 ;;
    esac
fi

_workshop_use_java() {
    local major='' sdkman_dir="${SDKMAN_DIR:-$HOME/.sdkman}" candidate identifier runtime compiler runtime_major compiler_major
    if [[ $# -ne 2 || "$1" != --jdk ]]; then
        printf '%s\n' '[FAIL] 사용법: source ../scripts/use-java.sh --jdk 8|25' >&2
        return 2
    fi
    major="$2"
    case "$major" in
        8|25) ;;
        *) printf '%s\n' '[FAIL] --jdk 값으로 8, 25 중 하나를 지정하세요.' >&2; return 2 ;;
    esac
    if [[ ! -f ./mvnw ]]; then
        printf '%s\n' '[FAIL] 샘플 앱 루트에서 실행하세요. 현재 폴더에 mvnw가 없습니다.' >&2
        return 1
    fi

    if [[ ! -r "$sdkman_dir/bin/sdkman-init.sh" ]]; then
        printf '[FAIL] SDKMAN 초기화 파일이 없습니다: %s/bin/sdkman-init.sh\n' "$sdkman_dir" >&2
        return 1
    fi
    if ! source "$sdkman_dir/bin/sdkman-init.sh"; then
        printf '%s\n' '[FAIL] SDKMAN 초기화에 실패했습니다.' >&2
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
        printf '[FAIL] 실행 가능한 SDKMAN JDK %s를 찾지 못했습니다. 설치된 JDK와 SDKMAN_DIR을 확인하세요.\n' "$major" >&2
        return 1
    fi
    if ! sdk use java "$identifier"; then
        printf '[FAIL] SDKMAN에서 JDK %s (%s)로 전환하지 못했습니다.\n' "$major" "$identifier" >&2
        return 1
    fi
    export JAVA_HOME="$sdkman_dir/candidates/java/$identifier"
    export PATH="$JAVA_HOME/bin:$PATH"
    hash -r
    printf '[PASS] SDKMAN JDK %s 선택: %s\n' "$major" "$identifier"
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
        printf '[FAIL] java -version에 실패했습니다.\n' >&2
        return "$result"
    fi
    printf '[INFO] javac -version\n'
    if javac -version; then
        :
    else
        result=$?
        printf '[FAIL] javac -version에 실패했습니다.\n' >&2
        return "$result"
    fi
}

if _workshop_use_java "$@"; then
    _workshop_show_versions 0
else
    _workshop_show_versions "$?"
fi
return $?
