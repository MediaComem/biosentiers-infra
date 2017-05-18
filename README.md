# BioSentiers Infrastructure

Infrastructure for the BioSentiers backend & frontend:

* [PostgreSQL][postgresql] database with [PostGIS][postgis]
* [Nginx][nginx] web server
* [Nodenv][nodenv] to manage multiple [Node.js][node] versions
* [PM2][pm2] process manager for Node.js

This repo will only set up the required infrastructure.
To deploy the BioSentiers backend and frontend,
follow the instructions in their respective repositories:

* https://github.com/MediaComem/biosentiers-backend
* https://github.com/MediaComem/biosentiers-frontend

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->


- [Requirements](#requirements)
- [Usage](#usage)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->



## Requirements

* [Ansible][ansible] 2+, [installation][ansible-install]
* [Vagrant][vagrant] 1.9+, [installation][vagrant-install] (for testing)
* [Virtual Box][virtualbox] 5+, [installation][virtualbox-install] (for testing)



## Usage

* Put the project's password in a `.vault-password` file in the repository

To **test** the infrastructure in a Vagrant virtual machine:

* Run `vagrant up`

To **run** the infrastructure in production:

* Create an [Ansible inventory][ansible-inventory] and save it as `production.inventory`
* Apply the production playbook:

      ansible-playbook \
        --inventory production.inventory \
        --vault-password-file .vault-password \
        playbook.production.yml



[ansible]: https://www.ansible.com
[ansible-install]: http://docs.ansible.com/ansible/intro_installation.html
[ansible-inventory]: http://docs.ansible.com/ansible/intro_inventory.html
[nginx]: https://www.nginx.com
[node]: https://nodejs.org
[nodenv]: https://github.com/nodenv/nodenv
[pm2]: http://pm2.io
[postgis]: http://postgis.net
[postgresql]: https://www.postgresql.org
[vagrant]: https://www.vagrantup.com
[vagrant-install]: https://www.vagrantup.com/downloads.html
[virtualbox]: https://www.virtualbox.org
[virtualbox-install]: https://www.virtualbox.org/wiki/Downloads
