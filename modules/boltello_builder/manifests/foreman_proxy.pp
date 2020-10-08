# == Class boltello_builder::foreman_proxy
#
class boltello_builder::foreman_proxy (
  Boolean $enable_remote_execution
){  
  include ::foreman_proxy

  if $enable_remote_execution {
    include ::foreman_proxy::plugin::remote_execution::ssh

    $katello_server    = lookup('boltello::katello_server')
    $foreman_proxy_dir = lookup('foreman_proxy::dir')
    $ssl_port          = lookup('foreman_proxy::ssl_port')
    $ssh_identity_dir  = lookup('foreman_proxy::plugin::remote_execution::ssh::ssh_identity_dir')
    $ssh_identity_file = lookup('foreman_proxy::plugin::remote_execution::ssh::ssh_identity_file')
    $katello           = ($facts['boltello_role'] == 'katello')
    $proxy             = ($facts['boltello_role'] == 'proxy')

    Exec {
      require => Class['::foreman_proxy::plugin::remote_execution::ssh'],
    }

    exec { 'ensure_ssh_identity_dirs':
      command => "/bin/mkdir -p {${ssh_identity_dir},${foreman_proxy_dir}} && /bin/chown foreman-proxy:foreman-proxy {${ssh_identity_dir},${foreman_proxy_dir}}",
      creates => ["${ssh_identity_dir}", "${foreman_proxy_dir}"],
    }

    # https://access.redhat.com/solutions/4282171
    file { 'ensure_ssh_hidden_dir':
      path    => "${foreman_proxy_dir}/.ssh",
      ensure  => link,
      target  => "${ssh_identity_dir}",
      notify  => Exec['restorecon_ssh_hidden_dir'],
      require => Exec['ensure_ssh_identity_dirs'],
    }

    exec { 'restorecon_ssh_hidden_dir':
      command     => "/sbin/restorecon -RvF ${foreman_proxy_dir}/.ssh",
      refreshonly => true,
    }

    if $katello {
      exec { 'ensure_ssh_identity_file':
        command => "/bin/sudo -u foreman-proxy ssh-keygen -f ${ssh_identity_dir}/${ssh_identity_file} -N ''",
        creates => "${ssh_identity_dir}/${ssh_identity_file}",
        notify  => Service['foreman-proxy'],
      }
    } elsif $proxy {
      exec { 'add_pubkey':
        command => "/bin/curl -k https://${katello_server}:${ssl_port}/ssh/pubkey > ${ssh_identity_dir}/${ssh_identity_file}.pub",
        creates => "${ssh_identity_dir}/${ssh_identity_file}.pub",
        notify  => [
          Exec['add_to_authorized_keys'],
          Service['foreman-proxy']
        ],
        require => [
          Exec['ensure_ssh_identity_dirs'],
          File['ensure_ssh_hidden_dir']
        ],
      }

      exec { 'add_to_authorized_keys':
        command     => "/bin/cat ${ssh_identity_dir}/${ssh_identity_file}.pub >> /root/.ssh/authorized_keys",
        unless      => "/bin/grep -i foreman-proxy@${katello_server} /root/.ssh/authorized_keys",
        refreshonly => true,
      }
    }
  }
}
