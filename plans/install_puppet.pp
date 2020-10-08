# == Plan boltello::install_puppet
#
plan boltello::install_puppet(
  TargetSpec $nodes                = get_target('localhost'),
  Optional[TargetSpec] $server     = get_target('katello'),
  Optional[Boolean] $manage_config = false,
  String[1] $boltdir               = boltello::get_boltdir()
) {
  $puppet   = '/opt/puppetlabs/bin/puppet'
  $version  = lookup('boltello::puppet_version')
  $platform = $version.split('\.')[0]

  # Initialize install script variable
  $puppet_install_script = "${boltdir}/modules/boltello_builder/files/install_puppet_${platform}_agent.sh"

  # Install puppet agent package
  $check_puppet = run_command("type -p ${puppet} 2>/dev/null", 
    $nodes, 
    'check puppet binary', 
    _catch_errors => true,
  )

  unless $check_puppet.ok {
    run_script($puppet_install_script, 
      $nodes, 
      'arguments' => ['-v', "${version}"], 
      _run_as     => 'root',
      _description => "install puppet ${platform}",
    )

    if $manage_config {
      run_command("${puppet} config set server ${server} --section main", 
        $nodes, 
        "set server property: ${server}",
      )
    }

    # Pre-install bolt
    $proxies = get_targets('proxies')

    get_targets($nodes).each |TargetSpec $node| {
      if $node in $proxies {
        run_command('/bin/yum -y install puppet-bolt',
          $node,
          'ensure puppet-bolt',
        )
      }
    }
  }
}
