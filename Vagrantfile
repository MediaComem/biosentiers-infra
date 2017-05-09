# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure('2') do |config|
  config.vm.box = 'ubuntu/xenial64'

  config.vm.network 'private_network', ip: '192.168.50.4'
  config.vm.network 'forwarded_port', guest: 80, host: 3001
  config.vm.network 'forwarded_port', guest: 443, host: 3002

  config.vm.provider 'virtualbox' do |vb|
    vb.memory = '2048'
    vb.cpus = 4
  end

  config.vm.provision 'shell', inline: <<-SHELL
    if ! which python &>/dev/null; then
      apt-get install -q -y python
    fi
  SHELL

  config.vm.provision 'ansible' do |ansible|
    ansible.playbook = 'vagrant.yml'
    ansible.tags = ENV['ANSIBLE_TAGS'].split(',') if ENV.key? 'ANSIBLE_TAGS'
    ansible.skip_tags = ENV['ANSIBLE_SKIP_TAGS'].split(',') if ENV.key? 'ANSIBLE_SKIP_TAGS'
    ansible.extra_vars = {}
    ansible.verbose = ENV['ANSIBLE_VERBOSE']
  end
end
