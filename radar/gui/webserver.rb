require 'sinatra'
require 'active_support'
require "active_support/core_ext"

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
  <<STRING
  <html>
    <head>
        <title>GPX + radar</title>
    </head>
    <body>
        <h1>Upload GPX file</h1>
        
        <form action="/upload_gpx" method="POST" enctype="multipart/form-data">
            <input type="file" name="file">
            <input type="submit" value="Upload GPX">
        </form>
    </body>
</html>
STRING
  
end

get '/radar_image/:epoch_time_in_seconds' do
  t = Time.at params[:epoch_time_in_seconds].to_i
  path_to_radar_image = "images/#{t.strftime('%Y%m%d')}/#{t.strftime('%Y%m%d_%H%M')}.png"
  unless File.exists?("public/#{path_to_radar_image}") # display some random radar image when not found
    
    path_to_radar_image = Dir.glob('public/images/**/*.png').sample.gsub 'public/', ''
    puts "not found, altering to random image: #{path_to_radar_image}"
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
  
  redirect "/view/#{unique_gpx_filename}.html"
end

get '/view/:unique_gpx_filename' do
  track_as_geojson_js_filename = "gpx/#{params[:unique_gpx_filename].gsub('.html', '')}.geojson.js"
  
  <<STRING
    <!DOCTYPE html>
<html>

<head>
    <title>SHMU radary</title>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link href="http://cdn.leafletjs.com/leaflet-0.7.3/leaflet.css" rel="stylesheet" type="text/css" />
    <link href="http://cdnjs.cloudflare.com/ajax/libs/vis/3.12.0/vis.min.css" rel="stylesheet" type="text/css" /> 
    <style>
    #map {
        position: absolute;
        top: 0;
        left: 0;
        right: 0;
        bottom: 120px;
    }
    
    #title_container {
        z-index: 10000;
        position: absolute;
        left: 100px;
    }    
    
    #timeline { 
        height: 120px; 
        position: absolute;
        left: 0;
        right: 0;
        bottom: 0;
    }

    body {
            font-family: "Helvetica Neue", Helvetica, Arial, sans-serif;
        }

    h1 {
        font-size: 36px;
        font-weight: 300;
        line-height: 1.1;
    }

    .datetimeControl p {
        margin: 0;
        font-size: 16px;
    }
    </style>
</head>

<body>
    <!-- <div id="title_container">
        <h1>Example 1</h1>
        <p>LeafletPlayback with vis.js timeline as slider control</p>
    </div> -->

    <div id="map"></div>
    <div id="timeline"></div>

    <script src="http://code.jquery.com/jquery-1.11.0.js"></script>
    <script src="http://cdnjs.cloudflare.com/ajax/libs/vis/3.12.0/vis.min.js"></script>  
    <script src="http://cdn.leafletjs.com/leaflet-0.7.3/leaflet-src.js"></script>

    <script src="../LeafletPlayback.min.js"></script>
    <script src="../#{track_as_geojson_js_filename}"></script>
    <script src="../radar.js"></script>
</body>
</html>
STRING
end