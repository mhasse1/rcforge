# development project root
PROJECT_ROOT="${HOME}/src/rcforge"

# environment variables for rcForge code to be executed from within the project
RCFORGE_APP_NAME="rcForge_src"
RCFORGE_VERSION="na"

# RCFORGE standard path variables
# These typically point to install-root. Here we point to project-root.
RCFORGE_ROOT="$PROJECT_ROOT"
RCFORGE_CORE="${RCFORGE_ROOT}/system/core"
RCFORGE_LIB="${RCFORGE_ROOT}/system/lib"
RCFORGE_UTILS="${RCFORGE_ROOT}/system/utils"
RCFORGE_LOCAL="${RCFORGE_ROOT}/local"
RCFORGE_TOOLS="${RCFORGE_ROOT}/tools"

# main function
main() {
	export RCFORGE_APP_NAME
	export RCFORGE_VERSION
	export PROJECT_ROOT
	export RCFORGE_ROOT
	export RCFORGE_CORE
	export RCFORGE_LIB
	export RCFORGE_UTILS
	export RCFORGE_LOCAL
	export RCFORGE_TOOLS
}

shell=$(ps -o comm= -p $$)
if [[ $shell == "-zsh" ]]; then
	[[ $ZSH_EVAL_CONTEXT != *:file:* ]] && main
elif [[ $shell == "bash" ]]; then
	[[ "${BASH_SOURCE[0]}" == "$0" ]] && main
fi
