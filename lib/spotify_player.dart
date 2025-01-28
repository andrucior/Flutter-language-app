import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:developer';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SpotifyPlayerScreen extends StatefulWidget {
  final String songName;
  final String artistName;
  final String albumName;
  final String spotifyUrl;
  final String? previewUrl;
  final String selectedLanguage;
  final String targetLanguage;

  const SpotifyPlayerScreen({
    super.key,
    required this.songName,
    required this.artistName,
    required this.albumName,
    required this.spotifyUrl,
    this.selectedLanguage = 'en',
    this.targetLanguage = 'en',
    this.previewUrl,
  });

  @override
  SpotifyPlayerScreenState createState() => SpotifyPlayerScreenState();
}

class SpotifyPlayerScreenState extends State<SpotifyPlayerScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<List<String>> lyricsLines = [];
  final ValueNotifier<String> _translatedCaptionNotifier = ValueNotifier<String>('');
  int _currentPage = 0; // Track the current page
  final int _linesPerPage = 3; // Maximum lines per page
  String _selectedWord = '';
  bool _lyricsLoading = true;

  @override
  void initState() {
    super.initState();
    fetchLyrics();
    if (widget.previewUrl != null) {
      _playPreviewAudio();
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> fetchLyrics() async {
    try {
      final response = await http.get(Uri.parse(
          'http://192.168.1.104:8000/get_lyrics?'
              'artist=${Uri.encodeComponent(widget.artistName)}'
              '&song=${Uri.encodeComponent(widget.songName)}'
              '&language=${Uri.encodeComponent(widget.selectedLanguage)}'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['lyrics'] != null) {
          setState(() {
            var processed = processLyrics(data['lyrics'] as List<dynamic>);
            lyricsLines = processed.$1; // lines
            _lyricsLoading = false;
          });
        } else {
          setState(() {
            _lyricsLoading = false;
          });
          showErrorSnackBar("Lyrics not found.");
        }
      } else {
        setState(() {
          _lyricsLoading = false;
        });
        showErrorSnackBar("Failed to load lyrics: ${response.statusCode}");
      }
    } catch (e) {
      log("Error fetching lyrics: $e");
      setState(() {
        _lyricsLoading = false;
      });
      showErrorSnackBar("An error occurred while fetching lyrics.");
    }
  }

  (List<List<String>>, List<String>) processLyrics(List<dynamic> lyrics) {
    List<List<String>> lines = [];
    List<String> allWords = [];

    for (var line in lyrics) {
      if (line is List<dynamic>) {
        var words = line.whereType<String>().toList();
        if (words.isNotEmpty) {
          lines.add(words);
          allWords.addAll(words);
        }
      }
    }

    return (lines, allWords);
  }

  Future<void> _translateWord(String word) async {
    try {
      final response = await http.get(Uri.parse(
          'http://192.168.1.104:8000/get_translation?'
              'word=${Uri.encodeComponent(word)}'
              '&source=${widget.selectedLanguage}'
              '&target=${widget.targetLanguage}'));

      if (response.statusCode == 200) {
        _translatedCaptionNotifier.value = response.body;
      } else {
        _translatedCaptionNotifier.value = "Translation failed.";
      }
    } catch (e) {
      log("Error translating word: $e");
      _translatedCaptionNotifier.value = "Translation failed.";
    }
  }

  Future<void> _addToFlashcards(String caption, String translation) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      showErrorSnackBar("User not logged in.");
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

      showSuccessSnackBar("Added to Flashcards!");
    } catch (e) {
      showErrorSnackBar("Error occurred while saving.");
    }
  }

  Future<void> _playPreviewAudio() async {
    if (widget.previewUrl != null) {
      try {
        await _audioPlayer.play(UrlSource(widget.previewUrl!));
      } catch (e) {
        log("Error playing audio: $e");
        showErrorSnackBar("Failed to play audio preview.");
      }
    }
  }

  Future<void> _launchUrl(String url) async {
    if (!await launchUrl(Uri.parse(url))) {
      showErrorSnackBar("Could not launch URL.");
    }
  }

  void showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _goToNextPage() {
    if ((_currentPage + 1) * _linesPerPage < lyricsLines.length) {
      setState(() {
        _currentPage++;
      });
    }
  }

  void _goToPreviousPage() {
    if (_currentPage > 0) {
      setState(() {
        _currentPage--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;

    final startIndex = _currentPage * _linesPerPage;
    final endIndex = startIndex + _linesPerPage;
    final paginatedLyrics = lyricsLines.isEmpty
        ? []
        : lyricsLines.sublist(startIndex, endIndex.clamp(0, lyricsLines.length));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.songName),
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Song: ${widget.songName}", style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Text("Artist: ${widget.artistName}", style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text("Album: ${widget.albumName}", style: TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _launchUrl(widget.spotifyUrl),
              icon: Icon(Icons.open_in_browser),
              label: Text("Open in Spotify"),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: screenHeight / 3,
              child: _lyricsLoading
                  ? const Center(child: CircularProgressIndicator())
                  : lyricsLines.isEmpty
                  ? const Center(child: Text("No lyrics available"))
                  : SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.start,
                  children: paginatedLyrics.expand<Widget>((line) {
                    return line.map<Widget>((word) {
                      return GestureDetector(
                        onTap: () async {
                          _selectedWord = word;
                          await _translateWord(word);
                        },
                        child: Chip(
                          label: Text(
                            word,
                            style: const TextStyle(color: Colors.white),
                          ),
                          backgroundColor: Colors.blue[500],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    }).toList();
                  }).toList(),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: _goToPreviousPage,
                  child: Text("Previous"),
                ),
                ElevatedButton(
                  onPressed: _goToNextPage,
                  child: Text("Next"),
                ),
              ],
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
                          onPressed: () => _addToFlashcards(_selectedWord, translation),
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
