# == Function boltello_builder::symbolize_keys
#
# @summary Returns the Hash with keys transformed as type Symbol
# @example Calling the function
#   $x = boltello::symbolize_keys($h)
# @return The Hash with keys as type Symbol
#
Puppet::Functions.create_function(:'boltello_builder::symbolize_keys') do
  dispatch :symbolize_keys do
    param 'Hash', :h
  end

  def symbolize_keys(h)
    h = Hash[h.map { |k,v| [k.to_sym, v] }]
  end
end
