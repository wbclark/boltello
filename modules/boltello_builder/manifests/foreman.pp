# == Class boltello_builder::foreman
#
class boltello_builder::foreman (
  Array[String] $ignored_environments = [],
  Array[String] $trusted_hosts = [],
  Array[Hash] $foreman_config_entries = [{}],
  Boolean $enable_remote_execution = undef
){
  include ::foreman
  include ::foreman::cli

  # Only include REX if enabled in Hiera
  if $enable_remote_execution {
    include foreman::plugin::remote_execution
  }

  Foreman_config_entry {
    require => Class['::foreman::settings'],
  }

  $foreman_trusted_hosts = [{
    'trusted_hosts' => {
      'name'  => 'trusted_hosts',
      'value' => $trusted_hosts.to_json(),
  }}]

  $config_entries = $foreman_config_entries + $foreman_trusted_hosts

  # Process any 'foreman_config_entries' found in Hiera
  $config_entries.reduce({}) |Variant[Undef, Hash] $memo, Hash $config_entry| {
    create_resources(foreman_config_entry, $config_entry)
  }

  # Symbolize keys for the ignored_environemnts.yaml file
  $ignored = { 'ignored' => $ignored_environments }
  $content = boltello_builder::symbolize_keys($ignored)

  # Manage Foreman's ignored_environments.yml file
  file { '/usr/share/foreman/config/ignored_environments.yml':
    ensure => $ignored_environments.empty() ? {
      true    => absent,
      default => present
    },
    content => $content.to_yaml(),
    owner   => 'root',
    group   => 'root',
    require => Class['::foreman'],
  }
}
