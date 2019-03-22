#!/bin/bash

# check availability of different package managers
for i in apt-get yum dnf; do # sort from least to most preferred
    which $i > /dev/null && PKGMGR=$i # e.g. if 'apt-get' command is available, PKGMGR will be set to 'apt-get'
done

# use package managers to install prerequisites
case "$PKGMGR" in
    apt-get)
        sudo apt-get install ansible python openssh-client openssh-server
        ;;
    dnf)
        sudo dnf install python ansible openssh
        ;;
    yum)
        sudo yum install python ansible openssh
        ;;
esac

# start sshd if systemctl is installed
which systemctl > /dev/null && sudo systemctl start sshd