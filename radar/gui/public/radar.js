upcoming_radar_overlay1_timestamp = null;
displayed_radar_overlay1_timestamp = null;
upcoming_radar_overlay2_timestamp = null;
displayed_radar_overlay2_timestamp = null;
radar_overlay1 = null;
radar_overlay2 = null;

imageBounds = [[46.449212403852584, 16.21358871459961], [49.92602987536322, 22.70427703857422]];

$(function() {

    demoTracks = [trackToDisplay];
    // Get start/end times
    var startTime = new Date(demoTracks[0].properties.time[0]);
    var endTime = new Date(demoTracks[0].properties.time[demoTracks[0].properties.time.length - 1]);

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
    var timeline = new vis.Timeline(document.getElementById('timeline'), timelineData, timelineOptions);

    // Set custom time marker (blue)
    timeline.setCustomTime(startTime);

    // Setup leaflet map
    map = new L.Map('map');

    var basemapLayer = new L.TileLayer('http://freemap.sk/C/{z}/{x}/{y}.png');

    // Center map and default zoom level
    map.setView([48.74157, 19.35118], 8);

    // Adds the background layer to the map
    map.addLayer(basemapLayer);


    // =====================================================
    // =============== Playback ============================
    // =====================================================

    // Playback options
    var playbackOptions = {
        playControl: true,
        dateControl: true,
        speed: 5.0, // doesnt seem to influence the animation speed
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

    // Initialize playback
    var playback = new L.Playback(map, null, onPlaybackTimeChange, playbackOptions);

    playback.setData(demoTracks);
    playback.addData(trackToDisplay);

    // Uncomment to test data reset;
    //playback.setData(blueMountain);    

    // Set timeline time change event, so cursor is set after moving custom time (blue)
    timeline.on('timechange', onCustomTimeChange);





    function onCustomTimeChange(properties) {
        if (!playback.isPlaying()) {
            ms = properties.time.getTime();
            playback.setCursor(ms);
            adjustRadarImage(ms);
        }
    }

    // A callback so timeline is set after changing playback time
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
            radar_overlay1_image_url = '../radar_image/' + displayed_radar_overlay1_timestamp;
            radar_overlay1 = L.imageOverlay(radar_overlay1_image_url, imageBounds);
            radar_overlay1.addTo(map);
        }

        o1 = attitude_towards_overlay2;
        if (radar_overlay1)
            radar_overlay1.setOpacity(Math.sqrt(o1)*0.9);

        if (upcoming_radar_overlay2_timestamp !== displayed_radar_overlay2_timestamp) {
            if (radar_overlay2)
                map.removeLayer(radar_overlay2);

            displayed_radar_overlay2_timestamp = upcoming_radar_overlay2_timestamp;
            radar_overlay2_image_url = '../radar_image/' + displayed_radar_overlay2_timestamp;
            radar_overlay2 = L.imageOverlay(radar_overlay2_image_url, imageBounds);
            radar_overlay2.addTo(map);
        }

        o2 = (1.0 - attitude_towards_overlay2);

        if (radar_overlay2)
            radar_overlay2.setOpacity(Math.sqrt(o2)*0.9);
    }
});
