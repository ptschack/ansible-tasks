# How to apply these playbooks

## Clone the repository

`git clone https://github.com/ptschack/ansible-tasks.git`

## Create hosts and site.yml files inside repository

Use `hosts.example` and `site.yml.example` as templates.

## Apply playbooks

Run `./run_playbooks.sh`.

If given a parameter, execution will be limited to that host: `./run_playbooks.sh joes-computer`.