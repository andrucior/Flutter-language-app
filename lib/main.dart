import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color.fromARGB(255, 46, 45, 45),
    ),
  );
  runApp(const YoutubePlayerDemoApp());
}

/// Creates [YoutubePlayerDemoApp] widget.
class YoutubePlayerDemoApp extends StatelessWidget {
  const YoutubePlayerDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Youtube Player Flutter',
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.black,
        primarySwatch: Colors.red,
        appBarTheme: const AppBarTheme(
          color: Colors.black12,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w300,
            fontSize: 20,
          ),
        ),
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),
      home: const MyHomePage(),
    );
  }
}

/// Homepage
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late YoutubePlayerController _controller;
  late TextEditingController _idController;

  late PlayerState _playerState;
  late YoutubeMetaData _videoMetaData;
  bool _isPlayerReady = false;

  final List<String> _ids = [
    'ooNEcr-VgP0',
  ];

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: _ids.first,
      autoPlay: true,
      params: const YoutubePlayerParams(
        mute: false,
        showControls: true,
        showFullscreenButton: true,
      ),
    )..listen((event) {
        if (event.playerState == PlayerState.playing && !_isPlayerReady) {
          setState(() {
            _isPlayerReady = true;
          });
        }
        setState(() {
          _playerState = event.playerState;
          _videoMetaData = event.metaData;
        });
      });
    _idController = TextEditingController();
    _videoMetaData = const YoutubeMetaData();
    _playerState = PlayerState.unknown;
  }

  @override
  void dispose() {
    _controller.close();
    _idController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerScaffold(
      controller: _controller,
      builder: (context, player) => Scaffold(
        appBar: AppBar(
          title: const Text('Youtube Player Flutter'),
          actions: [
            IconButton(
              icon: const Icon(Icons.video_library),
              onPressed: () => log('Video Library Tapped!'),
            ),
          ],
        ),
        body: Column(
          children: [
            player,
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(8.0),
                children: [
                  _space,
                  _text('Title', _videoMetaData.title),
                  _space,
                  _text('Channel', _videoMetaData.author),
                  _space,
                  _text('Video Id', _videoMetaData.videoId),
                  _space,
                  _controlButtons(),
                  _space,
                  TextField(
                    controller: _idController,
                    enabled: _isPlayerReady,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      hintText: 'Enter Youtube video id or link',
                    ),
                  ),
                  _space,
                  ElevatedButton(
                    onPressed: _isPlayerReady
                        ? () {
                            final id = YoutubePlayerController.convertUrlToId(
                              _idController.text,
                            );
                            if (id != null) {
                              _controller.load(params: const YoutubePlayerParams(showFullscreenButton: true), id: id);
                            } else {
                              _showSnackBar('Invalid Youtube link');
                            }
                          }
                        : null,
                    child: const Text('Load Video'),
                  ),
                  _space,
                  _volumeSlider(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _text(String title, String value) {
    return RichText(
      text: TextSpan(
        text: '$title: ',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        children: [
          TextSpan(
            text: value,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      ),
    );
  }

  Widget _controlButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: const Icon(Icons.skip_previous),
          onPressed: _isPlayerReady
              ? () {
                  final index = _ids.indexOf(_controller.metadata.videoId);
                  _controller.load(params: const YoutubePlayerParams(showFullscreenButton: true), id: _ids[(index - 1) % _ids.length]);
                }
              : null,
        ),
        // IconButton(
        //   icon: Icon(
        //     _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
        //   ),
        //   onPressed: _isPlayerReady
        //       ? () {
        //           _controller.value.isPlaying
        //               ? _controller.pause()
        //               : _controller.play();
        //         }
        //       : null,
        // ),
        IconButton(
          icon: const Icon(Icons.skip_next),
          onPressed: _isPlayerReady
              ? () {
                  final index = _ids.indexOf(_controller.metadata.videoId);
                  _controller.load(params: const YoutubePlayerParams(showFullscreenButton: true), id:_ids[(index + 1) % _ids.length]);
                }
              : null,
        ),
      ],
    );
  }

  Widget _volumeSlider() {
    return Row(
      children: [
        const Text(
          'Volume',
          style: TextStyle(color: Colors.white),
        ),
        // Expanded(
        //   child: Slider(
        //     value: _controller.value.volume,
        //     min: 0,
        //     max: 100,
        //     divisions: 10,
        //     onChanged: _isPlayerReady
        //         ? (value) {
        //             _controller.setVolume(value);
        //           }
        //         : null,
        //   ),
        // ),
      ],
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget get _space => const SizedBox(height: 10);
}
