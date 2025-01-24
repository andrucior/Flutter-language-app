import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoId;
  final String selectedLanguage;
  final String targetLanguage;
  const VideoPlayerScreen(
      {super.key,
        required this.videoId,
        required this.selectedLanguage,
        this.targetLanguage = 'en'});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late YoutubePlayerController _controller;
  late Timer _timer;
  List<Caption> _captions = [];
  ValueNotifier<String> _currentCaptionNotifier = ValueNotifier('');
  ValueNotifier<String> _translatedCaptionNotifier = ValueNotifier('');
  String _selectedWord = '';
  final String _backendUrl = "http://192.168.1.104:8000/get_captions";

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: true,
      params: const YoutubePlayerParams(
        mute: false,
        showControls: true,
        showFullscreenButton: true,
        enableCaption: false,
      ),
    );
    _fetchCaptions();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _syncCaptions());
  }

  @override
  void dispose() {
    _controller.close();
    _timer.cancel();
    _currentCaptionNotifier.dispose();
    _translatedCaptionNotifier.dispose();
    super.dispose();
  }

  Future<void> _fetchCaptions() async {
    final url = Uri.parse(
        '$_backendUrl?video_id=${widget.videoId}&language=${widget
            .selectedLanguage}');
    setState(() {
      _captions = [];
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
              duration: Duration(
                  milliseconds: (caption['duration'] * 1000).toInt()),
            );
          }).toList();
          _currentCaptionNotifier.value = _captions[0].text;
        });
      } else {
        setState(() {
          _captions = [];
        });
      }
    } catch (e) {
      log("Error fetching captions: $e");
      setState(() {
        _captions = [];
      });
    }
  }

  Future<void> _syncCaptions() async {
    if (_captions.isEmpty) return;

    try {
      final currentTimeMillis =
      (await _controller.currentTime * 1000).toInt();
      final currentTime = Duration(milliseconds: currentTimeMillis);
      final caption = _captions.firstWhere(
            (c) =>
        c.offset <= currentTime && c.offset + c.duration > currentTime,
        orElse: () =>
            Caption(text: '', offset: Duration.zero, duration: Duration.zero),
      );

      if (caption.text != _currentCaptionNotifier.value) {
        _currentCaptionNotifier.value = caption.text;
      }
    } catch (e) {
      log('Error syncing captions: $e');
    }
  }

  Future<void> _translateWord(String word) async {
    final backend = 'http://192.168.1.104:8000/get_translation';
    final url = Uri.parse(
        '$backend?word=$word&target=en&source=${widget.selectedLanguage}');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        _translatedCaptionNotifier.value = response.body;
        _controller.pauseVideo();
        await Future.delayed(Duration(seconds: 1));
        _controller.playVideo();
        return;
      }
    } catch (e) {
      log("Error translating word: $e");
    }
    _translatedCaptionNotifier.value = "Translation failed";
  }

  Future<void> _addToFlashcards(String caption, String translation) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User not logged in.")),
      );
      return;
    }

    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('flashcards')
          .doc();

      await docRef.set({
        'caption': caption,
        'translation': translation,
        'source': widget.selectedLanguage,
        'target': widget.targetLanguage,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to Flashcards!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving flashcard: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final gapHeight = 4.0; // Adjust gap to avoid overflow

    return YoutubePlayerScaffold(
      controller: _controller,
      builder: (context, player) => Scaffold(
        appBar: AppBar(
          title: const Text('YouTube Caption Sync'),
        ),
        body: Column(
          children: [
            player,
            const SizedBox(height: 4), // Reduced height for player
            SizedBox(
              height: 200,
              child:
              Expanded(
                child: SingleChildScrollView(
                  child: ValueListenableBuilder<String>(
                    valueListenable: _currentCaptionNotifier,
                    builder: (context, caption, _) {
                    // Remove unwanted characters (commas, dots, newlines, etc.)
                      caption = caption
                          .replaceAll(RegExp(r'[^\w\sÀ-ÿ]'), '') // Remove unwanted punctuation
                          .split(RegExp(r' |\n')) // Split by space or newline
                          .where((word) => word.isNotEmpty) // Remove empty words
                          .join(' ');

                      return Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: caption
                              .split(' ')
                              .map(
                                (word) => GestureDetector(
                              onTap: () {
                                _selectedWord = word;
                                _translateWord(_selectedWord);
                              },
                              child: Chip(
                                label: Text(word),
                                backgroundColor: Colors.blue[500], // Background color
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12), // Border radius
                                ),
                                side: BorderSide.none, // Remove border color
                              ),
                            ),
                          )
                              .toList(),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            ValueListenableBuilder<String>(
              valueListenable: _translatedCaptionNotifier,
              builder: (context, translation, _) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.blue[50],
                  alignment: Alignment.topCenter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        translation.isEmpty
                            ? 'Tap a word to translate'
                            : 'Translation: $translation',
                        style: const TextStyle(fontSize: 16),
                      ),
                      if (translation.isNotEmpty)
                        ElevatedButton(
                          onPressed: () =>
                              _addToFlashcards(_selectedWord, translation),
                          child: const Text('Add to Flashcards'),
                        ),
                    ],
                  ),
                );
              },
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

  Caption({required this.text, required this.offset, required this.duration});
}
