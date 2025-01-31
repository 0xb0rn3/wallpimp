#!/usr/bin/env bash

# Detect Python executable
PYTHON_CMD=$(which python3 || which python)

if [ -z "$PYTHON_CMD" ]; then
    echo "No Python installation found!"
    exit 1
fi

# Check for virtual environment
if [ -n "$VIRTUAL_ENV" ]; then
    # Already in a virtual environment
    $PYTHON_CMD wallpimp.py
elif [ -d "wallpimp_env" ]; then
    # Activate virtual environment if it exists
    source wallpimp_env/bin/activate
    $PYTHON_CMD wallpimp.py
    deactivate
else
    # No virtual environment, try direct execution
    $PYTHON_CMD wallpimp.py
fi
