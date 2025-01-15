import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class App extends StatefulWidget {
  static String videoID = 'egMWlD3fLJ8';
  // YouTube Video Full URL : https://www.youtube.com/watch?v=egMWlD3fLJ8
  @override
  _AppState createState() => _AppState();
}

class _AppState extends State<App> {
  late YoutubePlayerController _controller;
  bool isFullScreen = false;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      initialVideoId: App.videoID,
      flags: YoutubePlayerFlags(
        autoPlay: false,
        mute: false,
      ),
    );
    _controller.addListener(() {
      if (_controller.value.isFullScreen != isFullScreen) {
        setState(() {
          isFullScreen = _controller.value.isFullScreen;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerBuilder(
      onExitFullScreen: () {
        SystemChrome.setPreferredOrientations(DeviceOrientation.values);
        setState(() {
          isFullScreen = false;
        });
      },
      player: YoutubePlayer(
          controller: _controller,
          liveUIColor: Colors.amber,
        showVideoProgressIndicator: true,
            
      ),
      builder: (context, player) => Scaffold(
      body: ListView(
        children: [
          player,
        ],
      ),
      )
    );
  }
}