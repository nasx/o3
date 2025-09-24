#!/bin/bash

TMP_DIRECTORY=/tmp

if [ ! -z "${GITHUB_ACTIONS}" ]; then
  TMP_DIRECTORY=$RUNNER_TEMP
fi

python -m venv $TMP_DIRECTORY/temp-venv
. $TMP_DIRECTORY/temp-venv/bin/activate

if [ -z "${VIRTUAL_ENV}" ]; then
  echo "Could not determine if we are running in a virtual environment...bailing."
  exit 1
fi

pip install -U -r requirements.txt

# ansible-galaxy collection install -r collections/requirements.yaml

ansible-lint -f full --profile production -v

if [ -z "${GITHUB_ACTIONS}" ]; then
  rm -rf /tmp/temp-venv
fi
