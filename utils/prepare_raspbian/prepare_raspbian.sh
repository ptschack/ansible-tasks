#!/bin/bash

# developed for / works on debian 9.8 "stretch"

RASPBIAN_DOWNLOAD_URL='https://downloads.raspberrypi.org/raspbian_lite_latest'

source specifics.sh
if [ -z "$RPI_HOSTNAMES" ]; then
    echo 'ERROR: $RPI_HOSTNAMES not set' >&2
    exit 1
elif [ -z "$RPI_USERNAME" ]; then
    echo 'ERROR: $RPI_USERNAME not set' >&2
    exit 1
elif [ -z "$MOUNTDIR" ]; then
    echo 'ERROR: $MOUNTDIR not set' >&2
    exit 1
elif [ -z "$AUTHORIZED_KEYS_FILE" ]; then
    echo 'ERROR: $AUTHORIZED_KEYS_FILE not set' >&2
    exit 1
fi

function get_package_manager(){ # check availability of different package managers
    local PKGMGR='' && \
    for i in apt-get yum dnf; do # sort from least to most preferred
        which $i > /dev/null && PKGMGR=$i # e.g. if 'apt-get' command is available, PKGMGR will be set to 'apt-get'
    done && \
    [ -z "$PKGMGR" ] && return 1
    echo $PKGMGR
}

function install_prerequisites(){
    local PKGMGR=$(get_package_manager)
    sudo $PKGMGR install qemu-user qemu-system proot
}

function download_raspbian(){
    local LINK=$(\
        curl -si $1 | \
        grep '^Location:' | \
        sed 's|^Location: ||' | \
        sed 's|\.zip.*$|\.zip|' \
    ) && \
    local CHECKSUM_ALG='sha256' && \
    local FILENAME_ZIP=$(echo $LINK | sed 's|^.*/||') && \
    local FILENAME_IMG=$(echo $FILENAME_ZIP | sed 's|\.zip|\.img|') && \
    echo -e '\ncurrent raspbian version: '$FILENAME_ZIP && \
    if [ ! -f $FILENAME_IMG ]; then
        echo -e '\n'$FILENAME_IMG' not found' && \
        if [ ! -f $FILENAME_ZIP ]; then
            echo -e '\ndownloading '$LINK && \
            wget $LINK
        fi && \
        if [ ! -f $FILENAME_ZIP'.'$CHECKSUM_ALG ]; then
            echo -e '\ndownloading '$LINK'.'$CHECKSUM_ALG && \
            wget $LINK'.'$CHECKSUM_ALG
        fi && \
        echo -en '\nverifying checksum: ' && \
        ${CHECKSUM_ALG}sum -c "${FILENAME_ZIP}.${CHECKSUM_ALG}" && \
        echo -en '\nunzipping ' && \
        unzip $FILENAME_ZIP || return 1
    fi
    RASPBIAN_FILENAME=$(pwd)'/'$FILENAME_IMG
}

function download_kernel(){
    if [ ! -d qemu-rpi-kernel ]; then
        git clone https://github.com/dhruvvyas90/qemu-rpi-kernel.git
    fi && \
    cd qemu-rpi-kernel && \
    git checkout master && \
    git pull && \
    cd ..
}

function mount_image(){
    local FILE=$1
    local MOUNT_POINT=$2
    if [ ! -f $FILE ] || [ ! -d $MOUNT_POINT ]; then
        echo "invalid parameter(s)" >&2
        echo "Usage: "$FUNCNAME" <path to img file> <path to mount dir>"
        return 1
    fi
    echo 'trying to mount '$FILE' ... '
    local SECTOR_SIZE=$(
        sudo fdisk -l $FILE | \
        grep 'Sector size' | \
        sed 's|Sector.*:\s*||' | \
        awk '{print $1}'
    )
    local PARTITION_START=$(
        sudo fdisk -l -o Type,Device,Start $FILE | \
        grep -A 99 '^Type\s*Device\s*Start$' | \
        grep '^Linux' | \
        awk '{print $3}'
    )
    local OFFSET=$(expr $SECTOR_SIZE \* $PARTITION_START)
    sudo mount -v -o offset=$OFFSET $FILE $MOUNT_POINT
}

function read_password(){
    local PASSWORD1='a'
    local PASSWORD2='b'
    while [ "$PASSWORD1" != "$PASSWORD2" ]; do
        read -sp 'enter password: ' PASSWORD1
        echo
        read -sp 'confirm password: ' PASSWORD2
        echo
    done
    PASSWORD=$PASSWORD1
}

install_prerequisites && \
echo && \
echo "####################################################" && \
echo "###   Customization Script for Raspbian Images   ###" && \
echo "####################################################" && \
echo && \
echo '$MOUNTDIR='$MOUNTDIR && \
echo '$AUTHORIZED_KEYS_FILE='$AUTHORIZED_KEYS_FILE && \
echo '$RPI_USERNAME='$RPI_USERNAME && \
echo '$RPI_HOSTNAMES:' && \
for i in ${RPI_HOSTNAMES[@]}; do
    echo '  '$i
done && \
echo && \
echo "Please input password for $RPI_USERNAME" && \
read_password && \
download_raspbian $RASPBIAN_DOWNLOAD_URL && \
for RPI_HOSTNAME in ${RPI_HOSTNAMES[@]}; do
    echo -e '\n\nsetting up '$RPI_HOSTNAME && \
    echo 'copying image to '${RPI_HOSTNAME}.img && \
    cp $RASPBIAN_FILENAME ${RPI_HOSTNAME}.img && \
    mount_image ${RPI_HOSTNAME}.img $MOUNTDIR && \
    sudo proot -q qemu-arm -S $MOUNTDIR <<< '\
        echo "# echo '$RPI_HOSTNAME' > /etc/hostname" && \
        echo '$RPI_HOSTNAME' > /etc/hostname && \
        echo "# adduser --disabled-password --gecos "" '$RPI_USERNAME'" && \
        adduser --disabled-password --gecos "" '$RPI_USERNAME' && \
        echo "# echo "'$RPI_USERNAME':*******" | chpasswd" && \
        echo "'$RPI_USERNAME':'$PASSWORD'" | chpasswd && \
        echo "# usermod -a -G sudo '$RPI_USERNAME'" && \
        usermod -a -G sudo '$RPI_USERNAME' && \
        echo "# userdel pi" && \
        userdel pi && \
        echo "# rm -rf /home/pi" && \
        rm -rf /home/pi && \
        echo "# touch /boot/ssh" && \
        touch /boot/ssh
    ' && \
    echo "\$ sudo mkdir -p $MOUNTDIR/home/$RPI_USERNAME/.ssh" && \
    sudo mkdir -p $MOUNTDIR/home/$RPI_USERNAME/.ssh && \
    echo "\$ sudo chown -R $USER $MOUNTDIR/home/$RPI_USERNAME/" && \
    sudo chown -R $USER $MOUNTDIR/home/$RPI_USERNAME/ && \
    echo "\$ cp -R $AUTHORIZED_KEYS_FILE $MOUNTDIR/home/$RPI_USERNAME/.ssh/" && \
    cp -R $AUTHORIZED_KEYS_FILE $MOUNTDIR/home/$RPI_USERNAME/.ssh/ && \
    if [ -f wpa_supplicant.conf ]; then
        echo "\$ cp -R wpa_supplicant.conf $MOUNTDIR/boot/" && \
        sudo cp -R wpa_supplicant.conf $MOUNTDIR/boot/ && \
        echo "\$ sudo chown -R $USER $MOUNTDIR/boot/wpa_supplicant.conf" && \
        sudo chown -R $USER $MOUNTDIR/boot/wpa_supplicant.conf
    fi && \
    sudo proot -q qemu-arm -S $MOUNTDIR <<< '\
        echo "# chown -R '$RPI_USERNAME':'$RPI_USERNAME' /home/'$RPI_USERNAME'" && \
        chown -R '$RPI_USERNAME':'$RPI_USERNAME' /home/'$RPI_USERNAME'
    ' && \
    echo "\$ sudo umount $MOUNTDIR" && \
    sudo umount $MOUNTDIR
done && \
unset PASSWORD