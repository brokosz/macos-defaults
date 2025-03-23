#!/bin/bash

# Default output directories for various options
default_dir="$HOME/.config/defaults"
dropbox_dir="$HOME/Dropbox/config/defaults"
icloud_dir="$HOME/Library/Mobile Documents/com~apple~CloudDocs/config/defaults"
workdocs_dir="$HOME/Library/CloudStorage/WorkDocsDrive-Documents/config/defaults"
box_dir="$HOME/Library/CloudStorage/Box-Box/config/defaults"  # Box.com default directory

# Flag for exporting modifier keys
export_modifier_keys=false

# Show help if the user asks for it
function show_help {
    echo "Usage: $0 [custom_output_directory] [options]"
    echo "Options:"
    echo "  -d, --dropbox        Use Dropbox default output directory"
    echo "  -i, --icloud         Use iCloud default output directory"
    echo "  -wd, --workdocs      Use WorkDocs default output directory"
    echo "  -b, --box            Use Box.com default output directory"
    echo "  -m, --modifiers      Include keyboard modifier key settings"
    echo "  -h, --help           Show this help message"
    echo "If no option is provided, ~/.config/defaults will be used."
    exit 0
}

# Initialize output_dir to the default directory
output_dir="$default_dir"

# Parse command-line options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--dropbox)
            output_dir="$dropbox_dir"
            shift
            ;;
        -i|--icloud)
            output_dir="$icloud_dir"
            shift
            ;;
        -wd|--workdocs)
            output_dir="$workdocs_dir"
            shift
            ;;
        -b|--box)
            output_dir="$box_dir"
            shift
            ;;
        -m|--modifiers)
            export_modifier_keys=true
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            # If the argument is not a predefined option, treat it as a custom directory
            output_dir="$1"
            shift
            ;;
    esac
done

# Create the custom output directory if it doesn't exist
if [[ ! -d "$output_dir" ]]; then
    echo "Directory $output_dir does not exist, creating it now..."
    mkdir -p "$output_dir"
fi

# Display the output directory being used
echo "Using output directory: $output_dir"

# Get all defaults domains
domains=$(defaults domains | tr -d ',')

# Initialize a counter for the number of files created
file_count=0

# Loop through each domain and export the settings
for domain in $domains; do
    # Replace dots in domain with underscores for file naming
    sanitized_domain=$(echo "$domain" | tr '.' '_')
    output_file="$output_dir/$sanitized_domain.plist"

    # Export the domain settings as a plist file
    defaults export "$domain" "$output_file"

    echo "Exported $domain to $output_file"
    file_count=$((file_count + 1)) # Increment the file counter
done

# Export modifier key settings if requested
if [ "$export_modifier_keys" = true ]; then
    echo "Exporting keyboard modifier key settings..."
    
    # Create a modifier keys directory
    mkdir -p "$output_dir/modifier_keys"
    
    # Get the UUID for the current machine
    uuid=$(ioreg -ad2 -c IOPlatformExpertDevice | xmllint --xpath '//key[.="IOPlatformUUID"]/following-sibling::*[1]/text()' - 2>/dev/null)
    
    if [ -z "$uuid" ]; then
        echo "Failed to get machine UUID, using alternative method..."
        # Alternative method if xmllint fails
        uuid=$(ioreg -rd1 -c IOPlatformExpertDevice | grep -o '"IOPlatformUUID" = "\([^"]*\)"' | awk -F'"' '{print $4}')
    fi
    
    if [ -n "$uuid" ]; then
        # Export ByHost GlobalPreferences
        byhost_file="$HOME/Library/Preferences/ByHost/.GlobalPreferences.$uuid.plist"
        if [ -f "$byhost_file" ]; then
            cp "$byhost_file" "$output_dir/modifier_keys/"
            echo "Exported modifier keys from $byhost_file"
            file_count=$((file_count + 1))
        else
            echo "Modifier keys file not found: $byhost_file"
        fi
        
        # Save the UUID for import reference
        echo "$uuid" > "$output_dir/modifier_keys/machine_uuid.txt"
        echo "Saved machine UUID for reference: $uuid"
    else
        echo "Failed to get machine UUID, modifier keys export skipped."
    fi
fi

# Print the final message
echo -e "\n***\n\nAll exports are complete. $file_count .plist files were created in $output_dir."
