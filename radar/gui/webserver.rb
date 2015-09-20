#encoding: utf-8

require 'sinatra'
require 'active_support'
require "active_support/core_ext"
require 'erb'
require 'rmagick'
include Magick

class Rainfall
  BOUNDING_LAT_0, BOUNDING_LON_0 = 46.449212403852584, 16.21358871459961
  BOUNDING_LAT_1, BOUNDING_LON_1 = 49.92602987536322, 22.70427703857422
  GIF_X_SIZE = 600
  GIF_Y_SIZE = 480

  attr_reader :data
  
  def initialize days, lat, lon
    x, y = to_pixel_position lat, lon
    
    t2 = Time.now
    t2 = t2 - (t2.min % 5)*60
    
    t1 = t2 - (60*60*24*days) # n days ago
    
    filenames = (0..(days*24*12)).to_a.collect do |i|
      t = t1 + (i * 60 * 5)
      "/home/peter/Desktop/t/#{t.strftime '%Y%m%d'}/#{t.strftime '%Y%m%d_%H%M'}.gif"
    end
    
    detailed_data = filenames.collect do |filename|
      GC.start if filename.include?('00')
      gather_rainfall_data filename, x, y
    end
    
    slice_size = 12 # 12 * 5 mins
    @data = detailed_data.each_slice(slice_size).to_a.collect do |slice|
      {:timestamp => slice[0][:timestamp], :mm => (slice.collect{|s| s[:mm]}.sum/slice_size.to_f).round(2)}
    end
  end
  
  private
  
  def gather_rainfall_data filename, x, y
    timestamp = filename[0..-5]
    
    if File.exists?(filename)
      img = ImageList.new filename
      rgb_16bit = img.pixel_color x, y
      r, g, b = (rgb_16bit.red/257).to_i, (rgb_16bit.green/257).to_i, (rgb_16bit.blue/257).to_i
      
      mm = to_rainfall_mm(r, g, b)
      # puts "[#{r}\t#{g}\t#{b}]\t #{mm}"
      {:timestamp => timestamp, :mm => mm, :r => r, :g => g, :b => b}
    else
      {:timestamp => timestamp, :mm => 0.0, :r => 0, :g => 0, :b => 0}
    end
  end
  
  # lat = pohyb z juhu na sever (0  = rovnik)
  # y = pohyb zo severu na juh!
  # 
  # lon = pohyb zo zapadu na vychod (16 = BA, 22 = KE)
  # x = pohyb zo zapadu na vychod

  def to_pixel_position lat, lon
    if lat > BOUNDING_LAT_1 || lat < BOUNDING_LAT_0
      raise "latitude #{lat.inspect} not in (46.449212403852584 .. 49.92602987536322 range)"
    end
  
    if lon > BOUNDING_LON_1 || lon < BOUNDING_LON_0
      raise "longitude #{lon.inspect} not in (16.21358871459961 .. 22.70427703857422 range)"
    end 
  
    x = (((lon - BOUNDING_LON_0) / (BOUNDING_LON_1 - BOUNDING_LON_0)) * GIF_X_SIZE).round(0)
    y = GIF_Y_SIZE - (((lat - BOUNDING_LAT_0) / (BOUNDING_LAT_1 - BOUNDING_LAT_0)) * GIF_Y_SIZE).round(0) - 1
    [x,y]
  end
  
  # [[44,100,176], [0,108,136], [0,192,52], [108,236,0], [252,200,0], [252,100,0], [216,8,0]]
  def to_rainfall_mm r, g, b
    if(b > 0)
      b = 176 if b > 176
      ((176 - b)/176.0) * 0.5
    elsif(g > 0)
      g = 244 if g > 244
      ((244 - g)/244.0) * 0.5 + 0.5
    else
      0.0
    end
  end
  
end

set :port, 1701
set :bind, '0.0.0.0'
set :environment, :production if (ARGV[0] && ARGV[0] == 'production')

helpers do
  
  def versioned_javascript js
    "js/#{js}.js?" + File.mtime(File.join("public/js", "#{js}.js")).to_i.to_s
  end
  
  def versioned_css css
    "css/#{css}.css?" + File.mtime(File.join("public/css", "#{css}.css")).to_i.to_s
  end
end


def geojson_of_latest_n_minutes_of_radar_images n=60*24*3
  t = Time.now
  n_minutes_before_now_in_seconds_in_epoch_time = t.to_i - (t.min % 10)*60  - n*60
  from_past_to_current_time_in_millis = (0...n).to_a.collect{|minutes| (n_minutes_before_now_in_seconds_in_epoch_time + minutes*60) * 1000 }
  
  output = {
    "type" => "Feature",
    "geometry" => {
      "type"  => "MultiPoint",
      "coordinates"  => [[0,0]]*n
    },
    "properties"  => {
      "time"  => from_past_to_current_time_in_millis
    }
  }
  
  output.to_json
end

get '/:lat/:lon' do
  lat = params[:lat].to_f
  lon = params[:lon].to_f
  
  days = 1
  if params[:days]
    days = params[:days].to_i
    days = 7 if days > 7
  end
  
  rainfall = Rainfall.new days, lat, lon
  erb :radar, 
    :locals => { :rainfall => rainfall,
    :js => "trackToDisplay = #{geojson_of_latest_n_minutes_of_radar_images(60*24*days)}; trackName = 'Zrážky za uplynulých pár dní'; gardenLat = #{lat}; gardenLon = #{lon}"}
end

get '/*' do
  redirect '/48.5614/19.7369?days=1'
end