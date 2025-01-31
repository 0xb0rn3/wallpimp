#!/usr/bin/env bash

# WallPimp Launcher Script

# Determine script's absolute directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Hidden execution directory
HIDDEN_DIR="${SCRIPT_DIR}/.wallpimp"

# Ensure hidden directory exists
mkdir -p "${HIDDEN_DIR}"

# Copy necessary files to hidden directory
cp wallpimp.py config.ini "${HIDDEN_DIR}/"

# Detect Python executable
PYTHON_CMD=$(which python3 || which python)

if [ -z "$PYTHON_CMD" ]; then
    echo "No Python installation found!"
    exit 1
fi

# Function to check and install dependencies
install_dependencies() {
    echo "Checking and installing dependencies..."
    $PYTHON_CMD -m pip install --user pyside6 pillow || {
        echo "Dependency installation failed. Please manually install pyside6 and pillow."
        exit 1
    }
}

# Check for required command-line tools
check_requirements() {
    command -v git >/dev/null 2>&1 || {
        echo "Git is required but not installed. Please install git."
        exit 1
    }
}

# Main execution
main() {
    # Ensure requirements are met
    check_requirements
    install_dependencies

    # Change to hidden directory and run script
    cd "${HIDDEN_DIR}"
    $PYTHON_CMD wallpimp.py
}

# Execute main function
main
