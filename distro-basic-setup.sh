#!/bin/bash

# CONFIG
# ______


# Username of your normal user (not root)
readonly USERNAME="rmw"
# Custom host file (which blocks ads) 
readonly HOSTS="https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"

# The email address which you use for git,
# I am lazy/clever so I use a grep but you can use a regular email address
readonly GIT_EMAIL=$(wget -qO- https://gitlab.com/RobinWils \
                         | grep -o '[[:alnum:]+\.\_\-]*@[[:alnum:]+\.\_\-]*' \
                         | tail -1)

# Keybindings
# Replacing caps with ctrl,
# keep this empty if you don't want any new Keybindings
readonly XKBOPTIONS="ctrl:nocaps"
# GRUB
readonly HIDE_GRUB=true
# Name in grub menu
readonly GRUB_DISTRIBUTOR="Devuan"
# Install virtualbox
readonly INSTALL_VBOX=true
readonly VBOX_PACKAGE="virtualbox-6.0"
# Install Jetbrains (intellij and rider)
# I need this for college
readonly INSTALL_JETBRAINS=true
readonly INTELLIJ_TAR="https://download.jetbrains.com/idea/ideaIU-2019.1.2.tar.gz"
readonly RIDER_TAR="https://download.jetbrains.com/rider/JetBrains.Rider-2019.1.1.tar.gz"
# Install keepassxc
readonly INSTALL_KEEPASSXC=true
readonly KEEPASSXC_DEB="https://github.com/magkopian/keepassxc-debian/releases/download/2.3.4-1/keepassxc_2.3.4-1_amd64_stable_stretch.deb"

# APT
# Apt will remove these packages
readonly APT_PACKAGES_TO_REMOVE="bluetooth bluez mousepad xfce4-goodies 
laptop-detect popularity-contest vim-common vim-tiny xxd xfce4-terminal 
xfce4-notes xfce4-notes-plugin vlc ristretto xsane xarchiver quodlibet 
evince"
# Apt will install these packages
readonly APT_PACKAGES="acpi sct emacs25 maim mplayer rsync fonts-hack-ttf qmmp 
blackbird-gtk-theme moka-icon-theme htop zip kdenlive git slop baobab"


# SCRIPT
# ______


if [ "$EUID" -ne 0 ]
then echo "You need to be root to execute this script."
     exit 1
fi

# Do not show dialogs during the install
export DEBIAN_FRONTEND=noninteractive

echo "Removing apt packages..."
apt-get -yqq purge $APT_PACKAGES_TO_REMOVE &> /dev/null
apt-get -yqq autoremove purge &> /dev/null

echo "Installing apt packages..."
apt-get -yqq --no-install-recommends install $APT_PACKAGES &> /dev/null

echo "Updating packages..."
apt-get update &> /dev/null
apt-get -yqq dist-upgrade &> /dev/null
apt-get -yqq upgrade &> /dev/null

if [[ $INSTALL_JETBRAINS = true ]];
then
    echo "Installing Jetbrains IDE's..."
    wget -O /tmp/idea.tar.gz $INTELLIJ_TAR &> /dev/null
    tar -xvf /tmp/idea.tar.gz -C /opt/ && mv /opt/*idea* /opt/idea &> /dev/null
    ln -sf /opt/idea/bin/idea.sh /usr/local/bin/idea
    rm -rf /tmp/idea.tar.gz
    
    wget -O /tmp/rider.tar.gz $RIDER_TAR &> /dev/null
    tar -xvf /tmp/rider.tar.gz -C /opt/ && mv /opt/*Rider* /opt/rider &> /dev/null
    ln -sf /opt/rider/bin/rider.sh /usr/local/bin/rider
    rm -rf /tmp/rider.tar.gz
    echo "Installing dotnet-core and maven..."
    apt-get -yqq \
            --no-install-recommends install apt-transport-https dirmngr \
            gnupg ca-certificates maven &> /dev/null
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 \
            --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF &> /dev/null
    echo "deb https://download.mono-project.com/repo/debian stable-stretch main" \
        | tee /etc/apt/sources.list.d/mono-official-stable.list &> /dev/null
    apt-get update &> /dev/null
    apt-get -yqq --no-install-recommends install mono-complete &> /dev/null
fi

if [[ $INSTALL_KEEPASSXC = true ]];
then
   wget -O /tmp/keepassxc.deb $KEEPASSXC_DEB &> /dev/null
   dpkg -i /tmp/keepassxc.deb &> /dev/null
   apt-get -yqq --fix-broken-install install &> /dev/null
    echo "Installing keepassxc..."
fi    

echo "Configuring git..."
git config --global core.editor emacs
git config --global user.email $GIT_EMAIL
git config --global user.name $GIT_EMAIL
cp -rf  ~/.gitconfig /home/$USERNAME/.gitconfig

echo "Configuring emacs..."
wget \
    -O ~/.emacs https://gitlab.com/RobinWils/dotfiles/raw/master/emacs/.emacs \
    -q &> /dev/null
cp -rf ~/.emacs /home/$USERNAME/.emacs
mkdir ~/.emacs.d
wget \
    -O ~/.emacs.d/emacs-init.org \
    https://gitlab.com/RobinWils/dotfiles/raw/master/emacs/emacs-init.org \
    -q &> /dev/null
cp -rf ~/.emacs.d/emacs-init.org /home/$USERNAME/.emacs.d/emacs-init.org

echo "Configuring green on black terminal colors..."
touch ~/.Xdefaults
echo "xterm*background: black" >> ~/.Xdefaults
echo "xterm*foreground: green" >> ~/.Xdefaults
cp -rf ~/.Xdefaults /home/$USERNAME/.Xdefaults

if [[ $HIDE_GRUB = true ]];
then
    echo "Updating grub..."
    /bin/cat <<EOM >/etc/default/grub
GRUB_DEFAULT=0
GRUB_HIDDEN_TIMEOUT=0
GRUB_HIDDEN_TIMEOUT_QUIET=true
GRUB_TIMEOUT=0
GRUB_DISTRIBUTOR="$GRUB_DISTRIBUTOR"
GRUB_CMDLINE_LINUX_DEFAULT="quiet"
GRUB_CMDLINE_LINUX=""
EOM
    update-grub &> /dev/null
fi

[ -z "$XKBOPTIONS" ] || (echo "Configuring keybindings..." \
&& sed -i "/XKBOPTIONS/c\XKBOPTIONS=\"$XKBOPTIONS\"" \
/etc/default/keyboard)

if [[ $INSTALL_VBOX = true ]];
then
echo "Installing virtualbox..."
echo "deb http://download.virtualbox.org/virtualbox/debian stretch contrib" >> /etc/apt/sources.list &> /dev/null
wget -q -O- https://www.virtualbox.org/download/oracle_vbox_2016.asc \
    | apt-key add &>/dev/null
apt-get update &>/dev/null
apt-get -yqq install $VBOX_PACKAGE &>/dev/null 
fi

echo "Replacing the default host file..."
wget -O /etc/hosts $HOSTS -q &> /dev/null
# Add hostname to hosts file since some programs depend on this line.
sed -i "/^127.0.0.1\\ localhost.localdomain/i 127.0.0.1\\ $HOSTNAME" /etc/hosts

echo "Autoremove unneeded packages..."
apt-get -yqq autoremove &> /dev/null

# TODO: XFCE configuration
# /home/rmw/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings

echo -e "\n\nInstallation complete, please reboot."