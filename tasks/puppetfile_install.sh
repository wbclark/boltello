# == Task boltello::puppetfile_install
#
#!/usr/bin/env bash
#
set -e

# Ensure bolt
[[ $(/bin/rpm -q puppet-bolt) ]] || yum -y install puppet-bolt

cd "${PT_boltdir}"
/usr/local/bin/bolt puppetfile install
