#!/usr/bin/env bash
set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$ROOT/scripts/install-prerequisites.sh"
PASSED=0

assert() {
    local name="$1"; shift
    if ! "$@"; then printf 'FAILED: %s\n' "$name" >&2; exit 1; fi
    PASSED=$((PASSED + 1))
}

bash -n "$ROOT/scripts/install-prerequisites.sh"
noninteractive=$(
    uname() { printf '%s\n' Darwin; }
    install_missing_tools() { printf '%s\n' 'UNEXPECTED INSTALL'; }
    export CI=1
    install_prerequisite_main --track java 2>&1 || true
)
assert 'noninteractive rejected' grep -q '비대화형 환경에서는 설치하지 않습니다' <<< "$noninteractive"
if [[ "$noninteractive" == *'UNEXPECTED INSTALL'* ]]; then exit 1; else PASSED=$((PASSED + 1)); fi

skip_output=$(
    SDKMAN_DIR='/nonexistent-workshop-sdkman-test'
    tool_path() { printf '/usr/bin/%s\n' "$1"; }
    confirm_install() { printf '%s\n' 'declined'; return 1; }
    install_missing_tools Darwin
)
assert 'existing node not installed' grep -q 'node.*PATH에서 발견' <<< "$skip_output"
assert 'SDKMAN consent requested' grep -q 'declined' <<< "$skip_output"

linux_output=$(
    SDKMAN_DIR='/nonexistent-workshop-sdkman-test'
    WSL_DISTRO_NAME=Ubuntu
    tool_path() { case "$1" in node) printf '%s\n' '/mnt/c/node.exe' ;; az) printf '%s\n' '/usr/bin/az' ;; esac; }
    apt-get() { :; }
    sudo() { printf 'sudo-call: %s\n' "$*"; }
    run_remote_installer() { printf 'installer: %s %s\n' "$1" "$2"; }
    install_node_with_nvm() { printf 'nvm-node-install\n'; }
    confirm_install() { return 1; }
    install_missing_tools Linux
)
assert 'WSL Windows binary distinguished' grep -q 'Windows 드라이브' <<< "$linux_output"
assert 'WSL Node uses nvm' grep -q 'nvm-node-install' <<< "$linux_output"
if [[ "$linux_output" == *'sudo-call:'* ]]; then exit 1; else PASSED=$((PASSED + 1)); fi
if [[ "$linux_output" == *'installer: https://aka.ms/'* ]]; then exit 1; else PASSED=$((PASSED + 1)); fi

failure_output=$(
    SDKMAN_DIR='/nonexistent-workshop-sdkman-test'
    tool_path() { if [[ "$1" != node ]]; then printf '/usr/bin/%s\n' "$1"; fi; }
    install_node_with_nvm() { return 1; }
    confirm_install() { return 1; }
    if install_missing_tools Darwin; then printf '%s\n' 'UNEXPECTED SUCCESS'; else printf '%s\n' 'EXPECTED FAILURE'; fi
)
assert 'failed installer propagates' grep -q 'EXPECTED FAILURE' <<< "$failure_output"

dependency_output=$(
    installed=0
    sdkman_missing_dependencies() { if (( installed == 0 )); then printf 'zip\nunzip\n'; fi; }
    apt-get() { :; }
    sudo() { printf 'sudo-call: %s\n' "$*"; if [[ "$*" == 'apt-get install -y zip unzip' ]]; then installed=1; fi; }
    confirm_install() { printf 'approval: %s\n' "$1"; return 0; }
    prepare_sdkman_dependencies Linux
)
assert 'missing SDKMAN dependencies shown' grep -q 'zip, unzip' <<< "$dependency_output"
assert 'dependencies require approval' grep -q 'approval: SDKMAN 선행 패키지' <<< "$dependency_output"
assert 'APT metadata updated' grep -q 'sudo-call: apt-get update' <<< "$dependency_output"
assert 'only missing packages installed' grep -q 'sudo-call: apt-get install -y zip unzip' <<< "$dependency_output"

declined_output=$(
    sdkman_missing_dependencies() { printf 'zip\nunzip\n'; }
    apt-get() { :; }
    sudo() { printf 'UNEXPECTED SUDO\n'; }
    confirm_install() { return 1; }
    if prepare_sdkman_dependencies Linux; then printf 'UNEXPECTED SUCCESS\n'; else printf 'EXPECTED FAILURE\n'; fi
)
assert 'declined dependency installation fails' grep -q 'EXPECTED FAILURE' <<< "$declined_output"
if [[ "$declined_output" == *'UNEXPECTED SUDO'* ]]; then exit 1; else PASSED=$((PASSED + 1)); fi

sdkman_output=$(
    SDKMAN_DIR='/nonexistent-workshop-sdkman-test'
    tool_path() { printf '/usr/bin/%s\n' "$1"; }
    confirm_install() { return 0; }
    prepare_sdkman_dependencies() { return 1; }
    run_remote_installer() { printf 'UNEXPECTED INSTALL\n'; }
    if install_missing_tools Linux; then printf 'UNEXPECTED SUCCESS\n'; else printf 'EXPECTED FAILURE\n'; fi
)
assert 'missing dependencies propagate failure' grep -q 'EXPECTED FAILURE' <<< "$sdkman_output"
if [[ "$sdkman_output" == *'UNEXPECTED INSTALL'* ]]; then exit 1; else PASSED=$((PASSED + 1)); fi

empty_install_output=$(
    SDKMAN_DIR='/nonexistent-workshop-sdkman-test'
    tool_path() { printf '/usr/bin/%s\n' "$1"; }
    confirm_install() { return 0; }
    prepare_sdkman_dependencies() { return 0; }
    run_remote_installer() { return 0; }
    if install_missing_tools Linux; then printf 'UNEXPECTED SUCCESS\n'; else printf 'EXPECTED FAILURE\n'; fi
)
assert 'installer success without SDKMAN fails' grep -q 'EXPECTED FAILURE' <<< "$empty_install_output"

apt_failure_output=$(
    sdkman_missing_dependencies() { printf 'zip\nunzip\n'; }
    apt-get() { :; }
    sudo() { printf 'sudo-call: %s\n' "$*"; return 1; }
    confirm_install() { return 0; }
    if prepare_sdkman_dependencies Linux; then printf 'UNEXPECTED SUCCESS\n'; else printf 'EXPECTED FAILURE\n'; fi
)
assert 'APT failure propagates' grep -q 'EXPECTED FAILURE' <<< "$apt_failure_output"
if [[ "$apt_failure_output" == *'sudo-call: apt-get install'* ]]; then exit 1; else PASSED=$((PASSED + 1)); fi

manual_output=$(
    sdkman_missing_dependencies() { printf 'zip\n'; }
    if prepare_sdkman_dependencies Darwin 2>&1; then printf 'UNEXPECTED SUCCESS\n'; else printf 'EXPECTED FAILURE\n'; fi
)
assert 'non-APT environment requires manual action' grep -q '직접 설치' <<< "$manual_output"
assert 'missing manual dependency fails' grep -q 'EXPECTED FAILURE' <<< "$manual_output"

mkdir -p "$ROOT/.test-output"
test_dir=$(mktemp -d "$ROOT/.test-output/workshop-sdkman-test.XXXXXXXX")
trap 'rm -rf -- "$test_dir"' EXIT
mkdir -p "$test_dir/bin"
printf 'preserve\n' > "$test_dir/marker"
existing_output=$(
    SDKMAN_DIR="$test_dir"
    tool_path() { printf '/usr/bin/%s\n' "$1"; }
    run_remote_installer() { printf 'UNEXPECTED INSTALL\n'; }
    if install_missing_tools Linux; then printf 'UNEXPECTED SUCCESS\n'; else printf 'EXPECTED FAILURE\n'; fi
)
assert 'partial SDKMAN directory fails' grep -q 'EXPECTED FAILURE' <<< "$existing_output"
assert 'existing files preserved' grep -q '^preserve$' "$test_dir/marker"
if [[ "$existing_output" == *'UNEXPECTED INSTALL'* ]]; then exit 1; else PASSED=$((PASSED + 1)); fi

printf '%s\n' 'sdk() { [[ "$1" == version ]]; }' > "$test_dir/bin/sdkman-init.sh"
assert 'working SDKMAN verified' verify_sdkman_installation "$test_dir"
printf '%s\n' 'sdk() { return 1; }' > "$test_dir/bin/sdkman-init.sh"
if verify_sdkman_installation "$test_dir"; then printf 'FAILED: broken SDKMAN accepted\n' >&2; exit 1; else PASSED=$((PASSED + 1)); fi
broken_existing_output=$(
    SDKMAN_DIR="$test_dir"
    tool_path() { printf '/usr/bin/%s\n' "$1"; }
    run_remote_installer() { printf 'UNEXPECTED INSTALL\n'; }
    if install_missing_tools Linux 2>&1; then printf 'UNEXPECTED SUCCESS\n'; else printf 'EXPECTED FAILURE\n'; fi
)
assert 'existing broken SDKMAN fails' grep -q 'EXPECTED FAILURE' <<< "$broken_existing_output"
assert 'existing broken SDKMAN preserved' grep -q '^sdk() { return 1; }$' "$test_dir/bin/sdkman-init.sh"
if [[ "$broken_existing_output" == *'UNEXPECTED INSTALL'* ]]; then exit 1; else PASSED=$((PASSED + 1)); fi

mkdir -p "$test_dir/nvm"
cat > "$test_dir/nvm/nvm.sh" <<'FIXTURE'
nvm_ensure_default_set() { mkdir -p "$NVM_DIR/alias"; printf '%s\n' "$1" > "$NVM_DIR/alias/default"; }
nvm() {
    printf 'nvm-call: %s\n' "$*" >&2
    case "$1" in
        which) printf '%s/versions/node/%s/bin/node\n' "$NVM_DIR" "$(node --version)" ;;
        version) if [[ "${MOCK_REUSE:-0}" == 1 ]]; then printf '%s\n' "$2"; else printf 'N/A\n'; fi ;;
        version-remote) printf '%s\n' "${MOCK_REMOTE:-v$2.99.1}"; return "${MOCK_REMOTE_FAILURE:-0}" ;;
        install)
            [[ "$#" == 3 && "$2" == --no-use ]] || return 1
            [[ "${MOCK_NVM_FAILURE:-0}" == 0 && "${MOCK_UPDATE_FAILURE:-0}" == 0 ]] || return 1
            local folder="$NVM_DIR/versions/node/$3/bin"
            mkdir -p "$folder"
            printf '#!/usr/bin/env bash\nprintf "%%s\\n" %q\n' "${MOCK_INSTALLED_VERSION:-$3}" > "$folder/node"
            printf '#!/usr/bin/env bash\nexit %s\n' "${MOCK_NPM_FAILURE:-0}" > "$folder/npm"
            chmod +x "$folder/node" "$folder/npm"
            nvm_ensure_default_set "$3"
            ;;
        use)
            [[ "${MOCK_NVM_USE_FAILURE:-0}" == 0 ]] || return 1
            MOCK_ACTIVE_VERSION="$2"
            node() { printf '%s\n' "${MOCK_NODE_AFTER:-$MOCK_ACTIVE_VERSION}"; }
            npm() { return "${MOCK_NPM_FAILURE:-0}"; }
            ;;
    esac
}
FIXTURE
nvm_output=$(
    NVM_DIR="$test_dir/nvm"
    tool_path() { if [[ -n "${MOCK_ACTIVE_VERSION:-}" ]]; then printf '%s/versions/node/%s/bin/node\n' "$NVM_DIR" "$MOCK_ACTIVE_VERSION"; fi; }
    confirm_install() { printf 'approval: %s\n' "$1"; return 0; }
    install_node_with_nvm 2>&1
)
assert 'nvm installs Node 22 without activating it' grep -q 'nvm-call: install --no-use v22.99.1' <<< "$nvm_output"
assert 'nvm activates Node 22' grep -q 'nvm-call: use v22.99.1' <<< "$nvm_output"
assert 'Node install requires approval' grep -q 'approval: Node.js 22' <<< "$nvm_output"
assert 'Node activation requires separate approval' grep -q 'approval: Node.js v22.99.1 활성화' <<< "$nvm_output"
assert 'fresh install does not create default alias' test ! -e "$test_dir/nvm/alias/default"
nvm_failure=$(
    NVM_DIR="$test_dir/nvm"
    tool_path() { :; }
    MOCK_NVM_FAILURE=1
    confirm_install() { return 0; }
    if install_node_with_nvm 2>&1; then printf 'UNEXPECTED SUCCESS\n'; else printf 'EXPECTED FAILURE\n'; fi
)
assert 'nvm Node failure propagates' grep -q 'EXPECTED FAILURE' <<< "$nvm_failure"
nvm_declined=$(
    NVM_DIR="$test_dir/nvm"
    tool_path() { :; }
    confirm_install() { return 1; }
    if install_node_with_nvm 2>&1; then printf 'UNEXPECTED SUCCESS\n'; else printf 'EXPECTED FAILURE\n'; fi
)
if [[ "$nvm_declined" == *'nvm-call: install'* ]]; then exit 1; else PASSED=$((PASSED + 1)); fi
fresh_activation_declined=$(
    NVM_DIR="$test_dir/nvm"
    tool_path() { :; }
    confirm_install() { [[ "$1" != *' 활성화:'* ]]; }
    if install_node_with_nvm 2>&1; then printf 'UNEXPECTED SUCCESS\n'; else printf 'EXPECTED FAILURE\n'; fi
)
assert 'fresh activation decline leaves no usable Node and fails' grep -q 'EXPECTED FAILURE' <<< "$fresh_activation_declined"
assert 'fresh activation decline never selects new Node' test "${fresh_activation_declined#*nvm-call: use}" = "$fresh_activation_declined"
assert 'fresh activation decline leaves default unset' test ! -e "$test_dir/nvm/alias/default"
fresh_nvm=$(
    NVM_DIR="$test_dir/fresh-nvm"
    tool_path() { if [[ -n "${MOCK_ACTIVE_VERSION:-}" ]]; then printf '%s/versions/node/%s/bin/node\n' "$NVM_DIR" "$MOCK_ACTIVE_VERSION"; fi; }
    confirm_install() { printf 'approval: %s\n' "$1"; return 0; }
    run_remote_installer() {
        printf 'installer: %s %s\n' "$1" "$2"
        cp "$test_dir/nvm/nvm.sh" "$NVM_DIR/nvm.sh"
    }
    install_node_with_nvm 2>&1
)
assert 'nvm installed from pinned official source' grep -q 'installer: https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh user' <<< "$fresh_nvm"
assert 'nvm and Node separate approvals' grep -q 'approval: nvm:' <<< "$fresh_nvm"
assert 'fresh nvm installs Node' grep -q 'nvm-call: install --no-use v22.99.1' <<< "$fresh_nvm"

cat > "$test_dir/bin/sdkman-init.sh" <<'FIXTURE'
sdk() {
    case "$1" in
        list)
            [[ "${MOCK_LIST_FAILURE:-0}" == 0 ]] || return 1
            [[ "${MOCK_NO_CANDIDATE:-0}" == 0 ]] || return 0
            if [[ "${MOCK_BUILD_IDENTIFIERS:-0}" == 1 ]]; then
                printf ' Vendor | Use | Version | Identifier\n'
                printf ' Temurin | | 25.0.6-ea | 25.0.6-ea-tem\n'
                printf ' | | 25.0.5.0+8 | \033[32m25.0.5.0+8-tem\033[0m\n'
                printf ' | | 21.0.13.0+9 | 21.0.13.0+9-tem\n'
                printf ' | | 8.0.512.0+9 | 8.0.512.0+9-tem\n'
            else
                printf 'Temurin | 25.0.1 | tem | | 25.0.1-tem\n | 21.0.9 | tem | | 21.0.9-tem\n | 8.0.472 | tem | | 8.0.472-tem\n'
            fi
            ;;
        install)
            [[ "$USE" == n && "$sdkman_auto_answer" == false ]] || return 1
            printf 'sdk-install: %s\n' "$3"
            [[ "${MOCK_JDK_FAILURE:-0}" == 0 ]] || return 1
            local folder="$SDKMAN_DIR/candidates/java/$3" major="${3%%.*}" version
            version="${3%-tem}"
            version="${version%%+*}"
            if [[ "$major" == 8 ]]; then
                version="${version#8.0.}"
                version="1.8.0_${version%%.*}"
            fi
            version="${MOCK_JDK_ACTUAL:-$version}"
            mkdir -p "$folder/bin"
            printf '#!/usr/bin/env bash\nprintf "%%s\\n" %q\n' "openjdk version \"$version\"" > "$folder/bin/java"
            printf '#!/usr/bin/env bash\nprintf "%%s\\n" %q\n' "javac $version" > "$folder/bin/javac"
            chmod +x "$folder/bin/java" "$folder/bin/javac"
            ;;
    esac
}
FIXTURE
java_output=$(
    confirm_install() { printf 'approval: %s\n' "$1"; return 0; }
    install_java_sdks "$test_dir"
)
for major in 8 21 25; do
    assert "JDK $major installed" grep -q "sdk-install: $major\\." <<< "$java_output"
    assert "JDK $major approval" grep -q "approval: JDK $major:" <<< "$java_output"
done
java_skip=$(
    confirm_install() { printf 'UNEXPECTED APPROVAL\n'; return 1; }
    install_java_sdks "$test_dir"
)
if [[ "$java_skip" == *'UNEXPECTED APPROVAL'* ]]; then exit 1; else PASSED=$((PASSED + 1)); fi
mkdir -p "$test_dir/empty/bin"
cp "$test_dir/bin/sdkman-init.sh" "$test_dir/empty/bin/sdkman-init.sh"
java_failure=$(
    MOCK_JDK_FAILURE=1
    confirm_install() { return 0; }
    if install_java_sdks "$test_dir/empty" 2>&1; then printf 'UNEXPECTED SUCCESS\n'; else printf 'EXPECTED FAILURE\n'; fi
)
assert 'JDK install failure propagates' grep -q 'EXPECTED FAILURE' <<< "$java_failure"
java_decline=$(
    confirm_install() { return 1; }
    install_java_sdks "$test_dir/empty"
)
if [[ "$java_decline" == *'sdk-install:'* ]]; then exit 1; else PASSED=$((PASSED + 1)); fi
java_list_failure=$(
    MOCK_LIST_FAILURE=1
    confirm_install() { return 0; }
    if install_java_sdks "$test_dir/empty" 2>&1; then printf 'UNEXPECTED SUCCESS\n'; else printf 'EXPECTED FAILURE\n'; fi
)
assert 'SDKMAN list failure propagates' grep -q 'EXPECTED FAILURE' <<< "$java_list_failure"
java_unavailable=$(
    MOCK_NO_CANDIDATE=1
    confirm_install() { return 0; }
    if install_java_sdks "$test_dir/empty" 2>&1; then printf 'UNEXPECTED SUCCESS\n'; else printf 'EXPECTED FAILURE\n'; fi
)
assert 'unavailable JDK reported' grep -q '정식 Temurin JDK 8가 없습니다' <<< "$java_unavailable"
assert 'unavailable JDK fails' grep -q 'EXPECTED FAILURE' <<< "$java_unavailable"
if [[ "$java_unavailable" == *'sdk-install:'* ]]; then exit 1; else PASSED=$((PASSED + 1)); fi
java_build_output=$(
    MOCK_BUILD_IDENTIFIERS=1
    confirm_install() { return 0; }
    install_java_sdks "$test_dir/empty"
)
for identifier in 8.0.512.0+9-tem 21.0.13.0+9-tem 25.0.5.0+8-tem; do
    assert "build identifier $identifier installed" grep -Fxq "sdk-install: $identifier" <<< "$java_build_output"
done
if [[ "$java_build_output" == *'sdk-install: 25.0.6-ea-tem'* ]]; then exit 1; else PASSED=$((PASSED + 1)); fi

update_noninteractive=$(
    uname() { printf 'Darwin\n'; }
    install_missing_tools() { printf 'UNEXPECTED INSTALL\n'; }
    export CI=1
    if install_prerequisite_main --track java --update 2>&1; then exit 1; else printf 'EXPECTED FAILURE\n'; fi
)
assert 'update flag accepted but CI rejected' grep -q '비대화형 환경에서는 설치하지 않습니다' <<< "$update_noninteractive"
assert 'CI update returns nonzero' grep -q 'EXPECTED FAILURE' <<< "$update_noninteractive"
assert 'CI update never dispatches installer' test "${update_noninteractive#*UNEXPECTED}" = "$update_noninteractive"
redirected_update=$(
    unset CI
    uname() { printf 'Darwin\n'; }
    install_missing_tools() { printf 'UNEXPECTED INSTALL\n'; }
    if install_prerequisite_main --track java --update </dev/null 2>&1; then exit 1; else printf 'EXPECTED FAILURE\n'; fi
)
assert 'redirected update rejected without CI' grep -q 'EXPECTED FAILURE' <<< "$redirected_update"
assert 'redirected update never dispatches' test "${redirected_update#*UNEXPECTED}" = "$redirected_update"

mkdir -p "$test_dir/update-nvm/versions/node/v22.1.0/bin" "$test_dir/update-nvm/alias"
printf 'v22.1.0\n' > "$test_dir/update-nvm/alias/default"
printf '#!/usr/bin/env bash\nprintf "v22.1.0\\n"\n' > "$test_dir/update-nvm/versions/node/v22.1.0/bin/node"
chmod +x "$test_dir/update-nvm/versions/node/v22.1.0/bin/node"
cp "$test_dir/nvm/nvm.sh" "$test_dir/update-nvm/nvm.sh"
node_update_case() (
    NVM_DIR="$test_dir/update-nvm"
    WSL_DISTRO_NAME=''
    local before="${MOCK_NODE_BEFORE:-v22.1.0}"
    mkdir -p "$NVM_DIR/versions/node/$before/bin"
    printf '#!/usr/bin/env bash\nprintf "%%s\\n" %q\n' "$before" > "$NVM_DIR/versions/node/$before/bin/node"
    chmod +x "$NVM_DIR/versions/node/$before/bin/node"
    tool_path() { printf '%s/versions/node/%s/bin/node\n' "$NVM_DIR" "${MOCK_ACTIVE_VERSION:-$before}"; }
    node() { printf '%s\n' "$before"; }
    npm() { return 0; }
    confirm_install() {
        printf 'approval: %s\n' "$1"
        if [[ "$1" == *' 활성화:'* ]]; then
            if [[ -n "${MOCK_CONCURRENT:-}" ]]; then before="$MOCK_CONCURRENT"; fi
            [[ "${MOCK_ACTIVATE:-1}" == 1 ]]
        else [[ "${MOCK_APPROVED:-1}" == 1 ]]; fi
    }
    if update_node_with_nvm "${MOCK_UPDATE:-1}"; then printf 'SUCCESS\n'; else printf 'EXPECTED FAILURE\n'; fi
    printf 'active-node: %s\n' "$(node --version)"
)
node_updated=$(node_update_case 2>&1)
assert 'Node exact latest installed without activation' grep -q 'nvm-call: install --no-use v22.99.1' <<< "$node_updated"
assert 'approved activation available to following script work' grep -q 'active-node: v22.99.1' <<< "$node_updated"
assert 'Node default alias preserved' grep -Fxq v22.1.0 "$test_dir/update-nvm/alias/default"
rm -- "$test_dir/update-nvm/alias/default"
node_no_default=$(node_update_case 2>&1)
assert 'Node update succeeds without a default alias' grep -q '^SUCCESS$' <<< "$node_no_default"
assert 'unset Node default remains unset' test ! -e "$test_dir/update-nvm/alias/default"
printf 'v22.1.0\n' > "$test_dir/update-nvm/alias/default"
assert 'old Node remains installed' test -x "$test_dir/update-nvm/versions/node/v22.1.0/bin/node"
assert 'Node separately approved' grep -q 'approval: Node.js 22' <<< "$node_updated"
for major in 24 25; do
    newer_node=$(MOCK_NODE_BEFORE="v$major.1.0" node_update_case 2>&1)
    assert "Node $major latest major queried" grep -q "nvm-call: version-remote $major" <<< "$newer_node"
    assert "Node $major updated without downgrade" grep -q "nvm-call: install --no-use v$major.99.1" <<< "$newer_node"
    assert "Node $major separately activated" grep -q "nvm-call: use v$major.99.1" <<< "$newer_node"
done
node_decline=$(MOCK_APPROVED=0 node_update_case 2>&1)
assert 'Node decline does not install' test "${node_decline#*nvm-call: install}" = "$node_decline"
assert 'Node decline does not activate another version' test "${node_decline#*nvm-call: use}" = "$node_decline"
activation_decline=$(MOCK_ACTIVATE=0 node_update_case 2>&1)
assert 'activation decline still installs Node' grep -q 'nvm-call: install --no-use' <<< "$activation_decline"
assert 'activation decline never uses new Node' test "${activation_decline#*nvm-call: use}" = "$activation_decline"
assert 'activation decline preserves default alias' grep -Fxq v22.1.0 "$test_dir/update-nvm/alias/default"
assert 'activation decline preserves supported status' grep -q '^SUCCESS$' <<< "$activation_decline"
assert 'activation decline preserves active Node' grep -q 'active-node: v22.1.0' <<< "$activation_decline"
node_concurrent=$(MOCK_CONCURRENT=v24.1.0 node_update_case 2>&1)
assert 'concurrent selection change fails before activation' grep -q 'EXPECTED FAILURE' <<< "$node_concurrent"
assert 'concurrent Node never overwritten' test "${node_concurrent#*nvm-call: use}" = "$node_concurrent"
node_latest=$(MOCK_NODE_BEFORE=v22.99.1 node_update_case 2>&1)
assert 'latest Node skipped' grep -q '이미 최신' <<< "$node_latest"
assert 'latest Node not reinstalled' test "${node_latest#*nvm-call: install}" = "$node_latest"
node_no_update=$(MOCK_UPDATE=0 node_update_case 2>&1)
assert 'no update preserves existing Node without prompts' test "${node_no_update#*approval:}" = "$node_no_update"
node_ahead=$(MOCK_REMOTE=v22.0.0 node_update_case 2>&1)
assert 'older remote release never downgrades Node' test "${node_ahead#*nvm-call: install}" = "$node_ahead"
node_old=$(MOCK_NODE_BEFORE=v20.1.0 node_update_case 2>&1)
assert 'unsupported major uses latest 22' grep -q 'nvm-call: install --no-use v22.99.1' <<< "$node_old"
node_old_decline=$(MOCK_NODE_BEFORE=v20.1.0 MOCK_ACTIVATE=0 node_update_case 2>&1)
assert 'unsupported Node without activation fails' grep -q 'EXPECTED FAILURE' <<< "$node_old_decline"
node_reuse=$(MOCK_REUSE=1 node_update_case 2>&1)
assert 'existing inactive release reused without reinstall' test "${node_reuse#*nvm-call: install}" = "$node_reuse"
assert 'existing inactive release still needs activation' grep -q 'approval: Node.js v22.99.1 활성화' <<< "$node_reuse"
for setting in MOCK_REMOTE_FAILURE=1 MOCK_REMOTE=v23.0.0 MOCK_REMOTE=v22.9.0-rc.1 MOCK_NODE_BEFORE=invalid MOCK_UPDATE_FAILURE=1 MOCK_INSTALLED_VERSION=v22.0.0 MOCK_NVM_USE_FAILURE=1 MOCK_NODE_AFTER=v22.1.0 MOCK_NPM_FAILURE=1; do
    node_failed=$(export "$setting"; node_update_case 2>&1)
    assert "Node error propagates: $setting" grep -q 'EXPECTED FAILURE' <<< "$node_failed"
done
unknown_node=$(
    NVM_DIR="$test_dir/update-nvm"
    WSL_DISTRO_NAME=''
    node() { printf 'v22.1.0\n'; }
    tool_path() { printf '%s/bin/sdkman-init.sh\n' "$test_dir"; }
    confirm_install() { return 0; }
    if update_node_with_nvm 2>&1; then printf 'UNEXPECTED SUCCESS\n'; else printf 'EXPECTED FAILURE\n'; fi
)
assert 'foreign Node not overwritten even with nvm installed' grep -q MANUAL <<< "$unknown_node"
assert 'foreign Node never installed' test "${unknown_node#*nvm-call: install}" = "$unknown_node"
missing_path_update=$(
    NVM_DIR="$test_dir/nvm"
    tool_path() { :; }
    confirm_install() { return 0; }
    update_node_with_nvm() { printf 'node-setup-update=%s\n' "$1"; }
    install_node_with_nvm 1
)
assert 'update also handles nvm Node absent from initial PATH' grep -q 'node-setup-update=1' <<< "$missing_path_update"

unordered=$'vendor | 21.0.9+99-tem\n | 21.0.10+2-tem\n | 21.0.10+11-tem\n | 21.0.11-ea-tem\n | 21.0.10+3-tem\n | 21.0.99-zulu'
assert 'latest JDK ordering uses version and numeric build, excludes EA/vendor' test "$(latest_temurin_identifier 21 <<< "$unordered")" = 21.0.10+11-tem
assert 'JDK extra numeric components retained' test "$(latest_temurin_identifier 25 <<< $' | 25.0.1+99-tem\n | 25.0.1.1+2-tem\n | 25.0.1.1+10-tem')" = 25.0.1.1+10-tem
assert 'Java 8 update sorted numerically' test "$(latest_temurin_identifier 8 <<< $' | 8.0.99-tem\n | 8.0.512+9-tem\n | 8.0.512+10-tem\n | 8.0.513-ea-tem')" = 8.0.512+10-tem
ln -s 21.0.9-tem "$test_dir/candidates/java/current"
default_java=$(readlink "$test_dir/candidates/java/current")
java_updated=$(
    MOCK_BUILD_IDENTIFIERS=1
    confirm_install() { printf 'approval: %s\n' "$1"; return 0; }
    install_java_sdks "$test_dir" 1
)
for major in 8 21 25; do
    assert "JDK $major update separately approved" grep -q "approval: JDK $major:" <<< "$java_updated"
    assert "JDK $major previous version retained" test -d "$test_dir/candidates/java/$([[ "$major" == 8 ]] && printf 8.0.472-tem || { [[ "$major" == 21 ]] && printf 21.0.9-tem || printf 25.0.1-tem; })"
done
assert 'default JDK link preserved' test "$(readlink "$test_dir/candidates/java/current")" = "$default_java"
assert 'wrong JDK patch rejected' test "$(jdk_matches_identifier "$test_dir/candidates/java/21.0.9-tem" 21.0.13-tem && printf accepted || printf rejected)" = rejected
java_latest=$(
    MOCK_BUILD_IDENTIFIERS=1
    confirm_install() { printf 'UNEXPECTED APPROVAL\n'; return 1; }
    install_java_sdks "$test_dir" 1
)
assert 'latest JDKs not reinstalled' test "${java_latest#*sdk-install:}" = "$java_latest"
assert 'latest JDKs not prompted' test "${java_latest#*UNEXPECTED}" = "$java_latest"
broken_latest="$test_dir/candidates/java/21.0.13.0+9-tem/bin/javac"
cp "$broken_latest" "$test_dir/saved-javac"
printf '#!/usr/bin/env bash\nexit 1\n' > "$broken_latest"
java_broken_latest=$(
    MOCK_BUILD_IDENTIFIERS=1
    confirm_install() { return 0; }
    if install_java_sdks "$test_dir" 1 2>&1; then printf 'UNEXPECTED SUCCESS\n'; else printf 'EXPECTED FAILURE\n'; fi
)
assert 'broken latest JDK fails execution validation' grep -q 'EXPECTED FAILURE' <<< "$java_broken_latest"
assert 'broken latest JDK is not overwritten' test "${java_broken_latest#*sdk-install:}" = "$java_broken_latest"
cp "$test_dir/saved-javac" "$broken_latest"
mkdir -p "$test_dir/update-empty/bin"
cp "$test_dir/bin/sdkman-init.sh" "$test_dir/update-empty/bin/sdkman-init.sh"
java_update_declined=$(confirm_install() { return 1; }; install_java_sdks "$test_dir/update-empty" 1)
assert 'JDK update decline does not install' test "${java_update_declined#*sdk-install:}" = "$java_update_declined"
for setting in MOCK_LIST_FAILURE=1 MOCK_NO_CANDIDATE=1 MOCK_JDK_FAILURE=1 MOCK_JDK_ACTUAL=21.0.1; do
    java_update_failed=$(
        export "$setting"
        confirm_install() { return 0; }
        if install_java_sdks "$test_dir/update-empty" 1 2>&1; then printf 'UNEXPECTED SUCCESS\n'; else printf 'EXPECTED FAILURE\n'; fi
    )
    assert "JDK update error propagates: $setting" grep -q 'EXPECTED FAILURE' <<< "$java_update_failed"
done
mkdir -p "$test_dir/brew/bin" "$test_dir/foreign/bin"
for tool in az azd; do
    printf '#!/usr/bin/env bash\nexit 0\n' > "$test_dir/brew/bin/$tool"
    cp "$test_dir/brew/bin/$tool" "$test_dir/foreign/bin/$tool"
    chmod +x "$test_dir/brew/bin/$tool" "$test_dir/foreign/bin/$tool"
done
azure_update_case() (
    local platform="$1" tool="$2" path="$3" changed=0
    brew() {
        case "$1" in
            --prefix) printf '%s/brew\n' "$test_dir" ;;
            list) return 0 ;;
            upgrade) printf 'brew-upgrade: %s\n' "$2"; changed=1; return "${MOCK_AZURE_FAILURE:-0}" ;;
        esac
    }
    dpkg-query() {
        case "$1:$2" in
            '-W:-f=${Status}') printf 'install ok installed\n' ;;
            '-W:-f=${Version}') printf '2.1.0-1\n' ;;
            -S:*) printf '%s: %s\n' "${MOCK_OWNER:-azure-cli}" "$2" ;;
        esac
    }
    dpkg() { [[ "${MOCK_APT_DOWNGRADE:-0}" == 0 ]]; }
    apt-cache() {
        [[ "${MOCK_APT_POLICY_FAILURE:-0}" == 0 ]] || return 1
        local origin="${MOCK_APT_ORIGIN:-packages.microsoft.com}"
        if (( changed )); then origin="${MOCK_APT_UPDATED_ORIGIN:-$origin}"; fi
        printf 'azure-cli:\n  Installed: 2.1.0-1\n  Candidate: 2.2.0-1\n  Version table:\n     2.2.0-1 500\n        500 https://%s/repos/azure-cli stable/main amd64 Packages\n *** 2.1.0-1 100\n        100 /var/lib/dpkg/status\n' "$origin"
    }
    apt-get() { printf 'UNEXPECTED DIRECT APT\n'; return 1; }
    sudo() { printf 'sudo-call: %s\n' "$*"; changed=1; return "${MOCK_AZURE_FAILURE:-0}"; }
    az() {
        [[ "${MOCK_VERSION_FAILURE:-0}" == 0 ]] || return 1
        if (( changed )); then printf '%s\n' "${MOCK_AZURE_AFTER:-2.2.0}"; else printf '2.1.0\n'; fi
    }
    azd() { printf 'azd version '; az; }
    confirm_install() { printf 'approval: %s\n' "$1"; [[ "${MOCK_APPROVED:-1}" == 1 ]]; }
    if update_azure_tool "$platform" "$tool" "$path"; then printf 'SUCCESS\n'; else printf 'EXPECTED FAILURE\n'; fi
)
for tool in az azd; do
    brew_update=$(azure_update_case Darwin "$tool" "$test_dir/brew/bin/$tool")
    assert "Homebrew $tool targeted update" grep -q 'brew-upgrade:' <<< "$brew_update"
    assert "Homebrew $tool runtime verified" grep -q '\[PASS\]' <<< "$brew_update"
    brew_declined=$(MOCK_APPROVED=0 azure_update_case Darwin "$tool" "$test_dir/brew/bin/$tool")
    assert "Homebrew $tool decline prevents mutation" test "${brew_declined#*brew-upgrade:}" = "$brew_declined"
    foreign_tool=$(azure_update_case Darwin "$tool" "$test_dir/foreign/bin/$tool")
    assert "foreign $tool path untouched" grep -q MANUAL <<< "$foreign_tool"
    assert "foreign $tool no package update" test "${foreign_tool#*brew-upgrade:}" = "$foreign_tool"
done
apt_azd=$(MOCK_OWNER=azd azure_update_case Linux azd "$test_dir/foreign/bin/azd")
assert 'APT azd targeted package updated' grep -q 'sudo-call: apt-get install --only-upgrade --no-remove -y azd=2.2.0-1' <<< "$apt_azd"
apt_updated=$(azure_update_case Linux az "$test_dir/foreign/bin/az")
assert 'APT only verified package/version requested without removals' grep -q 'sudo-call: apt-get install --only-upgrade --no-remove -y azure-cli=2.2.0-1' <<< "$apt_updated"
assert 'APT metadata refresh separately approved' grep -q 'approval: az 2.1.0' <<< "$apt_updated"
apt_unknown=$(MOCK_OWNER=other azure_update_case Linux az "$test_dir/foreign/bin/az")
assert 'APT foreign owner manual' grep -q MANUAL <<< "$apt_unknown"
assert 'APT foreign owner never updated' test "${apt_unknown#*sudo-call:}" = "$apt_unknown"
apt_untrusted=$(MOCK_APT_ORIGIN=example.invalid azure_update_case Linux az "$test_dir/foreign/bin/az")
assert 'APT untrusted origin manual' grep -q MANUAL <<< "$apt_untrusted"
assert 'APT untrusted origin untouched' test "${apt_untrusted#*sudo-call:}" = "$apt_untrusted"
apt_policy_failed=$(MOCK_APT_POLICY_FAILURE=1 azure_update_case Linux az "$test_dir/foreign/bin/az")
assert 'APT policy command failure is not manual success fallback' grep -q 'EXPECTED FAILURE' <<< "$apt_policy_failed"
assert 'APT policy failure never updates' test "${apt_policy_failed#*sudo-call:}" = "$apt_policy_failed"
apt_changed=$(MOCK_APT_UPDATED_ORIGIN=example.invalid azure_update_case Linux az "$test_dir/foreign/bin/az")
assert 'APT origin change after refresh fails' grep -q 'EXPECTED FAILURE' <<< "$apt_changed"
assert 'APT origin change prevents package install' test "${apt_changed#*sudo-call: apt-get install}" = "$apt_changed"
apt_refresh_failed=$(MOCK_AZURE_FAILURE=1 azure_update_case Linux az "$test_dir/foreign/bin/az")
assert 'APT refresh failure prevents package install' test "${apt_refresh_failed#*sudo-call: apt-get install}" = "$apt_refresh_failed"
apt_declined=$(MOCK_APPROVED=0 azure_update_case Linux az "$test_dir/foreign/bin/az")
assert 'APT declined update untouched' test "${apt_declined#*sudo-call:}" = "$apt_declined"
apt_downgrade=$(MOCK_APT_DOWNGRADE=1 azure_update_case Linux az "$test_dir/foreign/bin/az")
assert 'APT downgrade candidate fails before mutation' grep -q 'EXPECTED FAILURE' <<< "$apt_downgrade"
assert 'APT downgrade never invoked' test "${apt_downgrade#*sudo-call:}" = "$apt_downgrade"
for platform in Darwin Linux; do
    for setting in MOCK_AZURE_FAILURE=1 MOCK_VERSION_FAILURE=1 MOCK_AZURE_AFTER=1.0.0 MOCK_AZURE_AFTER=invalid; do
        azure_failed=$(export "$setting"; azure_update_case "$platform" az "$test_dir/brew/bin/az")
        assert "$platform Azure error propagates: $setting" grep -q 'EXPECTED FAILURE' <<< "$azure_failed"
    done
done

brew_setup_case() (
    local available=0
    command() {
        if [[ "$*" == '-v brew' ]]; then (( available )); else builtin command "$@"; fi
    }
    brew() { printf 'brew-call: %s\n' "$*"; return "${MOCK_BREW_VERSION_FAILURE:-0}"; }
    run_remote_installer() {
        printf 'installer: %s %s\n' "$1" "$2"
        [[ "${MOCK_BREW_INSTALL_FAILURE:-0}" == 0 ]] || return 1
        available=1
    }
    confirm_install() { printf 'approval: %s\n' "$1"; [[ "${MOCK_APPROVED:-1}" == 1 ]]; }
    if ensure_homebrew; then printf 'SUCCESS\n'; else printf 'EXPECTED FAILURE\n'; fi
)
brew_setup=$(brew_setup_case)
assert 'missing Homebrew has distinct consent' grep -q 'approval: Homebrew:' <<< "$brew_setup"
assert 'Homebrew official installer selected' grep -q 'installer: https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh user' <<< "$brew_setup"
assert 'Homebrew runtime verified' grep -q 'brew-call: --version' <<< "$brew_setup"
brew_setup_declined=$(MOCK_APPROVED=0 brew_setup_case)
assert 'Homebrew decline prevents installer' test "${brew_setup_declined#*installer:}" = "$brew_setup_declined"
for setting in MOCK_BREW_INSTALL_FAILURE=1 MOCK_BREW_VERSION_FAILURE=1; do
    brew_setup_failed=$(export "$setting"; brew_setup_case)
    assert "Homebrew error propagates: $setting" grep -q 'EXPECTED FAILURE' <<< "$brew_setup_failed"
done
mac_missing_brew_case() (
    local available=0
    SDKMAN_DIR="$test_dir/no-sdkman"
    command() {
        if [[ "$*" == '-v brew' ]]; then (( available )); else builtin command "$@"; fi
    }
    tool_path() { [[ "$1" == az ]] || printf '/fixture/%s\n' "$1"; }
    update_node_with_nvm() { :; }
    update_azure_tool() { :; }
    brew() { printf 'brew-call: %s\n' "$*"; }
    run_remote_installer() { printf 'installer: %s\n' "$1"; available=1; }
    confirm_install() {
        printf 'approval: %s\n' "$1"
        [[ "$1" != SDKMAN:* && "${MOCK_APPROVED:-1}" == 1 ]]
    }
    if install_missing_tools Darwin "$1"; then printf 'SUCCESS\n'; else printf 'EXPECTED FAILURE\n'; fi
)
mac_default=$(mac_missing_brew_case 0)
assert 'default does not install Homebrew' test "${mac_default#*installer:}" = "$mac_default"
assert 'default does not offer Homebrew' test "${mac_default#*approval: Homebrew:}" = "$mac_default"
mac_update=$(mac_missing_brew_case 1)
assert 'update offers missing Homebrew separately' grep -q 'approval: Homebrew:' <<< "$mac_update"
assert 'update offers Azure CLI separately after Homebrew' grep -q 'approval: az:' <<< "$mac_update"
assert 'update installs only requested Homebrew package' grep -q 'brew-call: install azure-cli' <<< "$mac_update"
mac_decline=$(MOCK_APPROVED=0 mac_missing_brew_case 1)
assert 'declined missing Homebrew causes no installs' test "${mac_decline#*installer:}" = "$mac_decline"
assert 'declined missing Homebrew prevents package install' test "${mac_decline#*brew-call: install}" = "$mac_decline"
printf 'PASS: %s installation Bash assertions\n' "$PASSED"
