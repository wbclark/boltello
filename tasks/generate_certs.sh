# == Task boltello::generate_certs
#
#!/usr/bin/env bash
#
set -e

files="${PT_boltdir}/modules/boltello_builder/files"
puppet_args="--certname ${PT_proxy} ${PT_puppet_cnames}"
katello_cnames="${PT_katello_cnames}"
ssl_dir=$(/opt/puppetlabs/puppet/bin/puppet config print ssldir)
puppetserver='/opt/puppetlabs/bin/puppetserver ca'
proxy="${PT_proxy}"
private_key="${ssl_dir}/private_keys/${proxy}.pem"

[[ -d $files/certs ]] || mkdir -p $files/certs
cd $files/certs

if [[ ! -f "$files/certs/$proxy-certs.tar" ]]; then
    # Generate katello certs
    foreman-proxy-certs-generate --scenario foreman-proxy-certs --foreman-proxy-fqdn "$proxy" \
        --certs-tar "$files/certs/$proxy-certs.tar" $katello_cnames > /dev/null 2>&1
fi

if [[ ! -f $private_key ]]; then
    # Generate puppet certs 
    $puppetserver generate $puppet_args || :
fi

# Archive public/private key
if [[ ! -f $files/certs/$proxy-certs.tar.gz ]]; then
    if [[ -f $private_key ]] ; then
        # Find and tar the public/private certificates 
        find $ssl_dir -type f \( -name "ca.pem" -o -name "crl.pem" -o -name "$proxy.pem" -not -path "$ssl_dir/ca/signed/*" \) -print0 | \
            xargs -0 tar -zcf $files/certs/$proxy-certs.tar.gz > /dev/null 2>&1
    fi
fi
