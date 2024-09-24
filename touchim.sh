#!/bin/bash

# -------------------------------------------------------------------
# Script Name: touchim.sh
# Description: Dynamically creates directories and files based on
#              a tree-like structure provided in a tree.txt file.
# -------------------------------------------------------------------

# Enable strict error handling
set -euo pipefail

# ----------------------------- #
#          Color Setup          #
# ----------------------------- #
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
RESET='\033[0m'

# ----------------------------- #
#       Default Configurations  #
# ----------------------------- #
DEFAULT_INPUT="tree.txt"
DEFAULT_OUTPUT="touchim-output"
DEFAULT_INDENT=4

# ----------------------------- #
#       Error Handling          #
# ----------------------------- #
error_exit() {
    echo -e "${RED}Error: $1${RESET}" >&2
    exit 1
}

# ----------------------------- #
#      Validate Input File      #
# ----------------------------- #
if [[ ! -f "$DEFAULT_INPUT" ]]; then
    error_exit "Input file '$DEFAULT_INPUT' not found."
fi

# ----------------------------- #
#      Initialize Arrays        #
# ----------------------------- #
declare -a path_stack=()  # Initialize the path_stack as an empty array
total_dirs=0
total_files=0

# ----------------------------- #
#      Parse tree.txt           #
# ----------------------------- #
while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip empty lines
    [[ -z "$line" ]] && continue

    # Remove tree symbols (│, ├, └, ─) and replace them with spaces
    clean_line=$(echo "$line" | sed 's/[│├└─]//g')

    # Determine indentation level based on leading spaces
    leading_spaces=$(echo "$line" | sed -n 's/^\( *\).*$/\1/p' | wc -c)
    indent_level=$(( (leading_spaces - 1) / DEFAULT_INDENT ))

    # Extract the actual name by trimming spaces
    name=$(echo "$clean_line" | sed 's/^ *//')

    # If the name ends with '/', treat it as a directory, else it's a file
    if [[ "$name" == */ ]]; then
        # It's a directory
        dir_name=${name%/}  # Remove trailing /

        # Update the path stack based on the current indentation level
        path_stack=("${path_stack[@]:0:indent_level}")
        path_stack+=("$dir_name")

        # Build the full directory path
        if [[ ${#path_stack[@]} -gt 0 ]]; then
            full_path=$(IFS=/; echo "${path_stack[*]}")
        else
            full_path=""
        fi

        # Create the directory
        mkdir -p "$DEFAULT_OUTPUT/$full_path"
        echo -e "${GREEN}Created directory:${RESET} $DEFAULT_OUTPUT/$full_path"
    else
        # It's a file
        path_stack=("${path_stack[@]:0:indent_level}")

        # Check that path_stack is not empty before building the file path
        if [[ ${#path_stack[@]} -gt 0 ]]; then
            full_path=$(IFS=/; echo "${path_stack[*]}/$name")
        else
            full_path="$name"
        fi

        # Ensure the parent directory exists and create the file
        mkdir -p "$DEFAULT_OUTPUT/$(dirname "$full_path")"
        touch "$DEFAULT_OUTPUT/$full_path"
        echo -e "${GREEN}Created file:${RESET} $DEFAULT_OUTPUT/$full_path"
    fi
done < "$DEFAULT_INPUT"

echo -e "${GREEN}All directories and files have been created successfully in '$DEFAULT_OUTPUT'.${RESET}"
