#!/bin/bash

#./prepare.sh

if [ ! -z "$1" ]; then
    ansible-playbook -i hosts site.yml --ask-become-pass --limit $@
else
    ansible-playbook -i hosts site.yml --ask-become-pass
fi
