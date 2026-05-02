# Settings

This document describes the configuration options available in the **Mainline Kernels (Arch Linux)** settings dialog.

## Notifications

### Notify if a major release is available
### Notify if a minor update is available
### Check every [#] [units]
Starts a background process that periodically checks for new kernels in the Arch Linux Archive and sends a desktop notification if a kernel is available that you don't have installed yet.

The monitor is installed in your desktop autostart folder such that it is started in the background any time you log in. It is removed by unselecting both notification checkboxes.

## Filters

### Hide RC and unstable releases
Excludes less stable, "bleeding edge" -rc kernels from the list.

### Hide failed or incomplete builds
Arch Linux Archive occasionally contains builds that are incomplete or failed for certain architectures. If enabled, only builds fully compatible with your native architecture (e.g., %s) will be shown.

### Hide flavors other than "generic"
By default, the tool shows all available flavors. Enable this to only see the standard "generic" kernels.

### Show [#] prior major versions
Defines a threshold value for the oldest major version to include in the display, as an offset from the whatever the current latest version is.

The threshold is whichever is lower:
- The oldest kernel you have installed
- The highest version available minus N

The special value "-1" is also allowed, and means to show all possible kernel versions. With this setting, the initial cache update or Reload may take a long time, but it's usable after that.

## Network

### Internet connection timeout in [##] seconds
The maximum time (in seconds) to wait for the server to respond before giving up.

### Max concurrent downloads [#]
The number of parallel download threads to use (via `aria2c`). Increasing this can speed up downloads on fast connections.

### Verify Checksums
If enabled, the tool will download the official CHECKSUMS file and use the SHA-256 hashes to verify the downloaded packages.

### Keep Packages
Don't delete the `.pkg.tar.zst` files after installing them. This allows to uninstall & reinstall kernels without having to re-download them. The cache is still kept trimmed based on the "prior major versions" setting.

### Keep Cache
Don't trim the cached index files. Instead, maintain a local mirror of the Archive history. This speeds up startup at the cost of some disk space (~20MB).

### Proxy URL
Proxy support via aria2c's `all-proxy` setting. Format: `[http://][USER:PASSWORD@]HOST[:PORT]`

## External Commands

### Arch Linux Archive URL
The base URL for the kernel packages. Default: `https://archive.archlinux.org/packages/l/linux/`

### User Agent String
The HTTP User-Agent header used for requests.

### Superuser Authorization
Command used to gain root permissions for running `pacman` and `mkinitcpio`. Default is `pkexec`.

If you need the command to be embedded within a string rather than appended to the end, you can use `%s`, which will be replaced with the actual command. For example: `su -c "%s"`.

### Terminal Window
Terminal command used to run the installation process. The default `[internal-vte]` uses the built-in terminal window.

If using an external terminal, it must stay in the foreground and block while the command is running. Examples:
- gnome-terminal: `--wait`
- konsole: `--no-fork`
- xfce4-terminal: `--disable-server`
