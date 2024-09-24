#!/bin/bash

# -------------------------------------------------------------------
# Script Name: touchim.sh
# Description: Dynamically creates directories and files based on
#              a tree-like structure provided in a tree.txt file.
#              Always skips creating the top-most directory in tree.txt.
#              Supports argument parsing for output directory and help.
# -------------------------------------------------------------------

# Enable strict error handling
set -euo pipefail

# ----------------------------- #
#       Default Configurations  #
# ----------------------------- #
DEFAULT_INPUT="tree.txt"
DEFAULT_INDENT=4  # Number of spaces per indentation level

# ----------------------------- #
#       Error Handling          #
# ----------------------------- #
error_exit() {
    echo -e "Error: $1" >&2
    exit 1
}

# ----------------------------- #
#      Display Help Message     #
# ----------------------------- #
show_help() {
    cat << EOF
Usage: $0 [options]

Options:
  -o, --output-dir DIR    Specify the output directory
  -h, --help              Display this help message

Examples:
  $0 -o ./                Create structure in the current directory without the top-level folder
  $0 --output-dir /path/to/output
EOF
}

# ----------------------------- #
#      Parse Command Line Args  #
# ----------------------------- #
output_dir=""
# Use GNU getopt for parsing
PARSED_ARGS=$(getopt -o o:h --long output-dir:,help -- "$@")
if [[ $? -ne 0 ]]; then
    show_help
    exit 1
fi

eval set -- "$PARSED_ARGS"

while true; do
    case "$1" in
        -o|--output-dir)
            output_dir="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# ----------------------------- #
#      Validate Input File      #
# ----------------------------- #
if [[ ! -f "$DEFAULT_INPUT" ]]; then
    error_exit "Input file '$DEFAULT_INPUT' not found."
fi

# ----------------------------- #
#    Determine Top-Level Dir    #
# ----------------------------- #
# Extract the first line that ends with '/'
top_dir=$(grep '/$' "$DEFAULT_INPUT" | head -n1 | sed 's:/*$::')
if [[ -z "$top_dir" ]]; then
    error_exit "No top-level directory found in '$DEFAULT_INPUT'."
fi

# ----------------------------- #
#    Set Output Directory       #
# ----------------------------- #
if [[ -z "$output_dir" ]]; then
    # Default: Output directory is current directory
    output_dir="."
else
    if [[ "$output_dir" == "." || "$output_dir" == "./" ]]; then
        # Output directly in current directory
        output_dir="."
    else
        # Output in specified directory
        mkdir -p "$output_dir"
    fi
fi

# ----------------------------- #
#      Initialize Variables     #
# ----------------------------- #
declare -a path_stack  # Stack to keep track of the current directory path
path_stack=()
total_dirs=0
total_files=0
skip_first_dir=1  # Always skip the first directory

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
    #   Handle Skipping First Dir  #
    # ----------------------------- #
    if [[ "$skip_first_dir" -eq 1 && "$indent_level" -eq 0 ]]; then
        # Skip the first directory
        skip_first_dir=0
        continue
    fi

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
        if [[ "$output_dir" == "." ]]; then
            # Output directly, no base path
            full_dir_path=$(IFS=/; echo "${path_stack[*]}")
        else
            # Include the base output_dir
            full_dir_path="$output_dir/$(IFS=/; echo "${path_stack[*]}")"
        fi

        # Create the directory
        mkdir -p "$full_dir_path"
        echo "Created directory: $full_dir_path"
        total_dirs=$((total_dirs + 1))
    else
        # It's a file
        file_name="$name"

        # Build the full file path
        if [[ "$output_dir" == "." ]]; then
            # Output directly, no base path
            if [[ "${#path_stack[@]}" -gt 0 ]]; then
                full_file_path=$(IFS=/; echo "${path_stack[*]}/$file_name")
            else
                full_file_path="$file_name"
            fi
        else
            # Include the base output_dir
            if [[ "${#path_stack[@]}" -gt 0 ]]; then
                full_file_path="$output_dir/$(IFS=/; echo "${path_stack[*]}/$file_name")"
            else
                full_file_path="$output_dir/$file_name"
            fi
        fi

        # Ensure the parent directory exists
        parent_dir=$(dirname "$full_file_path")
        if [[ "$parent_dir" != "." ]]; then
            mkdir -p "$parent_dir"
        fi

        # Create the file
        touch "$full_file_path"
        echo "Created file: $full_file_path"
        total_files=$((total_files + 1))
    fi
done < "$DEFAULT_INPUT"

# ----------------------------- #
#      Final Summary            #
# ----------------------------- #
if [[ "$output_dir" == "." ]]; then
    summary_dir="current directory"
else
    summary_dir="'$output_dir'"
fi
echo "All directories and files have been created successfully in $summary_dir."
echo "Total directories created: $total_dirs"
echo "Total files created: $total_files"
