import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
      title: 'YouTube Caption Sync',
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
  late Timer _timer;

  List<Caption> _captions = [];
  String _currentCaption = '';
  String _translatedCaption = '';
  bool _isHovered = false;
  bool _isTranslating = false;

  final List<Map<String, String>> _flashcards = [];

  void _addToFlashcards(String caption, String translation) {
    setState(() {
      _flashcards.add({
        'caption': caption,
        'translation': translation,
      });
    });
    log('Flashcard added: $caption -> $translation');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Added to Flashcards!'),
      ),
    );
  }
  final List<String> _ids = ['TfNAo3OWXkI']; // Example video ID
  final String _backendUrl = 'http://localhost:5000/get_captions'; // Flask backend URL

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
        enableCaption: false,
      ),
    );

    // print("Loading captions!");
    _fetchCaptions();

    // Start a timer to sync captions every 500ms.
    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      _syncCaptions();
    });
  }

  @override
  void dispose() {
    _controller.close();
    _timer.cancel();
    super.dispose();
  }

  // Load captions by calling Python backend (Flask API)
  Future<void> _fetchCaptions() async {
    final videoId = _ids.first; // Using the first video ID in the list
    final url = Uri.parse('$_backendUrl?video_id=$videoId&language=es');

    setState(() {
      _captions = []; // Clear the current captions before fetching
    });

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> captionsData = json.decode(response.body);
        setState(() {
          _captions = captionsData.map<Caption>((caption) {
            return Caption(
            text: caption['text'],
            offset: Duration(milliseconds: (caption['start'] * 1000).toInt()),
            duration: Duration(milliseconds: (caption['duration'] * 1000).toInt()),
          );
          }).toList();
        });
      } else {
        // print("Error fetching captions: ${response.body}");
        setState(() {
          _captions = []; // Empty captions list on error
        });
      }
    } catch (e) {
      // print("Error fetching captions: $e");
      setState(() {
        _captions = [];
      });
    }
  }

  // Sync captions with the video time
  Future<void> _syncCaptions() async {
    if (_captions.isEmpty) return;

    try {
      // Get the current playback position in milliseconds.
      final currentTimeMillis = (await _controller.currentTime * 1000).toInt(); // Convert to milliseconds

      // Convert to Duration for comparison
      final currentTime = Duration(milliseconds: currentTimeMillis);

      // Find the caption corresponding to the current time.
      final caption = _captions.firstWhere(
        (c) =>
            c.offset <= currentTime &&
            c.offset + c.duration > currentTime, // Check if the current time is within the caption's range.
        orElse: () => Caption(text: '', offset: Duration.zero, duration: Duration.zero), // Default empty caption if none is found.
      );

      // Update the current caption only if it has changed.
      if (caption.text != _currentCaption) {
        setState(() {
          _currentCaption = caption.text;
          _translatedCaption = ''; // Reset translated caption when caption changes.
        });
      }
    } catch (e) {
      // print('Error syncing captions: $e');
    }
  }


  Future<String> _mockTranslate(String text) async {
    final backend = 'http://localhost:5000/get_translation';
    final url = Uri.parse('$backend?word=$text&target=en');
    // print(text);

    try {
      final response = await http.get(url);
      // print(response.body.toString());
      if (response.statusCode == 200) {
        var translated = response.body;
        return "Translation: $translated";
      }
    } catch (e) {
        log("Error fetching captions: $e");
      }
    return "Could not translate. Try again later";
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerScaffold(
      controller: _controller,
      builder: (context, player) => Scaffold(
        appBar: AppBar(
          title: const Text('YouTube Caption Sync'),
        ),
        body: Column(
          children: [
            player,
            const SizedBox(height: 16),
            MouseRegion(
              onEnter: (_) async {
                if (!_isTranslating) {
                  setState(() {
                    _isHovered = true;
                    _isTranslating = true;
                  });
                  _controller.pauseVideo();

                  try {
                    final translation = await _mockTranslate(_currentCaption);
                    if (mounted) {
                      setState(() {
                        _translatedCaption = translation;
                      });
                    }
                  } catch (e) {
                    log("Error during translation: $e");
                  } finally {
                    if (mounted) {
                      setState(() {
                        _isTranslating = false;
                      });
                    }
                    _controller.playVideo();
                  }
                }
              },
              onExit: (_) {
                setState(() {
                  _isHovered = false;
                  _translatedCaption = '';
                });
              },
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    color: Colors.black54,
                    child: Text(
                      _currentCaption.isNotEmpty
                          ? (_isHovered
                              ? _translatedCaption // Show translation when hovered.
                              : _currentCaption) // Show original caption when not hovered.
                          : "No captions available.",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (_isHovered && _translatedCaption.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Display the translation underneath the hovered caption.
                          Text(
                            _translatedCaption,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () {
                              _addToFlashcards(_currentCaption, _translatedCaption);
                            },
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              backgroundColor: Colors.white,
                            ),
                            child: const Text('Add to Flashcards'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Caption {
  final String text;
  final Duration offset;
  final Duration duration;

  Caption({
    required this.text,
    required this.offset,
    required this.duration,
  });
}
