# == Plan boltello::generate_certs
#
plan boltello::generate_certs(
  TargetSpec $katello        = get_target('katello'),
  String[1] $boltdir         = boltello::get_boltdir()
) {
  # Bolt is explicitly disallowed from interpolating fact
  # data in plans. This hack replaces fact interpolation with
  # "dirty interpolation". SAN hostnames are loaded as raw YAML
  # and combined with a domain regex applied to the proxy's
  # certname. Assuming that any variable after a Hiera 
  # interpolation token ('%') has the host's domain name as 
  # a value, we deduce the Subject Alternative Names like so:
  #   hostname: proxy2.example.com
  #   (Hiera) CNAME values: [ foo, bar.%{facts.networking.domain} ]
  #   Example certificate with SAN:
  #       certname  : proxy2.example.com
  #       alt names : [ DNS:proxy2.example.com, DNS:foo, DNS:bar.example.com ]
  #

  $alt_names_data  = loadyaml("$boltdir/data/plans/shared.yaml")
  $alt_names_array = $alt_names_data['boltello::subject_alt_names']

  get_targets('proxies').each |TargetSpec $proxy| {
    $certname = "${proxy.name}"
    $domain   = "${certname.regsubst(/.*?\.(.+$)/, '\1')}"

    if !$alt_names_array.empty() {
      $parsed_puppet_alt_names = $alt_names_array.map |String $subject| {
        if $subject =~ '%' {
          $hostname = "${subject.split('%')[0].chop()}"
          "${hostname}.${domain}"
        } else {
          "${subject}"
        }
      }

      $puppet_cnames = "--subject-alt-names ${parsed_puppet_alt_names.join(',')}"

      $parsed_katello_alt_names = $alt_names_array.map |String $cname| {
        if $cname =~ '%' {
          $hostname = "${cname.split('%')[0].chop()}"
          "--cname ${hostname}.${domain} --foreman-proxy-cname ${hostname}.${domain}"
        } else {
          "--cname ${cname} --foreman-proxy-cname ${cname}"
        }
      }

      $katello_cnames = $parsed_katello_alt_names.join(' ')

    } else {
      $puppet_cnames  = ""
      $katello_cnames = ""
    }

    # Generate certificates with SANs in the CSR
    run_task('boltello::generate_certs',
      $katello,
      boltdir        => $boltdir,
      proxy          => $proxy.name,
      puppet_cnames  => $puppet_cnames,
      katello_cnames => $katello_cnames,
    )
  }
}
