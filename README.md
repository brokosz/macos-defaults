# macOS Defaults Export/Import Scripts

This repository contains two bash scripts to export and import macOS defaults (`plist`) files across different locations such as Dropbox, iCloud, Box, WorkDocs, OneDrive, Mega, or a custom directory. These scripts provide flexibility with various storage options or custom paths.

## Scripts

1. **export_defaults.sh**: Exports all macOS defaults into `.plist` files.
2. **import_defaults.sh**: Imports previously exported `.plist` files back into macOS defaults.

### Prerequisites

- These scripts require macOS and the use of the `defaults` command.
- Ensure you have permissions to read/write in the specified directories.

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
- `-mg, --mega` : Use Mega default output directory (`~/MEGAsync/config/defaults`).
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
- `-mg, --mega` : Use Mega default input directory (`~/MEGAsync/config/defaults`).
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

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for more details.
