# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#  puppet apply -e 'include boltello'
#
class boltello_builder (
  String[1] $message,
  Array[String] $classes
) {
  notice("${message}: ${facts['networking']['fqdn']}")

  $classes.unique.include
  
  case $facts['boltello_role'] {
    'katello': {
      Class['::katello'] ~> Class['::puppet']
    }
    default: {
      Class['::foreman_proxy_content'] ~> Class['::puppet']
    }
  }
}
