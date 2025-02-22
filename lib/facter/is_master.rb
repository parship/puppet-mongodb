# frozen_string_literal: true

require 'json'
require 'yaml'

def mongod_conf_file
  locations = ['/etc/mongod.conf', '/etc/mongodb.conf']
  locations.find { |location| File.exist? location }
end

def get_options_from_hash_config(config)
  result = []

  result << "--port #{config['net.port']}" unless config['net.port'].nil?
  # use --ssl and --host if:
  # - sslMode is "requireSSL"
  # - Parameter --sslPEMKeyFile is set
  # - Parameter --sslCAFile is set
  result << "--ssl --host #{Facter.value(:fqdn)}" if config['net.ssl.mode'] == 'requireSSL' || !config['net.ssl.PEMKeyFile'].nil? || !config['net.ssl.CAFile'].nil?
  result << "--sslPEMKeyFile #{config['net.ssl.PEMKeyFile']}" unless config['net.ssl.PEMKeyFile'].nil?
  result << "--sslCAFile #{config['net.ssl.CAFile']}" unless config['net.ssl.CAFile'].nil?
  # use --tls and --host if:
  # - tlsMode is "requireTLS"
  # - Parameter --tlsCertificateKeyFile is set
  # - Parameter --tlsCAFile is set
  result << "--tls --host #{Facter.value(:fqdn)}" if config['net.tls.mode'] == 'requireTLS' || !config['net.tls.certificateKeyFile'].nil? || !config['net.tls.CAFile'].nil?
  result << "--tlsCertificateKeyFile #{config['net.tls.certificateKeyFile']}" unless config['net.tls.certificateKeyFile'].nil?
  result << "--tlsCAFile #{config['net.tls.CAFile']}" unless config['net.tls.CAFile'].nil?

  result << '--ipv6' unless config['net.ipv6'].nil?

  result.join(' ')
end

def get_options_from_keyvalue_config(file)
  config = {}
  File.readlines(file).map do |line|
    k, v = line.split('=')
    config[k.rstrip] = v.lstrip.chomp if k && v
  end

  result = []

  result << "--port #{config['port']}" unless config['port'].nil?
  # use --ssl and --host if:
  # - sslMode is "requireSSL"
  # - Parameter --sslPEMKeyFile is set
  # - Parameter --sslCAFile is set
  result << "--ssl --host #{Facter.value(:fqdn)}" if config['ssl'] == 'requireSSL' || !config['sslcert'].nil? || !config['sslca'].nil?
  result << "--sslPEMKeyFile #{config['sslcert']}" unless config['sslcert'].nil?
  result << "--sslCAFile #{config['sslca']}" unless config['sslca'].nil?
  # use --tls and --host if:
  # - tlsMode is "requireTLS"
  # - Parameter --tlsCertificateKeyFile is set
  # - Parameter --tlsCAFile is set
  result << "--tls --host #{Facter.value(:fqdn)}" if config['tls'] == 'requireTLS' || !config['tlscert'].nil? || !config['tlsca'].nil?
  result << "--tlsCertificateKeyFile #{config['tlscert']}" unless config['tlscert'].nil?
  result << "--tlsCAFile #{config['tlsca']}" unless config['tlsca'].nil?

  result << '--ipv6' unless config['ipv6'].nil?

  result.join(' ')
end

def get_options_from_config(file)
  config = YAML.load_file(file)
  if config.is_a?(Hash) # Using a valid YAML file for mongo 2.6
    get_options_from_hash_config(config)
  else # It has to be a key-value config file
    get_options_from_keyvalue_config(file)
  end
end

Facter.add('mongodb_is_master') do
  setcode do
    if %w[mongosh mongod].all? { |m| Facter::Util::Resolution.which m }
      file = mongod_conf_file
      if file
        options = get_options_from_config(file)
        e = File.exist?('/root/.mongoshrc.js') ? 'load(\'/root/.mongoshrc.js\'); ' : ''

        # Check if the mongodb server is responding:
        Facter::Core::Execution.exec("mongosh --quiet #{options} --eval \"#{e}EJSON.stringify(db.adminCommand({ ping: 1 }))\"")

        if $CHILD_STATUS.success?
          Facter::Core::Execution.exec("mongosh --quiet #{options} --eval \"#{e}db.isMaster().ismaster\"")
        else
          'not_responding'
        end
      else
        'not_configured'
      end
    else
      'not_installed'
    end
  end
end
