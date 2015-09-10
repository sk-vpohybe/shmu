#encoding: utf-8

require 'sinatra'
require 'active_support'
require "active_support/core_ext"
require 'erb'

# take only each n-th point from large gpx files
module Enumerable
  def every_nth(n)
    (n - 1).step(self.size - 1, n).map { |i| self[i] }
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

def gpx_to_geojson gpx
  sampling = 1
  if gpx.size > 1500000
    sampling = 4
  elsif gpx.size > 1000000
    sampling = 3
  elsif gpx.size > 500000
    sampling = 2
  end
      
  h = Hash.from_xml gpx
  lon_lats = h['gpx']['trk']['trkseg']['trkpt'].every_nth(sampling).collect{|e| [e['lon'], e['lat']]}
  time = h['gpx']['trk']['trkseg']['trkpt'].every_nth(sampling).collect{|e| Time.parse(e['time']).to_i*1000}

  output = {
    "type" => "Feature",
    "geometry" => {
      "type"  => "MultiPoint",
      "coordinates"  => lon_lats
    },
    "properties"  => {
      "time"  => time
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

get '/' do
  error_msg = params[:error_message]
  erb :radar, 
    :locals => {:error_message => error_msg, 
    :js => "gpx = false; trackToDisplay = #{geojson_of_latest_n_minutes_of_radar_images}; trackName = 'Zrážky za uplynulú hodinu'; openErrorMessagePopup = #{!error_msg.nil?};"}
end

post '/upload_gpx' do
  timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
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
    erb :radar, :locals => { :unique_gpx_filename => unique_gpx_filename, :geojson => track_as_geojson_js_filename, :js => "gpx = true;"}
  else
    error_message = "Trasa s identifikátorom '#{unique_gpx_filename}' sa nenašla."
    redirect "/?error_message=#{CGI.escape(error_message)}"
  end

end