#!/bin/bash

# Default input directories for various options
default_dir="$HOME/.config/defaults"
dropbox_dir="$HOME/Dropbox/config/defaults"
icloud_dir="$HOME/Library/Mobile Documents/com~apple~CloudDocs/config/defaults"
workdocs_dir="$HOME/Library/CloudStorage/WorkDocsDrive-Documents/config/defaults"
box_dir="$HOME/Library/CloudStorage/Box-Box/config/defaults"  # Box.com default directory
onedrive_dir="$HOME/Library/CloudStorage/OneDrive-Personal/config/defaults"  # OneDrive default directory
mega_dir="$HOME/MEGAsync/config/defaults"  # Mega default directory
googledrive_dir="$HOME/Library/CloudStorage/GoogleDrive-*/config/defaults"  # Google Drive default directory

# Flags
import_modifier_keys=false
dry_run=false
create_backup=true
verbose=false
force_import=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Progress tracking
total_files=0
processed_files=0

# Import summary
imported_count=0
failed_count=0
skipped_count=0
changed_domains=()
unchanged_domains=()

# Utility functions
function log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

function log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

function log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

function log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

function show_progress() {
    local current=$1
    local total=$2
    local percent=$((current * 100 / total))
    local bar_length=50
    local filled_length=$((percent * bar_length / 100))
    
    printf "\r${BLUE}Progress:${NC} ["
    printf "%*s" $filled_length | tr ' ' '='
    printf "%*s" $((bar_length - filled_length)) | tr ' ' '-'
    printf "] %d%% (%d/%d)" $percent $current $total
}

function validate_cloud_service() {
    local service=$1
    local path=$2
    
    case $service in
        "dropbox")
            if [[ ! -d "$HOME/Dropbox" ]]; then
                log_warning "Dropbox folder not found. Make sure Dropbox is installed and synced."
                return 1
            fi
            ;;
        "icloud")
            if [[ ! -d "$HOME/Library/Mobile Documents/com~apple~CloudDocs" ]]; then
                log_warning "iCloud Drive not found. Make sure iCloud Drive is enabled."
                return 1
            fi
            ;;
        "onedrive")
            if [[ ! -d "$HOME/Library/CloudStorage/OneDrive-Personal" ]]; then
                log_warning "OneDrive Personal not found. Make sure OneDrive is installed and synced."
                return 1
            fi
            ;;
        "googledrive")
            local gdrive_path=$(find "$HOME/Library/CloudStorage" -name "GoogleDrive-*" -type d 2>/dev/null | head -1)
            if [[ -z "$gdrive_path" ]]; then
                log_warning "Google Drive not found. Make sure Google Drive is installed and synced."
                return 1
            fi
            # Update the path with the actual found path
            googledrive_dir="$gdrive_path/config/defaults"
            ;;
        "mega")
            if [[ ! -d "$HOME/MEGAsync" ]]; then
                log_warning "MEGAsync folder not found. Make sure MEGAsync is installed and synced."
                return 1
            fi
            ;;
    esac
    return 0
}

function validate_network_path() {
    local path=$1
    if [[ $path == smb://* ]] || [[ $path == afp://* ]] || [[ $path == /Volumes/* ]]; then
        if [[ $path == /Volumes/* ]]; then
            if [[ ! -d "$path" ]]; then
                log_error "Network volume not mounted: $path"
                return 1
            fi
        else
            log_info "Network path detected: $path"
            log_warning "Make sure the network share is mounted and accessible"
        fi
    fi
    return 0
}

function create_current_backup() {
    if [[ $create_backup == true ]] && [[ $dry_run == false ]]; then
        local backup_dir="$HOME/.config/defaults_backup_$(date +%Y%m%d_%H%M%S)"
        log_info "Creating backup of current settings: $backup_dir"
        
        mkdir -p "$backup_dir"
        
        # Export current settings
        local domains=$(defaults domains | tr -d ',' | tr ' ' '\n')
        local backup_count=0
        
        for domain in $domains; do
            local sanitized_domain=$(echo "$domain" | tr '.' '_')
            if defaults export "$domain" "$backup_dir/$sanitized_domain.plist" 2>/dev/null; then
                backup_count=$((backup_count + 1))
            fi
        done
        
        log_success "Backed up $backup_count current settings to $backup_dir"
        echo "BACKUP_LOCATION=$backup_dir" > "$backup_dir/restore_info.txt"
    fi
}

function check_machine_compatibility() {
    local input_dir=$1
    local machine_info_file="$input_dir/machine_info.txt"
    
    if [[ ! -f "$machine_info_file" ]]; then
        log_warning "No machine info file found. Settings may not be fully compatible."
        return 0
    fi
    
    local source_arch=$(grep "Architecture:" "$machine_info_file" | cut -d' ' -f2)
    local source_os=$(grep "macOS Version:" "$machine_info_file" | cut -d' ' -f3)
    local current_arch=$(uname -m)
    local current_os=$(sw_vers -productVersion)
    
    if [[ $verbose == true ]]; then
        log_info "Source machine: $source_arch, macOS $source_os"
        log_info "Current machine: $current_arch, macOS $current_os"
    fi
    
    if [[ "$source_arch" != "$current_arch" ]]; then
        log_warning "Architecture mismatch: source ($source_arch) vs current ($current_arch)"
        log_warning "Some settings may not work correctly"
    fi
    
    # Check major version compatibility
    local source_major=$(echo "$source_os" | cut -d'.' -f1)
    local current_major=$(echo "$current_os" | cut -d'.' -f1)
    
    if [[ "$source_major" != "$current_major" ]]; then
        log_warning "Major macOS version mismatch: source ($source_os) vs current ($current_os)"
        log_warning "Some settings may not be compatible"
    fi
}

function compare_settings() {
    local domain=$1
    local plist_file=$2
    
    # Get current settings for domain
    local current_settings=$(mktemp)
    if defaults export "$domain" "$current_settings" 2>/dev/null; then
        if cmp -s "$plist_file" "$current_settings"; then
            rm "$current_settings"
            return 1  # No changes needed
        fi
    fi
    rm -f "$current_settings"
    return 0  # Changes needed
}

# Show help if the user asks for it
function show_help {
    echo "Usage: $0 [custom_input_directory] [options]"
    echo "Options:"
    echo "  -d, --dropbox        Use Dropbox default input directory"
    echo "  -i, --icloud         Use iCloud default input directory"
    echo "  -wd, --workdocs      Use WorkDocs default input directory"
    echo "  -b, --box            Use Box.com default input directory"
    echo "  -od, --onedrive      Use OneDrive default input directory"
    echo "  -gd, --googledrive   Use Google Drive default input directory"
    echo "  -mg, --mega          Use Mega default input directory"
    echo "  -n, --network PATH   Use network path (SMB/AFP/mounted volume)"
    echo "  -m, --modifiers      Include keyboard modifier key settings"
    echo "  --dry-run            Show what would be imported without doing it"
    echo "  --no-backup          Skip creating backup of current settings"
    echo "  --force              Import all settings even if unchanged"
    echo "  -v, --verbose        Enable verbose output"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -d                Import from Dropbox"
    echo "  $0 -n /Volumes/NAS   Import from mounted network drive"
    echo "  $0 --dry-run -i      Preview what would be imported from iCloud"
    echo ""
    echo "If no option is provided, ~/.config/defaults will be used."
    exit 0
}

# Initialize input_dir to the default directory
input_dir="$default_dir"

# Parse command-line options
selected_service=""
network_path=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--dropbox)
            input_dir="$dropbox_dir"
            selected_service="dropbox"
            shift
            ;;
        -i|--icloud)
            input_dir="$icloud_dir"
            selected_service="icloud"
            shift
            ;;
        -wd|--workdocs)
            input_dir="$workdocs_dir"
            selected_service="workdocs"
            shift
            ;;
        -b|--box)
            input_dir="$box_dir"
            selected_service="box"
            shift
            ;;
        -od|--onedrive)
            input_dir="$onedrive_dir"
            selected_service="onedrive"
            shift
            ;;
        -gd|--googledrive)
            selected_service="googledrive"
            shift
            ;;
        -mg|--mega)
            input_dir="$mega_dir"
            selected_service="mega"
            shift
            ;;
        -n|--network)
            if [[ -z "$2" ]]; then
                log_error "Network path required after -n/--network"
                exit 1
            fi
            network_path="$2"
            input_dir="$2/config/defaults"
            shift 2
            ;;
        -m|--modifiers)
            import_modifier_keys=true
            shift
            ;;
        --dry-run)
            dry_run=true
            shift
            ;;
        --no-backup)
            create_backup=false
            shift
            ;;
        --force)
            force_import=true
            shift
            ;;
        -v|--verbose)
            verbose=true
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
                log_error "Invalid option or directory: $1"
                show_help
            fi
            ;;
    esac
done

# Validate cloud service if one was selected
if [[ -n "$selected_service" ]]; then
    if ! validate_cloud_service "$selected_service" "$input_dir"; then
        log_error "Cloud service validation failed. Continuing anyway..."
    fi
    # Update input_dir for Google Drive after validation
    if [[ "$selected_service" == "googledrive" ]]; then
        input_dir="$googledrive_dir"
    fi
fi

# Validate network path if specified
if [[ -n "$network_path" ]]; then
    if ! validate_network_path "$network_path"; then
        exit 1
    fi
fi

# Display the input directory being used
log_info "Using input directory: $input_dir"

if [[ $dry_run == true ]]; then
    log_info "DRY RUN MODE - No settings will be changed"
fi

# Check if directory exists
if [[ ! -d "$input_dir" ]]; then
    log_error "The directory $input_dir does not exist."
    exit 1
fi

# Check machine compatibility
check_machine_compatibility "$input_dir"

# Create backup of current settings
create_current_backup

# Count plist files
total_files=$(find "$input_dir" -name "*.plist" -not -path "*/modifier_keys/*" | wc -l | tr -d ' ')

if [[ $total_files -eq 0 ]]; then
    log_error "No plist files found in $input_dir"
    exit 1
fi

log_info "Found $total_files plist files to process"

log_info "Starting import process..."

# Loop through all plist files in the directory
for plist_file in "$input_dir"/*.plist; do
    if [[ -f "$plist_file" ]]; then
        processed_files=$((processed_files + 1))
        
        # Show progress
        if [[ $dry_run == false ]]; then
            show_progress $processed_files $total_files
        fi
        
        # Extract the domain from the filename
        domain=$(basename "$plist_file" .plist | tr '_' '.')
        
        if [[ $dry_run == true ]]; then
            if [[ $verbose == true ]]; then
                echo "Would import $domain from $plist_file"
            fi
            imported_count=$((imported_count + 1))
            continue
        fi
        
        # Check if settings have changed (unless force import is enabled)
        if [[ $force_import == false ]]; then
            if ! compare_settings "$domain" "$plist_file"; then
                if [[ $verbose == true ]]; then
                    log_info "Skipping $domain (no changes)"
                fi
                unchanged_domains+=("$domain")
                skipped_count=$((skipped_count + 1))
                continue
            fi
        fi
        
        # Import the plist file for the domain
        if defaults import "$domain" "$plist_file" 2>/dev/null; then
            if [[ $verbose == true ]]; then
                log_success "Imported $domain"
            fi
            changed_domains+=("$domain")
            imported_count=$((imported_count + 1))
        else
            log_error "Failed to import $domain"
            failed_count=$((failed_count + 1))
        fi
    fi
done

# Clear progress line
if [[ $dry_run == false ]]; then
    echo ""
fi

# Import modifier key settings if requested
if [[ $import_modifier_keys == true ]]; then
    log_info "Processing keyboard modifier key settings..."
    
    # Check if the modifier_keys directory exists
    if [[ -d "$input_dir/modifier_keys" ]]; then
        # Get the current machine UUID
        current_uuid=$(ioreg -ad2 -c IOPlatformExpertDevice | xmllint --xpath '//key[.="IOPlatformUUID"]/following-sibling::*[1]/text()' - 2>/dev/null)
        
        if [[ -z "$current_uuid" ]]; then
            if [[ $verbose == true ]]; then
                log_info "Using alternative method to get machine UUID..."
            fi
            current_uuid=$(ioreg -rd1 -c IOPlatformExpertDevice | grep -o '"IOPlatformUUID" = "\([^"]*\)"' | awk -F'"' '{print $4}')
        fi
        
        if [[ -n "$current_uuid" ]]; then
            # Look for the .GlobalPreferences file
            for glob_pref in "$input_dir/modifier_keys"/.GlobalPreferences.*.plist; do
                if [[ -f "$glob_pref" ]]; then
                    source_uuid=$(basename "$glob_pref" | sed -E 's/\.GlobalPreferences\.(.*)\.plist/\1/')
                    target_file="$HOME/Library/Preferences/ByHost/.GlobalPreferences.$current_uuid.plist"
                    
                    if [[ $dry_run == true ]]; then
                        log_info "Would import modifier keys from $glob_pref"
                        log_info "Source UUID: $source_uuid, Target UUID: $current_uuid"
                        imported_count=$((imported_count + 1))
                        break
                    fi
                    
                    # Backup current settings if they exist
                    if [[ -f "$target_file" ]] && [[ $create_backup == true ]]; then
                        backup_file="$target_file.backup.$(date +%Y%m%d%H%M%S)"
                        cp "$target_file" "$backup_file"
                        if [[ $verbose == true ]]; then
                            log_info "Backed up current modifier keys to $backup_file"
                        fi
                    fi
                    
                    # Extract modifier key settings
                    temp_plist=$(mktemp)
                    
                    # Get all modifier key mapping entries
                    if plutil -extract "com.apple.keyboard.modifiermapping" xml1 -o "$temp_plist" "$glob_pref" 2>/dev/null; then
                        if [[ -s "$temp_plist" ]]; then
                            # If target doesn't exist, create an empty plist first
                            if [[ ! -f "$target_file" ]]; then
                                echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\">
<dict>
</dict>
</plist>" > "$target_file"
                            fi
                            
                            # Merge the settings
                            if defaults import "$HOME/Library/Preferences/ByHost/.GlobalPreferences.$current_uuid" "$temp_plist" 2>/dev/null; then
                                log_success "Imported modifier key settings"
                                imported_count=$((imported_count + 1))
                                
                                # Restart cfprefsd to apply changes
                                if [[ $verbose == true ]]; then
                                    log_info "Restarting preference daemon..."
                                fi
                                killall cfprefsd 2>/dev/null
                            else
                                log_error "Failed to import modifier key settings"
                                failed_count=$((failed_count + 1))
                            fi
                        else
                            log_warning "No modifier key mappings found in source file"
                        fi
                    else
                        log_warning "Could not extract modifier key mappings from source file"
                    fi
                    
                    rm -f "$temp_plist"
                    break
                fi
            done
        else
            log_error "Failed to get machine UUID, modifier keys import skipped"
        fi
    else
        log_warning "Modifier keys directory not found: $input_dir/modifier_keys"
    fi
fi

# Print detailed import summary
echo ""
log_info "Import Summary:"
echo "  Total files processed: $total_files"
echo "  Successfully imported: $imported_count"
if [[ $failed_count -gt 0 ]]; then
    echo "  Failed imports: $failed_count"
fi
if [[ $skipped_count -gt 0 ]]; then
    echo "  Skipped (unchanged): $skipped_count"
fi

if [[ $dry_run == true ]]; then
    log_info "DRY RUN completed. No settings were actually changed."
else
    if [[ $import_modifier_keys == true ]]; then
        echo "  Modifier keys: processed"
    fi
    
    # Show changed domains if verbose
    if [[ $verbose == true ]] && [[ ${#changed_domains[@]} -gt 0 ]]; then
        echo ""
        log_info "Changed domains:"
        for domain in "${changed_domains[@]}"; do
            echo "  - $domain"
        done
    fi
    
    # Show unchanged domains if verbose and not forced
    if [[ $verbose == true ]] && [[ $force_import == false ]] && [[ ${#unchanged_domains[@]} -gt 0 ]]; then
        echo ""
        log_info "Unchanged domains (skipped):"
        for domain in "${unchanged_domains[@]}"; do
            echo "  - $domain"
        done
    fi
    
    if [[ $imported_count -gt 0 ]]; then
        log_success "Import completed successfully!"
        log_info "You may need to restart applications for changes to take effect."
    else
        log_info "No changes were needed."
    fi
fi
