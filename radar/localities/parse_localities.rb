require 'active_support'
require "active_support/core_ext"
require 'i18n'

I18n.config.available_locales = :en

h = Hash.from_xml(File.read('./localities.osm'))


out = h['osm']['node'].collect do |node|
	lat = node['lat']
	lon = node['lon']
	fullname = node['tag'].find{|t| t['k'] == 'name'}['v']
	urlname = I18n.transliterate(fullname).downcase.split(' ').join('-')
	puts "#{fullname}\t#{urlname}"
	[fullname, urlname, lat, lon]

end

File.open('./localities.raw', 'wb') {|f| f.write(Marshal.dump(out)) }