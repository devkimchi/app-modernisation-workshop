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
    update_node_with_nvm "${1:-0}"
}

update_node_with_nvm() {
    local update="${1:-1}" current='' latest nvm_dir installed active resolved_dir major=22 node_path live_path
    node_path=$(tool_path node)
    if [[ -n "${WSL_DISTRO_NAME:-}" && "$node_path" =~ ^/mnt/[a-zA-Z]/ ]]; then node_path=''; fi
    if [[ -n "$node_path" ]]; then
        current=$(node --version) || { printf '%s\n' '[FAIL] Node.js 버전 확인에 실패했습니다.' >&2; return 1; }
        if [[ ! "$current" =~ ^v([0-9]+)\.[0-9]+\.[0-9]+$ ]]; then
            printf '%s\n' '[FAIL] Node.js 정식 버전 확인에 실패했습니다.' >&2; return 1
        fi
        if (( BASH_REMATCH[1] >= 22 )); then major="${BASH_REMATCH[1]}"; fi
    fi
    nvm_dir=$(nvm_directory)
    if [[ ! -s "$nvm_dir/nvm.sh" ]]; then
        printf '%s\n' '[MANUAL] 기존 Node.js는 nvm 관리 설치로 확인되지 않았습니다. 기존 설치 관리자로 업데이트하세요.'
        return 1
    fi
    export NVM_DIR="$nvm_dir"
    if ! source "$NVM_DIR/nvm.sh" --no-use || [[ $(type -t nvm) != function ]]; then
        printf '%s\n' '[FAIL] nvm 초기화에 실패했습니다.' >&2; return 1
    fi
    # nvm이 있어도 현재 실행 파일이 다른 관리자 소유라면 덮어쓰지 않는다.
    resolved_dir=$(cd -P -- "$NVM_DIR" && pwd) || return 1
    if [[ -n "$current" ]]; then
        installed=$(nvm which current) || return 1
        active=$(canonical_tool_path "$node_path") || return 1
        installed=$(canonical_tool_path "$installed") || return 1
        if [[ "$active" != "$installed" || "$installed" != "$resolved_dir/versions/node/$current/bin/node" ]]; then
            printf '%s\n' '[MANUAL] 현재 Node.js의 nvm 출처를 확인하지 못했습니다. 기존 설치 관리자로 업데이트하세요.'
            return 1
        fi
        if (( ! update )); then
            printf '[INFO] Node.js %s 유지 (--update 없음).\n' "$current"
            version_not_older "${current#v}" 22.0.0
            return $?
        fi
    fi
    if ! confirm_install "Node.js $major: nvm으로 최신 정식 버전을 조회하고 필요하면 추가 설치합니다. 기존 버전은 보존합니다."; then
        [[ -n "$current" ]] && version_not_older "${current#v}" 22.0.0
        return $?
    fi
    latest=$(nvm version-remote "$major") || { printf '[FAIL] 최신 Node.js %s 조회에 실패했습니다.\n' "$major" >&2; return 1; }
    if [[ ! "$latest" =~ ^v$major\.[0-9]+\.[0-9]+$ ]]; then
        printf '[FAIL] 정식 Node.js %s 식별자를 확인하지 못했습니다.\n' "$major" >&2; return 1
    fi
    if [[ -n "$current" ]] && version_not_older "${current#v}" "${latest#v}"; then
        npm --version || return 1
        printf '[INFO] Node.js %s 유지 (이미 최신 또는 다운그레이드 없음).\n' "$current"; return 0
    fi
    if [[ $(type -t nvm_ensure_default_set) != function ]]; then
        printf '%s\n' '[MANUAL] 이 nvm의 기본 alias 보존 방식을 확인하지 못했습니다. 수동으로 업데이트하세요.'
        return 1
    fi
    installed="$NVM_DIR/versions/node/$latest/bin"
    # nvm install의 자동 default alias 생성은 설치 하위 셸에서만 막는다.
    if [[ $(nvm version "$latest") != "$latest" ]] && ! (
        nvm_ensure_default_set() { return 0; }
        nvm install --no-use "$latest"
    ); then
        printf '%s\n' '[FAIL] Node.js 설치에 실패했습니다.' >&2; return 1
    fi
    if [[ $("$installed/node" --version) != "$latest" ]] || ! PATH="$installed:$PATH" "$installed/npm" --version; then
        printf '%s\n' '[FAIL] 설치된 Node.js 또는 npm 실행 검증 실패.' >&2; return 1
    fi
    if ! confirm_install "Node.js $latest 활성화: 스크립트 환경에서 nvm use를 실행합니다. 기본 alias와 기존 버전은 유지하며 부모 터미널은 변경하지 않습니다."; then
        printf '[INFO] 활성화하지 않았습니다. 필요하면 nvm use %s를 직접 실행하세요.\n' "$latest"
        [[ -n "$current" ]] && version_not_older "${current#v}" 22.0.0
        return $?
    fi
    live_path=$(tool_path node)
    if [[ -n "${WSL_DISTRO_NAME:-}" && "$live_path" =~ ^/mnt/[a-zA-Z]/ ]]; then live_path=''; fi
    if [[ "$live_path" != "$node_path" ]] ||
        { [[ -n "$current" ]] && { [[ $(node --version) != "$current" ]] ||
            [[ $(canonical_tool_path "$live_path") != "$active" ]]; }; }; then
        printf '%s\n' '[MANUAL] 활성 Node.js가 변경되어 활성화하지 않습니다.' >&2; return 1
    fi
    if ! nvm use "$latest" || [[ $(node --version) != "$latest" ]] ||
        [[ $(canonical_tool_path "$(tool_path node)") != "$resolved_dir/versions/node/$latest/bin/node" ]] ||
        ! npm --version; then
        printf '%s\n' '[FAIL] Node.js 활성화 또는 실행 검증 실패.' >&2; return 1
    fi
    printf '[PASS] Node.js %s 활성화 완료 (스크립트 환경, 기본 alias 유지).\n' "$latest"
    printf '[INFO] 부모 터미널은 변경되지 않습니다. 현재 터미널에서 실행: export NVM_DIR=%q; source "$NVM_DIR/nvm.sh" --no-use; nvm use %s\n' "$NVM_DIR" "$latest"
}

canonical_tool_path() (
    local path="$1" link count=0
    [[ -e "$path" ]] || return 1
    while [[ -L "$path" ]]; do
        (( count++ < 40 )) || return 1
        link=$(readlink "$path") || return 1
        if [[ "$link" == /* ]]; then path="$link"; else path="$(dirname "$path")/$link"; fi
    done
    cd -P -- "$(dirname "$path")" || return 1
    printf '%s/%s\n' "$PWD" "${path##*/}"
)

version_not_older() {
    local next="$1" previous="$2" i
    local -a a b
    [[ "$next" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && "$previous" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 1
    IFS=. read -r -a a <<< "$next"
    IFS=. read -r -a b <<< "$previous"
    for i in 0 1 2; do
        (( 10#${a[i]} > 10#${b[i]} )) && return 0
        (( 10#${a[i]} < 10#${b[i]} )) && return 1
    done
    return 0
}

azure_tool_version() {
    local text
    if [[ "$1" == az ]]; then
        text=$(az version --query '"azure-cli"' --output tsv) || return 1
        [[ "$text" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 1
        printf '%s\n' "$text"
    else
        text=$(azd version) || return 1
        [[ "$text" =~ ^azd[[:space:]]version[[:space:]]([0-9]+\.[0-9]+\.[0-9]+)([[:space:]]|$) ]] || return 1
        printf '%s\n' "${BASH_REMATCH[1]}"
    fi
}

ensure_homebrew() {
    command -v brew >/dev/null 2>&1 && return 0
    if ! confirm_install 'Homebrew: 공식 설치 스크립트를 실행합니다. 네트워크, 디스크와 관리자 권한이 필요하며 macOS 개발 도구가 설치될 수 있습니다. 출처: https://brew.sh'; then return 1; fi
    if ! run_remote_installer 'https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh' user; then
        printf '%s\n' '[FAIL] Homebrew 설치에 실패했습니다.' >&2; return 1
    fi
    if ! command -v brew >/dev/null 2>&1; then
        if [[ -x /opt/homebrew/bin/brew ]]; then export PATH="/opt/homebrew/bin:$PATH"
        elif [[ -x /usr/local/bin/brew ]]; then export PATH="/usr/local/bin:$PATH"; fi
    fi
    if ! brew --version; then printf '%s\n' '[FAIL] Homebrew 실행 확인에 실패했습니다.' >&2; return 1; fi
}

microsoft_apt_candidate() {
    local policy
    policy=$(LC_ALL=C apt-cache policy "$1") || return 2
    printf '%s\n' "$policy" | awk '
        /Candidate:/ { candidate=$2 }
        /^[[:space:]]*(\*\*\*[[:space:]]*)?[^[:space:]]+[[:space:]]+[0-9]+$/ {
            version=$1 == "***" ? $2 : $1
        }
        version == candidate && $2 ~ /^https:\/\/packages\.microsoft\.com\// { found=1 }
        END { if(found) print candidate; else exit 1 }'
}

linux_azd_target() {
    case "$(uname -m)" in
        x86_64) printf '/opt/microsoft/azd/azd-linux-amd64\n' ;;
        aarch64|arm64) printf '/opt/microsoft/azd/azd-linux-arm64\n' ;;
        *) printf '%s\n' '[FAIL] azd: 지원하지 않는 CPU 아키텍처입니다.' >&2; return 1 ;;
    esac
}

linux_azd_link() { printf '/usr/local/bin/azd\n'; }

azd_file_hash() {
    local result
    result=$(sha256sum -- "$1") || return 1
    [[ "$result" =~ ^([a-f0-9]{64})[[:space:]] ]] || return 1
    printf '%s\n' "${BASH_REMATCH[1]}"
}

azd_package_owned() {
    local path status
    for path in "$@"; do
        if command -v dpkg-query >/dev/null 2>&1; then
            dpkg-query -S "$path" >/dev/null 2>&1 && return 0
            status=$?
            (( status == 1 )) || return 2
        fi
        if command -v rpm >/dev/null 2>&1; then
            rpm -qf "$path" >/dev/null 2>&1 && return 0
            status=$?
            (( status == 1 )) || return 2
        fi
    done
    return 1
}

install_linux_azd() (
    local path="${1:-}" target link before='' digest='' after live
    local state="${XDG_STATE_HOME:-$HOME/.local/state}/app-modernisation-workshop"
    local record temporary owner_status ancestor
    local -a saved=()
    if ! command -v sha256sum >/dev/null 2>&1; then
        printf '%s\n' '[FAIL] azd: 설치 기록 검증에 sha256sum이 필요합니다.' >&2; return 1
    fi
    record="$state/azd-script-install"
    target=$(linux_azd_target) || return 1
    link=$(linux_azd_link) || return 1
    for ancestor in "${target%/*}" "${link%/*}" "$state"; do
        while [[ ! -e "$ancestor" && ! -L "$ancestor" && "$ancestor" != / ]]; do ancestor=$(dirname -- "$ancestor"); done
        if [[ "$ancestor" != /* || ! -d "$ancestor" ]] ||
            { [[ "$ancestor" != / ]] && [[ "$(canonical_tool_path "$ancestor")" != "$ancestor" ]]; }; then
            printf '[FAIL] azd: 설치/기록 경로가 일반 절대 경로가 아닙니다: %s\n' "$ancestor" >&2; return 1
        fi
    done
    if [[ -L "$state" || -L "$record" || ( -e "$state" && ! -d "$state" ) ]]; then
        printf '%s\n' '[FAIL] azd: 관리 기록 경로가 일반 디렉터리/파일이 아닙니다.' >&2; return 1
    fi
    if azd_package_owned "$link" "$target" "${path:-$link}"; then
        printf '%s\n' '[MANUAL] azd: 패키지 관리자가 소유한 설치는 공식 스크립트로 덮어쓰지 않습니다.'
        return 0
    else
        owner_status=$?
        if (( owner_status != 1 )); then
            printf '%s\n' '[FAIL] azd: 패키지 소유권 조회에 실패했습니다.' >&2; return 1
        fi
    fi
    if [[ -n "$path" ]]; then
        if [[ "$path" != "$link" || ! -L "$link" || ! -f "$target" || ! -x "$target" || -L "$target" ||
            "$(canonical_tool_path "$target")" != "$target" ||
            "$(canonical_tool_path "$link")" != "$target" ]]; then
            printf '[MANUAL] azd: 공식 스크립트 기본 경로와 다른 설치는 덮어쓰지 않습니다: %s\n' "$path"
            return 0
        fi
        before=$(azure_tool_version azd) && digest=$(azd_file_hash "$target") || {
            printf '%s\n' '[FAIL] azd: 기존 버전/해시 확인에 실패했습니다.' >&2; return 1;
        }
        if [[ -e "$record" ]]; then
            [[ -f "$record" ]] && mapfile -t saved < "$record" || {
                printf '%s\n' '[FAIL] azd: 관리 기록을 읽지 못했습니다.' >&2; return 1;
            }
            if [[ "${#saved[@]}" != 4 || "${saved[0]}" != official-script ||
                "${saved[1]}" != "$target" || "${saved[2]}" != "$before" || "${saved[3]}" != "$digest" ]]; then
                printf '%s\n' '[FAIL] azd: 설치 파일이 관리 기록과 다릅니다. 자동으로 변경하지 않습니다.' >&2; return 1
            fi
        else
            if ! confirm_install "azd $before ($path -> $target): 설치 출처는 미확인입니다. 이 설치를 Microsoft 공식 스크립트 방식으로 인계하고 업데이트하도록 승인하시겠습니까?"; then return 0; fi
        fi
    elif [[ -e "$link" || -L "$link" || -e "${target%/*}" || -L "${target%/*}" || -e "$record" ]]; then
        printf '%s\n' '[MANUAL] azd: 기존 설치 경로 또는 관리 기록이 남아 있습니다. 덮어쓰지 않습니다.'
        return 0
    fi
    if ! confirm_install "azd ${before:-미설치}: Microsoft 공식 스크립트로 설치/업데이트합니다. 네트워크와 sudo가 필요할 수 있습니다. 출처: https://aka.ms/install-azd.sh"; then return 0; fi
    live=$(tool_path azd)
    if [[ -z "$path" && -n "${WSL_DISTRO_NAME:-}" && "$live" =~ ^/mnt/[a-zA-Z]/ ]]; then live=''; fi
    if [[ "$live" != "$path" ]] || { [[ -n "$path" ]] &&
        { [[ "$(canonical_tool_path "$link")" != "$target" ]] ||
          [[ "$(azd_file_hash "$target")" != "$digest" ]]; }; }; then
        printf '%s\n' '[FAIL] azd: 승인 중 실행 경로/파일이 변경되었습니다.' >&2; return 1
    fi
    if [[ -z "$path" && ( -e "$link" || -L "$link" || -e "${target%/*}" || -L "${target%/*}" || -e "$record" ) ]]; then
        printf '%s\n' '[FAIL] azd: 승인 중 설치 경로/관리 기록이 생성되었습니다.' >&2; return 1
    fi
    if azd_package_owned "$link" "$target"; then
        printf '%s\n' '[FAIL] azd: 승인 중 패키지 소유권이 변경되었습니다.' >&2; return 1
    else
        owner_status=$?
        if (( owner_status != 1 )); then
            printf '%s\n' '[FAIL] azd: 패키지 소유권 재조회에 실패했습니다.' >&2; return 1
        fi
    fi
    if ! (umask 077; mkdir -p -- "$state") || ! temporary=$(mktemp "$state/.azd-script-install.XXXXXXXX"); then
        printf '%s\n' '[FAIL] azd: 관리 기록을 준비하지 못했습니다.' >&2; return 1
    fi
    trap 'rm -f -- "$temporary"' EXIT
    if ! run_remote_installer 'https://aka.ms/install-azd.sh' user; then
        printf '%s\n' '[FAIL] azd 공식 스크립트 설치/업데이트에 실패했습니다.' >&2; return 1
    fi
    hash -r
    if [[ "$(tool_path azd)" != "$link" || ! -L "$link" || ! -f "$target" || ! -x "$target" || -L "$target" ||
        "$(canonical_tool_path "$link")" != "$target" ]] ||
        ! after=$(azure_tool_version azd) || { [[ -n "$before" ]] && ! version_not_older "$after" "$before"; } ||
        ! digest=$(azd_file_hash "$target"); then
        printf '%s\n' '[FAIL] azd: 설치 후 경로/버전/해시 검증에 실패했습니다. 관리 기록을 갱신하지 않습니다.' >&2; return 1
    fi
    if ! printf 'official-script\n%s\n%s\n%s\n' "$target" "$after" "$digest" > "$temporary" ||
        ! mv -f -- "$temporary" "$record"; then
        printf '%s\n' '[FAIL] azd: 관리 기록 저장에 실패했습니다.' >&2; return 1
    fi
    printf '[PASS] azd: 공식 스크립트 설치/업데이트 확인 (%s -> %s).\n' "${before:-미설치}" "$after"
)

update_azure_tool() {
    local os="$1" tool="$2" path="$3" package prefix managed='' before after candidate installed
    case "$tool" in az) package=azure-cli ;; azd) package=azd ;; esac
    if [[ "$os" == Darwin ]] && command -v brew >/dev/null 2>&1; then
        [[ "$tool" != azd ]] || package=azure/azd/azd
        if prefix=$(brew --prefix "$package") && brew list --versions "$package" >/dev/null 2>&1 &&
            [[ -x "$prefix/bin/$tool" ]] &&
            [[ "$(canonical_tool_path "$path")" == "$(canonical_tool_path "$prefix/bin/$tool")" ]]; then managed=brew; fi
    elif [[ "$os" == Linux ]] && command -v dpkg-query >/dev/null 2>&1 &&
        command -v apt-cache >/dev/null 2>&1 && command -v apt-get >/dev/null 2>&1 && command -v sudo >/dev/null 2>&1; then
        # 패키지 이름 외에 선택된 실행 파일의 소유자와 Microsoft 업데이트 원본도 확인한다.
        if [[ "$(dpkg-query -W -f='${Status}' "$package" 2>/dev/null)" == 'install ok installed' ]] &&
            { [[ "$(dpkg-query -S "$path" 2>/dev/null)" == "$package: $path" ]] ||
              [[ "$(dpkg-query -S "$(canonical_tool_path "$path")" 2>/dev/null)" == "$package: $(canonical_tool_path "$path")" ]]; }; then
            if candidate=$(microsoft_apt_candidate "$package"); then
                installed=$(dpkg-query -W -f='${Version}' "$package") || return 1
                if ! dpkg --compare-versions "$candidate" ge "$installed"; then
                    printf '[FAIL] %s: APT 후보가 현재 버전보다 낮습니다. 변경하지 않습니다.\n' "$tool" >&2; return 1
                fi
                managed=apt
            else
                case $? in
                    1) ;;
                    *) printf '[FAIL] %s: APT 업데이트 원본 조회에 실패했습니다.\n' "$tool" >&2; return 1 ;;
                esac
            fi
        fi
    fi
    if [[ -z "$managed" && "$os" == Linux && "$tool" == azd ]]; then
        install_linux_azd "$path"
        return $?
    fi
    if [[ -z "$managed" ]]; then
        printf '[MANUAL] %s: 실행 파일의 Homebrew/APT(Microsoft 저장소) 출처를 확인하지 못했습니다. 덮어쓰지 않습니다. docs/java/8-troubleshooting.md를 참고하세요.\n' "$tool"
        return 0
    fi
    if ! before=$(azure_tool_version "$tool"); then printf '[FAIL] %s 버전 실행 확인에 실패했습니다.\n' "$tool" >&2; return 1; fi
    if ! confirm_install "$tool $before: 확인된 $managed 패키지 $package와 필요한 의존성을 업데이트합니다. 네트워크와 관리자 권한이 필요할 수 있습니다. OS 전체 업그레이드는 하지 않습니다."; then return 0; fi
    if [[ "$managed" == brew ]]; then
        if ! brew upgrade "$package"; then printf '[FAIL] %s 업데이트에 실패했습니다.\n' "$tool" >&2; return 1; fi
    else
        if ! sudo apt-get update; then
            printf '[FAIL] %s 업데이트 목록 갱신에 실패했습니다.\n' "$tool" >&2; return 1
        fi
        # 갱신 후 후보의 출처/다운그레이드 여부를 다시 확인하고 그 버전만 요청한다.
        if ! candidate=$(microsoft_apt_candidate "$package") ||
            ! dpkg --compare-versions "$candidate" ge "$installed"; then
            printf '[FAIL] %s 갱신 후 안전한 Microsoft APT 후보를 확인하지 못했습니다.\n' "$tool" >&2; return 1
        fi
        if ! sudo apt-get install --only-upgrade --no-remove -y "$package=$candidate"; then
            printf '[FAIL] %s 업데이트에 실패했습니다.\n' "$tool" >&2; return 1
        fi
    fi
    hash -r
    if ! after=$(azure_tool_version "$tool") || ! version_not_older "$after" "$before"; then
        printf '[FAIL] %s 업데이트 후 버전/실행 확인에 실패했습니다.\n' "$tool" >&2; return 1
    fi
    printf '[PASS] %s: %s → %s (이미 최신이면 유지).\n' "$tool" "$before" "$after"
}

latest_temurin_identifier() {
    local major="$1"
    awk -F '|' -v major="$major" '
        function newer(a,b, av,bv,ab,bb,an,bn,i,n) {
            split(a,ab,/\+/); split(b,bb,/\+/)
            an=split(ab[1],av,/\./); bn=split(bb[1],bv,/\./); n=an>bn?an:bn
            for(i=1;i<=n;i++) { if(av[i]+0>bv[i]+0) return 1; if(av[i]+0<bv[i]+0) return 0 }
            an=split(ab[2],av,/\./); bn=split(bb[2],bv,/\./); n=an>bn?an:bn
            for(i=1;i<=n;i++) { if(av[i]+0>bv[i]+0) return 1; if(av[i]+0<bv[i]+0) return 0 }
            return 0
        }
        { id=$NF; gsub(/\033\[[0-9;]*m/,"",id); gsub(/^[ \t]+|[ \t\r]+$/,"",id)
          if(id ~ ("^" major "\\.[0-9]+(\\.[0-9]+)*(\\+[0-9]+(\\.[0-9]+)*)?-tem$")) {
              version=id; sub(/-tem$/,"",version)
              if(best=="" || newer(version,best)) { best=version; selected=id }
          }
        }
        END { if(selected!="") print selected }'
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

jdk_matches_identifier() {
    local candidate="$1" identifier="$2" major="${2%%.*}" expected actual runtime compiler
    jdk_matches_major "$candidate" "$major" || return 1
    expected="${identifier%-tem}"
    expected="${expected%%+*}"
    if [[ "$major" == 8 ]]; then
        expected="${expected#8.0.}"
        expected="1.8.0_${expected%%.*}"
    else
        while [[ "$expected" == *.0 ]]; do expected="${expected%.0}"; done
    fi
    runtime=$("$candidate/bin/java" -version 2>&1) || return 1
    compiler=$("$candidate/bin/javac" -version 2>&1) || return 1
    [[ "$runtime" =~ version[[:space:]]+\"([^\"]+)\" ]] || return 1
    actual="${BASH_REMATCH[1]}"
    actual="${actual%%+*}"
    if [[ "$major" != 8 ]]; then while [[ "$actual" == *.0 ]]; do actual="${actual%.0}"; done; fi
    [[ "$actual" == "$expected" ]] || return 1
    [[ "$compiler" =~ javac[[:space:]]+([^[:space:]]+) ]] || return 1
    actual="${BASH_REMATCH[1]}"
    actual="${actual%%+*}"
    if [[ "$major" != 8 ]]; then while [[ "$actual" == *.0 ]]; do actual="${actual%.0}"; done; fi
    [[ "$actual" == "$expected" ]]
}

install_java_sdks() (
    export SDKMAN_DIR="$1"
    local update="${2:-0}" major candidate identifier listing failed=0 found USE
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
        if (( found && ! update )); then printf '[INFO] JDK %s: 기존 SDKMAN 설치를 사용합니다 (%s).\n' "$major" "${candidate##*/}"; continue; fi
        if (( ! update )) && ! confirm_install "JDK $major: SDKMAN 목록에서 이 환경에 제공되는 정식 Temurin JDK를 선택해 설치합니다. 네트워크와 디스크 공간이 필요합니다. 기존 기본 JDK는 유지합니다."; then continue; fi
        if ! listing=$(PAGER=cat sdk list java); then
            printf '[FAIL] JDK %s 설치 목록을 조회하지 못했습니다.\n' "$major" >&2; failed=1; continue
        fi
        if (( update )); then
            identifier=$(printf '%s\n' "$listing" | latest_temurin_identifier "$major")
        else
            identifier=$(printf '%s\n' "$listing" | awk -F '|' -v major="$major" '
            { id=$NF; gsub(/\033\[[0-9;]*m/, "", id); gsub(/^[ \t]+|[ \t\r]+$/, "", id)
              if (id ~ ("^" major "\\.[0-9]+(\\.[0-9]+)*(\\+[0-9]+(\\.[0-9]+)*)?-tem$")) { print id; exit } }')
        fi
        if [[ -z "$identifier" ]]; then
            printf '[FAIL] 이 환경의 SDKMAN 목록에 정식 Temurin JDK %s가 없습니다. sdk list java로 다른 배포판을 확인하세요.\n' "$major" >&2
            failed=1; continue
        fi
        if (( update )); then
            candidate="$SDKMAN_DIR/candidates/java/$identifier"
            if [[ -e "$candidate" || -L "$candidate" ]]; then
                if jdk_matches_identifier "$candidate" "$identifier"; then
                    printf '[INFO] JDK %s: 최신 %s가 이미 설치되어 있습니다.\n' "$major" "$identifier"
                else
                    printf '[FAIL] 기존 JDK %s 실행 확인에 실패했습니다. 덮어쓰지 않습니다.\n' "$identifier" >&2; failed=1
                fi
                continue
            fi
            if ! confirm_install "JDK $major: 최신 정식 Temurin $identifier를 추가 설치합니다. 네트워크와 디스크가 필요하며 기존 버전과 기본 JDK는 유지합니다."; then continue; fi
        fi
        USE=n
        if ! sdk install java "$identifier" <<< n || ! jdk_matches_major "$SDKMAN_DIR/candidates/java/$identifier" "$major"; then
            printf '[FAIL] JDK %s 설치 또는 실행 확인에 실패했습니다 (%s).\n' "$major" "$identifier" >&2; failed=1
        elif (( update )) && ! jdk_matches_identifier "$SDKMAN_DIR/candidates/java/$identifier" "$identifier"; then
            printf '[FAIL] JDK %s의 실제 버전이 요청한 %s와 다릅니다.\n' "$major" "$identifier" >&2; failed=1
        fi
    done
    printf '[INFO] 현재 터미널에서 SDKMAN을 사용하려면: source %q\n' "$SDKMAN_DIR/bin/sdkman-init.sh"
    return "$failed"
)

install_missing_tools() {
    local os="$1" update="${2:-0}" tool path sdk_dir="${SDKMAN_DIR:-$HOME/.sdkman}" failed=0
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
                    install_java_sdks "$sdk_dir" "$update" || failed=1
                fi
                continue
            fi
        else
            path=$(tool_path "$tool")
            if [[ -n "$path" && ! ( "$os" == Linux && -n "${WSL_DISTRO_NAME:-}" && "$path" =~ ^/mnt/[a-zA-Z]/ ) ]]; then
                if (( update )); then
                    case "$tool" in
                        node) update_node_with_nvm "$update" || failed=1 ;;
                        az|azd) update_azure_tool "$os" "$tool" "$path" || failed=1 ;;
                    esac
                    continue
                fi
                printf '[INFO] %s: PATH에서 발견했습니다 (%s). 설치하거나 업데이트하지 않습니다.\n' "$tool" "$path"
                continue
            fi
            if [[ -n "$path" ]]; then
                printf '[INFO] %s: Windows 드라이브의 실행 파일만 PATH에서 선택되었습니다 (%s). WSL에 별도로 설치할 수 있습니다.\n' "$tool" "$path"
            fi
        fi
        case "$os:$tool" in
            Linux:node|Darwin:node)
                install_node_with_nvm "$update" || failed=1 ;;
            Linux:az)
                if ! command -v apt-get >/dev/null 2>&1 || ! command -v sudo >/dev/null 2>&1; then
                    printf '%s\n' '[WARN] Azure CLI 자동 설치에는 apt-get과 sudo가 필요합니다. docs/java/0-setup.md에서 수동 설치 방법을 확인하세요.'
                    continue
                fi
                if confirm_install 'Azure CLI: 현재 Linux 환경에 Microsoft 공식 설치 스크립트를 실행합니다. sudo와 네트워크가 필요하며 APT 저장소와 시스템 패키지가 변경됩니다. 출처: https://aka.ms/InstallAzureCLIDeb'; then
                    if ! run_remote_installer 'https://aka.ms/InstallAzureCLIDeb' sudo; then printf '%s\n' '[FAIL] Azure CLI 설치에 실패했습니다.' >&2; failed=1; fi
                fi ;;
            Linux:azd)
                install_linux_azd || failed=1 ;;
            Darwin:az|Darwin:azd)
                if ! command -v brew >/dev/null 2>&1; then
                    if (( update )); then
                        if ! ensure_homebrew; then failed=1; continue; fi
                    else
                        printf '[WARN] %s 자동 설치에는 Homebrew가 필요합니다. Homebrew는 자동 설치하지 않습니다.\n' "$tool"
                        continue
                    fi
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
                        install_java_sdks "$sdk_dir" "$update" || failed=1
                    fi
                fi ;;
        esac
    done
    return "$failed"
}

install_prerequisite_main() {
    local track='' requested='' engine os result=0 update=0
    while (( $# )); do
        case "$1" in
            --track|--container-engine)
                if (( $# < 2 )) || [[ -z "$2" || "$2" == --* ]]; then printf '[FAIL] %s 값이 필요합니다.\n' "$1" >&2; return 2; fi
                if [[ "$1" == --track ]]; then track="$2"; else requested="$2"; fi
                shift 2 ;;
            --update) update=1; shift ;;
            --help|-h) printf '%s\n' 'bash scripts/install-prerequisites.sh --track java [--container-engine docker|podman] [--update]'; return 0 ;;
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
    if (( update )); then
        printf '%s\n' '업데이트 모드: 도구별 출처 확인과 별도 동의 후 변경합니다. 기존 버전과 기본 런타임은 유지하며 Node.js 활성화는 별도 동의를 받습니다.'
    else
        printf '설치 대상: %s%s. 이미 PATH에 있는 도구는 변경하지 않습니다.\n' "$os" "${WSL_DISTRO_NAME:+ / WSL $WSL_DISTRO_NAME}"
    fi
    install_missing_tools "$os" "$update" || result=1
    hash -r
    printf '%s\n' '설치 후 사전 점검을 다시 실행합니다. 로그인, 확장과 수동 항목은 직접 확인하세요.'
    prerequisite_main --track java --container-engine "$engine" || result=1
    return "$result"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then install_prerequisite_main "$@"; exit $?; fi
