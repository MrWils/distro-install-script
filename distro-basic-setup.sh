#!/bin/bash

# This script assumes that your computer is connected to the internet during the
# execution of it. This was made for devuan/debian netinstall.
# I am not responsible for broken systems or lost files,

# RUN THIS AT YOUR OWN RISK.
# THIS SCRIPT HAS NOT BEEN TESTED YET.


# CONFIG
# ______

# Packages to install,
# the script uses guix to install these.

# Different users can have different packages in guix.
# This script installs all the packages for the non-root user.
# It also symlinks it to root so that they have the same packages.
# I install XFCE4 just in case that I have problems with EXWM.
# This has not happened yet.
readonly GUIX_PACKAGES="libreoffice testdisk keepassxc acpi mplayer icecat git 
wicd maim xrandr xfce4-session xfce4-panel rsync"

# Default packages of the netinstaller which you don't want.
# Apt will remove those packages.
readonly PACKAGES_TO_REMOVE="bluez bluetooth vim-common vim-tiny laptop-detect 
popularity-contest xxd"

# The email address which you use for git
# You don't have to use a grep but it is useful,
# just in case that I change my email.
readonly GIT_EMAIL=$(wget -qO- https://gitlab.com/RobinWils \
                         | grep -o '[[:alnum:]+\.\_\-]*@[[:alnum:]+\.\_\-]*' \
                         | tail -1)

# The username of your non-root user
readonly USERNAME="rmw"

# The prop wifi debian package
# Leave this empty if you don't need a prop WiFi driver.
readonly PROP_WIFI="firmware-iwlwifi"

# The Debian repo for the prop WiFi drivers
readonly DEBIAN_REPO="deb http://http.us.debian.org/debian/ 
testing non-free contrib main"

# Custom host file (which blocks ads) 
readonly HOSTS="https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"

# X and Emacs might crash or give errors
# if you remove one of these packages.
readonly ESSENTIAL_GUIX_PACKAGES="font-hack font-misc-misc xinit 
xf86-input-evdev emacs xf86-input-keyboard xf86-input-mouse xf86-input-synaptics 
xf86-video-nouveau"
# sct" the sct package does not work on guix for some reason
# but it is essential for my init script
readonly ESSENTIAL_APT_PACKAGES="curl dirmngr sct"

# SCRIPT
# ______

if [ "$EUID" -ne 0 ]
then echo "You need to be root to execute this script."
     exit 1
fi

# Prop WiFi driver
if ![ -z "$PROP_WIFI" ]
then
    mv /etc/apt/sources.list /etc/apt/sources.list.old
    touch /etc/apt/sources.list
    echo $DEBIAN_REPO >> /etc/apt/sources.list
    apt update
    apt -y --no-install-recommends install $PROP_WIFI
    mv /etc/apt/sources.list.old /etc/apt/sources.list
    apt update
fi

# Install required apt packages
apt -y --no-install-recommends install $ESSENTIAL_APT_PACKAGES

# Guix package manager
gpg --keyserver pool.sks-keyservers.net \
    --recv-keys 3CE464558A84FDC69DB40CFB090B11993D9AEBB5
bash <(curl -s https://git.savannah.gnu.org/cgit/guix.git/plain/etc/guix-install.sh)
# Start guix daemon
/gnu/store/*-guix-*/bin/guix-daemon --build-users-group=guixbuild &
# Setup guix
guix package -i glibc-utf8-locales
export GUIX_LOCPATH="$HOME/.guix-profile/lib/locale"
export INFOPATH="$HOME/.guix-profile/share/info${INFOPATH:+:}$INFOPATH"
export PATH="$HOME/.guix-profile/bin:$HOME/.guix-profile/sbin${PATH:+:}$PATH"
guix package -i nss-certs
export SSL_CERT_DIR="$HOME/.guix-profile/etc/ssl/certs"
export SSL_CERT_FILE="$HOME/.guix-profile/etc/ssl/certs/ca-certificates.crt"
export GIT_SSL_CAINFO="$SSL_CERT_FILE"
guix refresh
guix pull
guix package -u

# Remove packages
apt -y purge $PACKAGES_TO_REMOVE
apt -y autoremove

# Install packages as non-root user
su -c "guix package -i $ESSENTIAL_GUIX_PACKAGES $GUIX_PACKAGES" -s /bin/sh $USER

# Symlink the packages to root
rm -rf ~/.guix-profile
ln -sf /home/$USER/.guix-profile ~/.guix-profile

# Configure git
git config --global user.name $GIT_EMAIL
git config --global user.email $GIT_EMAIL
git config --global core.editor emacs

# Configure emacs
wget -O ~/.emacs https://gitlab.com/RobinWils/dotfiles/raw/master/.emacs
cp -rf ~/.emacs /home/$USERNAME/.emacs

# Create init script for startx
wget -O ~/.xinitrc https://gitlab.com/RobinWils/dotfiles/raw/master/.xinitrc
cp -rf ~/.xinitrc /home/$USERNAME/.xinitrc

# RICE FIREFOX
# The problem with this part is that the location does not exists until
# someone ran firefox. So this part is not configured yet.
# wget -O ~/.mozilla/firefox/*.default/chrome/userChrome.css \
    # https://gitlab.com/RobinWils/dotfiles/raw/master/userChrome.css

# Replace the default host file
wget -O /etc/hosts $HOSTS

# Give our user ownership on their files
chown -R $USERNAME /home/$USERNAME

# Set the important vars for guix
# I currently run a bash script with this after my system boots.
# Your init system can do this but I didn't take the time to write that yet.

# The first line is commented since we started the daemon already.
# It is not commented in that other script that I mentioned.

# /gnu/store/*-guix-*/bin/guix-daemon --build-users-group=guixbuild &
export GUIX_LOCPATH="$HOME/.guix-profile/lib/locale"
export SSL_CERT_DIR="$HOME/.guix-profile/etc/ssl/certs"
export SSL_CERT_FILE="$HOME/.guix-profile/etc/ssl/certs/ca-certificates.crt"
export GIT_SSL_CAINFO="$SSL_CERT_FILE"
export INFOPATH="$HOME/.guix-profile/share/info${INFOPATH:+:}$INFOPATH"
export PATH="$HOME/.guix-profile/bin:$HOME/.guix-profile/sbin${PATH:+:}$PATH"
export X_XFCE4_LIB_DIRS="$HOME/.guix-profile/lib/xfce4${X_XFCE4_LIB_DIRS:+:}$X_XFCE4_LIB_DIRS"
export XDG_DATA_DIRS="$HOME/.guix-profile/share${XDG_DATA_DIRS:+:}$XDG_DATA_DIRS"
export GIO_EXTRA_MODULES="$HOME/.guix-profile/lib/gio/modules${GIO_EXTRA_MODULES:+:}$GIO_EXTRA_MODULES"
exit 0
