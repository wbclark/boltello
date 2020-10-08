# == Plan boltello::katello_upgrade
#
plan boltello::katello_upgrade(
  Float $katello_version                      = undef,
  Float $foreman_version                      = undef,
  String[1] $boltdir                          = boltello::get_boltdir(),
  Optional[String] $hiera_config              = "$boltdir/hiera.yaml",
  Optional[String] $modulepath                = "$boltdir/modules",
  Optional[Boolean] $enforce_foreman_password = true,
  Optional[Boolean] $manage_pulp              = true,
  Optional[Boolean] $manage_candlepin         = true,
  Optional[Boolean] $monolithic               = false,
  Optional[Boolean] $force                    = false,
  Optional[Boolean] $update_metadata          = false,
  Optional[Boolean] $maintain_database        = false,
  Optional[Boolean] $optimize_database        = false,
  Optional[Boolean] $delete_auditrecords      = false,
  Optional[Boolean] $delete_reports           = false,
  Optional[String] $days_audit                = '10',
  Optional[String] $days_reports              = '2',
  Optional[String] $rails_env                 = 'production',  
  TargetSpec $nodes = $monolithic ? {
    true    => get_target('katello'),
    default => undef,
  }
) {
  # Get the katello target
  $katello = get_target('katello')

  # Get the proxy targets
  $proxies = get_targets('proxies')

  # Initialize source variables
  $foreman_source = "http://yum.theforeman.org/releases/${foreman_version}/el7/x86_64/foreman-release.rpm"
  $katello_source = "http://fedorapeople.org/groups/katello/releases/yum/${katello_version}/katello/el7/x86_64/katello-repos-latest.rpm"

  $puppetserver_version = lookup('boltello::puppet_version')
  $puppet_major_version = $puppetserver_version.split('\.')[0]

  $katello_repos = [
    'base',
    'extras',
    'updates',
    'epel', 
    'centos-sclo-rh',
    'centos-sclo-sclo',
    'katello', 
    'katello-candlepin',
    'katello-pulpcore',
    'pulp',
    'foreman',
    'foreman-plugins',
    'foreman-rails',
    'passenger',
    "puppet${puppet_major_version}"
  ]

  # Initialize some variables
  $foreman_scl = 'foreman-release-scl'
  $yum_options = '--setopt=deltarpm=0 --nogpgcheck'
  $enablerepos = "--enablerepo ${katello_repos.join(',')}"
  $yum         = '/bin/yum -y'
  $yum_clean   = '/bin/yum clean'
  $rake        = '/sbin/foreman-rake'
  $facter      = '/opt/puppetlabs/bin/facter -p'
  $custom_dir  = "--custom-dir=$boltdir/lib/facter"
  
  $next_action = $force ? {
    true    => "; 'force' enabled, continuing workflow...",
    default => "... skipping; add argument 'force=true' to bypass this check",
  }

  # Get katello version from hiera yaml
  $metadata_version       = Float(lookup('boltello::katello_version'))
  $db_user                = lookup('boltello::candlepin_db_user')
  $db_password            = Sensitive(lookup('boltello::candlepin_db_password'))
  $foreman_admin_password = Sensitive(lookup('boltello::initial_admin_password'))

  $pulp_services = [
    'pulp_workers',
    'pulp_celerybeat',
    'pulp_streamer',
    'pulp_resource_manager'
  ]

  # Filter targets and update packages based on role
  get_targets($nodes).each |TargetSpec $node| {
    # Get installed version from custom fact
    $facter_result = run_command("$facter $custom_dir boltello.katello_version", 
      $node, 
      'check installed katello version', 
      _catch_errors => true
    )

    if !$facter_result.ok {
      warning("Advisory: katello not installed on node ${node.name}, skipping...")
      next()
    }

    # Strip return character, convert to Float
    $installed_version = Float($facter_result[0].value['stdout'].chomp())

    # Limit updates to +1 patch-level increments 
    # Also ensure hiera data isn't stale
    $installed = ($installed_version > Float('1.0'))
    $threshold = $installed and ($katello_version - $installed_version >= Float('0.02')) 
    $staledata = $installed and ($katello_version - $metadata_version > Float('0.02'))

    # Compare versions
    if $threshold {
      fail_plan("installed version: $installed_version, target version: $katello_version. update incrementally")
    } elsif $staledata { 
      fail_plan("version from hiera: $metadata_version, target version: $katello_version. update hiera data")
    } elsif ($installed_version > $katello_version) {
      warning("Advisory: installed katello version ${installed_version} is greater than ${katello_version} on ${node.name}... skipping")
      next()
    } elsif ($katello_version == $installed_version) {
      warning("Advisory: katello ${installed_version} already installed on ${node.name}${next_action}")
      unless $force { next() }
    } 

    $katello_services = run_command('/bin/foreman-maintain service status --brief >/dev/null 2>&1', 
      $node, 
      'check katello-service status',
      _catch_errors => true
    )

    unless $katello_services.ok {
      run_command('/bin/foreman-maintain service start >/dev/null 2>&1', 
        $node, 
        'restart katello services'
      )
    }

    # Unlock packages
    run_plan('boltello::versionlock',
      nodes       => $node,
      lock_status => 'unlock',
    )

    if $katello.name == $node.name {
      $upgrade_check = run_command("$rake katello:upgrade_check", 
        $node, 
        'run katello:upgrade_check', 
        _catch_errors => true
      )

      unless $upgrade_check.ok {
        warning("Advisory: katello packages are unlocked!")
        warning("Advisory: run 'bolt plan run boltello::versionlock lock_status=locked --targets ${node.name}' to lock packages")
        err("Critical: katello:upgrade_check failed on node ${node.name}. check logs, resolve any issues and re-run plan")
        break()
      }

      run_command('rpm --import /etc/pki/rpm-gpg/*', 
        $node,
        'import gpg keys'
      )

      # Upgrade foreman
      run_command("$yum_clean metadata", 
        $node, 
        'run yum clean metadata'
      )

      run_command("$yum upgrade $yum_options $foreman_scl", 
        $node, 
        'upgrade foreman scl repository'
      )

      run_command("$yum update-to $yum_options $foreman_source", 
        $node,
        'update-to foreman repository'
      )

      run_command("$yum upgrade foreman $yum_options $enablerepos", 
        $node, 
        'upgrade foreman release versions'
      )
      
      # Yum update
      run_command("$yum update $yum_options $enablerepos", 
        $node, 
        'update system'
      )

      run_command("$yum_clean all", 
        $node, 
        'run yum clean all'
      )

      # Update packages
      run_command("$yum update-to $yum_options $katello_source", 
        $node, 
        'update-to katello repository'
      )

      run_command("$yum upgrade katello-candlepin",
        $node, 
        'upgrade katello-candlepin repository'
      )

      # Yum update again
      run_command("$yum_clean all", 
        $node, 
        'run yum clean all'
      )

      run_command("$yum upgrade candlepin candlepin-selinux tomcatjss --enablerepo=katello-candlepin,base",
        $node, 
        'upgrade candplepin packages'
      )

      run_command("$yum upgrade $yum_options $enablerepos", 
        $node, 
        'upgrade katello'
      )

      # Stop katello services
      run_command('/bin/foreman-maintain service stop >/dev/null 2>&1', 
        $node, 
        'stop katello services', 
        _catch_errors => true
      )

      # Run puppet
      run_plan('boltello::run_puppet', 
        nodes => $node,
      )

      if !$monolithic {
        # Recursively copy the boltdir to be served by puppet
        run_plan('boltello::configure_directories', 
          katello => $node, 
        )
      }

      # Yum update one last time
      run_command("$yum update $yum_options $enablerepos", 
        $node, 
        'update katello'
      )

      # Get current installed version from custom fact
      $new_facter_result = run_command("$facter $custom_dir boltello.katello_version", 
        $node, 
        're-check installed katello version'
      )

      $current_version = Float($new_facter_result[0].value['stdout'].chomp())

      if (($current_version == $katello_version) and !$installed) {
        warning("Advisory: katello upgraded from version ${installed_version} to version ${current_version} on ${node.name}")
      }

      # Manage database operations
      if $maintain_database or ($katello_version > $installed_version) {
        if $delete_auditrecords {
          # Permanently delete all audit records older than $days_audit days
          run_command("$rake audits:expire days=${days_audit} RAILS_ENV='${rails_env}'", 
            $node, 
            "delete audit records older than ${days_audit} days"
          )
        }

        if $delete_reports {
          # Permanently delete all reports older than $days_reports days
          run_command("$rake reports:expire days=${days_reports} batch_size=50000 sleep_time=0.000001 RAILS_ENV='${rails_env}'", 
            $node, 
            "delete reports older than ${days_reports} days"
          )
        }

        if $manage_candlepin {
          run_command("/usr/share/candlepin/cpdb --update --database '//localhost/candlepin' --user '${db_user}' --password '${db_password.unwrap()}'", 
            $node, 
            'update candlepin database'
          )
        }

        if $manage_pulp {
          run_command("/bin/foreman-maintain service stop --only ${pulp_services.join(',')} >/dev/null 2>&1",
            $node,
            'stop pulp services'
          )

          run_command("/bin/pulp-manage-db", 
            $node, 
            'update pulp database',
            _run_as => 'apache'
          )

          run_command("/bin/foreman-maintain service start --only ${pulp_services.join(',')} >/dev/null 2>&1",
            $node,
            'start pulp services'
          )
        }

        # Post-update rake tasks
        [
          'db:migrate',
          'db:seed',
          'upgrade:run',
          'apipie:cache:index',
          'tmp:cache:clear',
          'db:sessions:clear'
        ].each |String $task| {
          run_command("$rake $task", 
            $node, 
            "run foreman-rake $task"
          )
        }
      }

      run_command('/bin/foreman-maintain service restart >/dev/null 2>&1', 
        $node, 
        'restart katello services', 
        _catch_errors => true
      )

      # Check for katello-service status
      $check_status = run_command('/bin/foreman-maintain service status --brief >/dev/null 2>&1', 
        $node, 
        'check service status',
        _catch_errors => true
      )

      if $check_status.ok and ($current_version == $katello_version) {
        if $optimize_database {
          # Get database adapater
          $db_data = loadyaml('/etc/foreman/database.yml')
          $adapter = $db_data['production']['adapter']

          $optimize_command = $adapter ? {
            'postgresql' => 'su - postgres -c "vacuumdb --full --dbname=foreman"',
            'default'    => 'mysqlcheck --optimize --all-databases'
          }

          # Print notification
          warning("Advisory: reclaiming storage in the foreman ${adapter} database")

          # Stop katello services
          run_command("/bin/foreman-maintain service stop --exclude ${adapter} >/dev/null 2>&1", 
            $node, 
            'stop katello services'
          )

          # Optimize the database 
          $optimize = run_command("${optimize_command}", 
            $node, 
            "optimize ${adapter} database"
          )

          # Print notification
          if $optimize.ok {
            warning("Advisory: ${adapter} optimization complete, restarting services...")
          }

          # Restart katello services
          run_command('/bin/foreman-maintain service restart >/dev/null 2>&1', 
            $node, 
            'restart katello services'
          )
        }

        if ($katello_version > $metadata_version) and $update_metadata {
          # Update hiera with new version data
          without_default_logging() || { 
            run_plan('boltello::update_metadata', 
              katello         => $node, 
              katello_version => "${katello_version}", 
              foreman_version => "${foreman_version}"
            ) 
          }

          # Print notification
          warning("Revision: 'boltello::katello_version' updated from '${metadata_version}' to '${katello_version}' in $boltdir/data/common.yaml")
        }

        if $enforce_foreman_password {
          run_command("${rake} permissions:reset password=${foreman_admin_password.unwrap()}", 
            $node, 
            'ensure foreman admin password'
          )
        }

        # Lock packages
        run_plan('boltello::versionlock',
          nodes       => $node,
          lock_status => 'locked',
        )
      }
    } elsif !$monolithic {
      if $node in $proxies {
        # Yum update
        run_command("$yum update $yum_options $enablerepos", 
          $node, 
          'update system'
        )

        run_command("$yum_clean all", 
          $node, 
          'run yum clean all'
        )

        run_command('rpm --import /etc/pki/rpm-gpg/*', 
          $node,
          'import gpg keys'
        )

        # Update packages
        run_command("$yum update-to $yum_options $foreman_source", 
          $node, 
          'update-to foreman repository'
        )

        run_command("$yum update-to $yum_options $katello_source", 
          $node, 
          'update-to katello repository'
        )

        run_command("$yum upgrade $yum_options $enablerepos foreman-proxy-content", 
          $node, 
          'upgrade foreman-proxy-content'
        )

        # Yum update again
        run_command("$yum_clean all", 
          $node, 
          'run yum clean all'
        )

        run_command("$yum update candlepin candlepin-selinux tomcatjss --enablerepo katello-candlepin",
          $node, 
          'update candplepin packages'
        )

        run_command("$yum upgrade $yum_options $enablerepos", 
          $node, 
          'upgrade foreman-proxy-content'
        )
   
        # Run puppet
        run_plan('boltello::run_puppet', 
          nodes => $node,
        )

        # Yum update one last time
        run_command("$yum update $yum_options $enablerepos", 
          $node, 
          'update foreman-proxy-content'
        )

        run_command('/bin/foreman-maintain service restart >/dev/null 2>&1', 
          $node, 
          'restart katello services'
        )

        # Lock packages
        run_plan('boltello::versionlock',
          nodes       => $node,
          lock_status => 'locked',
        )

        # Get current installed version from custom fact
        $new_facter_result = run_command("$facter $custom_dir boltello.katello_version", 
          $node, 
          're-check installed katello version'
        )

        $current_version = Float($new_facter_result[0].value['stdout'].chomp())

        if (($current_version == $katello_version) and !$installed) {
          warning("Advisory: katello upgraded from version ${installed_version} to version ${current_version} on ${node.name}")
        }
      } else {
        warning("Advisory: ${node.name} not found in inventory... skipping")
        next()
      } 
    }
  }
}
