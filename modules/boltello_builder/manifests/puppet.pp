# == Class boltello_builder::puppet
#
class boltello_builder::puppet {
  include ::puppet

  if defined(Class['::puppet::server::config']) {
    include ::foreman::puppetmaster
  }
}
