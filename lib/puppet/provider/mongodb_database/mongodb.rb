# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), '..', 'mongodb'))
Puppet::Type.type(:mongodb_database).provide(:mongodb, parent: Puppet::Provider::Mongodb) do
  desc 'Manages MongoDB database.'

  defaultfor kernel: 'Linux'

  def self.instances
    require 'json'

    pre_cmd = '
    try {
      version=parseInt(db.version().split(\'.\')[0])
      if (version>=5){
        db.getMongo().setReadPref(\'nearest\')
      }
      else{
        rs.secondaryOk()
      }
    }
    catch (err) {
      rs.slaveOk()
    }
    '.squeeze(" ")
    mongo_eval_result = mongo_eval("#{pre_cmd};JSON.stringify(db.getMongo().getDBs())")
    dbs = JSON.parse mongo_eval_result

    dbs['databases'].map do |db|
      new(name: db['name'],
          ensure: :present)
    end
  end

  # Assign prefetched dbs based on name.
  def self.prefetch(resources)
    dbs = instances
    resources.each_key do |name|
      provider = dbs.find { |db| db.name == name }
      resources[name].provider = provider if provider
    end
  end

  def create
    if db_ismaster
      out = mongo_eval('db.dummyData.insert({"created_by_puppet": 1})', @resource[:name])
      raise "Failed to create DB '#{@resource[:name]}'\n#{out}" if %r{writeError} =~ out
    else
      Puppet.warning 'Database creation is available only from master host'
    end
  end

  def destroy
    if db_ismaster
      out = mongo_eval('db.dropDatabase()', @resource[:name])
      raise "Failed to destroy DB '#{@resource[:name]}'\n#{out}" if %r{writeError} =~ out
    else
      Puppet.warning 'Database removal is available only from master host'
    end
  end

  def exists?
    !(@property_hash[:ensure] == :absent || @property_hash[:ensure].nil?)
  end
end
