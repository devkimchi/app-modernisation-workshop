#!/usr/bin/env bash

if [ -z "${BASH_VERSION:-}" ]; then
    printf '%s\n' '[FAIL] ./scripts/check-prerequisites.sh로 실행하세요.' >&2
    return 2 2>/dev/null || exit 2
fi

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
    printf '[%s] [%s] %s: %s\n' "$1" "${4:-${CHECK_CONTEXT:-Bash}}" "$2" "$3"
    if [[ "$1" == FAIL ]]; then CHECK_FAILURES=$((CHECK_FAILURES + 1)); fi
}

tool_path() {
    command -v "$1" 2>/dev/null || true
}

initialize_node_environment() {
    local node_path nvm_dir
    node_path=$(tool_path node)
    if [[ -n "$node_path" ]]; then return 0; fi
    if [[ -n "${NVM_DIR:-}" ]]; then nvm_dir="$NVM_DIR"
    elif [[ -n "${XDG_CONFIG_HOME:-}" ]]; then nvm_dir="$XDG_CONFIG_HOME/nvm"
    else nvm_dir="$HOME/.nvm"; fi
    [[ -s "$nvm_dir/nvm.sh" ]] || return 0
    export NVM_DIR="$nvm_dir"
    if ! source "$NVM_DIR/nvm.sh" --no-use || [[ $(type -t nvm) != function ]]; then
        check_result WARN nvm "nvm 초기화에 실패했습니다: $NVM_DIR/nvm.sh"
        return 1
    fi
    if ! nvm use --silent default; then
        check_result WARN nvm 'nvm의 기본 Node.js를 활성화하지 못했습니다. nvm alias default <설치된-버전>으로 기본 버전을 지정하세요.'
        return 1
    fi
}

check_azure_provider() {
    local provider="$1"
    probe az provider show --namespace "$provider" --query registrationState --output tsv
    if (( PROBE_CODE == 0 )) && [[ "$PROBE_TEXT" == Registered ]]; then check_result PASS "$provider" Registered
    else check_result FAIL "$provider" "등록을 확인하지 못했습니다 (종료 코드 $PROBE_CODE): ${PROBE_TEXT:-출력 없음}. 설치 도우미에서 등록하거나 조회 오류를 해결하세요."; fi
}

check_azure_identity() {
    local subscription_id subscription_name tenant_id endpoint
    probe az account show --query '[[id,name]]' --output tsv
    if (( PROBE_CODE != 0 )) || [[ -z "$PROBE_TEXT" ]]; then
        check_result WARN azure-subscription '현재 구독 정보를 조회하지 못했습니다. 대상 구독과 테넌트를 직접 확인하세요.'
        return
    fi
    IFS=$'\t' read -r subscription_id subscription_name <<< "$PROBE_TEXT"
    if [[ -z "$subscription_id" || -z "$subscription_name" ]]; then
        check_result WARN azure-subscription '현재 구독 ID와 이름을 해석하지 못했습니다. 대상 구독을 직접 확인하세요.'
        return
    fi
    check_result MANUAL azure-subscription "구독 이름: $subscription_name / 구독 ID: $subscription_id"
    probe az account show --query tenantId --output tsv
    tenant_id="$PROBE_TEXT"
    if (( PROBE_CODE != 0 )) || [[ ! "$tenant_id" =~ ^[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}$ ]]; then
        check_result WARN azure-tenant '현재 테넌트 ID를 조회하지 못해 테넌트 이름을 확인할 수 없습니다.'
        return
    fi
    probe az cloud show --query endpoints.resourceManager --output tsv
    if (( PROBE_CODE != 0 )) || [[ ! "$PROBE_TEXT" =~ ^https:// ]]; then
        check_result WARN azure-tenant "테넌트 ID: $tenant_id. Azure 클라우드 엔드포인트를 조회하지 못해 테넌트 이름을 확인할 수 없습니다."
        return
    fi
    endpoint="${PROBE_TEXT%/}"
    probe az rest --method get --url "$endpoint/tenants?api-version=2022-12-01" --query "value[?tenantId=='$tenant_id'].displayName | [0]" --output tsv --only-show-errors
    if (( PROBE_CODE == 0 )) && [[ -n "$PROBE_TEXT" && "$PROBE_TEXT" != None && "$PROBE_TEXT" != null ]]; then
        check_result MANUAL azure-tenant "테넌트 이름: $PROBE_TEXT / 테넌트 ID: $tenant_id"
    else
        check_result WARN azure-tenant "테넌트 ID: $tenant_id. 테넌트 이름을 조회하지 못했습니다. 권한, 네트워크 및 Azure Portal을 확인하세요."
    fi
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
        check_result FAIL container-cli "$engine 실행 실패 (종료 코드 $PROBE_CODE). docs/java/00-setup.md를 확인하세요."
        return
    fi
    check_result PASS container-cli "$engine CLI 실행: $PROBE_TEXT (경로: $(tool_path "$engine"))"
    if [[ "$engine" == docker ]]; then format='{{.OSType}}'; else format='{{.Host.OS}}'; fi
    probe "$engine" info --format "$format"
    if (( PROBE_CODE != 0 )); then
        check_result FAIL container-engine "$engine 연결 실패. 엔진 상태와 권한을 확인하세요. 다른 엔진으로 자동 전환하지 않습니다."
    elif [[ "$PROBE_TEXT" != linux ]]; then
        check_result FAIL container-engine 'Linux 컨테이너 환경을 확인하지 못했습니다.'
    else
        check_result PASS container-engine "$engine CLI가 Linux 컨테이너 엔진에 연결했습니다. 엔진의 설치 위치는 이 검사로 확인하지 않습니다."
    fi
    if [[ "$engine" == docker ]]; then
        probe docker build --help
        if (( PROBE_CODE == 0 )) && [[ "$PROBE_TEXT" == *--platform* ]]; then check_result PASS builder-command 'Docker CLI 도움말에서 --platform 옵션을 확인했습니다. 실제 빌드는 아직 확인하지 않았습니다.'
        else check_result FAIL builder-command 'Docker --platform 빌드 기능을 확인하지 못했습니다.'; fi
        probe docker buildx version
        if (( PROBE_CODE == 0 )); then check_result PASS builder 'Docker CLI에서 Buildx 버전 조회에 성공했습니다. 실제 빌드는 아직 확인하지 않았습니다.'
        else check_result WARN builder 'Buildx를 확인하지 못했습니다. 실제 azd package에서 빌드 지원을 확인하세요.'; fi
    else
        if [[ "$(uname -s)" == Darwin ]]; then
            probe podman machine list
            if (( PROBE_CODE == 0 )); then check_result PASS podman-machine "Podman machine 목록 (선택된 연결은 별도로 확인): $PROBE_TEXT"
            else check_result WARN podman-machine 'Podman machine 목록을 조회하지 못했습니다. machine과 연결 설정을 직접 확인하세요.'; fi
        fi
        probe podman build --help
        if (( PROBE_CODE == 0 )) && [[ "$PROBE_TEXT" == *--platform* ]]; then
            check_result PASS builder 'Podman CLI 도움말에서 --platform 옵션을 확인했습니다. 실제 빌드는 아직 확인하지 않았습니다. Docker Buildx는 필요하지 않습니다.'
        else check_result FAIL builder 'Podman --platform 빌드 기능을 확인하지 못했습니다.'; fi
    fi
    check_result MANUAL container-workload '이 실습 셸에서 실제 linux/amd64 이미지 빌드, 컨테이너 포트 접근과 ACR 게시를 실습 중 확인하세요. 위 PASS는 실제 워크로드 성공을 보장하지 않습니다.'
}

check_java_sdks() {
    local sdk_dir="${SDKMAN_DIR:-$HOME/.sdkman}" candidate output compiler major compiler_major found8=0 found25=0
    if [[ ! -r "$sdk_dir/bin/sdkman-init.sh" ]]; then
        check_result FAIL sdkman 'SDKMAN 초기화 파일이 없습니다. docs/java/00-setup.md를 확인하세요.'
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
            25) found25=1 ;;
            *) continue ;;
        esac
        check_result PASS "jdk-$major" "SDKMAN 후보 ${candidate##*/}의 java와 javac를 확인했습니다."
    done
    (( found8 == 1 )) || check_result FAIL jdk-8 'SDKMAN으로 설치한 JDK 8이 필요합니다.'
    (( found25 == 1 )) || check_result FAIL jdk-25 'SDKMAN으로 설치한 JDK 25가 필요합니다.'
}

check_homebrew() {
    probe brew --version
    if (( PROBE_CODE == 0 )); then check_result PASS homebrew "$PROBE_TEXT"
    else check_result FAIL homebrew 'Homebrew가 필요합니다. ./scripts/install-prerequisites.sh --track java를 실행하세요.'; fi
}

check_glibc() {
    local version
    probe getconf GNU_LIBC_VERSION
    if (( PROBE_CODE != 0 )) || [[ ! "$PROBE_TEXT" =~ ^glibc[[:space:]]+([0-9]+)\.([0-9]+)(\.[0-9]+)?$ ]]; then
        check_result FAIL glibc 'glibc 버전을 확인하지 못했습니다. Modernize CLI에는 glibc 2.27 이상이 필요합니다. 지원되는 glibc 기반 Linux 배포판을 사용하세요.'
        return
    fi
    version="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.0"
    if minimum_version "$version" 2.27.0; then
        check_result PASS glibc "버전 $PROBE_TEXT (Modernize CLI 최소 2.27)"
    else
        check_result FAIL glibc "Modernize CLI에는 glibc 2.27 이상이 필요합니다. 확인된 버전: $PROBE_TEXT. glibc를 별도로 설치하지 말고 지원되는 Linux 배포판을 사용하세요."
    fi
}

check_modernize_tools() {
    probe modernize --version
    if (( PROBE_CODE == 0 )); then check_result PASS modernize "$PROBE_TEXT"
    elif [[ "$(uname -s)" == Linux && -x "$HOME/.local/bin/modernize" && "$PROBE_CODE" == 127 ]]; then
        check_result FAIL modernize '~/.local/bin/modernize가 PATH에 없습니다. 새 터미널을 열거나 셸 설정 파일을 다시 읽으세요.'
    else check_result FAIL modernize "Modernize CLI 설치 또는 실행 상태를 확인하세요 (종료 코드 $PROBE_CODE)."; fi
    probe gh --version
    if (( PROBE_CODE == 0 )) && minimum_version "$PROBE_TEXT" 2.45.0; then
        check_result PASS gh "$PROBE_TEXT"
        probe gh auth status
        if (( PROBE_CODE == 0 )); then check_result PASS gh-auth 'GitHub CLI 인증 상태를 확인했습니다. Copilot 모델 사용 권한은 별도로 확인하세요.'
        else check_result FAIL gh-auth 'gh auth login을 실행하거나 인증 오류를 해결하세요.'; fi
    else check_result FAIL gh 'GitHub CLI(gh) 2.45.0 이상이 필요합니다.'; fi
}

check_common() {
    local engine="$1" provider path
    probe git --version
    if (( PROBE_CODE == 0 )); then check_result PASS git "$PROBE_TEXT"; else check_result FAIL git 'Git이 필요합니다.'; fi
    initialize_node_environment || true
    probe node --version
    if (( PROBE_CODE == 0 )) && minimum_version "$PROBE_TEXT" 22.0.0; then check_result PASS node "$PROBE_TEXT (실행 파일: $(tool_path node))"
    elif (( PROBE_CODE == 127 )); then check_result FAIL node '이 Bash 환경의 PATH에서 Node.js를 찾지 못했습니다. 여기에서 Node.js 22 이상을 사용할 수 있도록 설정하세요.'
    else check_result FAIL node "이 Bash 환경에서 Node.js 22 이상을 실행하지 못했습니다 (종료 코드 $PROBE_CODE, 출력: ${PROBE_TEXT:-없음})."; fi
    probe az version --output json
    if (( PROBE_CODE == 0 )); then
        path=$(tool_path az)
        check_result PASS az "Azure CLI를 실행할 수 있습니다 (실행 파일: $path)."
        probe az extension show --name containerapp --query version --output tsv
        if (( PROBE_CODE == 0 )) && [[ -n "$PROBE_TEXT" ]]; then check_result PASS az-containerapp "확장 버전: $PROBE_TEXT"
        else check_result FAIL az-containerapp '설치 도우미에서 containerapp 확장을 설치하거나 조회 오류를 해결하세요.'; fi
        probe az account show --query state --output tsv
        if (( PROBE_CODE == 0 )) && [[ "$PROBE_TEXT" == Enabled ]]; then
            check_result PASS az-login '활성 구독이 있습니다.'
            check_azure_identity
            for provider in Microsoft.App Microsoft.OperationalInsights Microsoft.Storage Microsoft.ContainerRegistry Microsoft.ServiceBus Microsoft.DBforPostgreSQL; do
                check_azure_provider "$provider"
            done
        else check_result FAIL az-login 'az login 및 활성 구독 선택이 필요하거나 구독 조회에 실패했습니다.'; fi
    else check_result FAIL az 'Azure CLI 설치 또는 실행 상태를 확인하세요.'; fi
    probe azd version
    if (( PROBE_CODE == 0 )) && minimum_version "$PROBE_TEXT" 1.37.3; then
        check_result PASS azd "$PROBE_TEXT (실행 파일: $(tool_path azd))"
        probe azd auth login --check-status
        if (( PROBE_CODE == 0 )); then check_result PASS azd-login 'azd 로그인 상태를 확인했습니다.'
        else check_result FAIL azd-login 'azd auth login을 직접 실행하거나 인증 오류를 해결하세요.'; fi
    elif (( PROBE_CODE == 127 )); then check_result FAIL azd '이 Bash 환경의 PATH에서 azd를 찾지 못했습니다. 여기에서 azd 1.37.3 이상을 사용할 수 있도록 설정하세요.'
    else check_result FAIL azd "이 Bash 환경에서 azd 1.37.3 이상을 실행하지 못했습니다 (종료 코드 $PROBE_CODE, 출력: ${PROBE_TEXT:-없음})."; fi
    check_modernize_tools
    check_container "$engine"
    check_result MANUAL copilot-app 'Copilot app의 로그인, 라이선스, 조직 정책과 터미널 접근을 확인하세요.'
    check_result MANUAL azure-access '위에서 조회한 Azure CLI의 구독이 실습 대상인지 확인하고, 해당 구독의 리전, 쿼터, 역할 할당 및 데이터베이스 Entra 관리자 설정 권한을 확인하세요.' 'Azure (수동 확인)'
}

prerequisite_main() {
    local track='' requested='' engine os previous_dynamic="${AZURE_EXTENSION_USE_DYNAMIC_INSTALL-}"
    while (( $# )); do
        case "$1" in
            --track|--container-engine)
                if (( $# < 2 )) || [[ "$2" == --* || -z "$2" ]]; then printf '%s\n' "[FAIL] $1 값이 필요합니다." >&2; return 2; fi
                if [[ "$1" == --track ]]; then track="$2"; else requested="$2"; fi
                shift 2 ;;
            --help|-h) printf '%s\n' './scripts/check-prerequisites.sh --track java [--container-engine docker|podman]'; return 0 ;;
            *) printf '[FAIL] 알 수 없는 인자: %s\n' "$1" >&2; return 2 ;;
        esac
    done
    case "$track" in java|dotnet) ;; *) printf '%s\n' '[FAIL] --track java 또는 --track dotnet을 지정하세요.' >&2; return 2 ;; esac
    engine=$(resolve_engine "$requested") || return $?
    os=$(uname -s)
    if [[ "$track" == dotnet ]]; then
        printf '%s\n' '[FAIL] .NET은 Windows PowerShell에서 ./scripts/check-prerequisites.ps1 -Track dotnet을 실행하세요.'
        return 1
    fi
    case "$os" in
        Darwin|Linux) ;;
        *) printf '%s\n' '[FAIL] macOS와 Linux에서 실행하세요. Windows PowerShell에서는 ./scripts/check-prerequisites.ps1 -Track java를 실행하세요.'; return 1 ;;
    esac
    CHECK_FAILURES=0
    if [[ "$os" == Darwin ]]; then CHECK_CONTEXT='macOS Bash'
    else CHECK_CONTEXT='Linux Bash'; fi
    printf '트랙: java / 엔진: %s / 호출 환경: %s\n' "$engine" "$CHECK_CONTEXT"
    printf '%s\n' '다음 결과는 이 Bash의 PATH와 호출된 도구의 설정을 기준으로 합니다.'
    check_result PASS bash "Bash $BASH_VERSION"
    if [[ "$os" == Darwin ]]; then check_homebrew; fi
    if [[ "$os" == Linux ]]; then check_glibc; fi
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
