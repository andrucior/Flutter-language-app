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
  final ValueNotifier<String> _currentCaptionNotifier = ValueNotifier('');
  final ValueNotifier<String> _translatedCaptionNotifier = ValueNotifier('');
  String _selectedWord = '';
  final String _backendUrl = "http://127.0.0.1:8000"; // due to youtube api

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
        '$_backendUrl/get_captions?video_id=${widget.videoId}&language=${widget
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
    final backend = '$_backendUrl/get_translation';
    final url = Uri.parse(
        '$backend?word=$word&target=en&source=${widget.selectedLanguage}');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        _translatedCaptionNotifier.value = response.body;
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added to Flashcards!')),
        );
      }
    } catch (e) {
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error occurred while saving')),
          );
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    return YoutubePlayerScaffold(
      controller: _controller,
      builder: (context, player) => Scaffold(
        appBar: AppBar(
          title: const Text('YouTube Caption Sync'),
        ),
        body: Column(
          children: [
            SizedBox(
              height: screenWidth < 600 ? screenHeight / 3 : screenHeight / 2,
              width: screenWidth,
              child: player, // YouTube player widget
            ),
            const SizedBox(height: 4), // Reduced height for spacing
            SingleChildScrollView(
                child: ValueListenableBuilder<String>(
                  valueListenable: _currentCaptionNotifier,
                  builder: (context, caption, _) {
                    // Clean up the caption text
                    caption = caption
                        .replaceAll(RegExp(r'[^\w\sÀ-ÿ]'), '') // Remove unwanted punctuation
                        .split(RegExp(r'[ \n]')) // Split by space or newline
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
                              label: Text(
                                  word,
                                  style: TextStyle(
                                    color: Colors.white,
                                  ),
                                ),
                              backgroundColor: Colors.blue[500],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: BorderSide.none,
                            ),
                          ),
                        )
                            .toList(),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 50),
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
