# macOS Defaults Export/Import Scripts

This repository contains two enhanced bash scripts to export and import macOS defaults (`plist`) files across different locations such as Dropbox, iCloud, Box, WorkDocs, OneDrive, Mega, Google Drive, network drives, or custom directories. These scripts provide flexibility with various storage options, comprehensive error handling, progress tracking, and cross-machine compatibility features.

## Scripts

1. **export_defaults.sh**: Exports all macOS defaults into `.plist` files.
2. **import_defaults.sh**: Imports previously exported `.plist` files back into macOS defaults.

## Features

### Enhanced Safety & Error Handling
- **Automatic backups**: Creates timestamped backups before importing
- **Cloud service validation**: Checks if cloud storage apps are installed and synced
- **Write permission testing**: Validates directory access before operations
- **Dry run mode**: Preview operations without making changes
- **Cross-machine compatibility**: Handles architecture and macOS version differences

### Progress & Feedback
- **Real-time progress bars**: Visual progress tracking during operations
- **Detailed summaries**: Comprehensive reports of what was changed
- **Verbose logging**: Optional detailed output for troubleshooting
- **Color-coded messages**: Clear visual feedback with info, warning, and error messages

### Storage Options
- **Multiple cloud services**: Dropbox, iCloud, OneDrive, Google Drive, Mega, Box, WorkDocs
- **Network drives**: Support for SMB, AFP, and mounted volumes
- **Custom directories**: Use any local or network path
- **Automatic path detection**: Finds cloud service folders automatically

### Smart Import Features
- **Change detection**: Only imports settings that have actually changed
- **Machine information tracking**: Records source machine details for compatibility
- **Selective processing**: Skip unchanged domains to speed up imports
- **Force import option**: Override change detection when needed

### Prerequisites

- These scripts require macOS and the use of the `defaults` command.
- Ensure you have permissions to read/write in the specified directories.
- For cloud services, make sure the respective apps are installed and synced.

---

## Warning

### `import_defaults.sh`

Be cautious when running the `import_defaults.sh` script, especially on systems where defaults are already set. The script will **overwrite any existing settings** for the domains specified in the `.plist` files being imported. This means:

- **Existing system or app settings may be replaced** with the values in the `.plist` files.
- There is **no undo option**, so ensure that you have a backup of your current settings before running the script.

It's a good idea to export the current defaults using `export_defaults.sh` before importing new settings, to have a reference or backup of your current configuration.

---

## Installation and Setup

1. Clone the repository from GitHub:

    ```bash
    git clone https://github.com/brokosz/macos-defaults-scripts.git
    ```

2. Navigate into the cloned repository:

    ```bash
    cd macos-defaults-scripts
    ```

3. Make the scripts executable:

    ```bash
    chmod +x export_defaults.sh
    chmod +x import_defaults.sh
    ```

4. (Optional) Move the scripts to a directory in your `$PATH` to use them globally:

    ```bash
    sudo mv export_defaults.sh /usr/local/bin/export_defaults
    sudo mv import_defaults.sh /usr/local/bin/import_defaults
    ```

    This allows you to run the scripts from anywhere using `export_defaults` and `import_defaults`.

---

## Usage

### export_defaults.sh

The `export_defaults.sh` script exports macOS defaults to the specified directory. If no directory is specified, it defaults to `~/.config/defaults`. **If a custom directory is specified but doesn't exist, the script will create it automatically.**

```bash
./export_defaults.sh [custom_output_directory] [options]
```

#### Options

- `-d, --dropbox` : Use Dropbox default output directory (`~/Dropbox/config/defaults`).
- `-i, --icloud` : Use iCloud default output directory (`~/Library/Mobile Documents/com~apple~CloudDocs/config/defaults`).
- `-wd, --workdocs` : Use WorkDocs default output directory (`~/Library/CloudStorage/WorkDocsDrive-Documents/config/defaults`).
- `-b, --box` : Use Box.com default output directory (`~/Library/CloudStorage/Box-Documents/config/defaults`).
- `-od, --onedrive` : Use OneDrive default output directory (`~/Library/CloudStorage/OneDrive-Personal/config/defaults`).
- `-gd, --googledrive` : Use Google Drive default output directory (`~/Library/CloudStorage/GoogleDrive-*/config/defaults`).
- `-mg, --mega` : Use Mega default output directory (`~/MEGAsync/config/defaults`).
- `-n, --network PATH` : Use network path (SMB/AFP/mounted volume).
- `-m, --modifiers` : Include keyboard modifier key settings.
- `--dry-run` : Show what would be exported without doing it.
- `--no-backup` : Skip creating backup of existing directory.
- `-v, --verbose` : Enable verbose output.
- `-h, --help` : Display help information.

#### Example Usages:

- Export to Dropbox:
  ```bash
  ./export_defaults.sh -d
  ```

- Export to iCloud:
  ```bash
  ./export_defaults.sh -i
  ```

- Export to OneDrive:
  ```bash
  ./export_defaults.sh -od
  ```

- Export to Mega:
  ```bash
  ./export_defaults.sh -mg
  ```

- Export to Google Drive:
  ```bash
  ./export_defaults.sh -gd
  ```

- Export to a network drive:
  ```bash
  ./export_defaults.sh -n /Volumes/NetworkDrive
  ```

- Preview export to iCloud (dry run):
  ```bash
  ./export_defaults.sh --dry-run -i
  ```

- Export with verbose output and modifier keys:
  ```bash
  ./export_defaults.sh -d -m -v
  ```

- Export to a custom directory (if it doesn’t exist, it will be created):
  ```bash
  ./export_defaults.sh /path/to/custom/dir
  ```

---

### import_defaults.sh

The `import_defaults.sh` script imports macOS defaults from `.plist` files in the specified directory. If no directory is specified, it defaults to `~/.config/defaults`.

```bash
./import_defaults.sh [custom_input_directory] [options]
```

#### Options

- `-d, --dropbox` : Use Dropbox default input directory (`~/Dropbox/config/defaults`).
- `-i, --icloud` : Use iCloud default input directory (`~/Library/Mobile Documents/com~apple~CloudDocs/config/defaults`).
- `-wd, --workdocs` : Use WorkDocs default input directory (`~/Library/CloudStorage/WorkDocsDrive-Documents/config/defaults`).
- `-b, --box` : Use Box.com default input directory (`~/Library/CloudStorage/Box-Documents/config/defaults`).
- `-od, --onedrive` : Use OneDrive default input directory (`~/Library/CloudStorage/OneDrive-Personal/config/defaults`).
- `-gd, --googledrive` : Use Google Drive default input directory (`~/Library/CloudStorage/GoogleDrive-*/config/defaults`).
- `-mg, --mega` : Use Mega default input directory (`~/MEGAsync/config/defaults`).
- `-n, --network PATH` : Use network path (SMB/AFP/mounted volume).
- `-m, --modifiers` : Include keyboard modifier key settings.
- `--dry-run` : Show what would be imported without doing it.
- `--no-backup` : Skip creating backup of current settings.
- `--force` : Import all settings even if unchanged.
- `-v, --verbose` : Enable verbose output.
- `-h, --help` : Display help information.

#### Example Usages:

- Import from Dropbox:
  ```bash
  ./import_defaults.sh -d
  ```

- Import from iCloud:
  ```bash
  ./import_defaults.sh -i
  ```

- Import from OneDrive:
  ```bash
  ./import_defaults.sh -od
  ```

- Import from Mega:
  ```bash
  ./import_defaults.sh -mg
  ```

- Import from OneDrive:
  ```bash
  ./import_defaults.sh -od
  ```

- Import from Mega:
  ```bash
  ./import_defaults.sh -mg
  ```

- Import from Google Drive:
  ```bash
  ./import_defaults.sh -gd
  ```

- Import from a network drive:
  ```bash
  ./import_defaults.sh -n /Volumes/NetworkDrive
  ```

- Preview import from iCloud (dry run):
  ```bash
  ./import_defaults.sh --dry-run -i
  ```

- Force import all settings with verbose output:
  ```bash
  ./import_defaults.sh --force -v -d
  ```

- Import from a custom directory:
  ```bash
  ./import_defaults.sh /path/to/custom/dir
  ```

---

## Custom Path

You can specify a custom path directly. The script will automatically detect if the first argument is a valid directory path and use it for the operation. **If the custom directory doesn't exist, it will be created automatically.**

### Example:

```bash
./export_defaults.sh /path/to/custom/dir
./import_defaults.sh /path/to/custom/dir
```

---

## Advanced Usage

### Network Drives

The scripts support various network storage options:

- **SMB shares**: `./export_defaults.sh -n /Volumes/MyNAS`
- **AFP shares**: `./export_defaults.sh -n /Volumes/AppleShare`
- **Mounted volumes**: Any path under `/Volumes/`

Make sure the network drive is mounted before running the scripts.

### Cross-Machine Compatibility

When importing settings between different machines, the scripts automatically:

- Check architecture compatibility (Intel vs Apple Silicon)
- Warn about macOS version differences
- Handle machine-specific UUIDs for modifier keys
- Create machine information files for reference

### Backup and Recovery

- **Automatic backups**: Current settings are backed up before import
- **Timestamped backups**: Each backup has a unique timestamp
- **Manual restore**: Use the backup files to restore previous settings

Example backup location: `~/.config/defaults_backup_20241201_143022/`

---

## Troubleshooting

### Common Issues

**Cloud service not found**
- Make sure the cloud storage app is installed and synced
- Check that the sync folder exists in the expected location

**Permission denied**
- Ensure you have write permissions to the target directory
- For network drives, check your network credentials

**Import fails silently**
- Use `--verbose` flag to see detailed output
- Check if the plist files are valid using `plutil -lint filename.plist`

**Settings don't take effect**
- Some applications need to be restarted
- Try logging out and back in for system-wide settings
- Use `killall cfprefsd` to refresh the preferences daemon

### Getting Help

Use the `--help` flag for detailed usage information:
```bash
./export_defaults.sh --help
./import_defaults.sh --help
```

Use `--dry-run` to preview operations without making changes:
```bash
./import_defaults.sh --dry-run -i
```

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for more details.
