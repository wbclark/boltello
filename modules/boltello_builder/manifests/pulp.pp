# == Class boltello_builder:pulp
#
class boltello_builder::pulp {
  include ::foreman_proxy::plugin::pulp
  include ::foreman_proxy_content

  selinux::port { 'allow_crane_port':
    ensure   => 'present',
    seltype  => 'http_port_t',
    protocol => 'tcp',
    port     => 5000,
  }
}
