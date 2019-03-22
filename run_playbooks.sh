#!/bin/bash

./prepare.sh

if [ ! -z "$1" ]; then
    ansible-playbook -i hosts site.yml --ask-become-pass --limit $1
else
    ansible-playbook -i hosts site.yml --ask-become-pass
fi
