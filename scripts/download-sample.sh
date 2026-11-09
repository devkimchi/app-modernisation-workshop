#!/usr/bin/env bash

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
        printf '%s\n' '[FAIL] Bash에서는 일반 POSIX 경로를 사용하세요. Windows Git Bash 예: /c/workshops/app' >&2; return 2
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
    local parent staging source required notice license=false payload
    target=$(safe_destination "$target" "$workshop")
    parent="${target%/*}"; parent="${parent:-/}"
    mkdir -p -- "$parent"
    staging=$(mktemp -d "$parent/.workshop-download.XXXXXXXX")
    trap 'result=$?; trap - EXIT; if [[ -d "$staging" ]]; then rm -rf -- "$staging" || result=1; fi; if (( result != 0 )); then printf "[FAIL] 다운로드 실패. 대상 상태를 확인하고 빈 경로로 다시 시도하세요: %s\n" "$target" >&2; fi; exit "$result"' EXIT
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
    for notice in LICENSE LICENSE.txt LICENSE.md NOTICE NOTICE.txt; do
        if [[ -f "$staging/checkout/$notice" ]]; then
            cp -p "$staging/checkout/$notice" "$payload/UPSTREAM-$notice"
            [[ "$notice" != LICENSE* ]] || license=true
        fi
        [[ ! -f "$source/$notice" || "$notice" != LICENSE* ]] || license=true
    done
    # Production values are fixed URLs, SHA-1 and directory names, not user input.
    printf '{\n  "repository": "%s",\n  "commit": "%s",\n  "subdirectory": "%s",\n  "licenseFileFound": %s\n}\n' "$repository" "$commit" "$subdirectory" "$license" > "$payload/upstream-source.json"
    git init --quiet "$payload"
    safe_destination "$target" "$workshop" >/dev/null
    [[ ! -d "$target" ]] || rmdir -- "$target"
    # mkdir reserves the destination; cp will never merge into another writer's directory.
    mkdir -- "$target"
    cp -Rp "$payload/." "$target/"
    printf '[PASS] 샘플 다운로드: %s\n[PASS] 원본 커밋: %s / 독립 Git 저장소\n' "$target" "$commit"
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
            --help|-h) printf '%s\n' 'bash scripts/download-sample.sh --track java|dotnet [--destination PATH] [--container-engine docker|podman]'; return 0 ;;
            *) printf '[FAIL] 알 수 없는 인자: %s\n' "$1" >&2; return 2 ;;
        esac
    done
    sample_definition "$track" || return $?
    source "$DOWNLOAD_SCRIPTS/check-prerequisites.sh"
    engine=$(resolve_engine "$requested") || return $?
    workshop="$(cd "$DOWNLOAD_SCRIPTS/.." && pwd -P)"
    destination=$(safe_destination "${destination:-$workshop/$track}" "$workshop") || return $?
    if [[ "$track" == dotnet ]]; then
        os=$(uname -s)
        case "$os" in MINGW*|MSYS*) ;; *) printf '%s\n' '[FAIL] .NET Bash 진입점은 Windows Git Bash에서만 지원합니다.'; return 1 ;; esac
        command -v pwsh >/dev/null 2>&1 || { printf '%s\n' '[FAIL] PowerShell 7이 필요합니다.'; return 1; }
        MSYS2_ARG_CONV_EXCL='*' pwsh -NoLogo -NoProfile -File "$(cygpath -w "$DOWNLOAD_SCRIPTS/download-sample.ps1")" -Track dotnet -ContainerEngine "$engine" -Destination "$(cygpath -w "$destination")"
        return $?
    fi
    bash "$DOWNLOAD_SCRIPTS/check-prerequisites.sh" --track java --container-engine "$engine" || {
        printf '%s\n' '[FAIL] 사전 점검이 통과하지 않아 다운로드하지 않았습니다.' >&2; return 1;
    }
    download_sample "$destination" "$SAMPLE_REPOSITORY" "$SAMPLE_COMMIT" "$SAMPLE_SUBDIRECTORY" "$track" "$workshop"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then download_main "$@"; exit $?; fi
