function UserOpts(mainMenu){
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
    
   if(localStorage.getItem('mapType'))
    this.mapType = localStorage.getItem('mapType')
   else
    this.mapType = 'K'
   
   this.changeMapTypeTo = function(maptype){
       this.mapType = maptype
       localStorage.setItem('mapType', maptype)
       if(this.mapType == 'K' || this.mapType == 'T')
         this.mapSource = 'https://nabezky.sk/map-tiles-jpg/'+this.mapType+'/{z}/{x}/{y}.jpeg'
       else
         this.mapSource = 'https://api.mapbox.com/v4/mapbox.outdoors/{z}/{x}/{y}.png?access_token=pk.eyJ1IjoicGV0ZXJ2b2p0ZWsiLCJhIjoiY2lpc3V5eGNrMDA5dHc5bTAwejVuamZpYiJ9.Af2Lk6oEDNcJqGZ4Obbq_A'
       
       mainMenu.showActiveMapType(this.mapType)
  }
   
   this.changeMapTypeTo(this.mapType)
}

function RadarApp() {
  this.mainMenu = new MainMenu()
  this.userOpts = new UserOpts(this.mainMenu)
  this.leafletMap = new LeafletMap(this.userOpts)
  this.positionHash = new L.Hash(this.leafletMap.map);
  this.popups = new Popups(this.userOpts.openErrorMessagePopup)
  this.timeline = new Timeline(this.leafletMap.map, this.userOpts)
  new ToggleTransparencyButton()

  var disableCurrentPositionButton = this.userOpts.gpx
  new ToggleMyPositionButton(this.leafletMap.map, disableCurrentPositionButton)
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

function MainMenu(){
    this.turisticMapCheckbox = $('#turisticMapEnabled')
    this.cycloMapCheckbox = $('#cycloMapEnabled')
    this.mapboxOutdoorsMapCheckbox = $('#mapboxMapEnabled')
    
    this.showActiveMapType = function(mapType){
        this.mapboxOutdoorsMapCheckbox.hide()
        this.turisticMapCheckbox.hide()
        this.cycloMapCheckbox.hide()  
        
        if(mapType == 'K')
            this.cycloMapCheckbox.show()
        if(mapType == 'T') 
            this.turisticMapCheckbox.show()
        if(mapType == 'mapbox') 
            this.mapboxOutdoorsMapCheckbox.show()
    }
    
    this.showActiveMapType()
}

function LeafletMap(opts){
  this.map = new L.Map('map', {minZoom: 7, maxZoom: 15});
  this.opts = opts

  this.basemapLayer = new L.TileLayer(this.opts.mapSource, {attribution: '(c) SHMÚ.sk, freemap.sk, mapbox.com, openstreetmap.org'});

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

  this.map.addLayer(this.basemapLayer); 
  
  this.changeMapType = function(mapType){
      this.opts.changeMapTypeTo(mapType)
      this.basemapLayer.setUrl(this.opts.mapSource)
  }
}


function Timeline(map, opts){
  var ONE_HOUR =  1000*60*60
  var FIVE_MINUTES  = 1000 * 60 * 5
  this.map = map
  this.opts = opts
  shmuOverlay = new ShmuImageOverlay(this.map)

  // Set timeline options
  var timelineOptions = {
      "width": "100%",
      "height": "120px",
      "style": "box",
      "axisOnTop": true,
      "showCustomTime": true
  };

  startTime = new Date(this.opts.trackToDisplay.properties.time[0]);
  endTime = new Date(this.opts.trackToDisplay.properties.time[this.opts.trackToDisplay.properties.time.length - 1]);

  var timelineData = new vis.DataSet([{start: startTime, end: endTime, content: trackName}]);
  timeline = new vis.Timeline(document.getElementById('timeline'), timelineData, timelineOptions);

  var playbackOptions = {
      playControl: false,
      dateControl: false,
      tickLen: 2000
  };

  playback = new L.Playback(this.map, null, onPlaybackTimeChange, playbackOptions);
  playback.setData([this.opts.trackToDisplay]);
  playback.addData(this.opts.trackToDisplay);
  playback.setSpeed(500);

  timeline.on('timechange', onCustomTimeChange);
  this.playOrPauseButton = new PlayOrPauseButton(playback, timeline)
  var that = this
  
  $('.leaflet-control-layers').hide();

  if (gpx){
    timeline.setCustomTime(startTime);
    trackAsPolyline = this.opts.trackToDisplay
    trackAsPolyline['geometry']['type'] = 'LineString'
    L.geoJson(trackAsPolyline, {color: '#8D2ACB', opacity: 0.9}).addTo(this.map);
    
    var mins_maxs_relative_time_and_ele = this.opts.trackToDisplay.properties.mins_maxs_relative_time_and_ele
    
    if(mins_maxs_relative_time_and_ele && mins_maxs_relative_time_and_ele.length > 0){
        var colors = mins_maxs_relative_time_and_ele.map(function(e){
            return('rgba(0,140,0,'+e[1]+') '+e[0]+'%')
        }).join(',')
        var gradient = '-webkit-linear-gradient(left , '+colors+')'
        $('.vis.timeline .item.range').css({'background': gradient, 'color': 'black'})        
    }
    timeline.setWindow(startTime, endTime)
  } else {
      var now = (new Date()).getTime()
      timeline.setCustomTime(endTime);
      shmuOverlay.adjustRadarImage(now - FIVE_MINUTES);
      timeline.setWindow(now - ONE_HOUR - FIVE_MINUTES * 2, now + FIVE_MINUTES * 2)
  }

  var timelineInFuture = false

  function onCustomTimeChange(properties) {
      var now = (new Date()).getTime()
      if (!playback.isPlaying()) {
          ms = properties.time.getTime();
          playback.setCursor(ms);
          shmuOverlay.adjustRadarImage(ms);
          updateDistanceText(ms)
          if(now < ms){
              if(!timelineInFuture){
                  timelineInFuture = true
                  timeline.setWindow(now - ONE_HOUR * 1.5, now + 24 * ONE_HOUR)
              }
          } else {
              if(timelineInFuture){
                  timelineInFuture = false
                  timeline.setWindow(now - ONE_HOUR - FIVE_MINUTES, now + FIVE_MINUTES * 2)
              }
          }
      }
  }

  function onPlaybackTimeChange(ms) {
      timeline.setCustomTime(new Date(ms));
      shmuOverlay.adjustRadarImage(ms);
      updateDistanceText(ms)
      if(playback.isPlaying() && playback.getEndTime() <  ms + 10000 ){
          playback.stop()
          that.playOrPauseButton.refreshIcon()
      }
  }
  
  trackToDisplay = this.opts.trackToDisplay
   function updateDistanceText(ms){
    if(trackToDisplay.properties.time_to_distance_and_ele == null){
        return(null)
    }
    var roundMs = ms - (ms % 1000)
    var distance_and_eles = null
    var subtractions = 0
    while(distance_and_eles == null){     
    distance_and_eles = trackToDisplay.properties.time_to_distance_and_ele[roundMs]
    roundMs -= 1000
    subtractions++
    if(50 < subtractions)
        break
    }
    if(distance_and_eles){
        var distance = distance_and_eles[0]
        var ele_up = distance_and_eles[1] || 0
        var ele_down = distance_and_eles[2] || 0
        var info = '↦ '+ distance +' km&nbsp;&nbsp;'
        info += '⇡ '+ele_up + ' m&nbsp;&nbsp;'
        info += '⇣ '+ele_down + ' m'
        $($('.content')[1]).html(info)
        
    }
  }
}

function ToggleMyPositionButton(map, hideButton){
    this.button = $('#toggleMyPosition')
    this.map = map
    this.marker = null
    var that = this

    this.enable = function(){
        that.button.addClass('active')
        localStorage.setItem('displayMyPosition', 'true')
        if ("geolocation" in navigator) {
            navigator.geolocation.getCurrentPosition(function(position) {
                var latlon = [position.coords.latitude, position.coords.longitude]
                that.marker = L.marker(latlon)
                that.marker.addTo(that.map);
                that.map.setView(latlon, 10);
            });
        }
    }

    this.disable = function(){
        that.button.removeClass('active')
        localStorage.setItem('displayMyPosition', 'false')
        if(that.marker){
            that.map.removeLayer(that.marker)
            that.marker = null
        }
    }

    if(hideButton)
        this.button.hide()
    else if(localStorage.getItem('displayMyPosition') == 'true')
        this.enable()     

    this.button.click(function(event){
        if(localStorage.getItem('displayMyPosition') == 'true')
            that.disable()
        else 
            that.enable()
    })
}

function ToggleTransparencyButton(){
    this.button = $('#toggleTransparency')
    if(localStorage.getItem('transparencyEnabled') == 'true'){
        this.button.addClass('active')
        var css = {'background-color': 'rgba(255,255,255,0.3)'}
        $('#timeline').css(css)
        $('#logo').css(css)        
    }
    var that = this
    this.button.click(function(event){
        if(localStorage.getItem('transparencyEnabled') == 'true'){
            var css = {'background-color': 'rgba(255,255,255,0.75)'}
            localStorage.setItem('transparencyEnabled', 'false')
            that.button.removeClass('active')
        } else {
            var css = {'background-color': 'rgba(255,255,255,0.3)'}
            localStorage.setItem('transparencyEnabled', 'true')
            that.button.addClass('active')
        }

        $('#timeline').css(css)
        $('#logo').css(css)
    })

}
function PlayOrPauseButton(playback, timeline){
    this.button = $('#playOrPause')
    this.refreshIcon = function(){
        if(playback.isPlaying())
            this.button.html('&nbsp;<i class="fa fa-pause"></i>&nbsp;')
        else
            this.button.html('&nbsp;<i class="fa fa-play"></i>&nbsp;')
    }
    
    var that = this    
    
    this.button.click(function(event){
        if(playback.isPlaying()){
            playback.stop()
        }
        else {
            if(playback.getEndTime() < playback.getTime() + 10000){
                timeline.setCustomTime(startTime);
                playback.setCursor(startTime.getTime());
            }
            
            playback.start()
        }
        that.refreshIcon()
    })   
}

function ShmuImageOverlay(map){
  this.map = map
  this.upcoming_radar_overlay1_timestamp = null;
  this.displayed_radar_overlay1_timestamp = null;
  this.upcoming_radar_overlay2_timestamp = null;
  this.displayed_radar_overlay2_timestamp = null;
  this.radar_overlay1 = null;
  this.radar_overlay2 = null;


    
  this.adjustRadarImage = function(ms) {
      seconds_since_unix_epoch = parseInt(ms / 1000);
      this.upcoming_radar_overlay1_timestamp = seconds_since_unix_epoch - (seconds_since_unix_epoch % 300);
      this.upcoming_radar_overlay2_timestamp = this.upcoming_radar_overlay1_timestamp + 5 * 60;
      attitude_towards_overlay2 = (this.upcoming_radar_overlay2_timestamp - seconds_since_unix_epoch) / (5 * 60);


      if (this.upcoming_radar_overlay1_timestamp !== this.displayed_radar_overlay1_timestamp) {
          if (this.radar_overlay1)
              this.map.removeLayer(this.radar_overlay1);

          this.displayed_radar_overlay1_timestamp = this.upcoming_radar_overlay1_timestamp;
          var hash = this.urlAndBoundsForImage(this.displayed_radar_overlay1_timestamp)
          this.radar_overlay1 = L.imageOverlay(hash.url, hash.bounds);
          this.radar_overlay1.addTo(this.map);
      }

      var o1 = attitude_towards_overlay2;
      if (this.radar_overlay1)
          this.radar_overlay1.setOpacity(Math.sqrt(o1) * 0.8);

      if (this.upcoming_radar_overlay2_timestamp !== this.displayed_radar_overlay2_timestamp) {
          if (this.radar_overlay2)
              this.map.removeLayer(this.radar_overlay2);

          this.displayed_radar_overlay2_timestamp = this.upcoming_radar_overlay2_timestamp;
          var hash = this.urlAndBoundsForImage(this.displayed_radar_overlay2_timestamp)
          this.radar_overlay2 = L.imageOverlay(hash.url, hash.bounds);
          this.radar_overlay2.addTo(this.map);
      }

      var o2 = (1.0 - attitude_towards_overlay2);

      if (this.radar_overlay2)
          this.radar_overlay2.setOpacity(Math.sqrt(o2) * 0.8);
  }

  this.URL_ROOT = 'https://www.shmu.sk'
  this.ALADIN_HOUR_CONVERTER = {0: '00', 1: '00', 2: '00',
    3: '03', 4: '03', 5: '03',
    6: '06', 7: '06', 8: '06',
    9: '09', 10: '09', 11: '09',
    12: '12', 13: '12', 14: '12',
    15: '15', 16: '15', 17: '15',
    18: '18', 19: '18', 20: '18',
    21: '21', 22: '21', 23: '21',

}

this.RADAR_BOUNDS = [[46.058153, 13.646195], [50.658881, 23.776679]];
this.ALADIN_BOUNDS = [[47.43994,16.52446], [49.8865,22.8980]]
this.urlAndBoundsForImage = function(timestamp){
    var imageTime = new Date(timestamp * 1000)
    var now = new Date()
    if(imageTime < now){
        var bounds = this.RADAR_BOUNDS
        var url = this.URL_ROOT + '/data/dataradary/data.cmax/cmax.kruh.' + strftime('%Y%m%d.%H%M', imageTime) + '.0.png';
    } else {
        var bounds = this.ALADIN_BOUNDS 
        var hours = imageTime.getHours()
        imageTime.setTime(imageTime.getTime() + (3*60*60*1000)) 
        var yyyymmdd = strftime('%Y%m%d', imageTime)
        var h = this.ALADIN_HOUR_CONVERTER[imageTime.getHours()]
        var url = this.URL_ROOT + '/aladin/' + yyyymmdd + '/' + yyyymmdd + '-'+h+'.gif'
    }
    return({url: url, bounds: bounds})
}    
}

radarApp = new RadarApp()
