# == Plan boltello::katello_prep
#
plan boltello::katello_prep(
  TargetSpec $nodes = get_target('localhost'),
  String $boltdir   = boltello::get_boltdir(),
  Boolean $force    = false
) {
  $foreman_version      = lookup('boltello::foreman_version')
  $katello_version      = lookup('boltello::katello_version')
  $nginx_version        = lookup('boltello::nginx_version')
  $postgresql_prefix    = lookup('boltello::postgresql_prefix')
  $postgresql_version   = lookup('boltello::postgresql_version')
  $puppetserver_version = lookup('boltello::puppetserver_version')
  $puppet_major_version = $puppetserver_version.split('\.')[0]

  $katello_role = (get_target($nodes).name == get_target('katello').name)
  
  $major_packages = [
    'katello',
    'foreman',
    'puppetserver',
    'centos-release-scl-rh',
  ]

  $katello_packages = [
    'qpid-dispatch-router', 
    'candlepin',
    'katello',
    'katello-debug'
  ]

  $selinux_packages = [ 
    'katello-selinux', 
    'foreman-selinux', 
    'candlepin-selinux', 
    'pulpcore-selinux', 
    'crane-selinux' 
  ]

  $major_packages_check = run_command("/bin/rpm -q ${major_packages.join(' ')}",
    $nodes,
    "check major packages",
    _catch_errors => true,
  )

  if !$major_packages_check.ok or $force {

    $release_packages = [
      {
        'name'   => 'foreman-release',
        'source' => "http://yum.theforeman.org/releases/${foreman_version}/el7/x86_64/foreman-release.rpm",
      },
      {
        'name'   => 'katello-repos',
        'source' => "http://fedorapeople.org/groups/katello/releases/yum/${katello_version}/katello/el7/x86_64/katello-repos-latest.rpm",
      },
      {
        'name'   => "puppet${puppet_major_version}-release",
        'source' => "https://yum.puppet.com/puppet${puppet_major_version}/puppet${puppet_major_version}-release-el-7.noarch.rpm",
      },
      {
        'name'   => 'epel-release',
        'source' => 'https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm',
      }
    ]

    $test_release_packages = $release_packages.map |Hash $package| { 
      $package['name'] 
    }

    $release_packages_check = run_command("/bin/rpm -q ${test_release_packages.join(' ')}",
      $nodes,
      "check installed release packages",
      _catch_errors => true,
    )

    if !$release_packages_check.ok  or $force {
      $release_packages.map |Integer $i, Hash $package| {
        run_command("/bin/yum -y localinstall ${package['source']}",
          $nodes,
          "ensure ${package['name']} package",
          _catch_errors => true,
        )
      }
    }

    $katello_packages_check = run_command("/bin/rpm -q ${katello_packages.join(' ')} ${selinux_packages.join(' ')}",
      $nodes,
      "check installed katello packages",
      _catch_errors => true,
    )

    if !$katello_packages_check.ok or $force {
      run_command('/bin/yum -y install centos-release-scl-rh',
        $nodes,
        'ensure centos scl release package',
        _catch_errors => true,
      )

      run_command('yum -y update',
        $nodes,
        'run yum update',
        _catch_errors => true,
      )

      run_command("/bin/yum -y install ${katello_packages.join(' ')}",
        $nodes,
        'ensure katello packages',
        _catch_errors => true,
      )

      run_command("/bin/yum -y install ${selinux_packages.join(' ')}",
        $nodes,
        'ensure selinux packages',
        _catch_errors => true,
      )
    }

    $puppetserver_package_check = run_command('/bin/rpm -q --queryformat "%{version}" puppetserver',
      $nodes,
      'check installed puppetserver version',
      _catch_errors => true,
    )

    $puppetserver_package_version = $puppetserver_package_check[0].value['stdout']

    $installed_version = $puppetserver_package_version ? {
       /[0-9]+?/ => Float($puppetserver_package_version.regsubst('(.*)\..*', '\1')),
       default   => Float('0.0'),
    }

    $hiera_version = Float($puppetserver_version.regsubst('(.*)\..*', '\1'))

    if ($installed_version != $hiera_version) {
      run_command("/bin/yum -y install puppetserver-${puppetserver_version} --enablerepo puppet${puppet_major_version}",
        $nodes,
        'ensure puppetserver package',
        _catch_errors => true,
      )
    }

    if $katello_role {
      $db_manage  = lookup('boltello::db_manage')
      $db_datadir = lookup('boltello::postgresql_datadir')
      $db_version = Float($postgresql_version)
      
      if ($installed_version != $hiera_version) {
        run_command('/opt/puppetlabs/puppet/bin/gem install puppetserver-ca',
          $nodes,
          'ensure puppetserver-ca gem',
          _catch_errors => true,
        )
      }

      if $db_manage {
        $rpm_version_query = run_command("/bin/rpm -qa --queryformat '%{version}' ${postgresql_prefix}postgresql-server",
          $nodes,
          'check postgresql version',
          _catch_errors => true
        )

        $postgresql_rpm_version = $rpm_version_query.to_data.reduce({}) |Hash $memo, Hash $data| { 
          if $data['value']['stdout'] =~ /[0-9]/ {
            Float($data['value']['stdout'])
          } else {
            Float('0.0')
          }
        }

        $install_postgresql = ($postgresql_rpm_version <= $db_version) 
        $upgrade_postgresql = !file::exists("${db_datadir}")
        $postgresql_install = ($install_postgresql or $upgrade_postgresql)

      } else {
        $postgresql_install = false
      }

      if ($postgresql_install or ($db_manage and $force)) {
        $foreman_infra_content = "[foreman-infra-el7]\\\\nname=Foreman infra el7\\\\nbaseurl=https://yum.theforeman.org/infra/el7/\\\\nenabled=True\\\\ngpgcheck=False"
        $foreman_infra_repo = '/etc/yum.repos.d/foreman-infra-el7.repo' 

        run_command("/bin/test -f ${foreman_infra_repo} || echo -e \$(echo ${foreman_infra_content}) > ${foreman_infra_repo}",
          $nodes,
          'ensure foreman-infra-el7 repo',
          _catch_errors => true,
        )

        run_command("/bin/yum -y install rh-redis5-redis",
          $nodes,
          'ensure redis5 packages',
          _catch_errors => true,
        )

        run_command("/bin/yum -y install ${postgresql_prefix}postgresql-server ${postgresql_prefix}postgresql-contrib",
          $nodes,
          'ensure postgresql-server packages',
          _catch_errors => true,
        )

        run_command("/bin/yum -y install ${postgresql_prefix}postgresql-evr --enablerepo foreman-infra-el7",
          $nodes,
          'ensure postgresql-server-evr package',
          _catch_errors => true,
        )

        run_command("/bin/scl enable ${postgresql_prefix}postgresql bash || :",
          $nodes,
          'enable postgresql-server',
          _catch_errors => false,
        )

        $new_rpm_version_query = run_command("/bin/rpm -qa --queryformat '%{version}' ${postgresql_prefix}postgresql",
          $nodes,
          'check postgresql version',
          _catch_errors => true
        )

        $installed_postgresql_version = $new_rpm_version_query.to_data.reduce({}) |Hash $memo, Hash $data| { 
          if $data['value']['stdout'] =~ /[0-9]/ {
            Float($data['value']['stdout'])
          } else {
            Float('0.0')
          }
        }

        warning("Advisory: ${postgresql_prefix}postgresql version ${installed_postgresql_version} installed")
      }
    } else {
      $proxy_packages = [
        "nginx-${nginx_version}",
        'git', 
        'foreman-proxy-content'
      ]
      
      get_targets($nodes).each |TargetSpec $node| {
        $check_proxy_packages = run_command("/bin/rpm -q ${proxy_packages.join(' ')}",
          $node,
          'check additional proxy packages',
          _catch_errors => true,
        )

        if !$check_proxy_packages.ok  or $force {
          $proxy_packages.each |String $package| {
            run_command("/bin/yum -y install ${package}",
              $nodes,
              "ensure ${package} package",
              _catch_errors => true,
            )
          }
        }
      }
    }

    # Lock packages
    if (!$katello_packages_check.ok or !$release_packages_check.ok or !$puppetserver_package_check.ok or $force) {
      run_plan('boltello::versionlock',
        nodes       => $nodes,
        lock_status => 'locked',
      )
    }
  }
}
