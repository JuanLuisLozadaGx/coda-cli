#!/usr/bin/env bash

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly SCRIPT_DIR
SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_NAME

usage() {
    cat >&2 << EOF
Usage: ${SCRIPT_NAME} [-h] [VENV_PATH] [--no-shell-config]

Install Coda packages into a Python virtual environment.

Arguments:
    VENV_PATH           Path where the virtual environment will be created.
                        Defaults to ~/.coda-venv if not specified.
    --no-shell-config   Do not update shell configuration files (PATH).
    -h, --help          Show this help message.

Supported Python versions: 3.12, 3.13

EOF
    exit "${1:-1}"
}

find_python() {
    local version="$1"
    local python_exe
    
    # shellcheck disable=SC2155
    local search_paths="
        $(command -v "python${version}" 2>/dev/null || true)
        $(command -v python3 2>/dev/null || true)
        $(command -v python 2>/dev/null || true)
        /usr/local/bin/python${version}
        /usr/bin/python${version}
    "
    # Add macOS-specific paths only if running on macOS
    case "$(uname -s)" in
        Darwin)
            search_paths="$search_paths
        /opt/homebrew/bin/python${version}
        /Library/Frameworks/Python.framework/Versions/${version}/bin/python${version}
        ${HOME}/Library/Frameworks/Python.framework/Versions/${version}/bin/python${version}
        ${HOME}/.pyenv/shims/python${version}"
            ;;
    esac
    
    for path in $search_paths; do
        if [ -z "$path" ]; then
            continue
        fi
        
        if [ -x "$path" ]; then
            python_exe="$path"
            local detected_version
            detected_version=$("$python_exe" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null || echo "")
            
            if [ "$detected_version" = "$version" ]; then
                printf "%s" "$python_exe"
                return 0
            fi
        fi
    done
    
    return 1
}

find_wheel() {
    local package_name="$1"
    local wheel_path
    
    wheel_path=$(find "$SCRIPT_DIR" -maxdepth 1 -name "${package_name}-*.whl" | head -1)
    
    if [ -z "$wheel_path" ]; then
        return 1
    fi
    
    printf "%s" "$wheel_path"
    return 0
}

install_wheels() {
    local venv_bin="$1"
    local pip_exe="${venv_bin}/pip"
    
    local packages="coda_core coda_cli coda_batch coda_api coda"
    
    for package in $packages; do
        local wheel
        if ! wheel=$(find_wheel "$package"); then
            printf 'Error: Could not find wheel for package: %s\n' "$package" >&2
            return 1
        fi
        
        printf 'Installing %s from %s...\n' "$package" "$(basename "$wheel")"
        
        if ! "$pip_exe" install --find-links "$SCRIPT_DIR" "$wheel"; then
            printf 'Error: Failed to install %s\n' "$package" >&2
            return 1
        fi
    done
    
    return 0
}

is_safe_venv_path() {
    local path="$1"

    # Allow only a conservative set of characters in the virtualenv path to
    # avoid injecting unintended shell syntax into shell rc files.
    # This whitelist includes typical filesystem path characters and
    # implicitly excludes quotes, backticks, dollar signs, and newlines.
    if printf '%s' "$path" | grep -Eq '^[A-Za-z0-9_./:-]+$'; then
        return 0
    fi

    return 1
}

update_shell_rc() {
    local venv_bin="$1"
    local shell_rc="$2"
    local shell_name="$3"
    
    if ! is_safe_venv_path "$venv_bin"; then
        printf 'Skipping shell rc update for %s: unsafe virtualenv path "%s"\n' "$shell_name" "$venv_bin" >&2
        return 1
    fi
    
    local rc_path="${HOME}/${shell_rc}"
    local path_entry="export PATH=\"${venv_bin}:\$PATH\"  # Added by coda installer"
    
    if [ ! -f "$rc_path" ]; then
        printf '%s\n' "$path_entry" > "$rc_path"
        printf 'Created %s with PATH entry.\n' "$rc_path"
    elif grep -q "Added by coda installer" "$rc_path"; then
        printf '%s already contains coda PATH entry.\n' "$rc_path"
    else
        {
            printf '\n'
            printf '%s\n' "$path_entry"
        } >> "$rc_path"
        printf 'Updated %s with coda PATH entry.\n' "$rc_path"
    fi
}

main() {
    local venv_path="${HOME}/.coda-venv"
    local update_shell_config=1
    local venv_path_provided=0
    
    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --no-shell-config)
                update_shell_config=0
                ;;
            -h|--help)
                usage 0
                ;;
            *)
                if [ "$venv_path_provided" -eq 0 ]; then
                    venv_path="$1"
                    venv_path_provided=1
                else
                    usage
                fi
                ;;
        esac
        shift
    done
    
    printf 'Coda Installation Script\n'
    printf '========================\n\n'
    
    printf 'Searching for Python 3.12 or 3.13...\n'
    local python_exe
    if ! python_exe=$(find_python "3.13"); then
        if ! python_exe=$(find_python "3.12"); then
            printf 'Error: Python 3.12 or 3.13 not found in any expected location.\n' >&2
            printf 'Please install one of these versions.\n' >&2
            return 1
        fi
    fi
    
    printf 'Found Python: %s\n' "$python_exe"
    
    local detected_version
    detected_version=$("$python_exe" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    printf 'Python version: %s\n\n' "$detected_version"
    
    if [ -d "$venv_path" ]; then
        printf 'Virtual environment already exists at: %s\n' "$venv_path"
    else
        printf 'Creating virtual environment at: %s\n' "$venv_path"
        if ! "$python_exe" -m venv "$venv_path"; then
            printf 'Error: Failed to create virtual environment.\n' >&2
            return 1
        fi
    fi
    
    local venv_bin="${venv_path}/bin"
    
    printf 'Installing wheels...\n'
    if ! install_wheels "$venv_bin"; then
        return 1
    fi
    
    if [ "$update_shell_config" -eq 1 ]; then
        if [ ! -t 0 ] || [ -z "${SHELL:-}" ]; then
            printf 'Non-interactive environment detected, skipping shell configuration.\n'
        else
            printf '\nUpdating shell configuration...\n'
            local shell_name
            shell_name=$(basename "$SHELL")
            case "$shell_name" in
                zsh)
                    update_shell_rc "$venv_bin" ".zshrc" "zsh"
                    ;;
                bash)
                    update_shell_rc "$venv_bin" ".bashrc" "bash"
                    ;;
                *)
                    printf 'Warning: Unsupported shell detected: %s\n' "$shell_name" >&2
                    printf 'To add coda to your PATH, run:\n' >&2
                    # shellcheck disable=SC2016
                    printf '  export PATH="%s:$PATH"\n' "$venv_bin" >&2
                    printf 'Or add the line to your shell configuration file.\n' >&2
                    ;;
            esac
        fi
    else
        printf '\nShell configuration update skipped (--no-shell-config specified).\n'
        printf 'To add coda to your PATH, run:\n'
        # shellcheck disable=SC2016
        printf '  export PATH="%s:$PATH"\n' "$venv_bin"
        printf 'Or add the line to your shell configuration file.\n'
    fi
    
    printf '\n========================================\n'
    printf 'Installation completed successfully!\n'
    printf 'Virtual environment: %s\n' "$venv_path"
    printf 'Executables: %s\n' "$venv_bin"
    printf '\nTo activate the environment in your current shell, run:\n'
    printf '  source %s/activate\n' "$venv_bin"
    printf '\nOr to use coda directly, reload your shell:\n'
    # shellcheck disable=SC2016
    printf '  exec $SHELL\n'
    printf '========================================\n'
    
    return 0
}

main "$@"
