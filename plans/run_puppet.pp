# == Plan boltello::run_puppet
#
plan boltello::run_puppet(
  TargetSpec $nodes,
  Optional[String] $boltdir      = boltello::get_boltdir(),
  String[1] $hiera_config        = "$boltdir/hiera.yaml",
  String[1] $modulepath          = "$boltdir/modules",
  Optional[String] $log_level    = 'debug',
  Optional[String] $logdest      = 'syslog'
) {
  $puppet_apply = '/opt/puppetlabs/bin/puppet apply'
  $args         = "-e 'include boltello_builder' --hiera_config ${hiera_config} --modulepath ${modulepath} --log_level ${log_level} --logdest ${logdest}"

  # Run puppet apply to configure the nodes
  run_command("${puppet_apply} ${args}",
    $nodes,
    'run puppet apply',
  )
}
