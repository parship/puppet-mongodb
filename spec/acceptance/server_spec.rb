# frozen_string_literal: true

require 'spec_helper_acceptance'

describe 'mongodb::server class' do
  case fact('osfamily')
  when 'Debian'
    config_file = if fact('os.distro.codename') =~ %r{^(buster)$}
                    '/etc/mongod.conf'
                  else
                    '/etc/mongodb.conf'
                  end
    service_name = if fact('os.distro.codename') =~ %r{^(buster)$}
                     'mongod'
                   else
                     'mongodb'
                   end
    package_name = if fact('os.distro.codename') =~ %r{^(buster)$}
                     'mongodb-org-server'
                   else
                     'mongodb-server'
                   end
  else
    config_file = '/etc/mongod.conf'
    service_name = 'mongod'
    package_name = 'mongodb-org-server'
  end
  major_version = 6 # fact('mongodb_version').split('.')[0].to_i
  mongo_cli = if major_version >= 5
                'mongosh'
              else
                'mongo'
              end

  describe 'installation' do
    it 'works with no errors' do
      pp = <<-EOS
        class { 'mongodb::server': }
        -> class { 'mongodb::client': }
      EOS

      apply_manifest(pp, catch_failures: true)
      apply_manifest(pp, catch_changes: true)
    end

    describe package(package_name) do
      it { is_expected.to be_installed }
    end

    describe file(config_file) do
      it { is_expected.to be_file }
    end

    describe service(service_name) do
      it { is_expected.to be_enabled }
      it { is_expected.to be_running }
    end

    describe port(27_017) do
      it { is_expected.to be_listening }
    end

    describe command('mongo --version') do
      its(:exit_status) { is_expected.to eq 0 }
    end
  end

  describe 'installation using custom port' do
    it 'change port to 27018' do
      pp = <<-EOS
        class { 'mongodb::server':
          port => 27018,
        }
        -> class { 'mongodb::client': }
      EOS

      apply_manifest(pp, catch_failures: true)
      apply_manifest(pp, catch_changes: true)
    end

    describe package(package_name) do
      it { is_expected.to be_installed }
    end

    describe file(config_file) do
      it { is_expected.to be_file }
    end

    describe service(service_name) do
      it { is_expected.to be_enabled }
      it { is_expected.to be_running }
    end

    describe port(27_017) do
      it { is_expected.not_to be_listening }
    end

    describe port(27_018) do
      it { is_expected.to be_listening }
    end
  end

  describe 'installation using authentication' do
    it 'works with no errors' do
      pp = <<-EOS
        class { 'mongodb::server':
          auth           => true,
          create_admin   => false,
          handle_creds   => true,
          store_creds    => true,
          admin_username => 'admin',
          admin_password => 'password',
          restart        => true,
          set_parameter  => ['enableLocalhostAuthBypass: true']
        }
        class { 'mongodb::client': }

        mongodb_user { "User admin on db admin":
          ensure        => present,
          password_hash => mongodb_password('admin', 'password'),
          username      => 'admin',
          database      => 'admin',
          roles         => ['dbAdmin', 'userAdminAnyDatabase'],
        }
      EOS

      apply_manifest(pp, catch_failures: true)
      apply_manifest(pp, catch_changes: true)
    end

    describe package(package_name) do
      it { is_expected.to be_installed }
    end

    describe file(config_file) do
      it { is_expected.to be_file }
    end

    describe service(service_name) do
      it { is_expected.to be_enabled }
      it { is_expected.to be_running }
    end

    describe port(27_017) do
      it { is_expected.to be_listening }
    end

    describe command('mongo --quiet --eval "db.serverCmdLineOpts().code"') do
      its(:stdout) { is_expected.to match '13' }
    end

    describe file("/root/.#{mongo_cli}.js") do
      it { is_expected.to be_file }
      it { is_expected.to be_owned_by 'root' }
      it { is_expected.to be_grouped_into 'root' }
      it { is_expected.to be_mode 600 }
      it { is_expected.to contain 'admin.auth(\'admin\', \'password\')' }
    end

    describe command("#{mongo_cli} admin --quiet --eval \"load('/root/.#{mongo_cli}.js');printjson(db.getUser('admin')['customData'])\"") do
      its(:exit_status) { is_expected.to eq 0 }
      its(:stdout) { is_expected.to match "{ \"createdBy\" : \"Puppet Mongodb_user['User admin on db admin']\" }\n" }
    end

    describe command('mongo --version') do
      its(:exit_status) { is_expected.to eq 0 }
    end
  end

  describe 'uninstallation' do
    it 'uninstalls mongodb' do
      pp = <<-EOS
        class { 'mongodb::server':
             ensure => absent,
             package_ensure => absent,
             service_ensure => stopped,
             service_enable => false
           }
        -> class { 'mongodb::client': ensure => absent, }
      EOS
      apply_manifest(pp, catch_failures: true)
      apply_manifest(pp, catch_changes: true)
    end

    describe package(package_name) do
      it { is_expected.not_to be_installed }
    end

    describe service(service_name) do
      it { is_expected.not_to be_enabled }
      it { is_expected.not_to be_running }
    end

    describe port(27_017) do # rubocop:disable RSpec/RepeatedExampleGroupBody
      it { is_expected.not_to be_listening }
    end

    describe port(27_018) do # rubocop:disable RSpec/RepeatedExampleGroupBody
      it { is_expected.not_to be_listening }
    end
  end
end
