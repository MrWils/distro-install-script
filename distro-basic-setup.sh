#!/bin/bash

# This script assumes that your computer is connected to the internet during
# the execution of it. This was made for Devuan netinstall.
# I am not responsible for broken systems or lost files,

# Different users can have different packages in guix.
# This script installs all the packages for the non-root user.
# It also adds the same guix-profile to the root's .bashrc,
# so that they have the same packages.

# RUN THIS AT YOUR OWN RISK.
# THIS SCRIPT HAS NOT BEEN TESTED YET.


# CONFIG
# ______


# The username of your non-root user
readonly USERNAME="rmw"


# REPOSITORIES
# The Debian repo for the prop WiFi drivers
readonly DEBIAN_REPO="deb http://http.us.debian.org/debian/ 
testing non-free contrib main"

# The propetiary wifi debian package,
# leave this empty if you don't need a prop WiFi driver
readonly PROP_WIFI="firmware-iwlwifi"

# The repo to use after the installation
readonly REPO="deb https://repo.pureos.net/pureos green main"
# Repository key
readonly REPO_KEYRING="pureos-archive-keyring"

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
readonly GRUB_DISTRIBUTOR="GNU+Devuan+Guix"


# APT
# Apt will remove these packages
readonly APT_PACKAGES_TO_REMOVE="bluetooth bluez laptop-detect popularity-contest \
vim-common vim-tiny xxd"
# Packages that we need so that the installer runs
readonly REQUIRED_APT_PACKAGES="apt-transport-https ca-certificates \
curl dirmngr wget"
# Other apt packages, most of these are required so that EXWM/Xorg works
readonly APT_PACKAGES="sct xserver-xorg xserver-xorg-input-evdev \
xserver-xorg-input-kbd xserver-xorg-input-mouse \
xserver-xorg-input-synaptics pm-utils"
# Video driver for xorg (apt)
readonly VIDEO_DRIVER_FOR_X="xserver-xorg-video-nouveau"


# GUIX
# Packages to install
readonly GUIX_PACKAGES="acpi alsa-utils emacs git nss-certs firefox font-hack \
keepassxc libreoffice maim mplayer rsync testdisk wicd xrandr"
# xfce4-panel xfce4-session
# font-misc-misc xf86-input-evdev xf86-input-keyboard xf86-input-mouse
# xf86-input-synaptics xf86-video-nouveau xinit xorg-server sct"


# SCRIPT
# ______

if [ "$EUID" -ne 0 ]
then echo "You need to be root to execute this script."
     exit 1
fi

# Do not show dialogs during the install
export DEBIAN_FRONTEND=noninteractive


echo -e "\nPreparing the install"
echo -e "---------------------\n"


if ! [ -z "$PROP_WIFI" ]
then
    echo "Installing propetiary WiFi driver..."
    mv /etc/apt/sources.list /etc/apt/sources.list.old
    touch /etc/apt/sources.list
    echo $DEBIAN_REPO >> /etc/apt/sources.list
    apt-get update > /dev/null
    apt-get -yqq --no-install-recommends \
            install $PROP_WIFI > /dev/null
fi


echo "Removing unneeded apt packages..."
apt-get -yqq purge $APT_PACKAGES_TO_REMOVE > /dev/null
apt-get -yqq autoremove --purge > /dev/null


echo "Install packages which are required for the install..."
apt-get -yqq --no-install-recommends install $REQUIRED_APT_PACKAGES &> /dev/null


echo "Switching repositories..."
rm -rf /etc/apt/sources.list
touch /etc/apt/sources.list
echo $REPO >> /etc/apt/sources.list


echo "Installing the keyring..."
apt-get -yqq update --allow-insecure-repositories &> /dev/null 
apt-get -yqq install $REPO_KEYRING --allow-unauthenticated &> /dev/null


echo "Updating system..."
apt-get update &> /dev/null
apt-get -yqq dist-upgrade &> /dev/null
apT-get -yqq upgrade &> /dev/null


echo "Installing apt packages..."
apt-get -yqq --no-install-recommends \
        install $APT_PACKAGES $VIDEO_DRIVER_FOR_X &> /dev/null


echo -e "\nPreparing guix"
echo -e "--------------\n"


if [[ -e "/var/guix" || -e "/gnu" ]]; then
    echo "A previous Guix installation was found."
    echo "Exiting script"
    exit 1
fi


echo "Installing the guix package manager..."
gpg --keyserver pool.sks-keyservers.net \
    --recv-keys 3CE464558A84FDC69DB40CFB090B11993D9AEBB5 &> /dev/null
bash <(curl -s https://git.savannah.gnu.org/cgit/guix.git/plain/etc/guix-install.sh)


echo "Creating SysV script for the guix-daemon..."
/bin/cat <<EOM >/etc/init.d/guix-daemon
#!/bin/sh
### BEGIN INIT INFO
# Provides:          guix-daemon
# Required-Start:    mountdevsubfs
# Required-Stop:
# Should-Start:
# Should-Stop:
# X-Start-Before:
# X-Stop-After:
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
### END INIT INFO

SCRIPTNAME=/etc/init.d/guix-daemon
. /lib/lsb/init-functions
[ -x /root/.guix-profile/bin/guix-daemon ] || exit 0

do_start()
{
    /root/.guix-profile/bin/guix-daemon \
        --build-users-group=guixbuild \
        2> /var/log/guix.log &
}

case "$1" in
    start)
        log_action_begin_msg "Setting up GNU Guix daemon"
        do_start
        case "$?" in
            0|1) log_action_end_msg 0 ;;
            2) log_action_end_msg 1 ;;
        esac
        ;;
    stop|restart|force-reload|status)
        log_action_begin_msg "Killing GNU Guix daemon"
        killall guix-daemon
        ;;
    *)
        echo "Usage: $SCRIPTNAME start" >&2
        exit 3
        ;;
esac
EOM


echo "Starting the guix-daemon..."
update-rc.d guix-daemon defaults
chmod a+x /etc/init.d/guix-daemon
/etc/init.d/guix-daemon start


# THE SYSV DAEMON DOES NOT WORK
# SO WE CREATE A SCRIPT AND RUN THAT
/bin/cat <<EOM >~/run-guix-daemon.sh
#!/bin/sh
~root/.config/guix/current/bin/guix-daemon --build-users-group=guixbuild &> /dev/null &
EOM
chmod +x ~/run-guix-daemon.sh
sh ~/run-guix-daemon.sh


echo "Make a guix profile for our user..."
mkdir /var/guix/profiles/per-user/rmw
chown rmw /var/guix/profiles/per-user/rmw


echo -e "\nInstall guix packages"
echo -e "---------------------\n"


echo "Adding the important paths for guix to bashrc..."
su -c 'echo "# Regular system paths" >> ~/.bashrc &&
echo "export PATH=\$PATH:/usr/local/bin:usr/local/sbin:/usr/sbin:/sbin" >> ~/.bashrc && 
echo "# Guix paths" >> ~/.bashrc && 
echo "export PATH=\$PATH:$HOME/.config/guix/current/bin"  >> ~/.bashrc &&
echo "export GUIX_PROFILE=$HOME/.guix-profile"  >> ~/.bashrc &&
echo "source \$GUIX_PROFILE/etc/profile" >> ~/.bashrc &&
echo "# Guix locales" >> ~/.bashrc &&
echo "export GUIX_LOCPATH=$HOME/.guix-profile/lib/locale" >> ~/.bashrc' $USERNAME &> /dev/null

cp /home/$USERNAME/.bashrc ~/.bashrc
source ~/.bashrc
su -c 'source ~/.bashrc' $USERNAME


echo -e "\nUpdating guix (guix pull)..."
guix pull &> /dev/null


echo "Configuring the locales...."
guix package -i glibc-utf8-locales &> /dev/null
source ~/.bashrc
su -c 'source ~/.bashrc' $USERNAME

echo "Installing the guix packages..."
guix package -i $GUIX_PACKAGES #&> /dev/null


echo -e "\nConfigure packages"
echo -e "------------------\n"


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
update-grub > /dev/null 
fi


echo "Configuring git..."
git config --global core.editor emacs
git config --global user.email $GIT_EMAIL
git config --global user.name $GIT_EMAIL
cp -rf  ~/.gitconfig /home/$USERNAME/.gitconfig


echo "Configuring emacs..."
wget \
    -O ~/.emacs https://gitlab.com/RobinWils/dotfiles/raw/master/.emacs \
    -q > /dev/null
cp -rf ~/.emacs /home/$USERNAME/.emacs


echo "Creating init script for startx..."
wget \
    -O ~/.xinitrc https://gitlab.com/RobinWils/dotfiles/raw/master/.xinitrc \
    -q > /dev/null
cp -rf  ~/.xinitrc /home/$USERNAME/.xinitrc


# RICE FIREFOX
# The problem with this part is that the location does not exists until
# someone runs firefox. So this part is not configured yet.
# wget -O ~/.mozilla/firefox/*.default/chrome/userChrome.css \
# https://gitlab.com/RobinWils/dotfiles/raw/master/userChrome.css


echo "Replacing the default host file..."
wget -O /etc/hosts $HOSTS -q > /dev/null


echo "Making sure that the users owns their home..."
chown -R $USERNAME /home/$USERNAME
chown -R root /root


echo -e "\n\nInstallation finished!"
echo "Enjoy your new system!\n"
exit 0
