#!/bin/bash

# Default input directories for various options
default_dir="$HOME/.config/defaults"
dropbox_dir="$HOME/Dropbox/config/defaults"
icloud_dir="$HOME/Library/Mobile Documents/com~apple~CloudDocs/config/defaults"
workdocs_dir="$HOME/Library/CloudStorage/WorkDocsDrive-Documents/config/defaults"
box_dir="$HOME/Library/CloudStorage/Box-Box/config/defaults"  # Box.com default directory

# Flag for importing modifier keys
import_modifier_keys=false

# Show help if the user asks for it
function show_help {
    echo "Usage: $0 [custom_input_directory] [options]"
    echo "Options:"
    echo "  -d, --dropbox        Use Dropbox default input directory"
    echo "  -i, --icloud         Use iCloud default input directory"
    echo "  -wd, --workdocs      Use WorkDocs default input directory"
    echo "  -b, --box            Use Box.com default input directory"
    echo "  -m, --modifiers      Include keyboard modifier key settings"
    echo "  -h, --help           Show this help message"
    echo "If no option is provided, ~/.config/defaults will be used."
    exit 0
}

# Initialize input_dir to the default directory
input_dir="$default_dir"

# Parse command-line options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--dropbox)
            input_dir="$dropbox_dir"
            shift
            ;;
        -i|--icloud)
            input_dir="$icloud_dir"
            shift
            ;;
        -wd|--workdocs)
            input_dir="$workdocs_dir"
            shift
            ;;
        -b|--box)
            input_dir="$box_dir"
            shift
            ;;
        -m|--modifiers)
            import_modifier_keys=true
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            # If the argument is a valid directory, treat it as a custom directory
            if [[ -d "$1" ]]; then
                input_dir="$1"
                shift
            else
                echo "Invalid option or directory: $1"
                show_help
            fi
            ;;
    esac
done

# Display the input directory being used
echo "Using input directory: $input_dir"

# Check if directory exists
if [ ! -d "$input_dir" ]; then
    echo "The directory $input_dir does not exist."
    exit 1
fi

# Initialize a counter for the number of files imported
file_count=0

# Loop through all plist files in the directory
for plist_file in "$input_dir"/*.plist; do
    if [ -f "$plist_file" ]; then
        # Extract the domain from the filename
        domain=$(basename "$plist_file" .plist | tr '_' '.')

        # Import the plist file for the domain
        defaults import "$domain" "$plist_file"

        echo "Imported $domain from $plist_file"
        file_count=$((file_count + 1)) # Increment the file counter
    fi
done

# Import modifier key settings if requested
if [ "$import_modifier_keys" = true ]; then
    echo "Importing keyboard modifier key settings..."
    
    # Check if the modifier_keys directory exists
    if [ -d "$input_dir/modifier_keys" ]; then
        # Get the current machine UUID
        current_uuid=$(ioreg -ad2 -c IOPlatformExpertDevice | xmllint --xpath '//key[.="IOPlatformUUID"]/following-sibling::*[1]/text()' - 2>/dev/null)
        
        if [ -z "$current_uuid" ]; then
            echo "Failed to get machine UUID, using alternative method..."
            # Alternative method if xmllint fails
            current_uuid=$(ioreg -rd1 -c IOPlatformExpertDevice | grep -o '"IOPlatformUUID" = "\([^"]*\)"' | awk -F'"' '{print $4}')
        fi
        
        if [ -n "$current_uuid" ]; then
            # Look for the .GlobalPreferences file
            for glob_pref in "$input_dir/modifier_keys"/.GlobalPreferences.*.plist; do
                if [ -f "$glob_pref" ]; then
                    # Check source UUID vs current UUID
                    source_uuid=$(basename "$glob_pref" | sed -E 's/\.GlobalPreferences\.(.*)\.plist/\1/')
                    
                    # Create target file path
                    target_file="$HOME/Library/Preferences/ByHost/.GlobalPreferences.$current_uuid.plist"
                    
                    echo "Backing up current modifier keys settings..."
                    # Backup current settings if they exist
                    if [ -f "$target_file" ]; then
                        backup_file="$target_file.backup.$(date +%Y%m%d%H%M%S)"
                        cp "$target_file" "$backup_file"
                        echo "Backed up current settings to $backup_file"
                    fi
                    
                    # Extract just the modifier key settings using plutil
                    echo "Extracting modifier key mappings from source file..."
                    temp_plist=$(mktemp)
                    
                    # Get all modifier key mapping entries
                    plutil -extract "com.apple.keyboard.modifiermapping" xml1 -o "$temp_plist" "$glob_pref" 2>/dev/null
                    
                    if [ $? -ne 0 ]; then
                        echo "No direct modifier mapping found, looking for keyboard-specific mappings..."
                        # Try to find any keys that match the pattern
                        for key in $(plutil -p "$glob_pref" | grep "com.apple.keyboard.modifiermapping" | awk -F': ' '{print $1}' | sed 's/"//g'); do
                            echo "Found modifier mapping: $key"
                            # Extract this specific key
                            plutil -extract "$key" xml1 -o - "$glob_pref" >> "$temp_plist" 2>/dev/null
                        done
                    fi
                    
                    if [ -s "$temp_plist" ]; then
                        echo "Applying modifier key settings to $target_file"
                        
                        # If target doesn't exist, create an empty plist first
                        if [ ! -f "$target_file" ]; then
                            echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\">
<dict>
</dict>
</plist>" > "$target_file"
                        fi
                        
                        # Merge the extracted settings into the target file
                        # Using defaults command to merge the settings
                        defaults import "$HOME/Library/Preferences/ByHost/.GlobalPreferences.$current_uuid" "$temp_plist"
                        
                        echo "Modifier key settings imported successfully"
                        file_count=$((file_count + 1))
                        
                        # Clean up
                        rm "$temp_plist"
                        
                        # Restart cfprefsd to apply changes
                        echo "Restarting preference daemon to apply changes..."
                        killall cfprefsd
                    else
                        echo "No modifier key mappings found in the source file."
                        rm "$temp_plist"
                    fi
                    break
                fi
            done
        else
            echo "Failed to get machine UUID, modifier keys import skipped."
        fi
    else
        echo "Modifier keys directory not found: $input_dir/modifier_keys"
    fi
fi

# Check if no plist files were found
if [ "$file_count" -eq 0 ]; then
    echo "No plist files found in $input_dir."
else
    # Print the final message
    echo -e "\n***\n\nAll imports are complete. $file_count .plist files were imported from $input_dir."
fi
