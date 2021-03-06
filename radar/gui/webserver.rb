#encoding: utf-8

require 'sinatra'
require 'active_support'
require "active_support/core_ext"
require 'erb'
require 'time'

class Numeric
  def to_rad
    self * Math::PI / 180
  end
end

class Array
  def sum
    inject(0.0) { |result, el| result + el }
  end

  def mean 
    sum / size.to_f
  end
end

# http://www.movable-type.co.uk/scripts/latlong.html
# loc1 and loc2 are arrays of [latitude, longitude]
def haversine_km_distance loc1, loc2
    lat1, lon1 = loc1
    lat1 = lat1.to_f
    lon1 = lon1.to_f
    lat2, lon2 = loc2
    lat2 = lat2.to_f
    lon2 = lon2.to_f
    dLat = (lat2-lat1).to_rad;
    dLon = (lon2-lon1).to_rad;
    a = Math.sin(dLat/2) * Math.sin(dLat/2) +
        Math.cos(lat1.to_rad) * Math.cos(lat2.to_rad) *
        Math.sin(dLon/2) * Math.sin(dLon/2);
    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
    d = 6371 * c; # Multiply by 6371 to get Kilometers
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

def ele_local_mins_maxs trkpts

  trkpts_len = trkpts.length
  prev_ele = 0
  prev_prev_ele = 0
  
  mins_maxs = []
  last_pt = nil
  last_ele = nil
  min_ele = 80000
  max_ele = 0
  
  trkpts.each_with_index do |pt, i|
    next if i < 10 || trkpts_len < i + 10
    ele = trkpts[i-9..i+9].select{|pt| pt['ele']}.collect{|pt| pt['ele'].to_f}.sort[3..-4].mean.round(-1)
    
    min_ele = ele if ele < min_ele
    max_ele = ele if max_ele < ele
    
    if mins_maxs.length == 0
      mins_maxs << [pt, ele]
    elsif prev_prev_ele < prev_ele && prev_ele > ele # local max
      mins_maxs << [pt, ele]
    elsif prev_prev_ele > prev_ele && prev_ele < ele  # local min
      mins_maxs << [pt, ele]
    end
    
    if ele != last_ele
      prev_prev_ele = prev_ele
      prev_ele = ele
    end
    
    last_ele = ele
    last_pt = pt
  end
  
  mins_maxs << [last_pt, last_ele]
  
  start_time = Time.parse(mins_maxs.first[0]['time']).to_i
  end_time =  Time.parse(mins_maxs.last[0]['time']).to_i
  ele_span = (max_ele - min_ele).to_f
  time_span = (end_time - start_time).to_f
  
  mins_maxs_relative_time_and_ele = []
  mins_maxs.each do |pt, ele|
    t = Time.parse(pt['time']).to_i
    relative_t = (((t - start_time)/time_span)*100).round(0)
    relative_ele = ((ele - min_ele)/ele_span).round(2)
    mins_maxs_relative_time_and_ele << [relative_t, relative_ele]
  end
  
  mins_maxs_relative_time_and_ele
end 

def moving_ele_average trkpts, i
  if(0 <= i-9 && trkpts[i+9] )
    return trkpts[(i-9)..(i+9)].select do |pt| 
      pt['ele']
    end.collect do |pt|
      pt['ele'].to_f
    end.sort[3..-4].mean
  else
   
    return nil
  end
  

end

def gpx_to_geojson gpx
  h = Hash.from_xml gpx
  trksegments = h['gpx']['trk']['trkseg']
  if(trksegments.class == Hash)
    trksegments = [trksegments]
  end
 
  lon_lats = []
  time = []
  time_to_distance_and_ele = {}
  total_distance = 0.0
  total_ele_up = 0.0
  total_ele_down = 0.0
  prev_ele = nil
  
  trkpts = trksegments.collect do |trkseg|
    trkseg['trkpt']
  end.flatten
  
  trkpts.each_with_index do |trkpt, i|
    lon_lats << [trkpt['lon'], trkpt['lat']]
    t = Time.parse(trkpt['time']).to_i*1000
    time << t
    next_pt = trkpts[i+1]
    if next_pt
      distance = haversine_km_distance([trkpt['lat'], trkpt['lon']], [next_pt['lat'], next_pt['lon']])
      total_distance += distance
      time_to_distance_and_ele[t] = [total_distance.round(1)]
      
      ele = moving_ele_average trkpts, i
      if(ele && prev_ele)
        ele_diff = ele - prev_ele
        if(0 < ele_diff)
          total_ele_up += ele_diff
        else
          total_ele_down += ele_diff
        end
        time_to_distance_and_ele[t] << total_ele_up.round(0)
        time_to_distance_and_ele[t] << total_ele_down.round(0)
      else
        time_to_distance_and_ele[t] << total_ele_up.round(0)
        time_to_distance_and_ele[t] << total_ele_down.round(0)
      end
      prev_ele = ele       
    end
  end
  mins_maxs_relative_time_and_ele = []
  if(300.0 < total_ele_up || 300.0 < total_ele_down)
    mins_maxs_relative_time_and_ele = ele_local_mins_maxs trkpts
  end

  output = {
    "type" => "Feature",
    "geometry" => {
      "type"  => "MultiPoint",
      "coordinates"  => lon_lats
    },
    "properties"  => {
      "time"  => time,
      "time_to_distance_and_ele" => time_to_distance_and_ele,
      "mins_maxs_relative_time_and_ele" => mins_maxs_relative_time_and_ele
    }
  }
  
  output.to_json
end

def geojson_of_latest_n_minutes_of_radar_images n=60
  t = Time.now
  n_minutes_before_now_in_seconds_in_epoch_time = t.to_i - (t.min % 5)*60  - n*60
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

post '/upload_gpx' do
  unique_gpx_filename = nil
  error_message = nil
  
  begin
    filename = params[:file][:filename]
    file = params[:file][:tempfile]
    gpx = file.read

    if(gpx.size < 2000000)
      unique_gpx_filename = rand(36**6).to_s(36)
      File.open("./public/gpx/#{unique_gpx_filename}", 'wb') { |f| f.write(gpx) }
 
      geojson = gpx_to_geojson(gpx)
      track_as_geojson_js_filename = "gpx/#{unique_gpx_filename}.geojson.js"
      File.open("./public/#{track_as_geojson_js_filename}", 'wb') do
        |f| f.write("trackToDisplay = #{geojson}; trackName = 'Názov gpx súboru: #{filename.gsub("'", '')}';") 
      end
    else
      error_message = "súbor nemôže byť väčší ako 2MB"
    end
  rescue  => e   
    puts e
    puts e.class
    puts e.backtrace
    error_message = "#{e} #{e.class}"
  end
  
  if error_message
    redirect "/?error_message=#{CGI.escape(error_message)}"
  else
    redirect "/track/#{unique_gpx_filename}"
  end
end

get '/track/:unique_gpx_filename' do
  unique_gpx_filename = params[:unique_gpx_filename]
  
  if unique_gpx_filename =~ /^[0-9a-zA-Z]*$/ && File.exists?("public/gpx/#{unique_gpx_filename}")# safety check
    track_as_geojson_js_filename = "gpx/#{unique_gpx_filename}.geojson.js"
    
    erb :radar, 
      :locals => { :unique_gpx_filename => unique_gpx_filename, 
      :geojson => track_as_geojson_js_filename, 
      :js => "gpx = true;"}
    
  else
    error_message = "Trasa s identifikátorom '#{unique_gpx_filename}' sa nenašla."
    redirect "/?error_message=#{CGI.escape(error_message)}"
  end
end

Marshal.load(File.read('./localities.raw')).each do |locality_original_name, locality_url_name, localityLat, localityLon|
  get "/#{locality_url_name}" do

    error_msg = params[:error_message]
    erb :radar, 
      :locals => {:error_message => error_msg, 
        :locality_original_name => locality_original_name,
      :js => "gpx = false; localityLat = #{localityLat}; localityLon = #{localityLon}; trackToDisplay = #{geojson_of_latest_n_minutes_of_radar_images}; trackName = '#{locality_original_name}: zrážky za uplynulú hodinu'"}

  end  
end


get '/*' do
  error_msg = params[:error_message]
  erb :radar, 
    :locals => {:error_message => error_msg, 
    :js => "gpx = false; trackToDisplay = #{geojson_of_latest_n_minutes_of_radar_images}; trackName = 'Zrážky za uplynulú hodinu'; openErrorMessagePopup = #{!error_msg.nil?};"}
end

