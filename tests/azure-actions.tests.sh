#!/usr/bin/env bash
set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$ROOT/scripts/check-prerequisites.sh"
CHECK_FAILURES=0
calls=''
logged_in=0
can_prompt_azure() { return 0; }
confirm_azure_action() { [[ "${approved:-0}" == 1 ]]; }
probe() {
    PROBE_CODE=0; PROBE_TEXT=''
    case "$*" in
        'az account show --query state --output tsv')
            if (( logged_in )); then PROBE_TEXT=Enabled; else PROBE_CODE=1; PROBE_TEXT='fixture auth error'; fi ;;
        'az account list --query [].[id,name] --output tsv') PROBE_TEXT=$'id-one\tFirst\nid-two\tSecond' ;;
        'az extension show --name containerapp --query version --output tsv') PROBE_CODE=1 ;;
        'azd auth login --check-status') PROBE_CODE=1 ;;
        *) printf 'Unexpected probe: %s\n' "$*" >&2; exit 1 ;;
    esac
}
az() { calls+="$*;"; logged_in=1; return "${action_failure:-0}"; }
azd() { calls+="azd $*;"; return "${action_failure:-0}"; }
approved=0
prepare_azure_account
prepare_containerapp_extension
prepare_azd_login
[[ -z "$calls" ]]
approved=1
prepare_azure_account <<< id-two
[[ "$calls" == 'login;account set --subscription id-two;' ]]
calls=''
prepare_azure_account <<< invalid
[[ -z "$calls" ]]
prepare_containerapp_extension
prepare_azd_login
[[ "$calls" == 'extension add --name containerapp --upgrade;azd auth login;' ]]
calls=''
action_failure=1
logged_in=0
prepare_azure_account <<< id-one
[[ "$calls" == 'login;' ]]
calls=''
can_prompt_azure() { return 1; }
prepare_azure_account
prepare_containerapp_extension
prepare_azd_login
[[ -z "$calls" ]]
source "$ROOT/scripts/check-prerequisites.sh"
can_prompt_azure() { return 0; }
approved=1
confirm_azure_action() { [[ "$approved" == 1 ]]; }
registered=0
query_failure=0
calls=''
probe() {
    PROBE_CODE="$query_failure"
    if (( registered )); then PROBE_TEXT=Registered; else PROBE_TEXT=NotRegistered; fi
}
az() { calls+="$*;"; registered=1; }
check_azure_provider Microsoft.App
[[ "$calls" == 'provider register --namespace Microsoft.App --wait;' ]]
[[ "$CHECK_FAILURES" == 0 ]]
calls=''
check_azure_provider Microsoft.App
[[ -z "$calls" ]]
registered=0
query_failure=1
before="$CHECK_FAILURES"
check_azure_provider Microsoft.App
[[ -z "$calls" && "$CHECK_FAILURES" == "$((before + 1))" ]]
query_failure=0
confirm_azure_action() { return 1; }
check_azure_provider Microsoft.App
[[ -z "$calls" ]]
source "$ROOT/scripts/check-prerequisites.sh"
CI=1
if confirm_azure_action 'must not prompt'; then exit 1; fi
printf 'PASS: Azure action approval, selection, failure and noninteractive cases\n'
