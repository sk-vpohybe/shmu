#encoding: utf-8

require 'sinatra'
require 'active_support'
require "active_support/core_ext"
require 'erb'

set :port, 1701

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

get '/' do
  erb :index
end

get '/radar_image/:epoch_time_in_seconds' do
  t = Time.at params[:epoch_time_in_seconds].to_i
  path_to_radar_image = "images/#{t.strftime('%Y%m%d')}/#{t.strftime('%Y%m%d_%H%M')}.gif"
  
  unless File.exists?("public/#{path_to_radar_image}") 
    # force first day we started image download
    path_to_radar_image = "images/20150805/20150805_#{t.strftime('%H%M')}.gif"
  end
  
  redirect path_to_radar_image
end

post '/upload_gpx' do
  timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
  filename = params[:file][:filename]
  file = params[:file][:tempfile]

  unique_gpx_filename = "#{timestamp}_#{filename.gsub(' ', '_')}"
  gpx = file.read
  File.open("./public/gpx/#{unique_gpx_filename}", 'wb') { |f| f.write(gpx) }
  
  geojson = gpx_to_geojson(gpx)
  track_as_geojson_js_filename = "gpx/#{unique_gpx_filename}.geojson.js"
  File.open("./public/#{track_as_geojson_js_filename}", 'wb') do
    |f| f.write("trackName = '#{filename}'; trackToDisplay = #{geojson};") 
  end
  
  redirect "/gpx/#{unique_gpx_filename}.html"
end

get '/gpx/:unique_gpx_filename' do
  track_as_geojson_js_filename = "gpx/#{params[:unique_gpx_filename].gsub('.html', '')}.geojson.js"
  erb :gpx, :locals => {:track_as_geojson_js_filename => track_as_geojson_js_filename, :unique_gpx_filename => params[:unique_gpx_filename]}
end