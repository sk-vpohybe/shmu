#encoding: utf-8

require 'sinatra'
require 'active_support'
require "active_support/core_ext"
require 'erb'

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

get '/' do
  erb :radar, 
    :locals => { :js => "trackToDisplay = #{geojson_of_latest_n_minutes_of_radar_images}; trackName = 'Zrážky za uplynulé tri dni'"}
end