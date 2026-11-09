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

test_dir=$(mktemp -d "${TMPDIR:-/tmp}/workshop-sdkman-test.XXXXXXXX")
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
nvm() {
    printf 'nvm-call: %s\n' "$*" >&2
    case "$1" in
        version) printf 'N/A\n' ;;
        install) return "${MOCK_NVM_FAILURE:-0}" ;;
        use) node() { printf 'v22.1.0\n'; }; npm() { printf '10.0.0\n'; } ;;
    esac
}
FIXTURE
nvm_output=$(
    NVM_DIR="$test_dir/nvm"
    confirm_install() { printf 'approval: %s\n' "$1"; return 0; }
    install_node_with_nvm 2>&1
)
assert 'nvm installs Node 22' grep -q 'nvm-call: install 22' <<< "$nvm_output"
assert 'nvm activates Node 22' grep -q 'nvm-call: use 22' <<< "$nvm_output"
assert 'Node install requires approval' grep -q 'approval: Node.js 22' <<< "$nvm_output"
nvm_failure=$(
    NVM_DIR="$test_dir/nvm"
    MOCK_NVM_FAILURE=1
    confirm_install() { return 0; }
    if install_node_with_nvm 2>&1; then printf 'UNEXPECTED SUCCESS\n'; else printf 'EXPECTED FAILURE\n'; fi
)
assert 'nvm Node failure propagates' grep -q 'EXPECTED FAILURE' <<< "$nvm_failure"
nvm_declined=$(
    NVM_DIR="$test_dir/nvm"
    confirm_install() { return 1; }
    install_node_with_nvm 2>&1
)
if [[ "$nvm_declined" == *'nvm-call: install'* ]]; then exit 1; else PASSED=$((PASSED + 1)); fi
fresh_nvm=$(
    NVM_DIR="$test_dir/fresh-nvm"
    confirm_install() { printf 'approval: %s\n' "$1"; return 0; }
    run_remote_installer() {
        printf 'installer: %s %s\n' "$1" "$2"
        cp "$test_dir/nvm/nvm.sh" "$NVM_DIR/nvm.sh"
    }
    install_node_with_nvm 2>&1
)
assert 'nvm installed from pinned official source' grep -q 'installer: https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh user' <<< "$fresh_nvm"
assert 'nvm and Node separate approvals' grep -q 'approval: nvm:' <<< "$fresh_nvm"
assert 'fresh nvm installs Node' grep -q 'nvm-call: install 22' <<< "$fresh_nvm"

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
            version="$major.0.1"
            [[ "$major" != 8 ]] || version=1.8.0_472
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
printf 'PASS: %s installation Bash assertions\n' "$PASSED"
