# Export core environment variables
export RCFORGE_APP_NAME="rcForge"
export RCFORGE_VERSION="0.5.0"

export RCFORGE_CONFIG_ROOT="${XDG_CONFIG_HOME:-$HOME/.config}/rcforge"
export RCFORGE_DATA_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/rcforge"
export RCFORGE_LIB="${RCFORGE_DATA_ROOT}/system/lib"
export RCFORGE_CORE="${RCFORGE_DATA_ROOT}/system/core"
export RCFORGE_UTILS="${RCFORGE_DATA_ROOT}/system/utils"
export RCFORGE_USER_UTILS="${RCFORGE_DATA_ROOT}/utils"
export RCFORGE_SCRIPTS="${RCFORGE_CONFIG_ROOT}/rc-scripts"
export RCFORGE_CONFIG="${RCFORGE_CONFIG_ROOT}/config"
