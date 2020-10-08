# == Task: boltello::generate_puppetfile
#
# Walk the directory of modules* and print out a Puppetfile
# See: https://github.com/rnelson0/puppet-generate-puppetfile
#
# [*] Katello modules: /usr/share/foreman-installer/modules
#
# Requires jq rpm, generate-puppetfile gem
#
if [[ ! $(rpm -qa | grep jq) ]]; then
    yum -y install jq
fi

if [[ ! $(/opt/puppetlabs/puppet/bin/gem list | grep generate-puppetfile) ]]; then
    /opt/puppetlabs/puppet/bin/gem install generate-puppetfile
fi

modulepath="$PT_modulepath"
modules=($(find $modulepath -maxdepth 1 -type d | xargs))
puppetfile=$(mktemp)
export PATH="/opt/puppetlabs/bin:$PATH"

# Parse metadata, write to temporary Puppetfile
for module in "${modules[@]}"; do
    if [[ $module != $modulepath ]]; then
        metadata=$module/metadata.json
        if [[ -f $metadata ]]; then
            name=$(cat "$metadata" | jq '.name' | xargs)
            version=$(cat "$metadata" | jq '.version' | xargs)
            mod=$(echo $name | tr "-" "/")
            echo -e "mod '${mod}', '${version}'" >> $puppetfile
        fi
    fi
done

# Run the gem to output a formatted puppetfile to console
/opt/puppetlabs/puppet/bin/generate-puppetfile -p $puppetfile

# Remove temp file
rm -f $puppetfile 0 2 3 15
