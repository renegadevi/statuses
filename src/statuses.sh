#!/usr/bin/env bash

# Define icons and colors
FOLDER_ICON=""   # Folder icon
FILE_ICON=""     # File icon
BRANCH_ICON=""   # Branch icon
MODIFIED_ICON="" # Modified icon
ADDED_ICON=""    # Added icon
DELETED_ICON=""  # Deleted icon
RENAMED_ICON="凜" # Renamed icon
COPIED_ICON=""   # Copied icon
STAGED_ICON=""   # Staged icon
CONFLICT_ICON="" # Conflict icon

CLEAN_ICON="✔"    # Clean status icon
CHANGES_ICON="✖"  # Changes status icon

BRANCH_COLOR="\033[36m"  # Cyan for branch names
STATUS_COLOR="\033[33m"  # Yellow for status symbols
CLEAN_COLOR="\033[32m"   # Green for "Clean"
CHANGES_COLOR="\033[31m" # Red for "Changes"
RESET_COLOR="\033[0m"    # Reset color

# Advanced and simple mode flags
ADVANCED=false
SIMPLE=false

# Function to display help
show_help() {
    cat <<EOF
statuses - A CLI tool to display Git statuses across multiple directories.

Usage:
  statuses [OPTIONS]

Options:
  --simple, -s       Show a simplified status view (one-line output per folder).
  -a                 Show advanced Git status with detailed information.
  --help, -h         Show this help message and exit.

Examples:
  statuses           Display the detailed Git status (default).
  statuses --simple  Show a simplified view of the Git status.
  statuses -a        Show the advanced Git status.

EOF
    exit 0
}

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        --help|-h)
            show_help
            ;;
        --simple|-s)
            SIMPLE=true
            ;;
        -a)
            ADVANCED=true
            ;;
        *)
            echo -e "\033[31mUnknown option: $arg\033[0m"
            show_help
            ;;
    esac
done

# Array to track processed directories
declare -a processed_dirs
declare -a folder_names

# Function to check if a folder has already been processed
is_processed() {
    local dir="$1"
    for processed in "${processed_dirs[@]}"; do
        if [[ "$dir" == "$processed" || "$dir" == "$processed/"* ]]; then
            return 0 # Already processed or subdirectory
        fi
    done
    return 1 # Not processed
}

# Function to get relative path
get_relative_path() {
    local dir="$1"
    echo "${dir#$(pwd)/}"
}

# Function to collect folder names for alignment
collect_folder_name() {
    local dir="$1"
    local relative_dir
    relative_dir=$(get_relative_path "$dir")
    [[ "$relative_dir" == "" ]] && relative_dir="Current Folder"
    folder_names+=("$relative_dir")
}

# Function to calculate max width of folder names
get_max_width() {
    local max_width=0
    for folder in "${folder_names[@]}"; do
        local length=${#folder}
        if (( length > max_width )); then
            max_width=$length
        fi
    done
    echo $max_width
}

# Function to display the Git status of a directory in simple mode
display_simple_status() {
    local dir="$1"
    local relative_dir
    relative_dir=$(get_relative_path "$dir")
    [[ "$relative_dir" == "" ]] && relative_dir="Current Folder"

    local status=""
    if [[ -z "$(git -C "$dir" status --porcelain)" ]]; then
        status="${CLEAN_COLOR}${CLEAN_ICON} Clean${RESET_COLOR}"
    else
        status="${CHANGES_COLOR}${CHANGES_ICON} Changes${RESET_COLOR}"
    fi

    # Get the maximum width for alignment
    local max_width
    max_width=$(get_max_width)
    local padded_width=$((max_width + 4)) # Add padding for icon and space
    printf "%-${padded_width}s %b\n" "${FOLDER_ICON} ${relative_dir}" "$status"
}

# Function to display the Git status of a directory in detailed mode
display_detailed_status() {
    local dir="$1"
    local is_advanced="$2"
    local depth="$3" # Depth level for indentation

    if [[ ! -d "$dir/.git" ]]; then
        return
    fi

    # Set indentation based on depth
    local indent=""
    for ((i = 0; i < depth; i++)); do
        indent+="  "
    done

    # Display the directory name relative to the current working directory
    local relative_dir
    relative_dir=$(get_relative_path "$dir")
    [[ "$relative_dir" == "" ]] && relative_dir="Current Folder"
    echo -e "${indent}${FOLDER_ICON} ${BRANCH_COLOR}${relative_dir}${RESET_COLOR}"

    if $is_advanced; then
        git -C "$dir" status -sb | sed "s/^/${indent}  /"
    else
        git -C "$dir" status --porcelain | while IFS= read -r line; do
            # Extract the status (2 characters) and the file path (remainder of the line)
            local status="${line:0:2}"
            local path="${line:3}"

            case "$status" in
                " M") echo -e "${indent}  ${STATUS_COLOR}${MODIFIED_ICON} Modified: ${path}${RESET_COLOR}" ;;
                "A ") echo -e "${indent}  ${STATUS_COLOR}${ADDED_ICON} Added: ${path}${RESET_COLOR}" ;;
                "D ") echo -e "${indent}  ${STATUS_COLOR}${DELETED_ICON} Deleted: ${path}${RESET_COLOR}" ;;
                "R ") echo -e "${indent}  ${STATUS_COLOR}${RENAMED_ICON} Renamed: ${path}${RESET_COLOR}" ;;
                "C ") echo -e "${indent}  ${STATUS_COLOR}${COPIED_ICON} Copied: ${path}${RESET_COLOR}" ;;
                "AM") echo -e "${indent}  ${STATUS_COLOR}${STAGED_ICON} Staged & Modified: ${path}${RESET_COLOR}" ;;
                "MM") echo -e "${indent}  ${STATUS_COLOR}${MODIFIED_ICON} Modified (Staged & Unstaged): ${path}${RESET_COLOR}" ;;
                "UU") echo -e "${indent}  ${STATUS_COLOR}${CONFLICT_ICON} Conflict: ${path}${RESET_COLOR}" ;;
                "??")
                    if [[ -d "$dir/$path" ]]; then
                        echo -e "${indent}  ${STATUS_COLOR}${FOLDER_ICON} Untracked Folder: ${path}${RESET_COLOR}"
                        display_detailed_status "$dir/$path" "$is_advanced" $((depth + 1))
                    else
                        echo -e "${indent}  ${STATUS_COLOR}${FILE_ICON} Untracked File: ${path}${RESET_COLOR}"
                    fi
                    ;;
                *) echo -e "${indent}  ${STATUS_COLOR}${FILE_ICON} Unknown Status: ${status} ${path}${RESET_COLOR}" ;;
            esac
        done
    fi

    # Check for clean or dirty status
    if [[ -z "$(git -C "$dir" status --porcelain)" ]]; then
        echo -e "${indent}  ${CLEAN_COLOR}${CLEAN_ICON} Clean${RESET_COLOR}"
    else
        echo -e "${indent}  ${CHANGES_COLOR}${CHANGES_ICON} Changes${RESET_COLOR}"
    fi
    echo ""
}

# Handle current directory
if [[ -d ".git" ]]; then
    current_dir=$(pwd)
    processed_dirs+=("$current_dir")
    collect_folder_name "."
fi

# Collect folder names for alignment
for repo in */; do
    full_path=$(realpath "$repo")
    is_processed "$full_path"
    already_processed=$?

    if [[ -d "$repo/.git" && $already_processed -ne 0 ]]; then
        processed_dirs+=("$full_path")
        collect_folder_name "$repo"
    fi
done

# Display statuses
if $SIMPLE; then
    # Display simple statuses after collecting folder names
    for repo in "${processed_dirs[@]}"; do
        display_simple_status "$repo"
    done
else
    # Display detailed statuses
    for repo in "${processed_dirs[@]}"; do
        display_detailed_status "$repo" "$ADVANCED" 0
    done
fi
