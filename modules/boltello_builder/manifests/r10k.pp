# == Class: boltello_builder::r10k
#
class boltello_builder::r10k(
  String $default_environment = 'production',
  String $remote = undef,
) {
  include ::r10k

  unless $remote.empty() {
    exec { '/bin/r10k deploy environment':
      require => Class['r10k::install', 'r10k::config'],
      creates => "/etc/puppetlabs/code/environments/${default_environment}/Puppetfile",
    }
  }
}
