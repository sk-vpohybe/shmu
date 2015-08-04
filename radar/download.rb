require 'net/http'
require 'fileutils'

while true do
  html = Net::HTTP.get('www.shmu.sk', '/sk/?page=1&id=meteo_radar')
  line_with_image_url = html.split("\n").find{|l| l.include?('<img src="/data/')}
  relative_image_url = line_with_image_url.split("\"")[1]

  time = Time.now
  dir = "images/#{time.strftime('%Y%m%d')}"
  FileUtils.mkdir_p dir
  image_filename = "#{dir}/#{time.strftime('%Y%m%d_%H')}#{time.min - (time.min % 5)}.png"
  radar_image = Net::HTTP.get('www.shmu.sk', relative_image_url)
  File.open(image_filename, 'wb'){|f| f.write radar_image}
  
  puts "downloaded: #{image_filename}"

  sleep 60*5
end