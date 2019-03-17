#!/bin/bash
#sudo dnf install python ansible openssh
#sudo systemctl start sshd
ansible-playbook -i hosts site.yml --ask-become-pass
