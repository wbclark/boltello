# == Plan boltello::check_version
#
plan boltello::check_version(
  TargetSpec $nodes,
  Boolean $force,
  String[1] $boltdir = boltello::get_boltdir()
) {
  # Check for installed katello versions
  $rpm_query = run_command('/bin/rpm -q --queryformat "%{version}" katello', 
    $nodes, 
    'check installed katello version', 
    _catch_errors => true
  )
  
  $rpm_query_result = $rpm_query[0].value['stdout']
  
  $installed_version = $rpm_query_result ? {
    /[0-9]/ => Float($rpm_query_result.regsubst('(.*)\..*', '\1')),
    default => Float('0.0')
  }

  # Get katello version from hiera yaml
  $katello_version = Float(lookup('boltello::katello_version'))

  $installed = ($installed_version > Float('0.0'))
  $threshold = $installed and ($katello_version - $installed_version > Float('0.009'))
  $staledata = $installed and ($installed_version - $katello_version > Float('0.02'))

  # A discrepancy of more than one version
  if $threshold {
    fail_plan("installed version: $installed_version, version from hiera: $katello_version. use the 'boltello::katello_upgrade' plan")
  } elsif $staledata {
    fail_plan("installed version: $installed_version, version from hiera: $katello_version. update the hiera data")
  }

  if ($installed_version >= $katello_version) {
    if !$force {
      fail_plan("installed katello version: $installed_version, version from hiera: $katello_version. use the 'force', Luke")
    } else {
      if ($installed_version == $katello_version) {
        warning("Advisory: katello version $installed_version already installed; 'force' enabled, continuing workflow...")
      }
    }
  }
}
