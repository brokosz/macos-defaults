#!/bin/bash

# Default output directories for various options
default_dir="$HOME/.config/defaults"
dropbox_dir="$HOME/Dropbox/config/defaults"
icloud_dir="$HOME/Library/Mobile Documents/com~apple~CloudDocs/config/defaults"
workdocs_dir="$HOME/Library/CloudStorage/WorkDocsDrive-Documents/config/defaults"
box_dir="$HOME/Library/CloudStorage/Box-Box/config/defaults"  # Box.com default directory
onedrive_dir="$HOME/Library/CloudStorage/OneDrive-Personal/config/defaults"  # OneDrive default directory
mega_dir="$HOME/MEGAsync/config/defaults"  # Mega default directory
googledrive_dir="$HOME/Library/CloudStorage/GoogleDrive-*/config/defaults"  # Google Drive default directory

# Flags
export_modifier_keys=false
dry_run=false
create_backup=true
verbose=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Progress tracking
total_domains=0
processed_domains=0

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

function create_backup_if_exists() {
    local output_dir=$1
    if [[ -d "$output_dir" ]] && [[ $create_backup == true ]]; then
        local backup_dir="${output_dir}.backup.$(date +%Y%m%d_%H%M%S)"
        log_info "Creating backup of existing directory: $backup_dir"
        cp -r "$output_dir" "$backup_dir"
        if [[ $? -eq 0 ]]; then
            log_success "Backup created successfully"
        else
            log_error "Failed to create backup"
            return 1
        fi
    fi
    return 0
}

function get_machine_info() {
    local uuid=$(ioreg -ad2 -c IOPlatformExpertDevice | xmllint --xpath '//key[.="IOPlatformUUID"]/following-sibling::*[1]/text()' - 2>/dev/null)
    if [[ -z "$uuid" ]]; then
        uuid=$(ioreg -rd1 -c IOPlatformExpertDevice | grep -o '"IOPlatformUUID" = "\([^"]*\)"' | awk -F'"' '{print $4}')
    fi
    
    local arch=$(uname -m)
    local os_version=$(sw_vers -productVersion)
    local hostname=$(hostname)
    
    echo "# Machine Information" > "$1/machine_info.txt"
    echo "UUID: $uuid" >> "$1/machine_info.txt"
    echo "Architecture: $arch" >> "$1/machine_info.txt"
    echo "macOS Version: $os_version" >> "$1/machine_info.txt"
    echo "Hostname: $hostname" >> "$1/machine_info.txt"
    echo "Export Date: $(date)" >> "$1/machine_info.txt"
}

# Show help if the user asks for it
function show_help {
    echo "Usage: $0 [custom_output_directory] [options]"
    echo "Options:"
    echo "  -d, --dropbox        Use Dropbox default output directory"
    echo "  -i, --icloud         Use iCloud default output directory"
    echo "  -wd, --workdocs      Use WorkDocs default output directory"
    echo "  -b, --box            Use Box.com default output directory"
    echo "  -od, --onedrive      Use OneDrive default output directory"
    echo "  -gd, --googledrive   Use Google Drive default output directory"
    echo "  -mg, --mega          Use Mega default output directory"
    echo "  -n, --network PATH   Use network path (SMB/AFP/mounted volume)"
    echo "  -m, --modifiers      Include keyboard modifier key settings"
    echo "  --dry-run            Show what would be exported without doing it"
    echo "  --no-backup          Skip creating backup of existing directory"
    echo "  -v, --verbose        Enable verbose output"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -d                Export to Dropbox"
    echo "  $0 -n /Volumes/NAS   Export to mounted network drive"
    echo "  $0 --dry-run -i      Preview what would be exported to iCloud"
    echo ""
    echo "If no option is provided, ~/.config/defaults will be used."
    exit 0
}

# Initialize output_dir to the default directory
output_dir="$default_dir"

# Parse command-line options
selected_service=""
network_path=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--dropbox)
            output_dir="$dropbox_dir"
            selected_service="dropbox"
            shift
            ;;
        -i|--icloud)
            output_dir="$icloud_dir"
            selected_service="icloud"
            shift
            ;;
        -wd|--workdocs)
            output_dir="$workdocs_dir"
            selected_service="workdocs"
            shift
            ;;
        -b|--box)
            output_dir="$box_dir"
            selected_service="box"
            shift
            ;;
        -od|--onedrive)
            output_dir="$onedrive_dir"
            selected_service="onedrive"
            shift
            ;;
        -gd|--googledrive)
            selected_service="googledrive"
            shift
            ;;
        -mg|--mega)
            output_dir="$mega_dir"
            selected_service="mega"
            shift
            ;;
        -n|--network)
            if [[ -z "$2" ]]; then
                log_error "Network path required after -n/--network"
                exit 1
            fi
            network_path="$2"
            output_dir="$2/config/defaults"
            shift 2
            ;;
        -m|--modifiers)
            export_modifier_keys=true
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
        -v|--verbose)
            verbose=true
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

# Validate cloud service if one was selected
if [[ -n "$selected_service" ]]; then
    if ! validate_cloud_service "$selected_service" "$output_dir"; then
        log_error "Cloud service validation failed. Continuing anyway..."
    fi
    # Update output_dir for Google Drive after validation
    if [[ "$selected_service" == "googledrive" ]]; then
        output_dir="$googledrive_dir"
    fi
fi

# Validate network path if specified
if [[ -n "$network_path" ]]; then
    if ! validate_network_path "$network_path"; then
        exit 1
    fi
fi

# Display the output directory being used
log_info "Using output directory: $output_dir"

if [[ $dry_run == true ]]; then
    log_info "DRY RUN MODE - No files will be created"
fi

# Create backup if directory exists and backup is enabled
if [[ $dry_run == false ]]; then
    if ! create_backup_if_exists "$output_dir"; then
        exit 1
    fi
fi

# Create the output directory if it doesn't exist
if [[ ! -d "$output_dir" ]] && [[ $dry_run == false ]]; then
    log_info "Directory $output_dir does not exist, creating it now..."
    mkdir -p "$output_dir"
    if [[ $? -ne 0 ]]; then
        log_error "Failed to create directory: $output_dir"
        exit 1
    fi
fi

# Test write permissions
if [[ $dry_run == false ]]; then
    test_file="$output_dir/.write_test"
    if ! touch "$test_file" 2>/dev/null; then
        log_error "No write permission to directory: $output_dir"
        exit 1
    fi
    rm -f "$test_file"
fi

# Get all defaults domains and count them
log_info "Discovering defaults domains..."
domains=$(defaults domains | tr -d ',' | tr ' ' '\n' | sort)
total_domains=$(echo "$domains" | wc -l | tr -d ' ')

if [[ $verbose == true ]]; then
    log_info "Found $total_domains domains to export"
fi

# Initialize counters
file_count=0
failed_count=0
skipped_count=0

# Create machine info file
if [[ $dry_run == false ]]; then
    get_machine_info "$output_dir"
    log_info "Created machine information file"
fi

log_info "Starting export process..."

# Loop through each domain and export the settings
for domain in $domains; do
    processed_domains=$((processed_domains + 1))
    
    # Show progress
    if [[ $dry_run == false ]]; then
        show_progress $processed_domains $total_domains
    fi
    
    # Replace dots in domain with underscores for file naming
    sanitized_domain=$(echo "$domain" | tr '.' '_')
    output_file="$output_dir/$sanitized_domain.plist"
    
    if [[ $dry_run == true ]]; then
        if [[ $verbose == true ]]; then
            echo "Would export $domain to $output_file"
        fi
        file_count=$((file_count + 1))
        continue
    fi
    
    # Check if domain has any settings
    if ! defaults read "$domain" >/dev/null 2>&1; then
        if [[ $verbose == true ]]; then
            log_warning "Skipping empty domain: $domain"
        fi
        skipped_count=$((skipped_count + 1))
        continue
    fi
    
    # Export the domain settings as a plist file
    if defaults export "$domain" "$output_file" 2>/dev/null; then
        if [[ $verbose == true ]]; then
            log_success "Exported $domain"
        fi
        file_count=$((file_count + 1))
    else
        log_error "Failed to export $domain"
        failed_count=$((failed_count + 1))
    fi
done

# Clear progress line
if [[ $dry_run == false ]]; then
    echo ""
fi

# Export modifier key settings if requested
if [[ $export_modifier_keys == true ]]; then
    log_info "Exporting keyboard modifier key settings..."
    
    if [[ $dry_run == false ]]; then
        # Create a modifier keys directory
        mkdir -p "$output_dir/modifier_keys"
    fi
    
    # Get the UUID for the current machine
    uuid=$(ioreg -ad2 -c IOPlatformExpertDevice | xmllint --xpath '//key[.="IOPlatformUUID"]/following-sibling::*[1]/text()' - 2>/dev/null)
    
    if [[ -z "$uuid" ]]; then
        if [[ $verbose == true ]]; then
            log_info "Using alternative method to get machine UUID..."
        fi
        uuid=$(ioreg -rd1 -c IOPlatformExpertDevice | grep -o '"IOPlatformUUID" = "\([^"]*\)"' | awk -F'"' '{print $4}')
    fi
    
    if [[ -n "$uuid" ]]; then
        # Export ByHost GlobalPreferences
        byhost_file="$HOME/Library/Preferences/ByHost/.GlobalPreferences.$uuid.plist"
        if [[ -f "$byhost_file" ]]; then
            if [[ $dry_run == true ]]; then
                log_info "Would export modifier keys from $byhost_file"
            else
                cp "$byhost_file" "$output_dir/modifier_keys/"
                echo "$uuid" > "$output_dir/modifier_keys/machine_uuid.txt"
                log_success "Exported modifier keys"
            fi
            file_count=$((file_count + 1))
        else
            log_warning "Modifier keys file not found: $byhost_file"
        fi
    else
        log_error "Failed to get machine UUID, modifier keys export skipped."
    fi
fi

# Print the final summary
echo ""
log_info "Export Summary:"
echo "  Total domains processed: $total_domains"
echo "  Successfully exported: $file_count"
if [[ $failed_count -gt 0 ]]; then
    echo "  Failed exports: $failed_count"
fi
if [[ $skipped_count -gt 0 ]]; then
    echo "  Skipped (empty): $skipped_count"
fi

if [[ $dry_run == true ]]; then
    log_info "DRY RUN completed. No files were actually created."
else
    if [[ $export_modifier_keys == true ]]; then
        echo "  Modifier keys: exported"
    fi
    log_success "All exports complete. Files created in: $output_dir"
fi
