#!/usr/bin/env bash

packages=(
    qt5-wayland 
    qt5ct
    qt6-wayland 
    qt6ct
    qt5-svg
    qt5-quickcontrols2
    qt5-graphicaleffects
    gtk3 
    polkit-gnome 
    pipewire 
    pipewire-pulse
    wireplumber 
    wl-clipboard 
    cliphist 
    kitty 
    dunst
    waybar
    wofi 
    thunar
    wlogout 
    xdg-desktop-portal-hyprland 
    pamixer 
    pavucontrol 
    brightnessctl 
    bluez 
    bluez-utils 
    blueman 
    network-manager-applet 
    nwg-look
    sddm
)

#software for nvidia GPU only
nvidia_packages=(
    linux-headers 
    nvidia-dkms 
    nvidia-settings 
    libva 
    libva-nvidia-driver-git
)

# set some colors
CNT="[\e[1;36mNOTE\e[0m]"
COK="[\e[1;32mOK\e[0m]"
CER="[\e[1;31mERROR\e[0m]"
CAT="[\e[1;37mATTENTION\e[0m]"
CWR="[\e[1;35mWARNING\e[0m]"
CAC="[\e[1;33mACTION\e[0m]"
INSTLOG="install.log"

######
# functions go here

# function that would show a progress bar to the user
show_progress() {
    while ps | grep $1 &> /dev/null;
    do
        echo -n "."
        sleep 1
    done
    echo -en "Done!\n"
    sleep 0.5
}

# function that will test for a package and if not found it will attempt to install it
install_software() {
    # First lets see if the package is there
    if paru -Q $1 &>> /dev/null ; then
        echo -e "$COK - $1 is already installed."
    else
        # no package found so installing
        echo -en "$CNT - Now installing $1 ."
        paru -S --noconfirm $1 &>> $INSTLOG &
        show_progress $!
        # test to make sure package installed
        if paru -Q $1 &>> /dev/null ; then
            echo -e "\e[1A\e[K$COK - $1 was installed."
        else
            # if this is hit then a package is missing, exit to review log
            echo -e "\e[1A\e[K$CER - $1 install had failed, please check the install.log"
            exit
        fi
    fi
}

# clear the screen
clear

# set some expectations for the user
echo -e "$CNT - You are about to execute a script that would attempt to setup Hyprland."
sleep 1

# attempt to discover if this is a VM or not
echo -e "$CNT - Checking for Physical or VM..."
ISVM=$(hostnamectl | grep Chassis)
echo -e "Using $ISVM"
if [[ $ISVM == *"vm"* ]]; then
    echo -e "$CWR - Please note that VMs are not fully supported and if you try to run this on a Virtual Machine there is a high chance this will fail."
    sleep 1
fi

# give the user an option to exit out
read -rep $'[\e[1;33mACTION\e[0m] - Would you like to continue with the install (y,n) ' CONTINST
if [[ $CONTINST == "Y" || $CONTINST == "y" ]]; then
    echo -e "$CNT - Setup starting..."
    sudo touch /tmp/hypr.tmp
else
    echo -e "$CNT - This script will now exit, no changes were made to your system."
    exit
fi

# find the Nvidia GPU
if lspci -k | grep -A 2 -E "(VGA|3D)" | grep -iq nvidia; then
    ISNVIDIA=true
else
    ISNVIDIA=false
fi

### Disable wifi powersave mode ###
read -rep $'[\e[1;33mACTION\e[0m] - Would you like to disable WiFi powersave? (y,n) ' WIFI
if [[ $WIFI == "Y" || $WIFI == "y" ]]; then
    LOC="/etc/NetworkManager/conf.d/wifi-powersave.conf"
    echo -e "$CNT - The following file has been created $LOC.\n"
    echo -e "[connection]\nwifi.powersave = 2" | sudo tee -a $LOC &>> $INSTLOG
    echo -en "$CNT - Restarting NetworkManager service, Please wait."
    sudo systemctl restart NetworkManager &>> $INSTLOG
    
    #wait for services to restore (looking at you DNS)
    for i in {1..6} 
    do
        echo -n "."
        sleep 1
    done
    echo -en "Done!\n"
    sleep 1
    echo -e "\e[1A\e[K$COK - NetworkManager restart completed."
fi

#### Check for package manager ####
if [ ! -f /sbin/paru ]; then  
    echo -en "$CNT - Configuering paru."
    git clone https://aur.archlinux.org/paru.git &>> $INSTLOG
    cd paru
    makepkg -si --noconfirm &>> ../$INSTLOG &
    show_progress $!
    if [ -f /sbin/paru ]; then
        echo -e "\e[1A\e[K$COK - paru configured"
        cd ..
        
        # update the paru database
        echo -en "$CNT - Updating paru."
        paru -Suy --noconfirm &>> $INSTLOG &
        show_progress $!
        echo -e "\e[1A\e[K$COK - paru updated."
    else
        # if this is hit then a package is missing, exit to review log
        echo -e "\e[1A\e[K$CER - paru install failed, please check the install.log"
        exit
    fi
fi
#
# Install the correct hyprland version
echo -e "$CNT - Installing Hyprland, this may take a while..."   
install_software hyprland
mkdir -p ~/.config/hypr/ > /dev/null
cp -f ./hyprland.conf ~/.config/hypr/
cp -f ./media-binds.conf ~/.config/hypr/
cp -f ./env_var.conf ~/.config/hypr/
cp -f ./xdg-portal-hyprland ~/.config/hypr/

### Install all of the above pacakges ####
# Prep Stage - Bunch of needed items
echo -e "$CNT - Now installing the packages recommended for a proper Hyprland install ..."
for SOFTWR in ${packages[@]}; do
    install_software $SOFTWR 
done

# Setup Nvidia if it was found
if [[ "$ISNVIDIA" == true ]]; then
    echo -e "$CNT You have an NVIDIA GPU. Installing the needed packages and setting up configuration ..."
    for SOFTWR in ${nvidia_packages[@]}; do
        install_software $SOFTWR
    done

    # update config
    sudo sed -i 's/MODULES=()/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
    sudo mkinitcpio -P
    echo -e "options nvidia-drm modeset=1\noptions nvidia NVreg_PreserveVideoMemoryAllocations=1" | sudo tee -a /etc/modprobe.d/nvidia.conf &>> $INSTLOG
    sudo systemctl enable nvidia-suspend 2>> /dev/null
    sudo systemctl enable nvidia-hibernate 2>> /dev/null
    sudo systemctl enable nvidia-resume 2>> /dev/null

    echo -n "source = ~/.config/hypr/env_var_nvidia.conf.conf" >> ~/.config/hypr/hyprland.conf
    cp -f ./env_var_nvidia.conf ~/.config/hypr/
fi

# Start the bluetooth service
echo -e "$CNT - Starting the Bluetooth Service..."
sudo systemctl enable --now bluetooth.service &>> $INSTLOG

# Enable the sddm login manager service
echo -e "$CNT - Enabling the SDDM Service..."
sudo systemctl enable sddm &>> $INSTLOG

# Clean out other portals
echo -e "$CNT - Cleaning out conflicting xdg portals ..."
paru -R --noconfirm xdg-desktop-portal-gnome xdg-desktop-portal-gtk &>> $INSTLOG

echo -en "$CNT - Now installing fonts, this WILL take a while ..."
paru -S --noconfirm ttf-bitstream-vera ttf-croscore ttf-dejavu ttf-droid gnu-free-fonts ttf-ibm-plex ttf-liberation noto-fonts ttf-roboto ttf-ubuntu-font-family ttf-ms-fonts ttf-vista-fonts &>> $INSTLOG
echo -e "\e[1A\e[K$COK - The needed fonts have been installed!"

WLDIR=/usr/share/wayland-sessions
if [ -d "$WLDIR" ]; then
echo -e "$COK - $WLDIR found"
else
echo -e "$CWR - $WLDIR NOT found, creating..."
sudo mkdir $WLDIR
fi 

# stage the .desktop file
sudo cp hyprland.desktop /usr/share/wayland-sessions/
sudo ln -s /usr/bin/kitty /usr/bin/xdg-terminal-exec

### Script is done ###
echo -e "$CNT - Script had completed!"
sleep 1
echo -e "$CNT - Open up a terminal with SUPER + Q. Make sure to read through the default hyprland configuration at ~/.config/hypr/hyprland.conf"
sleep 3
echo -e "$CNT - Additional recommended packages:"
echo "swww / hyprpaper - Wallpaper daemon"
echo "firefox - Web browser"
echo "hyprlock / swaylock / swaylock-effects - Lockscreen manager"
echo "hypridle - Hyprland idle daemon"
echo "vim / neovim - Text editor"
sleep 2
if [[ "$ISNVIDIA" == true ]]; then 
    echo -e "$CAT - We attempted to set up an NVIDIA GPU.
In order for Hyprland to work properly, you must follow the directions in 'https://github.com/korvahannu/arch-nvidia-drivers-installation-guide' as this script was not able to do some of them. The NVIDIA driver that was automatically installed is 'nvidia-dkms', so you can skip the first and second steps.
After that, reboot and you should be good."
    sleep 5
    exit
else
    read -rep $'[\e[1;33mACTION\e[0m] - Would you like to start Hyprland now? (y,n) ' HYP
    if [[ $HYP == "Y" || $HYP == "y" ]]; then
        exec sudo systemctl start sddm &>> $INSTLOG
    else
        exit
    fi
fi

