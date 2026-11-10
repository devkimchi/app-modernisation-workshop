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
    printf '[%s] [%s] %s: %s\n' "$1" "${4:-${CHECK_CONTEXT:-Bash}}" "$2" "$3"
    if [[ "$1" == FAIL ]]; then CHECK_FAILURES=$((CHECK_FAILURES + 1)); fi
}

tool_path() {
    command -v "$1" 2>/dev/null || true
}

initialize_node_environment() {
    local node_path nvm_dir
    node_path=$(tool_path node)
    if [[ -n "$node_path" && ! ( "${CHECK_CONTEXT:-}" == WSL* && "$node_path" =~ ^/mnt/[a-zA-Z]/ ) ]]; then return 0; fi
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

can_prompt_azure() {
    [[ -t 0 && -t 1 && -z "${CI:-}" ]]
}

confirm_azure_action() {
    local answer
    can_prompt_azure || return 1
    read -r -p "$1 [y/N] " answer || return 1
    [[ "$answer" == y || "$answer" == Y ]]
}

run_azure_action() {
    if ! "$@"; then
        check_result WARN azure-action "명령 실행에 실패했습니다: $*. 위 오류를 확인하세요."
        return 1
    fi
}

prepare_azure_account() {
    local subscriptions selected id name valid=0
    can_prompt_azure || return 0
    probe az account show --query state --output tsv
    if (( PROBE_CODE != 0 )) || [[ "$PROBE_TEXT" != Enabled ]]; then
        check_result WARN az-login "활성 구독 확인 실패 (종료 코드 $PROBE_CODE): ${PROBE_TEXT:-출력 없음}. 미로그인 외에 권한 또는 네트워크 문제일 수도 있습니다."
        if confirm_azure_action '이 셸의 Azure CLI에서 az login을 실행하시겠습니까?'; then
            run_azure_action az login || return 0
        fi
    fi
    if confirm_azure_action '구독 목록을 조회하고 실습 구독을 직접 선택하시겠습니까?'; then
        probe az account list --query '[].[id,name]' --output tsv
        if (( PROBE_CODE != 0 )) || [[ -z "$PROBE_TEXT" ]]; then
            check_result WARN azure-subscription "구독 목록 조회 실패: ${PROBE_TEXT:-출력 없음}"
            return 0
        fi
        subscriptions="$PROBE_TEXT"
        printf '구독 ID / 이름:\n%s\n' "$subscriptions"
        read -r -p '변경할 구독 ID (Enter: 유지): ' selected || return 0
        [[ -n "$selected" ]] || return 0
        while IFS=$'\t' read -r id name; do
            [[ "$selected" == "$id" ]] && valid=1
        done <<< "$subscriptions"
        if (( valid )); then run_azure_action az account set --subscription "$selected" || return 0
        else check_result WARN azure-subscription '목록에 없는 구독 ID입니다. 구독을 변경하지 않았습니다.'; fi
    fi
}

prepare_containerapp_extension() {
    can_prompt_azure || return 0
    probe az extension show --name containerapp --query version --output tsv
    if (( PROBE_CODE != 0 )) || [[ -z "$PROBE_TEXT" ]]; then
        check_result WARN az-containerapp "확장 조회 실패 (종료 코드 $PROBE_CODE): ${PROBE_TEXT:-출력 없음}"
        if confirm_azure_action 'containerapp 확장을 설치하거나 업데이트하시겠습니까? 로컬 Azure CLI 확장 파일이 변경됩니다.'; then
            run_azure_action az extension add --name containerapp --upgrade || return 0
        fi
    fi
}

prepare_azd_login() {
    can_prompt_azure || return 0
    probe azd auth login --check-status
    if (( PROBE_CODE != 0 )); then
        check_result WARN azd-login "인증 확인 실패 (종료 코드 $PROBE_CODE): ${PROBE_TEXT:-출력 없음}"
        if confirm_azure_action '이 셸에서 azd auth login을 실행하시겠습니까? Azure CLI 로그인과 별개입니다.'; then
            run_azure_action azd auth login || return 0
        fi
    fi
}

check_azure_provider() {
    local provider="$1"
    probe az provider show --namespace "$provider" --query registrationState --output tsv
    if (( PROBE_CODE == 0 )) && [[ "$PROBE_TEXT" == Registered ]]; then
        check_result PASS "$provider" Registered
        return
    fi
    check_result WARN "$provider" "등록 상태 (종료 코드 $PROBE_CODE): ${PROBE_TEXT:-출력 없음}"
    if (( PROBE_CODE == 0 )) && [[ "$PROBE_TEXT" == NotRegistered || "$PROBE_TEXT" == Unregistered || "$PROBE_TEXT" == Registering ]]; then
        if confirm_azure_action "현재 Azure CLI 구독에 $provider 공급자를 등록하고 완료를 기다리시겠습니까? 구독 설정이 변경되며 등록 권한이 필요합니다."; then
            run_azure_action az provider register --namespace "$provider" --wait || true
            probe az provider show --namespace "$provider" --query registrationState --output tsv
        fi
    fi
    if (( PROBE_CODE == 0 )) && [[ "$PROBE_TEXT" == Registered ]]; then check_result PASS "$provider" Registered
    else check_result FAIL "$provider" "등록을 확인하지 못했습니다 (종료 코드 $PROBE_CODE): ${PROBE_TEXT:-출력 없음}. 대상 구독과 등록 권한을 확인하세요."; fi
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
        check_result FAIL container-cli "$engine 실행 실패 (종료 코드 $PROBE_CODE). docs/java/0-setup.md를 확인하세요."
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
    local sdk_dir="${SDKMAN_DIR:-$HOME/.sdkman}" candidate output compiler major compiler_major found8=0 found21=0 found25=0
    if [[ ! -r "$sdk_dir/bin/sdkman-init.sh" ]]; then
        check_result FAIL sdkman 'SDKMAN 초기화 파일이 없습니다. docs/java/0-setup.md를 확인하세요.'
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
        if [[ "${CHECK_CONTEXT:-}" == WSL* && "$path" =~ ^/mnt/[a-zA-Z]/ ]]; then
            check_result WARN az-origin 'WSL에서 Windows 드라이브의 Azure CLI를 사용하고 있습니다. 표시된 로그인과 구독은 이 CLI의 설정입니다. WSL에 설치된 CLI를 사용하려면 command -v az로 선택된 경로를 확인하고, 해당 CLI의 로그인과 구독을 다시 확인하세요.'
        fi
        prepare_azure_account
        prepare_containerapp_extension
        probe az extension show --name containerapp --query version --output tsv
        if (( PROBE_CODE == 0 )) && [[ -n "$PROBE_TEXT" ]]; then check_result PASS az-containerapp "확장 버전: $PROBE_TEXT"
        else check_result FAIL az-containerapp '확장 설치 여부와 조회 오류를 확인하세요.'; fi
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
        prepare_azd_login
        probe azd auth login --check-status
        if (( PROBE_CODE == 0 )); then check_result PASS azd-login 'azd 로그인 상태를 확인했습니다.'
        else check_result FAIL azd-login 'azd auth login을 직접 실행하거나 인증 오류를 해결하세요.'; fi
    elif (( PROBE_CODE == 127 )); then check_result FAIL azd '이 Bash 환경의 PATH에서 azd를 찾지 못했습니다. 여기에서 azd 1.37.3 이상을 사용할 수 있도록 설정하세요.'
    else check_result FAIL azd "이 Bash 환경에서 azd 1.37.3 이상을 실행하지 못했습니다 (종료 코드 $PROBE_CODE, 출력: ${PROBE_TEXT:-없음})."; fi
    check_container "$engine"
    if [[ "${CHECK_CONTEXT:-}" == WSL* ]]; then
        check_result MANUAL copilot-app 'Windows에서 실행하는 Copilot app의 로그인, 라이선스, 조직 정책과 Modernization 플러그인을 확인하세요.' 'Windows 호스트 (수동 확인)'
    else
        check_result MANUAL copilot-app 'Copilot app을 실행하는 호스트에서 로그인, 라이선스, 조직 정책과 Modernization 플러그인을 확인하세요.'
    fi
    check_result MANUAL azure-access '위에서 조회한 Azure CLI의 구독이 실습 대상인지 확인하고, 해당 구독의 리전, 쿼터, 역할 할당 및 데이터베이스 Entra 관리자 설정 권한을 확인하세요.' 'Azure (수동 확인)'
}

prerequisite_main() {
    local track='' requested='' engine os windows_host_checked=0 previous_dynamic="${AZURE_EXTENSION_USE_DYNAMIC_INSTALL-}"
    while (( $# )); do
        case "$1" in
            --track|--container-engine)
                if (( $# < 2 )) || [[ "$2" == --* || -z "$2" ]]; then printf '%s\n' "[FAIL] $1 값이 필요합니다." >&2; return 2; fi
                if [[ "$1" == --track ]]; then track="$2"; else requested="$2"; fi
                shift 2 ;;
            --windows-host-checked) windows_host_checked=1; shift ;;
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
    if [[ "$os" == Darwin ]]; then CHECK_CONTEXT='macOS Bash'
    elif [[ "${WORKSHOP_DEVCONTAINER:-}" == 1 ]]; then CHECK_CONTEXT='Dev Container Bash'
    else CHECK_CONTEXT="WSL${WSL_DISTRO_NAME:+ $WSL_DISTRO_NAME} Bash"; fi
    printf '트랙: java / 엔진: %s / 호출 환경: %s\n' "$engine" "$CHECK_CONTEXT"
    printf '%s\n' '다음 결과는 이 Bash의 PATH와 호출된 도구의 설정을 기준으로 합니다. Windows 호스트 검사와 별개입니다.'
    check_result PASS bash "Bash $BASH_VERSION"
    if [[ "$os" == Linux && "${WORKSHOP_DEVCONTAINER:-}" != 1 && "$windows_host_checked" != 1 ]]; then check_result MANUAL windows-host 'Windows Copilot app 호스트에도 Git과 Node.js 22 이상이 필요합니다. WSL 내부 검사와 별개이며 Windows PowerShell 진입점은 호스트도 검사합니다.'; fi
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
