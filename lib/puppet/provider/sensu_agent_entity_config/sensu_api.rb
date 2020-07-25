require File.expand_path(File.join(File.dirname(__FILE__), '..', 'sensu_api'))
require File.expand_path(File.join(File.dirname(__FILE__), '../../..', 'puppet_x/sensu/agent_entity_config'))

Puppet::Type.type(:sensu_agent_entity_config).provide(:sensu_api, :parent => Puppet::Provider::SensuAPI) do
  desc "Provider sensu_agent_entity_config using sensu API"

  mk_resource_methods

  defaultfor :kernel => ['Linux','windows']

  def self.instances
    configs = []

    namespaces.each do |namespace|
      data = api_request('entities', nil, {:namespace => namespace})
      next if (data.nil? || data.empty?)
      data.each do |d|
        entity = d['metadata']['name']
        namespace = d['metadata']['namespace']
        PuppetX::Sensu::AgentEntityConfig.config_classes.keys.each do |c|
          value = d[c] || d['metadata'][c]
          next if value.nil?
          case PuppetX::Sensu::AgentEntityConfig.config_classes[c]
          when Array
            value.each do |v|
              config = {}
              config[:ensure] = :present
              config[:entity] = entity
              config[:namespace] = namespace
              config[:config] = c
              config[:value] = v
              config[:name] = "#{config[:config]} value #{config[:value]} on #{entity} in #{namespace}"
              configs << new(config)
            end
          when Hash
            value.each_pair do |key, v|
              config = {}
              config[:ensure] = :present
              config[:entity] = entity
              config[:namespace] = namespace
              config[:config] = c
              config[:key] = key
              config[:value] = v
              config[:name] = "#{config[:config]}:#{config[:key]} on #{entity} in #{namespace}"
              configs << new(config)
            end
          else
            config = {}
            config[:ensure] = :present
            config[:entity] = entity
            config[:namespace] = namespace
            config[:config] = c
            config[:value] = value
            config[:name] = "#{config[:config]} on #{entity} in #{namespace}"
            configs << new(config)
          end
        end
      end
    end
    configs
  end

  def self.prefetch(resources)
    configs = instances
    resources.keys.each do |name|
      if provider = configs.find do |r|
        case PuppetX::Sensu::AgentEntityConfig.config_classes[r.config]
        when Array
          r.config == resources[name][:config] && r.value == resources[name][:value] && r.entity == resources[name][:entity] && r.namespace == resources[name][:namespace]
        when Hash
          r.config == resources[name][:config] && r.key == resources[name][:key] && r.entity == resources[name][:entity] && r.namespace == resources[name][:namespace]
        else
          r.config == resources[name][:config] && r.entity == resources[name][:entity] && r.namespace == resources[name][:namespace]
        end
      end
        resources[name].provider = provider
      end
    end
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def initialize(value = {})
    super(value)
    @property_flush = {}
  end

  type_properties.each do |prop|
    define_method "#{prop}=".to_sym do |value|
      @property_flush[prop] = value
    end
  end

  def update(add = true)
    entity = get_entity(resource[:entity], resource[:namespace])
    config = resource[:config]
    if PuppetX::Sensu::AgentEntityConfig.metadata_configs.include?(config)
      obj = entity['metadata'][config]
    else
      obj = entity[config]
    end
    case PuppetX::Sensu::AgentEntityConfig.config_classes[config]
    when Array
      if add && obj.nil?
        obj = []
      end
      if add
        obj << resource[:value]
      else
        obj.delete(resource[:value])
      end
    when Hash
      if add && obj.nil?
        obj = {}
      end
      if add
        obj[resource[:key]] = resource[:value]
      else
        obj.delete(resource[:key])
      end
    else
      if add
        obj = resource[:value]
      else
        obj = ""
      end
    end
    if PuppetX::Sensu::AgentEntityConfig.metadata_configs.include?(config)
      entity['metadata'][config] = obj
    else
      entity[config] = obj
    end
    opts = {
      :namespace => resource[:namespace],
      :method => 'put',
    }
    api_request("entities/#{resource[:entity]}", entity, opts)
  end

  def create
    update
    @property_hash[:ensure] = :present
  end

  def flush
    if !@property_flush.empty?
      update
    end
    @property_hash = resource.to_hash
  end

  def destroy
    update(false)
    @property_hash.clear
  end
end
