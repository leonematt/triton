#!/bin/bash
set -e

# ==========================================
# 1. CONFIGURATION
# ==========================================
TRITON_ROOT="$(pwd)"
LLVM_BUILD_DIR="${TRITON_ROOT}/.llvm-project/build"
LLVM_SRC_DIR="${TRITON_ROOT}/llvm-project"
SDK_DEST="${TRITON_ROOT}/test_sdk_isolated"
POISON_ROOT="/home/leonematt/dev/triton_repos/triton"

echo ">>> 1. Assembling Isolated SDK (Including LLD)..."
rm -rf "$SDK_DEST"
mkdir -p "$SDK_DEST"/{bin,lib,include,lib/cmake,NATIVE/bin}

# Copy Binaries (Translators + Linker)
cp "$LLVM_BUILD_DIR/bin/"{llvm-config,mlir-tblgen,llvm-tblgen,FileCheck,lld} "$SDK_DEST/bin/"
# Satisfy Ninja NATIVE requirement
cp "$LLVM_BUILD_DIR/bin/mlir-tblgen" "$SDK_DEST/NATIVE/bin/"

# Copy Fragmented Shared Objects
cp -a "$LLVM_BUILD_DIR/lib/"*.so* "$SDK_DEST/lib/"

# Copy CMake GPS Logic
cp -r "$LLVM_BUILD_DIR/lib/cmake"/* "$SDK_DEST/lib/cmake/"

# Flatten Headers (Merging ALL necessary Source + Generated)
echo ">>> Flattening Headers (LLVM + MLIR + LLD)..."
# Source headers
cp -r "$LLVM_SRC_DIR/llvm/include/llvm" "$SDK_DEST/include/"
cp -r "$LLVM_SRC_DIR/mlir/include/mlir" "$SDK_DEST/include/"
cp -r "$LLVM_SRC_DIR/lld/include/lld"   "$SDK_DEST/include/"  # <--- FIXED: Added LLD
# Generated headers (Overlaying them)
cp -ru "$LLVM_BUILD_DIR/include/llvm" "$SDK_DEST/include/"
cp -ru "$LLVM_BUILD_DIR/tools/mlir/include/mlir" "$SDK_DEST/include/"
cp -ru "$LLVM_BUILD_DIR/tools/lld/include/lld"   "$SDK_DEST/include/" # <--- FIXED: Added LLD Generated

# ==========================================
# 2. DEPOISONING (THE SURGERY)
# ==========================================
echo ">>> 2. Performing surgical depoisoning..."
find "$SDK_DEST" -name "cmake_install.cmake" -delete

find "$SDK_DEST" -type f -name "*.cmake" -exec sed -i \
    -e "s|$POISON_ROOT/.llvm-project/build|\${CMAKE_CURRENT_LIST_DIR}/../../..|g" \
    -e "s|$POISON_ROOT/llvm-project/llvm|\${CMAKE_CURRENT_LIST_DIR}/../../..|g" \
    -e "s|$POISON_ROOT/llvm-project/mlir|\${CMAKE_CURRENT_LIST_DIR}/../../..|g" \
    -e "s|$POISON_ROOT/llvm-project/lld|\${CMAKE_CURRENT_LIST_DIR}/../../..|g" \
    -e "s|$POISON_ROOT/llvm-project/install|\${CMAKE_CURRENT_LIST_DIR}/../../..|g" \
    -e "s|$POISON_ROOT/test_sdk_isolated|\${CMAKE_CURRENT_LIST_DIR}/../../..|g" \
    -e "s|$POISON_ROOT/llvm-project/third-party/unittest/googletest/include|/tmp/null|g" \
    -e "s|$POISON_ROOT/llvm-project/third-party/unittest/googlemock/include|/tmp/null|g" \
    {} +

echo "✨ SDK is now officially GHOSTED."

# ==========================================
# 3. FRESH TEST ENVIRONMENT
# ==========================================
echo ">>> 3. Preparing Fresh Test Environment..."
rm -rf .venv_final_test
python3 -m venv .venv_final_test
source .venv_final_test/bin/activate

pip install --upgrade pip
pip install cmake ninja setuptools wheel pybind11 numpy torch matplotlib pandas --extra-index-url https://download.pytorch.org/whl/cu124

# ==========================================
# 4. THE ULTIMATE TEST
# ==========================================
echo ">>> 4. Building Triton against Isolated SDK..."
export LLVM_SYSPATH="$SDK_DEST"
export PATH="$SDK_DEST/bin:$PATH"
export LD_LIBRARY_PATH="$SDK_DEST/lib:$LD_LIBRARY_PATH"

TRITON_CMAKE_CONFIGURE_OPTIONS="-DCMAKE_PREFIX_PATH=$SDK_DEST" \
pip install -v -e . --no-build-isolation

echo ">>> 5. Running Tutorial Validation..."
python3 python/tutorials/01-vector-add.py

echo "✅ SUCCESS: Everything built and ran."
