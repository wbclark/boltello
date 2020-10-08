# == Plan boltello::build_katello
#
plan boltello::build_katello(
  TargetSpec $nodes        = get_target('katello'),
  String[1] $boltdir       = boltello::get_boltdir(),
  String[1] $modulepath    = "$boltdir/modules",
  String[1] $hiera_config  = "$boltdir/hiera.yaml",
  Optional[Boolean] $force = false,
  Boolean $agent_only      = false,
  Boolean $katello_prep    = false,
  Boolean $monolithic      = false,
) {
  # Ensure command line options are mutually exclusive
  $build_stages   = [$agent_only, $katello_prep, $monolithic]
  $enabled_stages = $build_stages.filter |Boolean $value| { $value == true }
  
  if $enabled_stages.size > 1 {
    fail_plan('command line options are mutually exclusive')
  } elsif get_target($nodes).name != get_target('katello').name {
    fail_plan('ensure the target node is in the katello group')
  }

  # Iterate upon a single node to facilitate graceful exits with next()
  get_target($nodes).with |TargetSpec $node| {
    # Check installed version
    run_plan('boltello::check_version', 
      nodes => $node, 
      force => $force
    )

    # Install puppet agent
    run_plan('boltello::install_puppet', 
      nodes         => $node, 
      boltdir       => $boltdir, 
      manage_config => true
    )

    if $agent_only { 
      warning("Advisory: puppet agent package installed")
      next()  
    }

    # Ensure the boltello_role fact for the katello server
    run_task('boltello::boltello_role', 
      $node, 
      'ensure fact boltello_role => katello', 
      boltello_role => 'katello'
    )

    # Prep node with katello repositories/packages
    run_plan('boltello::katello_prep', 
      nodes => $node,
      force => ($katello_prep and $force)
    )

    if $katello_prep { 
      warning("Advisory: katello packages ensured")
      next() 
    }

    # Run puppet on the katello server
    run_plan('boltello::run_puppet', 
      nodes        => $node, 
      hiera_config => $hiera_config, 
      modulepath   => $modulepath
    )

    if !$monolithic { 
      # Recursively copy the boltdir to be served by puppet
      run_plan('boltello::configure_directories', 
        katello => $node, 
        boltdir => $boltdir,
      )

      # Generate katello & puppet certificates for each proxy server
      run_plan('boltello::generate_certs', 
        katello => $node, 
        boltdir => $boltdir, 
      )
    } else {
      warning("Advisory: katello monolithic configuration complete")
    }
  }
}
