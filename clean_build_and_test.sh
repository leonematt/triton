#!/bin/bash

set -e

VENV_DIR=.venv

rm -rf ~/.triton/llvm ~/.triton/llvm-dist "$VENV_DIR"

python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"

pip install -q --upgrade pip
pip install -q ninja cmake wheel pybind11 setuptools numpy torch matplotlib pandas

TRITON_PULL_LLVM_SHARED_LIBS=1 pip install -v -e . --no-build-isolation

python3 python/tutorials/01-vector-add.py

echo "Done. To use: source $VENV_DIR/bin/activate"
