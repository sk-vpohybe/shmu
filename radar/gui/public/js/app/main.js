function ServerSideOpts(){
  this.mapType = mapType
  this.gpx = gpx
  this.trackToDisplay = trackToDisplay
  this.trackName = trackName
  this.openErrorMessagePopup = false
  if(typeof(openErrorMessagePopup) != 'undefined')
    this.openErrorMessagePopup = openErrorMessagePopup
  
  this.localityLat = null
  if(typeof(localityLat) != 'undefined')
    this.localityLat = localityLat
    
  this.localityLon = null
  if(typeof(localityLon) != 'undefined')
    this.localityLon = localityLon
}

function RadarApp() {
  this.opts = new ServerSideOpts()
  this.leafletMap = new LeafletMap(this.opts)
  this.positionHash = new L.Hash(this.leafletMap.map);
  this.popups = new Popups(this.opts.openErrorMessagePopup)
  this.timeline = new Timeline(this.leafletMap.map, this.opts)
}

function Popups(openErrorMessagePopup){
  $('#oProjekte').popup();
  $('#launchGpxUpload').popup();
  $('#errorMessage').popup();

  if($('#share'))
      $('#share').popup();

  if(typeof(openErrorMessagePopup) != 'undefined' && openErrorMessagePopup == true)
      $('#errorMessage').popup('show');

  $('#uploadGpxButton').click(function() {
      if ($('#gpxFileToUpload')[0].value != '') {
          $('#uploadGpxButton').prop('disabled', true);
          $('#uploadGpxButton').text("Nahrávam...");
          $('#uploadGpxForm').submit();
      }
  });  
}

function LeafletMap(opts){
  this.map = new L.Map('map', {minZoom: 7, maxZoom: 15});
  this.opts = opts

  basemapLayer = new L.TileLayer('http://b2a35a46-50f3-47fd-bac2-e36bbbc00175.pub.cloud.scaleway.com/freemap-sk-tiles/'+mapType+'/{z}/{x}/{y}.jpeg', {attribution: '(c) SHMÚ.sk, freemap.sk, openstreetmap.org contributors'});

  if (this.opts.gpx){
      var lotLan = this.opts.trackToDisplay.geometry.coordinates[0];
      this.map.setView([lotLan[1], lotLan[0]], 10);
  }
  else if(this.opts.localityLat && this.opts.localityLon){
      this.map.setView([this.opts.localityLat, this.opts.localityLon], 11);
      new L.CircleMarker([this.opts.localityLat, this.opts.localityLon], {color: 'red', opacity: 0.7, fillOpacity: 0.7, radius: 15}).addTo(this.map)
  }
  else
  {
      if (!this.map.restoreView())
        this.map.setView([48.74157, 19.35118], 8);
  }

  this.map.addLayer(basemapLayer); 
}


function Timeline(map, opts){
  this.map = map
  this.opts = opts
  
  upcoming_radar_overlay1_timestamp = null;
  displayed_radar_overlay1_timestamp = null;
  upcoming_radar_overlay2_timestamp = null;
  displayed_radar_overlay2_timestamp = null;
  radar_overlay1 = null;
  radar_overlay2 = null;

  radarImageBounds = [[46.449212403852584, 16.21358871459961], [49.92602987536322, 22.70427703857422]];

  playbackTracks = [this.opts.trackToDisplay];
  startTime = new Date(playbackTracks[0].properties.time[0]);
  endTime = new Date(playbackTracks[0].properties.time[playbackTracks[0].properties.time.length - 1]);


  // Create a DataSet with data
  var timelineData = new vis.DataSet([{start: startTime, end: endTime, content: trackName}]);

  // Set timeline options
  var timelineOptions = {
      "width": "100%",
      "height": "120px",
      "style": "box",
      "axisOnTop": true,
      "showCustomTime": true
  };

  // Setup timeline
  timeline = new vis.Timeline(document.getElementById('timeline'), timelineData, timelineOptions);

  // Setup leaflet map


  var playbackOptions = {
      playControl: true,
      dateControl: true,
      tickLen: 2000,
      // layer and marker options
      layer: {
          pointToLayer: function(featureData, latlng) {
              var result = {};

              if (featureData && featureData.properties && featureData.properties.path_options) {
                  result = featureData.properties.path_options;
              }

              if (!result.radius) {
                  result.radius = 2;
              }

              result.color = '#4870B5';

              return new L.CircleMarker(latlng, result);
          }
      },
      marker: {
          getPopup: function(featureData) {
              var result = '';

              if (featureData && featureData.properties && featureData.properties.title) {
                  result = featureData.properties.title;
              }

              return result;
          }
      }

  };

  playback = new L.Playback(this.map, null, onPlaybackTimeChange, playbackOptions);
  playback.setData(playbackTracks);
  playback.addData(playbackTracks[0]);
  playback.setSpeed(500);

  timeline.on('timechange', onCustomTimeChange);

  if (gpx)
      timeline.setCustomTime(startTime);
  else {
      timeline.setCustomTime(endTime);
      adjustRadarImage(endTime - 1000 * 60 * 5);
      $('.leaflet-control-layers').hide();
  }

  $(".leaflet-top.leaflet-right").hide()
  var trackAsPolyline = this.opts.trackToDisplay
  trackAsPolyline['geometry']['type'] = 'LineString'
  L.geoJson(trackAsPolyline, {color: '#8D2ACB', opacity: 0.9}).addTo(this.map);
  $(".playControl button").text('Animovať trasu');

  function onCustomTimeChange(properties) {
      if (!playback.isPlaying()) {
          ms = properties.time.getTime();
          playback.setCursor(ms);
          adjustRadarImage(ms);
      }
  }

  function onPlaybackTimeChange(ms) {
      timeline.setCustomTime(new Date(ms));
      adjustRadarImage(ms);
  }

  function adjustRadarImage(ms) {
      seconds_since_unix_epoch = parseInt(ms / 1000);
      upcoming_radar_overlay1_timestamp = seconds_since_unix_epoch - (seconds_since_unix_epoch % 300);
      upcoming_radar_overlay2_timestamp = upcoming_radar_overlay1_timestamp + 5 * 60;
      attitude_towards_overlay2 = (upcoming_radar_overlay2_timestamp - seconds_since_unix_epoch) / (5 * 60);


      if (upcoming_radar_overlay1_timestamp !== displayed_radar_overlay1_timestamp) {
          if (radar_overlay1)
              map.removeLayer(radar_overlay1);

          displayed_radar_overlay1_timestamp = upcoming_radar_overlay1_timestamp;
          var tmpd = new Date(displayed_radar_overlay1_timestamp * 1000);
          radar_overlay1_image_url = 'http://b2a35a46-50f3-47fd-bac2-e36bbbc00175.pub.cloud.scaleway.com/radar/' + strftime('%Y%m%d', tmpd) + '/' + strftime('%Y%m%d_%H%M', tmpd) + '.gif';
          radar_overlay1 = L.imageOverlay(radar_overlay1_image_url, radarImageBounds);
          radar_overlay1.addTo(map);
      }

      o1 = attitude_towards_overlay2;
      if (radar_overlay1)
          radar_overlay1.setOpacity(Math.sqrt(o1) * 0.8);

      if (upcoming_radar_overlay2_timestamp !== displayed_radar_overlay2_timestamp) {
          if (radar_overlay2)
              map.removeLayer(radar_overlay2);

          displayed_radar_overlay2_timestamp = upcoming_radar_overlay2_timestamp;
          var tmpd = new Date(displayed_radar_overlay2_timestamp * 1000);
          radar_overlay2_image_url = 'http://b2a35a46-50f3-47fd-bac2-e36bbbc00175.pub.cloud.scaleway.com/radar/' + strftime('%Y%m%d', tmpd) + '/' + strftime('%Y%m%d_%H%M', tmpd) + '.gif';
          radar_overlay2 = L.imageOverlay(radar_overlay2_image_url, radarImageBounds);
          radar_overlay2.addTo(map);
      }

      o2 = (1.0 - attitude_towards_overlay2);

      if (radar_overlay2)
          radar_overlay2.setOpacity(Math.sqrt(o2) * 0.8);
  }


}

new RadarApp()