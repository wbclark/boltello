# == Task boltello::configure_directories
#
#!/usr/bin/env bash

set -e

platform=$PT_platform
boltdir=$PT_boltdir
modules=$boltdir/modules
boltello_modules=$modules/boltello_builder/files/boltello/modules
boltello_files=$boltello_modules/boltello_builder/files
boltello_templates=$boltello_modules/boltello_builder/templates
erbfile=$boltello_templates/install.erb
shfile="$modules/boltello_builder/files/install_puppet_${platform}_agent.sh"

# Ensure the directory structure is intact
[[ -d $boltello_modules ]] || mkdir -p $boltello_modules
[[ -d $boltello_templates ]] || mkdir -p $boltello_templates 
[[ -d $boltello_files ]] || mkdir -p $boltello_files

rsync -rc --exclude ".git*" --exclude "modules/*" --exclude "files/*" --exclude ".resource_types" \
    $boltdir $modules/boltello_builder/files
rsync -rc --exclude "files/*" $modules/boltello_builder $boltello_modules

# Copy the puppet agent install script to the recursively copied module's file directory
rsync --ignore-existing $shfile $boltello_files

# Copy the puppet agent install script to an erb file
rsync --ignore-existing $shfile $erbfile

# Add configuration commands to the erb file
set_server='\n\n/opt/puppetlabs/bin/puppet config set server <%= @fqdn %> --section main'
run_agent='/opt/puppetlabs/bin/puppet agent -t --server <%= @fqdn %> --waitforcert 5'
add_pubkey='/bin/curl -s -k https://<%= @fqdn %>:9090/ssh/pubkey >> /root/.ssh/authorized_keys'

[[ $(grep 'config set' $erbfile) ]] || echo -e $set_server >> $erbfile
[[ $(grep 'authorized_keys' $erbfile) ]] || echo -e $add_pubkey >> $erbfile
[[ $(grep 'waitforcert' $erbfile) ]] || echo -e $run_agent >> $erbfile
