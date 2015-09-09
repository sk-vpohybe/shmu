#encoding: utf-8

require 'sinatra'
require 'active_support'
require "active_support/core_ext"
require 'erb'

set :port, 1701
set :bind, '0.0.0.0'
set :environment, :production if (ARGV[0] && ARGV[0] == 'production')

def gpx_to_geojson gpx
  h = Hash.from_xml gpx
  lon_lats = h['gpx']['trk']['trkseg']['trkpt'].collect{|e| [e['lon'], e['lat']]}
  time = h['gpx']['trk']['trkseg']['trkpt'].collect{|e| Time.parse(e['time']).to_i*1000}

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
  erb :radar, :locals => {:title => 'Najnovšie zábery', :js => "gpx = false; trackToDisplay = #{geojson_of_latest_n_minutes_of_radar_images}; trackName = 'Radarové zábery za uplynulú hodinu';"}
end

post '/upload_gpx' do
  timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
  if params[:file]
    filename = params[:file][:filename]
    file = params[:file][:tempfile]

    unique_gpx_filename = "#{timestamp}_#{filename.gsub(' ', '_')}"
    gpx = file.read
    File.open("./public/gpx/#{unique_gpx_filename}", 'wb') { |f| f.write(gpx) }
  
    geojson = gpx_to_geojson(gpx)
    track_as_geojson_js_filename = "gpx/#{unique_gpx_filename}.geojson.js"
    File.open("./public/#{track_as_geojson_js_filename}", 'wb') do
      |f| f.write("trackToDisplay = #{geojson};") 
    end
  
    redirect "/gpx/#{unique_gpx_filename}.html"
  else
    
  end
end

get '/gpx/:unique_gpx_filename' do
  track_as_geojson_js_filename = "gpx/#{params[:unique_gpx_filename].gsub('.html', '')}.geojson.js"
  erb :radar, :locals => {:title => params[:unique_gpx_filename], :geojson => track_as_geojson_js_filename, :js => "gpx = true; trackName = '#{params[:unique_gpx_filename]}';"}
end