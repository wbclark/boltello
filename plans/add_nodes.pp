# Plan: boltello::add_nodes
#
plan boltello::add_nodes(
  TargetSpec $nodes,
  Optional[Boolean] $fresh_install  = false,
  Optional[Boolean] $manage_package = true,
  Optional[Boolean] $migrate_hosts  = false,
  Optional[Boolean] $monolithic     = false,
  Optional[Boolean] $force          = false,
  Optional[Boolean] $clean_certs    = false,
  Optional[TargetSpec] $server      = $monolithic ? {
    true  => get_target('katello'),
    false => undef
  },
  String $boltdir = boltello::get_boltdir()
) {
  $puppet = '/opt/puppetlabs/bin/puppet'
  $katello = get_target('katello')

  # Agents only
  if $katello in $nodes {
    fail_plan("Remove ${katello} from the list of target nodes")
  }

  if $force and !$migrate_hosts {
    fail_plan("the option 'force' has no affect without 'migrate_hosts=true'")
  }

  # Remove agent and release package
  if $fresh_install and !$manage_package {
    fail_plan("use 'manage_package=true' and 'fresh_install=true' to perform a fresh installation")
  } elsif $fresh_install and $manage_package {
    $puppet_rpm_query = run_command('[ $(which rpm 2>/dev/null) ] && rpm -q puppet-agent || apt list | grep puppet-agent', 
      $nodes,
      'check puppet rpm',
      _catch_errors => true
    )

    if $puppet_rpm_query.ok {
      run_command('[ $(which yum 2>/dev/null) ] && yum -y remove puppet-agent || apt-get -y remove puppet-agent', 
        $nodes, 
        'remove agent package'
      )

      run_command('[ $(which yum 2>/dev/null) ] && yum -y remove puppet*-release || apt-get -y remove puppet*-release', 
        $nodes, 
        'remove release package'
      )
    } else {
      warning('Advisory: no puppet-agent package found')
    }
  }

  if $manage_package {
    run_plan('boltello::install_puppet',
      $nodes,
      boltdir       => $boltdir,
      server        => $server,
      manage_config => true
    )
  }

  $puppet_ssl_query = run_command('/opt/puppetlabs/bin/puppet config print ssldir',
    $nodes,
    'get ssldir location',
    _run_as       => 'root',
    _catch_errors => true,
  )

  $ssl_dir = $puppet_ssl_query[0].value['stdout'].strip()

  if $migrate_hosts {
    run_command("${puppet} resource service puppet ensure=stopped",
      $nodes,
      'stop agent service'
    )

    $puppet_server_query = run_command('/opt/puppetlabs/bin/puppet config print server',
      $nodes,
      'get server identity',
      _run_as       => 'root',
      _catch_errors => true,
    )

    $configured_server = $puppet_server_query[0].value['stdout'].strip

    if $configured_server != get_target($server).name {
      run_command("${puppet} config set server ${server} --section main",
        $nodes,
        "set server identity: ${server}"
      )
    }

    $ssl_directory_exists = run_command("/bin/test -d ${ssl_dir}",
      $nodes,
      'check for existing ssl directory',
      _catch_errors => true
    )

    if $clean_certs {
      get_targets($nodes).each |TargetSpec $node| {
        run_command("${puppet}server ca clean --certname ${node.name} || :",
          $katello,
          "clean certitificate for node ${node.name}",
          _catch_errors => true
        )
      }
    }

    if $ssl_directory_exists and $force {
      run_command("/bin/rm -fr ${ssl_dir}", 
        $nodes, 
        'force remove ssl dir'
      )
    } 
  }

  if $ssl_directory_exists and !$migrate_hosts {
    fail_plan("SSL directory found. Use 'migrate_hosts=true', 'clean_certs=true', or remove manually")
  }

  # Run puppet agent
  $run_puppet = run_command("${puppet} agent -t --server ${server} --waitforcert 5",
    $nodes,
    'connect agent to new puppetmaster'
  )

  if !$run_puppet.ok {
    warning("Advisory: puppet agent run failed. try 'fresh_install=true' ... or 'force=true'")
    warning("          use 'clean_certs=true' if there's a certificate mismatch")

  } else {
    $migrate_or_join_new = $migrate_hosts ? {
      true    => "migrated",
      default => "joined"
    }

    warning("Advisory: successfully ${migrate_or_join_new} node to ${server}")

    if $migrate_hosts {
      run_command("${puppet} resource service puppet ensure=running",
        $nodes,
        'ensure agent service is running'
      )
    }

    # Ensure foreman smart proxy public key
    $enable_remote_execution = lookup('boltello::enable_remote_execution')
    $ssl_port = lookup('boltello::foreman_proxy_ssl_port')

    if $enable_remote_execution {

      $public_key_query = run_command("/bin/curl -k https://${server}:${ssl_port}/ssh/pubkey",
        $katello,
        'fetch foreman-proxy pubkey',
        _catch_errors => true
      )

      $public_key = $public_key_query[0].value['stdout'].strip()

      get_targets($nodes).each |TargetSpec $node| {
        run_command("[[ $(/bin/grep '${public_key}' /root/.ssh/authorized_keys) ]] || echo '${public_key}' >> /root/.ssh/authorized_keys",
          $node,
          'add katello ssh pub key to agent authorized_keys'
        )
      }
    }
  }
}
