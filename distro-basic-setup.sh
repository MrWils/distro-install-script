#!/bin/bash

# This script assumes that your computer is connected to the internet during
# the execution of it. This was made for Devuan netinstall.
# I am not responsible for broken systems or lost files,

# Different users can have different packages in guix.
# This script installs all the packages for the non-root user.
# It also symlinks it to root so that they have the same packages.
# I install XFCE4 just in case that I have problems with EXWM.
# This has not happened yet.

# RUN THIS AT YOUR OWN RISK.
# THIS SCRIPT HAS NOT BEEN TESTED YET.


# CONFIG
# ______


# Packages to install
readonly GUIX_PACKAGES="acpi git icecat keepassxc libreoffice maim mplayer \
rsync testdisk wicd xfce4-panel xfce4-session xrandr"

# Apt will remove these packages
readonly PACKAGES_TO_REMOVE="bluetooth bluez laptop-detect popularity-contest \
vim-common vim-tiny xxd"

# The email address which you use for git,
# I am lazy so I use a grep but you can use a regular email here.
readonly GIT_EMAIL=$(wget -qO- https://gitlab.com/RobinWils \
                            | grep -o '[[:alnum:]+\.\_\-]*@[[:alnum:]+\.\_\-]*' \
                            | tail -1)

# The username of your non-root user
readonly USERNAME="rmw"

# The prop wifi debian package,
# leave this empty if you don't need a prop WiFi driver
readonly PROP_WIFI="firmware-iwlwifi"

# The Debian repo for the prop WiFi drivers
readonly DEBIAN_REPO="deb http://http.us.debian.org/debian/ 
testing non-free contrib main"

# Custom host file (which blocks ads) 
readonly HOSTS="https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"

# Hide grub
readonly HIDE_GRUB=true
# Name in grub menu
readonly GRUB_DISTRIBUTOR="GNU+Devuan+Guix"

# X and Emacs might crash or give errors
# if you remove one of these packages
readonly ESSENTIAL_GUIX_PACKAGES="emacs nss-certs font-hack \
font-misc-misc xf86-input-evdev xf86-input-keyboard xf86-input-mouse \
xf86-input-synaptics xf86-video-nouveau xinit"
# sct" the sct package does not work on guix for some reason
# but it is essential for my init script
readonly ESSENTIAL_APT_PACKAGES="ca-certificates curl dirmngr nscd sct"
readonly RECOMMENDED_APT_PACKAGES="pm-utils"

# SCRIPT
# ______


if [ "$EUID" -ne 0 ]
then echo "You need to be root to execute this script."
     exit 1
fi


echo -e "\nPreparing the install"
echo -e "---------------------\n"


if ! [ -z "$PROP_WIFI" ]
then
    echo "Installing prop WiFi driver..."
    mv /etc/apt/sources.list /etc/apt/sources.list.old
    touch /etc/apt/sources.list
    echo $DEBIAN_REPO >> /etc/apt/sources.list
    apt-get update > /dev/null
    apt-get -y --no-install-recommends \
            install $PROP_WIFI > /dev/null
    mv /etc/apt/sources.list.old /etc/apt/sources.list
    apt-get update > /dev/null
fi


echo "Installing apt packages..."
apt-get -y --no-install-recommends \
        install $ESSENTIAL_APT_PACKAGES $RECOMMENDED_APT_PACKAGES > /dev/null


echo "Removing unneeded apt packages..."
apt-get -y purge $PACKAGES_TO_REMOVE > /dev/null
apt-get -y autoremove --purge > /dev/null


echo -e "\nPreparing guix"
echo -e "--------------\n"


if [[ -e "/var/guix" || -e "/gnu" ]]; then
    echo "A previous Guix installation was found."
    echo "Exiting script"
    exit 1
fi


echo "Installing the guix package manager..."
gpg --keyserver pool.sks-keyservers.net \
    --recv-keys 3CE464558A84FDC69DB40CFB090B11993D9AEBB5 \
&> /dev/null
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
# SO WE RUN IT MANUALLY
 ~root/.config/guix/current/bin/guix-daemon \
       --build-users-group=guixbuild 2> /dev/null &


echo "Make a guix profile for our user..."
mkdir /var/guix/profiles/per-user/rmw
chown rmw /var/guix/profiles/per-user/rmw

echo -e "\nUpdating guix (guix pull)..."
su -c "guix pull" \
   $USERNAME &> /dev/null

echo "Configuring the locales...."
su  -c 'guix package -i glibc-utf8-locales &&
export LC_ALL=en_US.UTF-8 ' \
    $USERNAME &> /dev/null


echo -e "\nInstall guix packages"
echo -e "---------------------\n"


echo "Installing the guix packages..."
su -c "guix package \
-i $ESSENTIAL_GUIX_PACKAGES $GUIX_PACKAGES" \
   $USERNAME &> /dev/null


echo -e "\nConfigure packages"
echo -e "------------------\n"


echo "Updating grub..."
if [[ $HIDE_GRUB = true ]]; then
    /bin/cat <<EOM >/etc/default/grub
GRUB_CMDLINE_LINUX=""
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
GRUB_DEFAULT=0
GRUB_DISTRIBUTOR="$GRUB_DISTRIBUTOR"
GRUB_HIDDEN_TIMEOUT=0
GRUB_HIDDEN_TIMEOUT_QUIET=true
EOM
fi
update-grub


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
wget -O /etc/hosts \
     $HOSTS -q \
     > /dev/null


echo "Setting the important paths for guix..."
su -c 'echo "export PATH=\$PATH:$HOME/.guix-profile/bin:$HOME/.guix-profile/sbin:/sbin:/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin"  >> ~/.bashrc &&
   guix package --search-paths | tail +2 >> ~/.bashrc' $USERNAME &> /dev/null
cp /home/$USERNAME/.bashrc ~/.bashrc


echo "Making sure that the users owns their home..."
chown -R $USERNAME /home/$USERNAME
chown -R root /root


echo -e "\nInstallation finished!"
echo "Enjoy your new system!"
echo -e "Make sure to add new guix paths to your .bashrc file.\n"
exit 0