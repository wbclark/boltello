# == Function boltello::get_boltdir
#
# @summary Returns the root bolt directory
# @example Calling the function
#   $boltdir = boltello::get_boltdir()
# @return The absolute path to the Boltdir, as type String
#
Puppet::Functions.create_function(:'boltello::get_boltdir') do
  def get_boltdir()
    boltdir = File.expand_path(File.dirname(File.dirname(__FILE__)))
    boltdir.slice!('/lib/puppet/functions')
    boltdir
  end
end
