#!/usr/bin/env bash

if [ -z "${BASH_VERSION:-}" ]; then
    printf '%s\n' '[FAIL] ./scripts/download-sample.sh로 실행하세요.' >&2
    return 2 2>/dev/null || exit 2
fi

DOWNLOAD_SCRIPTS="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

sample_definition() {
    case "$1" in
        java)
            SAMPLE_REPOSITORY=https://github.com/Azure-Samples/java-migration-copilot-samples.git
            SAMPLE_COMMIT=317d3bbfd61fb1e402bea61f90e385bec12f2070
            SAMPLE_SUBDIRECTORY=asset-manager ;;
        dotnet)
            SAMPLE_REPOSITORY=https://github.com/Azure-Samples/dotnet-migration-copilot-samples.git
            SAMPLE_COMMIT=7c1bf47b7e2627fe5a1c764716638815d35e0282
            SAMPLE_SUBDIRECTORY=ContosoUniversity ;;
        *) printf '%s\n' '[FAIL] 알 수 없는 트랙입니다.' >&2; return 2 ;;
    esac
}

safe_destination() {
    local path="$1" workshop="$2" current component entry full=''
    if [[ "$path" == *$'\n'* || "$path" == *$'\r'* ]]; then printf '%s\n' '[FAIL] 경로에 줄바꿈을 사용할 수 없습니다.' >&2; return 2; fi
    if [[ "$path" == //* || "$path" == *\\* || "$path" =~ ^[[:alpha:]]: ]]; then
        printf '%s\n' '[FAIL] Bash에서는 일반 POSIX 경로를 사용하세요.' >&2; return 2
    fi
    [[ "$path" == /* ]] || path="$PWD/$path"
    local -a parts
    IFS=/ read -r -a parts <<< "$path"
    for component in "${parts[@]}"; do
        case "$component" in
            ''|.) continue ;;
            ..) full="${full%/*}" ;;
            *) full="$full/$component" ;;
        esac
        if [[ -L "${full:-/}" ]]; then printf '%s\n' '[FAIL] 심볼릭 링크를 경유하는 대상은 지원하지 않습니다.' >&2; return 2; fi
    done
    full="${full:-/}"
    if [[ "$full" == / || "$full" == "$HOME" || "$full" == "$workshop" || "$full" -ef "$HOME" || "$full" -ef "$workshop" ]]; then
        printf '%s\n' '[FAIL] 홈, 루트 또는 워크샵 최상위는 대상이 될 수 없습니다.' >&2; return 2
    fi
    current="$full"
    while [[ -n "$current" ]]; do
        for component in docs scripts tests; do
            if [[ "$current" -ef "$workshop/$component" ]]; then printf '%s\n' '[FAIL] 워크샵 자료 폴더는 대상이 될 수 없습니다.' >&2; return 2; fi
        done
        current="${current%/*}"
    done
    for current in docs scripts tests; do
        case "$full/" in "$workshop/$current/"*) printf '%s\n' '[FAIL] 워크샵 자료 폴더는 대상이 될 수 없습니다.' >&2; return 2 ;; esac
    done
    if [[ -e "$full" ]]; then
        if [[ ! -d "$full" || ! -r "$full" || ! -x "$full" ]]; then printf '%s\n' '[FAIL] 대상이 폴더가 아니거나 읽을 수 없습니다.' >&2; return 2; fi
        for entry in "$full"/* "$full"/.[!.]* "$full"/..?*; do
            if [[ -e "$entry" || -L "$entry" ]]; then printf '%s\n' '[FAIL] 대상이 비어 있지 않습니다. 기존 파일은 덮어쓰지 않습니다.' >&2; return 2; fi
        done
    fi
    printf '%s\n' "$full"
}

download_sample() (
    set -e
    local target="$1" repository="$2" commit="$3" subdirectory="$4" track="$5" workshop="$6"
    local parent staging source required notice name normalized license=false payload cleanup
    target=$(safe_destination "$target" "$workshop")
    parent="${target%/*}"; parent="${parent:-/}"
    mkdir -p -- "$parent"
    staging="$parent/.workshop-download.$$.$RANDOM"
    (umask 077; mkdir -- "$staging")
    # Bash 3.2는 EXIT trap 전에 함수의 지역 변수를 해제할 수 있다.
    printf -v cleanup 'result=$?; trap - EXIT; rm -rf -- %q || result=1; if (( result != 0 )); then printf "[FAIL] 다운로드 실패. 대상 상태를 확인하고 빈 경로로 다시 시도하세요: %%s\\n" %q >&2; fi; exit "$result"' "$staging" "$target"
    trap "$cleanup" EXIT
    git init --quiet "$staging/checkout"
    git -C "$staging/checkout" remote add origin "$repository"
    git -C "$staging/checkout" fetch --quiet --depth 1 origin "$commit"
    git -C "$staging/checkout" -c advice.detachedHead=false -c core.autocrlf=false checkout --quiet --detach FETCH_HEAD
    [[ "$(git -C "$staging/checkout" rev-parse HEAD)" == "$commit" ]] || { printf '%s\n' '[FAIL] 커밋 검증 실패.' >&2; exit 1; }
    source="$staging/checkout/$subdirectory"
    if [[ "$track" == java ]]; then
        for required in pom.xml web worker mvnw .mvn/wrapper/maven-wrapper.properties; do
            [[ -e "$source/$required" ]] || { printf '[FAIL] 필수 경로 없음: %s\n' "$required" >&2; exit 1; }
        done
    else
        for required in ContosoUniversity.sln ContosoUniversity.csproj packages.config; do
            [[ -f "$source/$required" ]] || { printf '[FAIL] 필수 경로 없음: %s\n' "$required" >&2; exit 1; }
        done
    fi
    payload="$staging/payload"
    mkdir "$payload"
    cp -Rp "$source/." "$payload/"
    if [[ -e "$payload/upstream-source.json" || -L "$payload/upstream-source.json" ]]; then
        printf '%s\n' '[FAIL] 원본에 upstream-source.json이 있어 덮어쓰지 않고 중단합니다.' >&2; exit 1
    fi
    for notice in "$staging/checkout/"*; do
        [[ -f "$notice" ]] || continue
        name="${notice##*/}"
        normalized=$(printf '%s' "$name" | LC_ALL=C tr '[:lower:]' '[:upper:]')
        [[ "$normalized" =~ ^(LICENSE|LICENCE|NOTICE|COPYING|COPYRIGHT)([._-].*)?$ ]] || continue
        if [[ -e "$payload/UPSTREAM-$name" || -L "$payload/UPSTREAM-$name" ]]; then
            printf '[FAIL] 원본 파일과 고지 보존 경로가 충돌합니다: %s\n' "$name" >&2; exit 1
        fi
        cp -p "$notice" "$payload/UPSTREAM-$name"
        [[ ! "$normalized" =~ ^(LICENSE|LICENCE|COPYING)([._-].*)?$ ]] || license=true
    done
    for notice in "$source/"*; do
        [[ -f "$notice" ]] || continue
        normalized=$(printf '%s' "${notice##*/}" | LC_ALL=C tr '[:lower:]' '[:upper:]')
        [[ ! "$normalized" =~ ^(LICENSE|LICENCE|COPYING)([._-].*)?$ ]] || license=true
    done
    # Production values are fixed URLs, SHA-1 and directory names, not user input.
    printf '{\n  "repository": "%s",\n  "commit": "%s",\n  "subdirectory": "%s",\n  "licenseFileFound": %s\n}\n' "$repository" "$commit" "$subdirectory" "$license" > "$payload/upstream-source.json"
    safe_destination "$target" "$workshop" >/dev/null
    [[ ! -d "$target" ]] || rmdir -- "$target"
    # mkdir reserves the destination; cp will never merge into another writer's directory.
    mkdir -- "$target"
    cp -Rp "$payload/." "$target/"
    printf '[PASS] 샘플 다운로드: %s\n[PASS] 원본 커밋: %s / 앱 폴더에 Git 저장소를 만들지 않음\n' "$target" "$commit"
    if [[ "$license" == false ]]; then printf '%s\n' '[WARN] 원본 라이선스 파일이 없습니다. 재배포 권한을 가정하지 마세요.'; fi
)

download_main() {
    local track='' requested='' destination='' engine workshop os
    while (( $# )); do
        case "$1" in
            --track|--container-engine|--destination)
                if (( $# < 2 )) || [[ "$2" == --* || -z "$2" ]]; then printf '[FAIL] %s 값이 필요합니다.\n' "$1" >&2; return 2; fi
                case "$1" in --track) track="$2" ;; --container-engine) requested="$2" ;; --destination) destination="$2" ;; esac
                shift 2 ;;
            --help|-h) printf '%s\n' './scripts/download-sample.sh --track java [--destination PATH] [--container-engine docker|podman]'; return 0 ;;
            *) printf '[FAIL] 알 수 없는 인자: %s\n' "$1" >&2; return 2 ;;
        esac
    done
    sample_definition "$track" || return $?
    source "$DOWNLOAD_SCRIPTS/check-prerequisites.sh"
    engine=$(resolve_engine "$requested") || return $?
    if [[ "$track" == dotnet ]]; then
        printf '%s\n' '[FAIL] .NET은 Windows PowerShell에서 ./scripts/download-sample.ps1 -Track dotnet을 실행하세요.'
        return 1
    fi
    os=$(uname -s)
    case "$os" in
        Darwin|Linux) ;;
        *) printf '%s\n' '[FAIL] macOS와 Linux에서 실행하세요. Windows PowerShell에서는 ./scripts/download-sample.ps1 -Track java를 실행하세요.'; return 1 ;;
    esac
    workshop="$(cd "$DOWNLOAD_SCRIPTS/.." && pwd -P)"
    destination=$(safe_destination "${destination:-$workshop/$track}" "$workshop") || return $?
    bash "$DOWNLOAD_SCRIPTS/check-prerequisites.sh" --track java --container-engine "$engine" || {
        printf '%s\n' '[FAIL] 사전 점검이 통과하지 않아 다운로드하지 않았습니다.' >&2; return 1;
    }
    download_sample "$destination" "$SAMPLE_REPOSITORY" "$SAMPLE_COMMIT" "$SAMPLE_SUBDIRECTORY" "$track" "$workshop"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then download_main "$@"; exit $?; fi
