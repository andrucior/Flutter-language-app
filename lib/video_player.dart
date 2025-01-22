import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Video view
// Fetching captions, translation (from flask api)
// Adding to flashcards (in firebase databse)

class VideoPlayerScreen extends StatefulWidget {
  final String videoId;

  const VideoPlayerScreen({super.key, required this.videoId});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late YoutubePlayerController _controller;
  late Timer _timer;
  List<Caption> _captions = [];
  String _currentCaption = '';
  String _translatedCaption = '';
  bool _isHovered = false;
  final List<Map<String, String>> _flashcards = [];
  final String _backendUrl = 'http://localhost:8000/get_captions';

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
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) => _syncCaptions());
  }

  @override
  void dispose() {
    _controller.close();
    _timer.cancel();
    super.dispose();
  }

  Future<void> _fetchCaptions() async {
    final url = Uri.parse('$_backendUrl?video_id=${widget.videoId}&language=es');

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
              duration: Duration(milliseconds: (caption['duration'] * 1000).toInt()),
            );
          }).toList();
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
      final currentTimeMillis = (await _controller.currentTime * 1000).toInt();
      final currentTime = Duration(milliseconds: currentTimeMillis);

      final caption = _captions.firstWhere(
        (c) => c.offset <= currentTime && c.offset + c.duration > currentTime,
        orElse: () => Caption(text: '', offset: Duration.zero, duration: Duration.zero),
      );

      if (caption.text != _currentCaption) {
        setState(() {
          _currentCaption = caption.text;
          _translatedCaption = '';
        });
      }
    } catch (e) {
      log('Error syncing captions: $e');
    }
  }

  Future<String> _translateWord(String word) async {
    final backend = 'http://localhost:8000/get_translation';
    final url = Uri.parse('$backend?word=$word&target=en');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return response.body;
      }
    } catch (e) {
      log("Error translating word: $e");
    }
    return "Translation failed";
  }

  Future<void> _addToFlashcards(String caption, String translation) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to save flashcards.')),
      );
      return;
    }

    final flashcardData = {
      'caption': caption,
      'translation': translation,
      'createdAt': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid) // Store under the specific user's ID
        .collection('flashcards')
        .add(flashcardData);

    log('Flashcard saved to Firestore: $caption -> $translation');
    setState(() {
      _flashcards.add({'caption': caption, 'translation': translation});
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Flashcard saved!')),
    );
  } catch (e) {
    log('Error saving flashcard: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to save flashcard.')),
    );
  }
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
                setState(() {
                  _isHovered = true; // Hover effect triggers translation availability.
                });
              },
              onExit: (_) {
                setState(() {
                  _isHovered = false;
                  _translatedCaption = ''; // Clear translation on exit.
                });
              },
              child: Column(
                children: [
                  // Original caption split into word tiles (buttons).
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8.0, // Space between word tiles.
                    runSpacing: 8.0, // Space between lines of word tiles.
                    children: _currentCaption.isNotEmpty
                        ? _currentCaption
                            .replaceAll(RegExp(r'[^\w\sÀ-ÿ]'), '') // Remove punctuation.
                            .split(' ')
                            .map((word) {
                              return TextButton(
                                onPressed: () async {
    
                                  setState(() {
                                    _translatedCaption = "Translating..."; // Show translating status.
                                  });

                                try {
                                  await _controller.pauseVideo();
                                  final translation = await _translateWord(word);
                                  if (mounted) {
                                    setState(() {
                                      _translatedCaption = 'Translation $translation';
                                    });
                                  }
                                } catch (e) {
                                  log("Error translating word: $e");
                                  if (mounted) {
                                    setState(() {
                                      _translatedCaption = 'Translation failed.';
                                    });
                                  }
                                }
                                finally {
                                  await _controller.playVideo();
                                }
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                                backgroundColor: Colors.blue[600],
                              ),
                              child: Text(
                                word,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            );
                          }).toList()
                        : [
                            const Text(
                              "No captions available.",
                              style: TextStyle(color: Colors.white, fontSize: 18),
                            ),
                          ],
                  ),
                  // Translated caption displayed underneath.
                  if (_isHovered && _translatedCaption.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Container(
                        padding: const EdgeInsets.all(8.0), // Optional padding around the text
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12.0)
                        ),
                        child: Text(
                          _translatedCaption,
                          style: const TextStyle(
                            color: Colors.blue,
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),

                  // Add to flashcards button.
                  if (_isHovered && _translatedCaption.isNotEmpty)
                    ElevatedButton(
                      onPressed: () {
                        _addToFlashcards(_currentCaption, _translatedCaption);
                      },
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.blue[600],
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
    );
  }
}

class Caption {
  final String text;
  final Duration offset;
  final Duration duration;

  Caption({required this.text, required this.offset, required this.duration});
}
