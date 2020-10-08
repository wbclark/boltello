plan boltello::configure_directories(
  TargetSpec $katello = get_target('katello'),
  String[1] $boltdir  = boltello::get_boltdir() 
) {
  # Get platform version
  $version  = lookup('boltello::puppet_version')
  $platform = $version.split('\.')[0]

  # Copy the boltdir into the module's files directory and configure module files
  run_task('boltello::configure_directories', 
    $katello, 
    'configure boltello directory for proxy deployment', 
    boltdir  => $boltdir, 
    platform => $platform,
  )
}
