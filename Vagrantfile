# -*- mode: ruby -*-
# vi: set ft=ruby :
require 'yaml'

# Oracle 21c Data Guard Environment
# Primary: ol8-21-dg1 (192.168.56.101)
# Standby: ol8-21-dg2 (192.168.56.102)

# Load configuration
params = YAML.load_file 'config/vagrant.yml'

Vagrant.configure("2") do |config|
  # Shared configuration
  config.vm.box = params['shared']['box']
  config.vm.box_url = params['shared']['box_url']
  config.vm.box_check_update = false

  # Shared folders
  config.vm.synced_folder ".", "/vagrant"
  config.vm.synced_folder "config", "/vagrant_config"
  config.vm.synced_folder "2-Standby/infrastructure", "/vagrant_scripts"
  config.vm.synced_folder "software", "/vagrant_software"
  config.vm.synced_folder "2-Standby/automation", "/vagrant_automation"
  config.vm.synced_folder "1-BD/SQL-VM scripts", "/vagrant_sql_scripts"
  config.vm.synced_folder "1-BD/directories", "/vagrant_directories"

  # Primary Database Server (Node 1)
  config.vm.define "primary", primary: true do |primary|
    primary.vm.hostname = "ol8-21-dg1.localdomain"
    primary.vm.network "private_network", ip: params['node1']['public_ip']
    primary.vm.network "forwarded_port", guest: 1521, host: 15210
    primary.vm.network "forwarded_port", guest: 5500, host: 5500

    primary.vm.provider "virtualbox" do |vb|
      vb.name = params['node1']['vm_name']
      vb.memory = params['node1']['mem_size']
      vb.cpus = params['node1']['cpus']

      # Set non-rotational flag for better performance
      vb.customize ['storageattach', :id, '--storagectl', 'SATA Controller',
                    '--port', '0', '--nonrotational', params['shared']['non_rotational']]

      # Create and attach u01 disk (Oracle software and databases)
      u01_disk = params['node1']['u01_disk']
      unless File.exist?(u01_disk)
        vb.customize ['createhd', '--filename', u01_disk,
                      '--size', params['node1']['disk_size']]
      end
      vb.customize ['storageattach', :id, '--storagectl', 'SATA Controller',
                    '--port', 1, '--device', 0, '--type', 'hdd', '--medium', u01_disk,
                    '--nonrotational', params['shared']['non_rotational']]

      # Create and attach u02 disk (Backups and FRA)
      u02_disk = params['node1']['u02_disk']
      unless File.exist?(u02_disk)
        vb.customize ['createhd', '--filename', u02_disk,
                      '--size', params['node1']['disk_size']]
      end
      vb.customize ['storageattach', :id, '--storagectl', 'SATA Controller',
                    '--port', 2, '--device', 0, '--type', 'hdd', '--medium', u02_disk,
                    '--nonrotational', params['shared']['non_rotational']]
    end

    primary.vm.provision "shell", path: "2-Standby/scripts/primary/setup.sh"
    primary.vm.provision "shell",
      path: "2-Standby/scripts/optional/deploy_sql_and_directories.sh",
      name: "deploy_sql_and_directories",
      run: "never"
    primary.vm.provision "shell",
      path: "2-Standby/scripts/optional/setup_oracle_autostart.sh",
      name: "setup_oracle_autostart",
      run: "never"
  end

  # Standby Database Server (Node 2)
  config.vm.define "standby", autostart: false do |standby|
    standby.vm.hostname = "ol8-21-dg2.localdomain"
    standby.vm.network "private_network", ip: params['node2']['public_ip']
    standby.vm.network "forwarded_port", guest: 1521, host: 15220
    standby.vm.network "forwarded_port", guest: 5500, host: 5501

    standby.vm.provider "virtualbox" do |vb|
      vb.name = params['node2']['vm_name']
      vb.memory = params['node2']['mem_size']
      vb.cpus = params['node2']['cpus']

      # Set non-rotational flag
      vb.customize ['storageattach', :id, '--storagectl', 'SATA Controller',
                    '--port', '0', '--nonrotational', params['shared']['non_rotational']]

      # Create and attach u01 disk
      u01_disk = params['node2']['u01_disk']
      unless File.exist?(u01_disk)
        vb.customize ['createhd', '--filename', u01_disk,
                      '--size', params['node2']['disk_size']]
      end
      vb.customize ['storageattach', :id, '--storagectl', 'SATA Controller',
                    '--port', 1, '--device', 0, '--type', 'hdd', '--medium', u01_disk,
                    '--nonrotational', params['shared']['non_rotational']]

      # Create and attach u02 disk (for backups from primary)
      u02_disk = params['node2']['u02_disk']
      unless File.exist?(u02_disk)
        vb.customize ['createhd', '--filename', u02_disk,
                      '--size', params['node2']['disk_size']]
      end
      vb.customize ['storageattach', :id, '--storagectl', 'SATA Controller',
                    '--port', 2, '--device', 0, '--type', 'hdd', '--medium', u02_disk,
                    '--nonrotational', params['shared']['non_rotational']]
    end

    standby.vm.provision "shell", path: "2-Standby/scripts/standby/setup.sh"
    standby.vm.provision "shell",
      path: "2-Standby/scripts/optional/deploy_sql_and_directories.sh",
      name: "deploy_sql_and_directories",
      run: "never"
    standby.vm.provision "shell",
      path: "2-Standby/scripts/optional/setup_oracle_autostart.sh",
      name: "setup_oracle_autostart",
      run: "never"
  end
end
