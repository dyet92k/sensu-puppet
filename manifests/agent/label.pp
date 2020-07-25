# @summary Add agent label
#
# @example
#   sensu::agent::label { 'contacts': value => 'ops@example.com' }
#
# @param key
#   Key of the label to add to agent.yml, defaults to `$name`.
# @param value
#   Label value to add to agent.yml
# @param redact
#   Boolean that sets if this entry should be added to redact list
# @param order
#   Order of the datacat fragment
# @param entity
#   Entity where to manage this label
# @param namespace
#   Namespace of entity to manage this label
#
define sensu::agent::label (
  String $value,
  String[1] $key   = $name,
  Boolean $redact = false,
  String[1] $order = '50',
  Optional[String[1]] $entity = undef,
  Optional[String[1]] $namespace = undef,
) {
  include sensu::agent
  if ! $entity {
    $_entity = $sensu::agent::config['name']
  } else{
    $_entity = $entity
  }
  if ! $namespace {
    $_namespace = $sensu::agent::config['namespace']
  } else {
    $_namespace = $namespace
  }

  datacat_fragment { "sensu_agent_config-label-${name}":
    target => 'sensu_agent_config',
    data   => {
      'labels' => { $key => $value },
    },
    order  => $order,
  }

  sensu_agent_entity_config { "sensu::agent::label ${name}":
    config    => 'labels',
    key       => $key,
    value     => $value,
    entity    => $_entity,
    namespace => $_namespace,
    provider  => $sensu::agent::agent_entity_config_provider,
  }

  if $redact {
    sensu::agent::config_entry { "redact-label-${name}":
      key   => 'redact',
      value => [$key],
    }
    sensu_agent_entity_config { "sensu::agent::label redact ${name}":
      config    => 'redact',
      value     => $key,
      entity    => $_entity,
      namespace => $_namespace,
      provider  => $sensu::agent::agent_entity_config_provider,
    }
  }
}
