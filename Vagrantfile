# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'yaml'

# Load project specifc configuration
current_dir         = File.dirname(File.expand_path(__FILE__))
config_file         = YAML.load_file("#{current_dir}/ressources/provisioning/config.yaml")
provisioning_config = config_file['provisioning']


# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  # Size the machine
  config.vm.provider "virtualbox" do |v|
    v.memory = provisioning_config['memory']
    v.cpus = provisioning_config['cpus']
  end


  # Every Vagrant virtual environment requires a box to build off of.
  config.vm.box = "ubuntu/trusty64"

  # Enable automatic box update checking
  config.vm.box_check_update = true

  # Set the hostname
  config.vm.hostname = provisioning_config['vm_hostname']

  # Enable/configure host manager
  config.hostmanager.enabled = true
  config.hostmanager.manage_host = true
  config.hostmanager.aliases = provisioning_config['hostmanager_aliases'] << provisioning_config['server_name']

  # Create a private network, which allows host-only access to the machine using a specific IP.
  config.vm.network "private_network", ip: provisioning_config['private_ip']

  # Share an additional folder to the guest VM. The first argument is the path on the host to the actual folder.
  # The second argument is the path on the guest to mount the folder.
  config.vm.synced_folder provisioning_config['host_webroot'], "/var/www/html/#{provisioning_config['server_name']}"

  # Define the bootstrap file: A (shell) script that runs after first setup of your box (= provisioning)
  config.vm.provision :shell do |s|
    s.path = "./ressources/provisioning/provision.sh"
  end

end
