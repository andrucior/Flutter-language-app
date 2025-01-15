import 'dart:developer';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:http/http.dart' as http;
import 'googleAuthService.dart'; // Import the GoogleAuthService class

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color.fromARGB(255, 46, 45, 45),
    ),
  );
  runApp(const YoutubePlayerDemoApp());
}

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

  String _hoveredWord = ''; // Store the hovered word
  Offset _hoverPosition = Offset.zero; // Store hover/tap position
  bool _showTranslation = false; // Control translation tile visibility

  final List<String> _ids = [
    'ooNEcr-VgP0', // Example video ID
  ];

  List<String> subtitles = [];
  final GoogleAuthService _googleAuthService = GoogleAuthService();

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

    _loadSubtitles();
  }

  Future<void> _loadSubtitles() async {
    try {
      // Obtain the access token using GoogleAuthService
      final accessToken = await _googleAuthService.authenticate();

      if (accessToken != null) {
        String srt = await fetchCaptions(_ids[0], accessToken);
        subtitles = _parseSrtToWords(srt);
        setState(() {});
      } else {
        log('Error: Failed to get access token.');
      }
    } catch (e) {
      log('Error loading captions: $e');
    }
  }

  Future<String> fetchCaptions(String videoId, String accessToken) async {
    // Step 1: Get caption ID
    final listUrl = 'https://www.googleapis.com/youtube/v3/captions';
    final listResponse = await http.get(
      Uri.parse('$listUrl?videoId=$videoId&part=snippet'),
      headers: {
        'Authorization': 'Bearer $accessToken', // Use the access token here
      },
    );

    if (listResponse.statusCode != 200) {
      throw Exception('Failed to fetch captions list');
    }

    final listData = jsonDecode(listResponse.body);
    if (listData['items'].isEmpty) {
      throw Exception('No captions available for this video');
    }

    final captionId = listData['items'][0]['id'];

    // Step 2: Download captions in SRT format
    final downloadUrl =
        'https://www.googleapis.com/youtube/v3/captions/$captionId?tfmt=srt';
    final downloadResponse = await http.get(
      Uri.parse(downloadUrl),
      headers: {
        'Authorization': 'Bearer $accessToken', // Use the access token here
      },
    );

    if (downloadResponse.statusCode != 200) {
      throw Exception('Failed to download captions');
    }
    print(downloadResponse);
    return downloadResponse.body; // Return the raw SRT content
  }

  List<String> _parseSrtToWords(String srt) {
    final lines = srt.split('\n');
    final words = <String>[];
    for (var line in lines) {
      if (!line.contains('-->') && line.trim().isNotEmpty && !RegExp(r'^\d+$').hasMatch(line)) {
        words.addAll(line.split(' '));
      }
    }
    return words;
  }

  Future<String> _translateWord(String word) async {
    // Mock translation function (replace with an API or library for real translation)
    return 'Translated: $word';
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerScaffold(
      controller: _controller,
      builder: (context, player) => Scaffold(
        appBar: AppBar(
          title: const Text('Youtube Player Flutter'),
        ),
        body: Stack(
          children: [
            Column(
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
                      _subtitleWithHover(),
                    ],
                  ),
                ),
              ],
            ),
            if (_showTranslation)
              Positioned(
                left: _hoverPosition.dx,
                top: _hoverPosition.dy - 50,
                child: Material(
                  elevation: 4.0,
                  borderRadius: BorderRadius.circular(8.0),
                  color: Colors.black,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: FutureBuilder<String>(
                      future: _translateWord(_hoveredWord),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Text(
                            'Translating...',
                            style: TextStyle(color: Colors.white),
                          );
                        }
                        return Text(
                          snapshot.data ?? 'Translation failed',
                          style: const TextStyle(color: Colors.white),
                        );
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _subtitleWithHover() {
    return Wrap(
      children: subtitles.map((word) {
        return GestureDetector(
          onTapDown: (details) => _onWordTap(word, details.globalPosition),
          onTapCancel: _onHoverExit,
          child: MouseRegion(
            onEnter: (event) => _onWordHover(word, event.position),
            onExit: (event) => _onHoverExit(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
              child: Text(
                word,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16.0,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _onWordHover(String word, Offset position) {
    setState(() {
      _hoveredWord = word;
      _hoverPosition = position;
      _showTranslation = true;
    });
  }

  void _onWordTap(String word, Offset position) {
    setState(() {
      _hoveredWord = word;
      _hoverPosition = position;
      _showTranslation = true;
    });
  }

  void _onHoverExit() {
    setState(() {
      _showTranslation = false;
    });
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

  Widget get _space => const SizedBox(height: 10);
}
