# == Class boltello_builder::reverse_proxy
#
class boltello_builder::reverse_proxy(
  Boolean $enable_remote_agent_install
){
  include ::nginx

  if $enable_remote_agent_install {
    file { '/usr/share/nginx':
      ensure  => directory,
      require => Class['::nginx'],
    }

    file { '/usr/share/nginx/install':
      ensure  => present,
      require => File['/usr/share/nginx'],
      content => template('boltello_builder/install.erb'),
    }
  }
}
