<?php 
header("Content-Type: text/html");
header("Expires: 0");
header("Last-Modified: " . gmdate("D, d M Y H:i:s") . " GMT");
header("Cache-Control: no-store, no-cache, must-revalidate");
header("Cache-Control: post-check=0, pre-check=0", false);
header("Pragma: no-cache");
?>

<!DOCTYPE html>
<html>
  <head>
    <title>Yoruba :: DCLM Radio</title>
		<//?php include 'assets/libs/meta.php'; ?>
  </head>


  <body>
    <div class="grid-x">
      <div class="large-6 medium-6 small-12 large-centered medium-centered cell">

        <div id="white-player" >
          <div class="white-player-top">
            <div class="grid-x">
              <div class="large-3 medium-3 small-3 cell">

              </div>
              <div class="large-12 large-centered medium-6 small-6 cell">
                <span class="now-playing">DCLM Radio - Yoruba</span>
              </div>
              <div class="large-3 medium-3 small-3 cell">
                <!--<img src="./img/show-playlist.svg" class="show-playlist"/>-->
              </div>
            </div>
          </div>

          <div id="white-player-center">
            <img amplitude-song-info="cover_art_url" amplitude-main-song-info="true" class="main-album-art" id="art" />

            <div class="song-meta-data ">
              <div class="grid-x align-center" >
                <span amplitude-song-info="name" amplitude-main-song-info="true" class="song-name" id="title"></span> 
              </div>
              <div class="grid-x align-center ">
              <span amplitude-song-info="artist" amplitude-main-song-info="true" class="song-artist" id="artist"></span>
              </div>
              <div class="grid-x align-center ">
                <span>Listeners:&nbsp;</span> 
                <span class="song-artist" id="listeners"> </span>
              </div>
            </div>

            <div class="time-progress">
              <div class="grid-x">
                <div class="large-12 medium-12 small-12 cell">
                  <div id="progress-container">
                    <!--<input type="range" class="amplitude-song-slider" amplitude-main-song-slider="true"/>-->
  				          <!--<progress id="song-played-progress" class="amplitude-song-played-progress" amplitude-main-song-played-progress="true"></progress>-->
  				          <progress id="song-buffered-progress" class="amplitude-buffered-progress" value="0"></progress>
  				    <input type="range" class="amplitude-volume-slider"/>
                  </div>
                </div>
              </div>

              <div class="grid-x">
                <div class="large-6 medium-6 small-6 cell">
                  <span class="current-time">
  				          <!--<span class="amplitude-current-minutes" amplitude-main-current-minutes="true"></span>:<span class="amplitude-current-seconds" amplitude-main-current-seconds="true"></span>-->
  				        </span>
                </div>
                <div class="large-6 medium-6 small-6 cell">
                  <span class="duration">
  				          <!--<span class="amplitude-duration-minutes" amplitude-main-duration-minutes="true"></span>:<span class="amplitude-duration-seconds" amplitude-main-duration-seconds="true"></span>-->
  				        </span>
                </div>
              </div>
            </div>
          </div>

          <div id="white-player-controls">
            <div class="grid-x">
              <div class="large-12 medium-12 small-12 cell">
                <!--<div class="amplitude-shuffle amplitude-shuffle-off" id="shuffle"></div>-->
                <!--<div class="amplitude-prev" id="previous"></div>-->
                <div class="amplitude-play-pause" amplitude-main-play-pause="true" id="play-pause"></div>
                <!--<div class="amplitude-next" id="next"></div>-->
              </div>

            </div>
          </div>

          <div id="white-player-controls">
            <div class="grid-x align-center">
              <?php include 'assets/libs/lang.php';?>
            </div>
          </div>

          <div id="white-player-controls">
            <div class="grid-x">
              <?php include 'assets/libs/appstore.php';?>
            </div>
          </div>

        </div>

      </div>
    </div>
    <?php include 'assets/libs/footer.php'; ?>
    <script>
      $(document).foundation();
      $(document).ready(function(){
          $('#myModal').foundation('reveal', 'open')
      });
    </script>  
  </body>
  <script type="text/javascript">
    Amplitude.init({
      "songs": [
        {
          "name": "On Air!",
          "artist": "DCLM Radio - Yoruba",
          "url": "https://airtime.dclm.org/radio/8060/yoruba",
          "cover_art_url": "assets/img/album-art/art.png",
          "genre": "Gospel",
      	  "live": true
        }
      ],
      "volume": 90
      //"autoplay": true
    });
  </script>

  <!-- Listeners count code -->
  <script>
    window.addEventListener('load',
    function getAPI(){
    // code to execute
    fetch('https://stat1.dclm.org/api/nowplaying/2')
        .then((res) => { return res.json() })
        .then((data) => {
          //console.log(data.listeners.current);
          document.getElementById('artist').innerHTML = data.now_playing.song.artist;
          document.getElementById('title').innerHTML = data.now_playing.song.title;
          document.getElementById('listeners').innerHTML = data.listeners.current;
          document.getElementById('art').src = data.now_playing.song.art;
        })
  	  setTimeout(getAPI, 60000);
    })
  </script>

</html>