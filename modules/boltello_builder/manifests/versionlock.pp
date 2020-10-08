# == Class: boltello_builder::versionlock
#
class boltello_builder::versionlock(
  Enum['locked', 'unlock'] $lock_status,
){
  $target = '/etc/yum/pluginconf.d/versionlock.list'

  $versionlock_packages = $lock_status ? {
    'locked' => Array(lookup('boltello::versionlock_packages')).sort(),
    'unlock' => {},
  }

  package { 'yum-plugin-versionlock':
    ensure   => present,
    provider => yum,
  }

  if $versionlock_packages.empty() {
    exec { 'clear_locked_packages':
      command   => "/bin/truncate -s 0 ${target}",
      logoutput => false,
    }
  }

  concat { "${target}":
    require => Package['yum-plugin-versionlock'],
    ensure  => present,
  }

  Concat::Fragment {
    target => "${target}",
    notify => Exec['refresh_yum']
  }

  concat::fragment { 'versionlock_header':
    content => "# Managed by Puppet\n",
    order   => -1,
  }

  $versionlock_packages.reduce(0) |Integer $order, Tuple $elements| {
    Hash($elements).each |String $package, String $version| {
      $versionlock = { "versionlock-${package}-${version}" => {
        content => "${order}:${package}-${version}*\n",
        order   => $order,
      }}
      create_resources(concat::fragment, $versionlock)
    }
    $order+1
  }

  exec { 'refresh_yum':
    command     => '/bin/yum clean plugins',
    require     => Concat["${target}"],
    refreshonly => true,
  }
}
