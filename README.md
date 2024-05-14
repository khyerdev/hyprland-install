# Arch Linux Hyprland Installer

This script is specific to Arch Linux and its derivatives. Heres how to use it:

1. Make sure base-devel, git, sudo, and networkmanager are installed, and that your NetworkManager.service is active
2. ```
   git clone https://github.com/khyerdev/hyprland-install
   cd hyprland-install
   ```
3. (This may solve some issues)
   ```
   chmod -R 755 .
   chmod 777 install.sh
   chown -R $USER:$USER .
   ```
4. Run `./install.sh`, follow its directions, and let it do its thing.
