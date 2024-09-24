#!/bin/bash

# -------------------------------------------------------------------
# Script Name: touchim.sh
# Description: Dynamically creates directories and files based on
#              a tree-like structure provided in a tree.txt file.
# -------------------------------------------------------------------

# Enable strict error handling
set -euo pipefail

# ----------------------------- #
#       Default Configurations  #
# ----------------------------- #
DEFAULT_INPUT="tree.txt"
DEFAULT_OUTPUT="touchim-output"
DEFAULT_INDENT=4  # Number of spaces per indentation level

# ----------------------------- #
#       Error Handling          #
# ----------------------------- #
error_exit() {
    echo -e "Error: $1" >&2
    exit 1
}

# ----------------------------- #
#      Validate Input File      #
# ----------------------------- #
if [[ ! -f "$DEFAULT_INPUT" ]]; then
    error_exit "Input file '$DEFAULT_INPUT' not found."
fi

# ----------------------------- #
#      Initialize Variables     #
# ----------------------------- #
declare -a path_stack  # Stack to keep track of the current directory path
path_stack=()
total_dirs=0
total_files=0

# ----------------------------- #
#      Parse tree.txt           #
# ----------------------------- #
while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip empty lines
    [[ -z "$line" ]] && continue

    # ----------------------------- #
    #   Step 1: Clean the Line      #
    # ----------------------------- #
    # Replace '│   ' with '    ' to standardize indentation
    # Replace '├── ' and '└── ' with '    ' to remove tree branches
    # Remove any remaining '─' or '│' symbols
    processed_line=$(echo "$line" | \
        sed 's/│   /    /g' | \
        sed 's/[├└]── /    /g' | \
        sed 's/[─│]//g')

    # ----------------------------- #
    #   Step 2: Determine Depth     #
    # ----------------------------- #
    # Count the number of leading spaces
    leading_spaces=$(echo "$processed_line" | sed -n 's/^\( *\).*$/\1/p' | wc -c)
    leading_spaces=$((leading_spaces - 1))  # Adjust for newline character

    # Calculate indentation level
    indent_level=$(( leading_spaces / DEFAULT_INDENT ))

    # ----------------------------- #
    #   Step 3: Extract Name        #
    # ----------------------------- #
    # Remove leading and trailing spaces to get the actual name
    name=$(echo "$processed_line" | sed 's/^ *//;s/ *$//')

    # ----------------------------- #
    #   Step 4: Update Path Stack   #
    # ----------------------------- #
    # Truncate the path stack to the current indentation level
    path_stack=("${path_stack[@]:0:indent_level}")

    # ----------------------------- #
    #   Step 5: Create Directory/File#
    # ----------------------------- #
    if [[ "$name" == */ ]]; then
        # It's a directory
        dir_name=${name%/}  # Remove trailing '/'

        # Add the directory to the path stack
        path_stack+=("$dir_name")

        # Build the full directory path
        if [[ ${#path_stack[@]} -gt 0 ]]; then
            full_dir_path=$(IFS=/; echo "${path_stack[*]}")
        else
            full_dir_path=""
        fi

        # Create the directory
        mkdir -p "$DEFAULT_OUTPUT/$full_dir_path"
        echo "Created directory: $DEFAULT_OUTPUT/$full_dir_path"
        total_dirs=$((total_dirs + 1))
    else
        # It's a file
        file_name="$name"

        # Build the full file path
        if [[ ${#path_stack[@]} -gt 0 ]]; then
            full_file_path=$(IFS=/; echo "${path_stack[*]}/$file_name")
        else
            full_file_path="$file_name"
        fi

        # Ensure the parent directory exists
        parent_dir=$(dirname "$full_file_path")
        if [[ "$parent_dir" != "." ]]; then
            mkdir -p "$DEFAULT_OUTPUT/$parent_dir"
        fi

        # Create the file
        touch "$DEFAULT_OUTPUT/$full_file_path"
        echo "Created file: $DEFAULT_OUTPUT/$full_file_path"
        total_files=$((total_files + 1))
    fi
done < "$DEFAULT_INPUT"

# ----------------------------- #
#      Final Summary            #
# ----------------------------- #
echo "All directories and files have been created successfully in '$DEFAULT_OUTPUT'."
echo "Total directories created: $total_dirs"
echo "Total files created: $total_files"
