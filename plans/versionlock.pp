# == Plan boltello::versionlock
#
plan boltello::versionlock(
  TargetSpec $nodes = get_target('localhost'),
  String $boltdir   = boltello::get_boltdir(),
  Enum['locked', 'unlock'] $lock_status,
){
  $puppet_apply = '/opt/puppetlabs/bin/puppet apply'
  $config = "--hiera_config ${boltdir}/hiera.yaml --modulepath ${boltdir}/modules --hiera_config $boltdir/hiera.yaml --log_level debug --logdest syslog"
  $args   = "-e 'class { \"boltello_builder::versionlock\": lock_status => \"${lock_status}\" }'"

  $command_notice = $lock_status ? {
    'locked' => 'version locking packages',
    'unlock' => 'unlocking packages',
  }

  run_command("$puppet_apply $args $config",
    $nodes,
    "${command_notice}",
    _catch_errors => true,
  )
}
