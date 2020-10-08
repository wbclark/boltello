
# == Class boltello_builder::certs
#
class boltello_builder::certs {
  include ::certs

  if $facts['boltello_role'] == 'proxy' {
    include ::certs::puppet
  }
}
