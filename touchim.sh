#!/bin/bash

# -------------------------------------------------------------------
# Script Name: touchim.sh
# Description: Dynamically creates directories and files based on
#              a tree-like structure provided in a tree.txt file.
# Author: Your Name
# Date: 2024-04-27
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
RC_FILE="$HOME/.touchimrc"

# ----------------------------- #
#         Help Function         #
# ----------------------------- #
show_help() {
    echo -e "${CYAN}Usage: $0 [OPTIONS]${RESET}"
    echo
    echo -e "${YELLOW}Options:${RESET}"
    echo -e "  -i, --input FILE           Specify input tree file (default: ${DEFAULT_INPUT})"
    echo -e "  -o, --output-dir DIR       Specify output directory (default: ${DEFAULT_OUTPUT})"
    echo -e "      --reset                Delete the created output directory"
    echo -e "  -h, --help                 Display this help message and exit"
    echo
    echo -e "${YELLOW}Examples:${RESET}"
    echo -e "  $0 --input mytree.txt --output-dir myproject"
    echo -e "  $0 -i mytree.txt -o myproject"
    echo -e "  $0 --reset"
    echo
}

# ----------------------------- #
#       Error Handling          #
# ----------------------------- #
error_exit() {
    echo -e "${RED}Error: $1${RESET}" >&2
    exit 1
}

# ----------------------------- #
#    Load or Initialize RC      #
# ----------------------------- #
load_config() {
    if [[ -f "$RC_FILE" ]]; then
        # Load configurations
        source "$RC_FILE"
    else
        # Initialize with default settings
        echo "input_file=\"$DEFAULT_INPUT\"" > "$RC_FILE"
        echo "output_dir=\"$DEFAULT_OUTPUT\"" >> "$RC_FILE"
        echo "indent_spaces=$DEFAULT_INDENT" >> "$RC_FILE"
        echo -e "${GREEN}Initialized configuration file at $RC_FILE${RESET}"
    fi
}

# ----------------------------- #
#      Save Configurations      #
# ----------------------------- #
save_config() {
    echo "input_file=\"$input_file\"" > "$RC_FILE"
    echo "output_dir=\"$output_dir\"" >> "$RC_FILE"
    echo "indent_spaces=$indent_spaces" >> "$RC_FILE"
}

# ----------------------------- #
#       Argument Parsing        #
# ----------------------------- #
# Initialize variables with default values
input_file="$DEFAULT_INPUT"
output_dir="$DEFAULT_OUTPUT"
indent_spaces="$DEFAULT_INDENT"
reset_flag=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -i|--input)
            if [[ -n "${2:-}" ]]; then
                input_file="$2"
                shift 2
            else
                error_exit "Argument for $1 is missing"
            fi
            ;;
        -o|--output-dir)
            if [[ -n "${2:-}" ]]; then
                output_dir="$2"
                shift 2
            else
                error_exit "Argument for $1 is missing"
            fi
            ;;
        --reset)
            reset_flag=1
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            error_exit "Unknown option: $1. Use --help to see available options."
            ;;
    esac
done

# ----------------------------- #
#        Load Config            #
# ----------------------------- #
load_config

# Override config with arguments if provided
if [[ "$input_file" != "$DEFAULT_INPUT" ]]; then
    input_file="$input_file"
fi

if [[ "$output_dir" != "$DEFAULT_OUTPUT" ]]; then
    output_dir="$output_dir"
fi

# Save the updated configurations
save_config

# ----------------------------- #
#        Reset Function         #
# ----------------------------- #
if [[ "$reset_flag" -eq 1 ]]; then
    if [[ -d "$output_dir" ]]; then
        echo -e "${YELLOW}Are you sure you want to delete the directory '$output_dir'? [y/N]${RESET}"
        read -r confirmation
        if [[ "$confirmation" =~ ^[Yy]$ ]]; then
            rm -rf "$output_dir"
            echo -e "${GREEN}Deleted directory '$output_dir' successfully.${RESET}"
            exit 0
        else
            echo -e "${YELLOW}Reset operation cancelled.${RESET}"
            exit 0
        fi
    else
        echo -e "${YELLOW}Directory '$output_dir' does not exist. Nothing to reset.${RESET}"
        exit 0
    fi
fi

# ----------------------------- #
#      Validate Input File      #
# ----------------------------- #
if [[ ! -f "$input_file" ]]; then
    error_exit "Input file '$input_file' not found."
fi

# ----------------------------- #
#      Parse tree.txt           #
# ----------------------------- #
declare -a path_stack
total_dirs=0
total_files=0
preview_structure=""

while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip empty lines
    [[ -z "$line" ]] && continue

    # Remove tree symbols and replace them with spaces
    clean_line=$(echo "$line" | sed 's/[│├└─]*//')

    # Determine the indentation level based on leading spaces
    leading_spaces=$(echo "$line" | sed -n 's/^\( *\).*$/\1/p' | wc -c)
    indent_level=$(( (leading_spaces - 1) / indent_spaces ))  # subtract 1 to account for zero index

    # Extract the actual name by trimming spaces
    name=$(echo "$clean_line" | sed 's/^ *//')

    # Determine if it's a directory (ends with /) or a file
    if [[ "$name" == */ ]]; then
        # It's a directory
        dir_name=${name%/}  # Remove trailing /

        # Update the path stack based on the current indentation level
        path_stack=("${path_stack[@]:0:indent_level}")
        path_stack+=("$dir_name")

        # Construct the full directory path
        full_path=$(IFS=/; echo "${path_stack[*]}")

        # Update preview
        preview_structure+="$full_path/\n"

        # Increment directory count
        ((total_dirs++))
    else
        # It's a file
        # Update the path stack based on the current indentation level
        path_stack=("${path_stack[@]:0:indent_level}")

        # Construct the full file path
        full_path=$(IFS=/; echo "${path_stack[*]}/$name")

        # Update preview
        preview_structure+="$full_path\n"

        # Increment file count
        ((total_files++))
    fi
done < "$input_file"

# ----------------------------- #
#      Display Preview          #
# ----------------------------- #
echo -e "${CYAN}Summary:${RESET}"
echo -e "Input File      : ${MAGENTA}$input_file${RESET}"
echo -e "Output Directory: ${MAGENTA}$output_dir${RESET}"
echo -e "Directories to Create: ${GREEN}$total_dirs${RESET}"
echo -e "Files to Create      : ${GREEN}$total_files${RESET}"
echo
echo -e "${YELLOW}Preview of the structure to be created:${RESET}"
echo -e "$preview_structure" | sed 's/\\n/\n/g'

echo
echo -e "${YELLOW}Proceed with creation? [y/N]${RESET}"
read -r user_confirm

if [[ ! "$user_confirm" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Operation cancelled by user.${RESET}"
    exit 0
fi

# ----------------------------- #
#      Create Directories        #
# ----------------------------- #
echo -e "${BLUE}Creating directories and files...${RESET}"

# Reset path stack
path_stack=()

# Create output directory if it doesn't exist
mkdir -p "$output_dir"

while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip empty lines
    [[ -z "$line" ]] && continue

    # Remove tree symbols and replace them with spaces
    clean_line=$(echo "$line" | sed 's/[│├└─]*//')

    # Determine the indentation level based on leading spaces
    leading_spaces=$(echo "$line" | sed -n 's/^\( *\).*$/\1/p' | wc -c)
    indent_level=$(( (leading_spaces - 1) / indent_spaces ))  # subtract 1 to account for zero index

    # Extract the actual name by trimming spaces
    name=$(echo "$clean_line" | sed 's/^ *//')

    # Determine if it's a directory (ends with /) or a file
    if [[ "$name" == */ ]]; then
        # It's a directory
        dir_name=${name%/}  # Remove trailing /

        # Update the path stack based on the current indentation level
        path_stack=("${path_stack[@]:0:indent_level}")
        path_stack+=("$dir_name")

        # Construct the full directory path
        full_path=$(IFS=/; echo "${path_stack[*]}")

        # Create the directory
        mkdir -p "$output_dir/$full_path"
        echo -e "${GREEN}Created directory:${RESET} $output_dir/$full_path"
    else
        # It's a file
        # Update the path stack based on the current indentation level
        path_stack=("${path_stack[@]:0:indent_level}")

        # Construct the full file path
        full_path=$(IFS=/; echo "${path_stack[*]}/$name")

        # Ensure the parent directory exists
        mkdir -p "$output_dir/$(dirname "$full_path")"

        # Touch the file
        touch "$output_dir/$full_path"
        echo -e "${GREEN}Created file:${RESET} $output_dir/$full_path"
    fi
done < "$input_file"

echo -e "${GREEN}All directories and files have been created successfully in '$output_dir'.${RESET}"
