# Activate the from-source toolchain (sourced by build steps).
export PATH="/usr/local/toolchain/bin:${PATH}"
export LD_LIBRARY_PATH="/usr/local/toolchain/lib64:/usr/local/toolchain/lib:${LD_LIBRARY_PATH:-}"
