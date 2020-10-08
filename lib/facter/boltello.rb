# boltello.rb
#
Facter.add(:boltello, :type => :aggregate) do
  # Get katello version
  chunk(:katello_version) do
    katello = Facter::Util::Resolution.exec('rpm -q --queryformat "%{version}" katello')
    katello.gsub!(/(.*)\..*/,'\1')
  end

  # Get foreman version
  chunk(:foreman_version) do
    foreman = Facter::Util::Resolution.exec('rpm -q --queryformat "%{version}" foreman')
    foreman.gsub!(/(.*)\..*/,'\1')
  end

  # Get puppetserver version
  chunk(:puppetserver_version) do
    foreman = Facter::Util::Resolution.exec('rpm -q --queryformat "%{version}" puppetserver')
    foreman.gsub!(/(.*)\..*/,'\1')
  end
  
  # Aggregate the chunks into a hash
  aggregate do |chunks|
    chunks.each_with_index do |k,v|
      "#{k} => #{v}"
    end
    chunks
  end
end
