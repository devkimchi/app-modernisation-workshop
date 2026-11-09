#!/usr/bin/env bash

WORKSHOP_SCRIPTS="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

resolve_engine() {
    local requested="${1:-}" configured="${AZD_CONTAINER_RUNTIME:-}" value
    for value in "$requested" "$configured"; do
        case "$value" in ''|docker|podman) ;; *) printf '%s\n' '[FAIL] 엔진은 docker 또는 podman이어야 합니다.' >&2; return 2 ;; esac
    done
    if [[ -n "$requested" && -n "$configured" && "$requested" != "$configured" ]]; then
        printf '%s\n' '[FAIL] 엔진 인자와 AZD_CONTAINER_RUNTIME이 다릅니다.' >&2
        return 2
    fi
    printf '%s\n' "${requested:-${configured:-docker}}"
}

probe() {
    PROBE_TEXT=''
    PROBE_CODE=0
    if ! command -v "$1" >/dev/null 2>&1; then PROBE_CODE=127; return 0; fi
    PROBE_TEXT=$("$@" 2>&1) || PROBE_CODE=$?
}

check_result() {
    printf '[%s] %s : %s\n' "$1" "$2" "$3"
    if [[ "$1" == FAIL ]]; then CHECK_FAILURES=$((CHECK_FAILURES + 1)); fi
}

minimum_version() {
    local text="$1" a b c x y z
    [[ "$text" =~ [0-9]+\.[0-9]+\.[0-9]+- ]] && return 1
    [[ "$text" =~ ([0-9]+)\.([0-9]+)\.([0-9]+) ]] || return 1
    a=${BASH_REMATCH[1]}; b=${BASH_REMATCH[2]}; c=${BASH_REMATCH[3]}
    IFS=. read -r x y z <<< "$2"
    (( 10#$a > 10#$x || (10#$a == 10#$x && 10#$b > 10#$y) || (10#$a == 10#$x && 10#$b == 10#$y && 10#$c >= 10#$z) ))
}

check_container() {
    local engine="$1" format
    probe "$engine" --version
    if (( PROBE_CODE != 0 )); then
        check_result FAIL container-cli "$engine 실행 실패 (종료 코드 $PROBE_CODE). docs/setup.md를 확인하세요."
        return
    fi
    check_result PASS container-cli "$PROBE_TEXT"
    if [[ "$engine" == docker ]]; then format='{{.OSType}}'; else format='{{.Host.OS}}'; fi
    probe "$engine" info --format "$format"
    if (( PROBE_CODE != 0 )); then
        check_result FAIL container-engine "$engine 연결 실패. 엔진 상태와 권한을 확인하세요. 다른 엔진으로 자동 전환하지 않습니다."
    elif [[ "$PROBE_TEXT" != linux ]]; then
        check_result FAIL container-engine 'Linux 컨테이너 환경을 확인하지 못했습니다.'
    else
        check_result PASS container-engine "$engine Linux 환경에 연결했습니다."
    fi
    if [[ "$engine" == docker ]]; then
        probe docker build --help
        if (( PROBE_CODE == 0 )) && [[ "$PROBE_TEXT" == *--platform* ]]; then check_result PASS builder-command 'Docker --platform 빌드 기능이 있습니다.'
        else check_result FAIL builder-command 'Docker --platform 빌드 기능을 확인하지 못했습니다.'; fi
        probe docker buildx version
        if (( PROBE_CODE == 0 )); then check_result PASS builder 'Docker Buildx가 있습니다.'
        else check_result WARN builder 'Buildx를 확인하지 못했습니다. 실제 azd package에서 빌드 지원을 확인하세요.'; fi
    else
        probe podman build --help
        if (( PROBE_CODE == 0 )) && [[ "$PROBE_TEXT" == *--platform* ]]; then
            check_result PASS builder 'Podman 내장 빌더가 있습니다. Docker Buildx는 필요하지 않습니다.'
        else check_result FAIL builder 'Podman --platform 빌드 기능을 확인하지 못했습니다.'; fi
    fi
    check_result MANUAL container-workload '실제 linux/amd64 빌드, 포트 접근과 ACR 게시 성공은 실습에서 확인하세요.'
}

check_java_sdks() {
    local sdk_dir="${SDKMAN_DIR:-$HOME/.sdkman}" candidate output compiler major compiler_major found8=0 found21=0 found25=0
    if [[ ! -r "$sdk_dir/bin/sdkman-init.sh" ]]; then
        check_result FAIL sdkman 'SDKMAN 초기화 파일이 없습니다. docs/setup.md를 확인하세요.'
        return
    fi
    # SDKMAN 초기화는 격리된 셸에서 수행해 현재 셸의 JAVA_HOME을 바꾸지 않는다.
    probe bash -c 'source "$1/bin/sdkman-init.sh" >/dev/null && sdk version' _ "$sdk_dir"
    if (( PROBE_CODE != 0 )); then
        check_result FAIL sdkman 'SDKMAN 초기화 또는 sdk version 실행에 실패했습니다.'
        return
    fi
    check_result PASS sdkman 'SDKMAN을 초기화하고 버전을 조회했습니다.'
    for candidate in "$sdk_dir"/candidates/java/*; do
        [[ "${candidate##*/}" != current && -x "$candidate/bin/java" && -x "$candidate/bin/javac" ]] || continue
        output=$("$candidate/bin/java" -version 2>&1) || continue
        [[ "$output" != *-ea* ]] || continue
        major=''
        if [[ "$output" =~ version[[:space:]]+\"1\.8\. ]]; then major=8
        elif [[ "$output" =~ version[[:space:]]+\"([0-9]+)(\.|\") ]]; then major="${BASH_REMATCH[1]}"; fi
        compiler=$("$candidate/bin/javac" -version 2>&1) || continue
        compiler_major=''
        if [[ "$compiler" =~ javac[[:space:]]+1\.8\. ]]; then compiler_major=8
        elif [[ "$compiler" =~ javac[[:space:]]+([0-9]+)(\.|$) ]]; then compiler_major="${BASH_REMATCH[1]}"; fi
        [[ -n "$major" && "$major" == "$compiler_major" && "$compiler" != *-ea* ]] || continue
        case "$major" in
            8) found8=1 ;;
            21) found21=1 ;;
            25) found25=1 ;;
            *) continue ;;
        esac
        check_result PASS "jdk-$major" "SDKMAN 후보 ${candidate##*/}의 java와 javac를 확인했습니다."
    done
    (( found8 == 1 )) || check_result FAIL jdk-8 'SDKMAN으로 설치한 JDK 8이 필요합니다.'
    (( found21 == 1 )) || check_result FAIL jdk-21 'SDKMAN으로 설치한 JDK 21이 필요합니다.'
    (( found25 == 1 )) || check_result FAIL jdk-25 'SDKMAN으로 설치한 JDK 25가 필요합니다.'
}

check_common() {
    local engine="$1" provider
    probe git --version
    if (( PROBE_CODE == 0 )); then check_result PASS git "$PROBE_TEXT"; else check_result FAIL git 'Git이 필요합니다.'; fi
    probe node --version
    if (( PROBE_CODE == 0 )) && minimum_version "$PROBE_TEXT" 22.0.0; then check_result PASS node "$PROBE_TEXT"
    else check_result FAIL node 'Node.js 22 이상이 필요합니다.'; fi
    probe az version --output json
    if (( PROBE_CODE == 0 )); then
        check_result PASS az 'Azure CLI를 실행할 수 있습니다.'
        probe az extension show --name containerapp --query version --output tsv
        if (( PROBE_CODE == 0 )) && [[ -n "$PROBE_TEXT" ]]; then check_result PASS az-containerapp "확장 버전: $PROBE_TEXT"
        else check_result FAIL az-containerapp '확장 설치 여부와 조회 오류를 확인하세요.'; fi
        probe az account show --query state --output tsv
        if (( PROBE_CODE == 0 )) && [[ "$PROBE_TEXT" == Enabled ]]; then
            check_result PASS az-login '활성 구독이 있습니다. 실제 대상 구독은 직접 확인하세요.'
            for provider in Microsoft.App Microsoft.OperationalInsights Microsoft.Storage Microsoft.ContainerRegistry Microsoft.ServiceBus Microsoft.DBforPostgreSQL; do
                probe az provider show --namespace "$provider" --query registrationState --output tsv
                if (( PROBE_CODE == 0 )) && [[ "$PROBE_TEXT" == Registered ]]; then check_result PASS "$provider" Registered
                else check_result FAIL "$provider" '등록 상태를 확인하지 못했습니다. 권한과 공급자 등록을 확인하세요.'; fi
            done
        else check_result FAIL az-login 'az login 및 활성 구독 선택이 필요하거나 구독 조회에 실패했습니다.'; fi
    else check_result FAIL az 'Azure CLI 설치 또는 실행 상태를 확인하세요.'; fi
    probe azd version
    if (( PROBE_CODE == 0 )) && minimum_version "$PROBE_TEXT" 1.37.3; then
        check_result PASS azd "$PROBE_TEXT"
        probe azd auth login --check-status
        if (( PROBE_CODE == 0 )); then check_result PASS azd-login 'azd 로그인 상태를 확인했습니다.'
        else check_result FAIL azd-login 'azd auth login을 직접 실행하거나 인증 오류를 해결하세요.'; fi
    else check_result FAIL azd '워크샵 기준 azd 1.37.3 이상이 필요합니다.'; fi
    check_container "$engine"
    check_result MANUAL copilot-app 'Copilot app 로그인, 라이선스, 조직 정책과 Modernization 플러그인을 확인하세요.'
    check_result MANUAL azure-access '대상 구독, 리전, 쿼터, 역할 할당 및 데이터베이스 Entra 관리자 설정 권한을 확인하세요.'
}

prerequisite_main() {
    local track='' requested='' engine os previous_dynamic="${AZURE_EXTENSION_USE_DYNAMIC_INSTALL-}"
    while (( $# )); do
        case "$1" in
            --track|--container-engine)
                if (( $# < 2 )) || [[ "$2" == --* || -z "$2" ]]; then printf '%s\n' "[FAIL] $1 값이 필요합니다." >&2; return 2; fi
                if [[ "$1" == --track ]]; then track="$2"; else requested="$2"; fi
                shift 2 ;;
            --help|-h) printf '%s\n' 'bash scripts/check-prerequisites.sh --track java|dotnet [--container-engine docker|podman]'; return 0 ;;
            *) printf '[FAIL] 알 수 없는 인자: %s\n' "$1" >&2; return 2 ;;
        esac
    done
    case "$track" in java|dotnet) ;; *) printf '%s\n' '[FAIL] --track java 또는 --track dotnet을 지정하세요.' >&2; return 2 ;; esac
    engine=$(resolve_engine "$requested") || return $?
    os=$(uname -s)
    if [[ "$track" == dotnet ]]; then
        case "$os" in MINGW*|MSYS*) ;; *) printf '%s\n' '[FAIL] .NET Bash 진입점은 Windows Git Bash에서만 지원합니다.'; return 1 ;; esac
        command -v pwsh >/dev/null 2>&1 || { printf '%s\n' '[FAIL] PowerShell 7을 설치하세요.'; return 1; }
        MSYS2_ARG_CONV_EXCL='*' pwsh -NoLogo -NoProfile -File "$(cygpath -w "$WORKSHOP_SCRIPTS/check-prerequisites.ps1")" -Track dotnet -ContainerEngine "$engine"
        return $?
    fi
    case "$os" in
        Darwin) ;;
        Linux)
            if [[ "${WORKSHOP_DEVCONTAINER:-}" != 1 ]] && ! grep -Eqi 'microsoft.*wsl2|wsl2.*microsoft' /proc/sys/kernel/osrelease; then
                printf '%s\n' '[FAIL] Java 지원 환경은 macOS, Windows WSL2 또는 워크숍 Dev Container입니다.'; return 1
            fi ;;
        *) printf '%s\n' '[FAIL] Windows Java는 Git Bash가 아니라 WSL2에서 실행하세요.'; return 1 ;;
    esac
    CHECK_FAILURES=0
    printf '트랙: java / 엔진: %s / 실행 환경: %s\n' "$engine" "$os"
    check_result PASS bash "Bash $BASH_VERSION"
    if [[ "$os" == Linux && "${WORKSHOP_DEVCONTAINER:-}" != 1 ]]; then check_result MANUAL windows-host 'Windows Copilot app 호스트에도 Git과 Node.js 22 이상이 필요합니다. WSL 내부 검사 결과와 별개입니다.'; fi
    export AZURE_EXTENSION_USE_DYNAMIC_INSTALL=no
    check_common "$engine"
    check_java_sdks
    if [[ -n "$previous_dynamic" ]]; then export AZURE_EXTENSION_USE_DYNAMIC_INSTALL="$previous_dynamic"
    else unset AZURE_EXTENSION_USE_DYNAMIC_INSTALL; fi
    printf '필수 실패: %s. MANUAL 항목은 자동 확인되지 않았습니다.\n' "$CHECK_FAILURES"
    printf 'azd 실행 전 현재 셸에서 export AZD_CONTAINER_RUNTIME=%s 를 실행하세요.\n' "$engine"
    (( CHECK_FAILURES == 0 ))
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then prerequisite_main "$@"; exit $?; fi
