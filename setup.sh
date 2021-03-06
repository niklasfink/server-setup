#!/bin/bash

set -e

function getCurrentDir() {
    local current_dir="${BASH_SOURCE%/*}"
    if [[ ! -d "${current_dir}" ]]; then current_dir="$PWD"; fi
    echo "${current_dir}"
}

function includeDependencies() {
    # shellcheck source=./setupLibrary.sh
    source "${current_dir}/setupLibrary.sh"
}

current_dir=$(getCurrentDir)
includeDependencies
output_file="output.log"

function main() {

    sudo apt-get -y update
    sudo apt-get -y upgrade
    
    #Fail2Ban installation
    sudo apt-get -y install fail2ban

    # Run setup functions
    # trap cleanup EXIT SIGHUP SIGINT SIGTERM

    addUserAccount "${username}"

    echo 'Running setup script...'
    logTimestamp "${output_file}"

    exec 3>&1 >>"${output_file}" 2>&1
    disableSudoPassword "${username}"
    addSSHKey "${username}" "${sshKey}"
    changeSSHConfig
    setupUfw

    beautifyBash

    if ! hasSwap; then
        setupSwap
    fi

    setupTimezone

    echo "Installing Network Time Protocol... " >&3
    configureNTP

    sudo service ssh restart

    # cleanup

    echo "Setup Done! Log file is located at ${output_file}" >&3
}

function beautifyBash() {
    execAsUser "${username}" "echo force_color_prompt=yes | tee -a ~/.bashrc"
    execAsUser "${username}" "echo \"PS1='\[\033[1;36m\]\u\[\033[1;31m\]@\[\033[1;32m\]\h:\[\033[1;35m\]\w\[\033[1;31m\]\$\[\033[0m\] '\" | tee -a ~/.bashrc"
    # bash histroy autosave:
    execAsUser "${username}" "echo \"export PROMPT_COMMAND='history -a'\" | tee -a ~/.bashrc"
}

function setupSwap() {
    if [ $(free | awk '/^Swap:/ {exit !$2}') ]; then
        createSwap
        mountSwap
    else
        echo "Already have swap." >&3
    fi
    tweakSwapSettings "10" "50"
    saveSwapSettings "10" "50"
}

function hasSwap() {
    [[ "$(sudo swapon -s)" == *"/swapfile"* ]]
}

function cleanup() {
    if [[ -f "/etc/sudoers.bak" ]]; then
        revertSudoers
    fi
}

function logTimestamp() {
    local filename=${1}
    {
        echo "==================="
        echo "Log generated on $(date)"
        echo "==================="
    } >>"${filename}" 2>&1
}

function setupTimezone() {
    if [ -z "${timezone}" ]; then
        timezone="Europe/Berlin"
    fi
    setTimezone "${timezone}"
    echo "Timezone is set to $(cat /etc/timezone)" >&3
}

main
