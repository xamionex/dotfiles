#!/usr/bin/env bash

# Main configuration (could be moved to config file)
readonly SEARCH_OTHER_DRIVES=true
readonly TARGET_DOCS="$HOME/Documents"
readonly TARGET_APPDATA="$HOME/AppData"
readonly TARGET_SAVES="$HOME/Saved Games"
readonly FOLDERS=("Documents" "AppData" "Saved Games")

# Main function coordinating the process
main() {
    local compat_dirs=()
    get_steam_compatdata_dirs compat_dirs

    create_target_directories
    process_all_compat_dirs "${compat_dirs[@]}"

    echo "All Windows special folders have been unified and validated."
}

# Populate compatdata directories array
get_steam_compatdata_dirs() {
    local -n _dirs=$1  # Nameref for indirect assignment
    _dirs=("$HOME/.local/share/Steam/steamapps/compatdata")

    if [ "$SEARCH_OTHER_DRIVES" = true ]; then
        while IFS= read -r -d $'\0' dir; do
            _dirs+=("$dir")
        done < <(find /mnt -maxdepth 4 -path '*/SteamLibrary/steamapps/compatdata' -print0 2>/dev/null)
    fi
}

# Create target directories
create_target_directories() {
    mkdir -p "$TARGET_DOCS" "$TARGET_APPDATA" "$TARGET_SAVES"
}

# Process all compatdata directories
process_all_compat_dirs() {
    local dir
    for dir in "$@"; do
        [ -d "$dir" ] || continue
        process_single_compat_dir "$dir"
    done
}

# Process single compatdata directory
process_single_compat_dir() {
    local dir="$1"
    while IFS= read -r -d $'\0' appid_dir; do
        process_appid_directory "$appid_dir"
    done < <(find "$dir" -mindepth 1 -maxdepth 1 -type d -print0)
}

# Process single AppID directory
process_appid_directory() {
    local appid_dir="$1"
    local appid=$(basename "$appid_dir")

    local folder
    for folder in "${FOLDERS[@]}"; do
        process_special_folder "$appid_dir" "$appid" "$folder"
    done
}

# Process individual special folder
process_special_folder() {
    local appid_dir="$1"
    local appid="$2"
    local folder="$3"

    local target
    case "$folder" in
        Documents) target="$TARGET_DOCS" ;;
        AppData) target="$TARGET_APPDATA" ;;
        "Saved Games") target="$TARGET_SAVES" ;;
        *) return 1 ;;
    esac

    local sourcedir="$appid_dir/pfx/drive_c/users/steamuser/$folder"
    local parent_dir=$(dirname "$sourcedir")

    mkdir -p "$parent_dir"
    manage_symlink "$sourcedir" "$target" "$folder" "$appid"
}

# Manage symlink creation/validation
manage_symlink() {
    local sourcedir="$1"
    local target="$2"
    local folder="$3"
    local appid="$4"

    if [ -L "$sourcedir" ]; then
        validate_existing_symlink "$sourcedir" "$target" "$folder" "$appid"
    elif [ -d "$sourcedir" ]; then
        migrate_and_link "$sourcedir" "$target" "$folder" "$appid"
    else
        create_symlink "$sourcedir" "$target" "$folder" "$appid"
    fi
}

# Validate existing symlink
validate_existing_symlink() {
    local sourcedir="$1"
    local target="$2"
    local folder="$3"
    local appid="$4"
    local current_target=$(readlink -f "$sourcedir")

    if [ "$current_target" != "$target" ]; then
        echo "Updating $folder symlink for $appid (was: $current_target)"
        recreate_symlink "$sourcedir" "$target"
    else
        echo "Valid $folder symlink exists for $appid"
    fi
}

# Migrate directory and create symlink
migrate_and_link() {
    local sourcedir="$1"
    local target="$2"
    local folder="$3"
    local appid="$4"

    echo "Migrating $folder for $appid"
    rsync -a -l --ignore-existing "$sourcedir/" "$target/"
    rm -rf "$sourcedir"
    create_symlink "$sourcedir" "$target" "$folder" "$appid"
}

# Create new symlink
create_symlink() {
    local sourcedir="$1"
    local target="$2"
    local folder="$3"
    local appid="$4"

    echo "Creating $folder symlink for $appid"
    ln -svf "$target" "$sourcedir"
}

# Helper to recreate symlink
recreate_symlink() {
    rm -f "$1"
    ln -svf "$2" "$1"
}

# Execute main function
main "$@"
