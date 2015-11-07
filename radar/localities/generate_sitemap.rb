out = Marshal.load(File.read('../gui/localities.raw')).collect do |locality_original_name, locality_url_name, localityLat, localityLon|
	"http://radar.cyklonaut.sk/#{locality_url_name}"
end

File.open("radar-cyklonaut-sitemap.txt", 'w'){|f| f.write out.join("\n")}