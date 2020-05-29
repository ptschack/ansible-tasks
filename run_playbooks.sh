#!/bin/bash

#./prepare.sh

if [ ! -z "$1" ]; then
    ansible-playbook --flush-cache -i hosts site.yml --ask-become-pass --extra-vars "ansible_python_interpreter=/usr/bin/python3" --limit $@
else
    ansible-playbook --flush-cache -i hosts site.yml --ask-become-pass --extra-vars "ansible_python_interpreter=/usr/bin/python3"
fi
