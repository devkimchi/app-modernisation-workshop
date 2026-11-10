#!/usr/bin/env bash

INSTALL_SCRIPTS="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "$INSTALL_SCRIPTS/check-prerequisites.sh"

confirm_install() {
    local answer
    printf '%s\n' "$1"
    read -r -p '설치하시겠습니까? [y/N] ' answer || return 1
    [[ "$answer" == y || "$answer" == Y ]]
}

run_remote_installer() {
    local url="$1" privilege="$2" temporary status
    command -v curl >/dev/null 2>&1 || { printf '%s\n' '[FAIL] curl이 필요합니다.' >&2; return 1; }
    temporary=$(mktemp "${TMPDIR:-/tmp}/workshop-installer.XXXXXXXX") || return 1
    if ! curl --fail --location --silent --show-error --proto '=https' --proto-redir '=https' --output "$temporary" "$url"; then
        rm -f -- "$temporary"
        printf '%s\n' '[FAIL] 설치 스크립트를 다운로드하지 못했습니다.' >&2
        return 1
    fi
    status=0
    if [[ "$privilege" == sudo ]]; then
        sudo bash "$temporary" || status=$?
    else
        bash "$temporary" || status=$?
    fi
    rm -f -- "$temporary"
    return "$status"
}

sdkman_missing_dependencies() {
    local dependency
    for dependency in curl zip unzip tar find sed; do
        command -v "$dependency" >/dev/null 2>&1 || printf '%s\n' "$dependency"
    done
}

prepare_sdkman_dependencies() {
    local os="$1" missing dependency package
    local -a packages=()
    if (( BASH_VERSINFO[0] < 4 )); then
        printf '%s\n' '[FAIL] SDKMAN 설치에는 Bash 4 이상이 필요합니다. Bash를 업그레이드한 뒤 다시 실행하세요.' >&2
        return 1
    fi
    missing=$(sdkman_missing_dependencies)
    if [[ -z "$missing" ]]; then return 0; fi
    printf '[WARN] SDKMAN 설치에 필요한 명령이 없습니다: %s\n' "${missing//$'\n'/, }"
    if [[ "$os" == Linux ]] && command -v apt-get >/dev/null 2>&1 && command -v sudo >/dev/null 2>&1; then
        while IFS= read -r dependency; do
            case "$dependency" in
                curl|zip|unzip|tar|sed) package="$dependency" ;;
                find) package=findutils ;;
                *) printf '[FAIL] 알 수 없는 SDKMAN 선행 도구: %s\n' "$dependency" >&2; return 1 ;;
            esac
            packages+=("$package")
        done <<< "$missing"
        if ! confirm_install "SDKMAN 선행 패키지: 현재 Linux 환경에 ${packages[*]}를 설치합니다. sudo와 네트워크가 필요하며 시스템 패키지가 변경됩니다."; then
            printf '%s\n' '[WARN] SDKMAN 선행 패키지 설치를 건너뛰어 SDKMAN을 설치하지 않습니다.'
            return 1
        fi
        if ! sudo apt-get update || ! sudo apt-get install -y "${packages[@]}"; then
            printf '%s\n' '[FAIL] SDKMAN 선행 패키지를 설치하지 못했습니다.' >&2
            return 1
        fi
        hash -r
        missing=$(sdkman_missing_dependencies)
        if [[ -z "$missing" ]]; then return 0; fi
        printf '[FAIL] 설치 후에도 SDKMAN 선행 명령을 찾을 수 없습니다: %s\n' "${missing//$'\n'/, }" >&2
        return 1
    fi
    printf '%s\n' '[FAIL] 누락된 명령을 직접 설치한 뒤 다시 실행하세요. docs/java/0-setup.md를 참고하세요.' >&2
    return 1
}

verify_sdkman_installation() {
    local sdk_dir="$1"
    if [[ ! -r "$sdk_dir/bin/sdkman-init.sh" ]]; then
        printf '[FAIL] 설치 스크립트가 종료됐지만 SDKMAN 초기화 파일이 없습니다: %s\n' "$sdk_dir/bin/sdkman-init.sh" >&2
        return 1
    fi
    if ! SDKMAN_DIR="$sdk_dir" bash -c 'source "$SDKMAN_DIR/bin/sdkman-init.sh" && [[ $(type -t sdk) == function ]] && sdk version >/dev/null'; then
        printf '[FAIL] SDKMAN 초기화 또는 실행에 실패했습니다: %s\n' "$sdk_dir" >&2
        return 1
    fi
}

nvm_directory() {
    if [[ -n "${NVM_DIR:-}" ]]; then printf '%s\n' "$NVM_DIR"
    elif [[ -n "${XDG_CONFIG_HOME:-}" ]]; then printf '%s/nvm\n' "$XDG_CONFIG_HOME"
    else printf '%s/.nvm\n' "$HOME"; fi
}

install_node_with_nvm() {
    local nvm_dir
    nvm_dir=$(nvm_directory)
    if [[ ! -s "$nvm_dir/nvm.sh" ]]; then
        if [[ -e "$nvm_dir" || -L "$nvm_dir" ]]; then
            printf '[FAIL] nvm 경로에 nvm.sh가 없습니다. 기존 경로를 변경하지 않습니다: %s\n' "$nvm_dir" >&2
            return 1
        fi
        if ! confirm_install "nvm: $nvm_dir에 공식 설치 스크립트를 실행합니다. 네트워크가 필요하며 셸 설정이 변경될 수 있습니다. 출처: https://github.com/nvm-sh/nvm"; then return 0; fi
        if ! mkdir -p "$nvm_dir"; then
            printf '[FAIL] nvm 설치 경로를 만들지 못했습니다: %s\n' "$nvm_dir" >&2; return 1
        fi
        if ! NVM_DIR="$nvm_dir" NODE_VERSION='' run_remote_installer 'https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh' user; then
            printf '%s\n' '[FAIL] nvm 설치에 실패했습니다.' >&2; return 1
        fi
    fi
    export NVM_DIR="$nvm_dir"
    if [[ ! -s "$NVM_DIR/nvm.sh" ]] || ! source "$NVM_DIR/nvm.sh" --no-use || [[ $(type -t nvm) != function ]]; then
        printf '%s\n' '[FAIL] nvm 초기화에 실패했습니다.' >&2; return 1
    fi
    if [[ $(nvm version 22) == v22.* ]]; then
        if ! nvm use 22; then printf '%s\n' '[FAIL] 기존 Node.js 22를 활성화하지 못했습니다.' >&2; return 1; fi
    elif confirm_install 'Node.js 22: nvm으로 현재 사용자에게 설치합니다. 네트워크가 필요하며 시스템 Node.js는 변경하지 않습니다.'; then
        if ! nvm install 22 || ! nvm use 22; then
            printf '%s\n' '[FAIL] nvm을 통한 Node.js 22 설치에 실패했습니다.' >&2; return 1
        fi
    else
        return 0
    fi
    if [[ $(node --version) != v22.* ]] || ! npm --version; then
        printf '%s\n' '[FAIL] 설치된 Node.js 22 또는 npm 실행에 실패했습니다.' >&2; return 1
    fi
    printf '[INFO] 현재 터미널에도 적용하려면: export NVM_DIR=%q; source "$NVM_DIR/nvm.sh"; nvm use 22\n' "$NVM_DIR"
}

jdk_matches_major() {
    local candidate="$1" major="$2" runtime compiler
    [[ -x "$candidate/bin/java" && -x "$candidate/bin/javac" ]] || return 1
    runtime=$("$candidate/bin/java" -version 2>&1) || return 1
    compiler=$("$candidate/bin/javac" -version 2>&1) || return 1
    [[ "$runtime" != *-ea* && "$compiler" != *-ea* ]] || return 1
    if [[ "$major" == 8 ]]; then
        [[ "$runtime" =~ version[[:space:]]+\"1\.8\. && "$compiler" =~ javac[[:space:]]+1\.8\. ]]
    else
        [[ "$runtime" =~ version[[:space:]]+\"$major(\.|\") && "$compiler" =~ javac[[:space:]]+$major(\.|$) ]]
    fi
}

install_java_sdks() (
    export SDKMAN_DIR="$1"
    local major candidate identifier listing failed=0 found USE
    if ! source "$SDKMAN_DIR/bin/sdkman-init.sh"; then
        printf '%s\n' '[FAIL] JDK 설치를 위한 SDKMAN 초기화에 실패했습니다.' >&2; return 1
    fi
    # SDKMAN 설치 함수가 참조하는 응답을 지정해 기존 기본 JDK를 유지한다.
    sdkman_auto_answer=false
    sdkman_colour_enable=false
    for major in 8 21 25; do
        found=0
        for candidate in "$SDKMAN_DIR"/candidates/java/*; do
            [[ "${candidate##*/}" != current ]] || continue
            if jdk_matches_major "$candidate" "$major"; then found=1; break; fi
        done
        if (( found )); then printf '[INFO] JDK %s: 기존 SDKMAN 설치를 사용합니다 (%s).\n' "$major" "${candidate##*/}"; continue; fi
        if ! confirm_install "JDK $major: SDKMAN 목록에서 이 환경에 제공되는 정식 Temurin JDK를 선택해 설치합니다. 네트워크와 디스크 공간이 필요합니다. 기존 기본 JDK는 유지합니다."; then continue; fi
        if ! listing=$(PAGER=cat sdk list java); then
            printf '[FAIL] JDK %s 설치 목록을 조회하지 못했습니다.\n' "$major" >&2; failed=1; continue
        fi
        identifier=$(printf '%s\n' "$listing" | awk -F '|' -v major="$major" '
            { id=$NF; gsub(/\033\[[0-9;]*m/, "", id); gsub(/^[ \t]+|[ \t\r]+$/, "", id)
              if (id ~ ("^" major "\\.[0-9]+(\\.[0-9]+)*(\\+[0-9]+(\\.[0-9]+)*)?-tem$")) { print id; exit } }')
        if [[ -z "$identifier" ]]; then
            printf '[FAIL] 이 환경의 SDKMAN 목록에 정식 Temurin JDK %s가 없습니다. sdk list java로 다른 배포판을 확인하세요.\n' "$major" >&2
            failed=1; continue
        fi
        USE=n
        if ! sdk install java "$identifier" <<< n || ! jdk_matches_major "$SDKMAN_DIR/candidates/java/$identifier" "$major"; then
            printf '[FAIL] JDK %s 설치 또는 실행 확인에 실패했습니다 (%s).\n' "$major" "$identifier" >&2; failed=1
        fi
    done
    printf '[INFO] 현재 터미널에서 SDKMAN을 사용하려면: source %q\n' "$SDKMAN_DIR/bin/sdkman-init.sh"
    return "$failed"
)

install_missing_tools() {
    local os="$1" tool path sdk_dir="${SDKMAN_DIR:-$HOME/.sdkman}" failed=0
    for tool in node az azd sdkman; do
        if [[ "$tool" == sdkman ]]; then
            if [[ -e "$sdk_dir" || -L "$sdk_dir" ]]; then
                if [[ ! -r "$sdk_dir/bin/sdkman-init.sh" ]]; then
                    printf '[FAIL] SDKMAN 경로가 이미 있지만 초기화 파일이 없습니다: %s. 내용을 확인하세요. 자동으로 변경하지 않습니다.\n' "$sdk_dir" >&2
                    failed=1
                elif ! verify_sdkman_installation "$sdk_dir"; then
                    printf '[WARN] 기존 SDKMAN 경로를 자동으로 변경하지 않습니다. 내용을 확인하세요: %s\n' "$sdk_dir" >&2
                    failed=1
                else
                    install_java_sdks "$sdk_dir" || failed=1
                fi
                continue
            fi
        else
            path=$(tool_path "$tool")
            if [[ -n "$path" && ! ( "$os" == Linux && -n "${WSL_DISTRO_NAME:-}" && "$path" =~ ^/mnt/[a-zA-Z]/ ) ]]; then
                printf '[INFO] %s: PATH에서 발견했습니다 (%s). 설치하거나 업데이트하지 않습니다.\n' "$tool" "$path"
                continue
            fi
            if [[ -n "$path" ]]; then
                printf '[INFO] %s: Windows 드라이브의 실행 파일만 PATH에서 선택되었습니다 (%s). WSL에 별도로 설치할 수 있습니다.\n' "$tool" "$path"
            fi
        fi
        case "$os:$tool" in
            Linux:node|Darwin:node)
                install_node_with_nvm || failed=1 ;;
            Linux:az)
                if ! command -v apt-get >/dev/null 2>&1 || ! command -v sudo >/dev/null 2>&1; then
                    printf '%s\n' '[WARN] Azure CLI 자동 설치에는 apt-get과 sudo가 필요합니다. docs/java/0-setup.md에서 수동 설치 방법을 확인하세요.'
                    continue
                fi
                if confirm_install 'Azure CLI: 현재 Linux 환경에 Microsoft 공식 설치 스크립트를 실행합니다. sudo와 네트워크가 필요하며 APT 저장소와 시스템 패키지가 변경됩니다. 출처: https://aka.ms/InstallAzureCLIDeb'; then
                    if ! run_remote_installer 'https://aka.ms/InstallAzureCLIDeb' sudo; then printf '%s\n' '[FAIL] Azure CLI 설치에 실패했습니다.' >&2; failed=1; fi
                fi ;;
            Linux:azd)
                if confirm_install 'Azure Developer CLI: 현재 Linux 환경에 Microsoft 공식 설치 스크립트를 실행합니다. 네트워크와 sudo가 필요할 수 있습니다. 출처: https://aka.ms/install-azd.sh'; then
                    if ! run_remote_installer 'https://aka.ms/install-azd.sh' user; then printf '%s\n' '[FAIL] azd 설치에 실패했습니다.' >&2; failed=1; fi
                fi ;;
            Darwin:az|Darwin:azd)
                if ! command -v brew >/dev/null 2>&1; then
                    printf '[WARN] %s 자동 설치에는 Homebrew가 필요합니다. Homebrew는 자동 설치하지 않습니다.\n' "$tool"
                    continue
                fi
                case "$tool" in
                    az) set -- azure-cli ;;
                    azd) set -- azure/azd/azd ;;
                esac
                if confirm_install "$tool: macOS에서 Homebrew 패키지 $1을 설치합니다. 네트워크가 필요하며 Homebrew 저장소와 패키지가 변경될 수 있습니다."; then
                    if ! brew install "$1"; then printf '[FAIL] %s 설치에 실패했습니다.\n' "$tool" >&2; failed=1; fi
                fi ;;
            *:sdkman)
                if confirm_install "SDKMAN: 현재 사용자의 $sdk_dir에 공식 설치 스크립트를 실행합니다. 네트워크가 필요하며 셸 설정 파일이 변경될 수 있습니다. JDK는 버전별로 별도 동의를 받아 설치합니다. 출처: https://get.sdkman.io"; then
                    if ! prepare_sdkman_dependencies "$os"; then
                        failed=1
                    elif ! SDKMAN_DIR="$sdk_dir" run_remote_installer 'https://get.sdkman.io' user; then
                        printf '%s\n' '[FAIL] SDKMAN 설치에 실패했습니다. 위 오류와 기존 설치 경로를 확인하세요.' >&2; failed=1
                    elif ! verify_sdkman_installation "$sdk_dir"; then
                        failed=1
                    else
                        install_java_sdks "$sdk_dir" || failed=1
                    fi
                fi ;;
        esac
    done
    return "$failed"
}

install_prerequisite_main() {
    local track='' requested='' engine os result=0
    while (( $# )); do
        case "$1" in
            --track|--container-engine)
                if (( $# < 2 )) || [[ -z "$2" || "$2" == --* ]]; then printf '[FAIL] %s 값이 필요합니다.\n' "$1" >&2; return 2; fi
                if [[ "$1" == --track ]]; then track="$2"; else requested="$2"; fi
                shift 2 ;;
            --help|-h) printf '%s\n' 'bash scripts/install-prerequisites.sh --track java [--container-engine docker|podman]'; return 0 ;;
            *) printf '[FAIL] 알 수 없는 인자: %s\n' "$1" >&2; return 2 ;;
        esac
    done
    [[ "$track" == java ]] || { printf '%s\n' '[FAIL] Bash 설치 도우미는 --track java만 지원합니다.' >&2; return 2; }
    engine=$(resolve_engine "$requested") || return $?
    os=$(uname -s)
    case "$os" in
        Darwin) ;;
        Linux)
            if [[ "${WORKSHOP_DEVCONTAINER:-}" != 1 ]] && ! grep -Eqi 'microsoft.*wsl2|wsl2.*microsoft' /proc/sys/kernel/osrelease; then
                printf '%s\n' '[FAIL] Java 설치 도우미는 macOS, WSL2 또는 워크숍 Dev Container에서 실행하세요.' >&2; return 1
            fi ;;
        *) printf '%s\n' '[FAIL] Java 설치 도우미는 Windows가 아닌 WSL2 또는 macOS에서 실행하세요.' >&2; return 1 ;;
    esac
    if [[ ! -t 0 || ! -t 1 || -n "${CI:-}" ]]; then
        printf '%s\n' '[FAIL] 설치는 대화형 터미널에서만 가능합니다. 비대화형 환경에서는 설치하지 않습니다.' >&2
        return 1
    fi
    printf '설치 대상: %s%s. 이미 PATH에 있는 도구는 변경하지 않습니다.\n' "$os" "${WSL_DISTRO_NAME:+ / WSL $WSL_DISTRO_NAME}"
    install_missing_tools "$os" || result=1
    hash -r
    printf '%s\n' '설치 후 사전 점검을 다시 실행합니다. 로그인, 확장과 수동 항목은 직접 확인하세요.'
    prerequisite_main --track java --container-engine "$engine" || result=1
    return "$result"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then install_prerequisite_main "$@"; exit $?; fi
