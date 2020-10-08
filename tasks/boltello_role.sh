# == Task boltello::boltello_role
#
#!/usr/bin/env bash
set -e

factsd="/etc/puppetlabs/facter/facts.d"
boltello_facts="$factsd/boltello_facts.yaml"

[[ -d "$factsd" ]] || mkdir -p "$factsd"
[[ -f "$boltello_facts" ]] || /bin/touch "$boltello_facts"

[[ $(/bin/grep "boltello_role: $PT_boltello_role" "$boltello_facts") ]] ||\
    echo -e "---\nboltello_role: $PT_boltello_role\n" > "$boltello_facts"
