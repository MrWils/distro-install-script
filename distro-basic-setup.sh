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

# GRUB
# Hide grub
readonly HIDE_GRUB=true
# Name in grub menu
readonly GRUB_DISTRIBUTOR="Devuan"
# Install virtualbox
readonly INSTALL_VBOX=true
readonly VBOX_PACKAGE="virtualbox-6.0"

# APT
# Apt will remove these packages
readonly APT_PACKAGES_TO_REMOVE="bluetooth bluez mousepad xfce4-goodies laptop-detect popularity-contest \
vim-common vim-tiny xxd xfce4-terminal xfce4-notes xfce4-notes-plugin vlc ristretto xsane xarchiver"
# Apt will install these packages
readonly APT_PACKAGES="acpi sct emacs25 maim mplayer rsync keepass2 fonts-hack-ttf qmmp blackbird-gtk-theme \
moka-icon-theme htop"


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

echo "Installing keepasshttp-connector plugin..."
apt-get install libmono-system-xml-linq4.0-cil libmono-system-data-datasetextensions4.0-cil \
libmono-system-runtime-serialization4.0-cil mono-mcs &> /dev/null
wget https://raw.github.com/pfn/keepasshttp/master/KeePassHttp.plgx -O /usr/lib/keepass2/KeePassHttp.plgx

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
get \
    -O ~/.emacs.d/emacs-init.org https://gitlab.com/RobinWils/dotfiles/raw/master/emacs/emacs-init.org
    q &> /dev/null
cp -rf ~/.emacs.d/emacs-init.org /home/$USERNAME/.emacs.d/emacs-init.org

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

if [[ $INSTALL_VBOX = true ]];
then
echo "Installing virtualbox..."
echo "deb http://download.virtualbox.org/virtualbox/debian stretch \
contrib" >> /etc/apt/sources.list &>/dev/null
wget -q -O- https://www.virtualbox.org/download/oracle_vbox_2016.asc | apt-key add &>/dev/null
apt-get update &>/dev/null
apt-get install $VBOX_PACKAGE &>/dev/null 
fi

echo "Replacing the default host file..."
wget -O /etc/hosts $HOSTS -q &> /dev/null
# Add hostname to hosts file since some programs depend on this line.
sed -i "/^127.0.0.1\\ localhost.localdomain/i 127.0.0.1\\ $HOSTNAME" /etc/hosts

# TODO: XFCE configuration
# /home/rmw/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings
