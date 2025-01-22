import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'video_player.dart';

// Video searching view
// Fetching videos from flask api

class VideoSearchScreen extends StatefulWidget {
  const VideoSearchScreen({super.key});

  @override
  _VideoSearchScreenState createState() => _VideoSearchScreenState();
}

class _VideoSearchScreenState extends State<VideoSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final String _backendUrl = "http://localhost:8000/search_videos"; // Backend URL
  List<dynamic> _videos = [];
  bool _isLoading = false;
  String _selectedLanguage = "es"; // Default language is Spanish

  Future<void> _searchVideos(String query) async {
    setState(() {
      _isLoading = true;
      _videos = [];
    });

    final url = Uri.parse(
        '$_backendUrl?query=$query&language=$_selectedLanguage&max_results=10');

    try {
      final response = await http.get(url);
      print(response.toString());
      if (response.statusCode == 200) {
        setState(() {
          _videos = json.decode(response.body);
        });
      } else {
        log('Error: ${response.body}');
      }
    } catch (e) {
      log('Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search YouTube Videos'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.language),
            onSelected: (String language) {
              setState(() {
                _selectedLanguage = language;
              });
            },
            itemBuilder: (context) => [
              _buildLanguageMenuItem("Spanish", "es", "🇪🇸"),
              _buildLanguageMenuItem("French", "fr", "🇫🇷"),
              _buildLanguageMenuItem("Italian", "it", "🇮🇹"),
              _buildLanguageMenuItem("German", "de", "🇩🇪"),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              decoration: const InputDecoration(
                hintText: 'Enter search query',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final query = _searchController.text;
                if (query.isNotEmpty) {
                  _searchVideos(query);
                }
              },
              child: const Text('Search'),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const CircularProgressIndicator(),
            if (!_isLoading && _videos.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: _videos.length,
                  itemBuilder: (context, index) {
                    final video = _videos[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 8.0, horizontal: 16.0),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: Image.network(
                          video['thumbnail'],
                          width: 60.0,
                          height: 60.0,
                          fit: BoxFit.cover,
                        ),
                      ),
                      title: Text(
                        video['title'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16.0,
                          color: Colors.black,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        video['description'],
                        style: const TextStyle(
                          fontSize: 14.0,
                          color: Colors.grey,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.redAccent,
                        size: 28.0,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VideoPlayerScreen(
                                videoId: video['videoId']),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildLanguageMenuItem(
      String label, String code, String flag) {
    return PopupMenuItem<String>(
      value: code,
      child: Row(
        children: [
          Text(
            flag,
            style: const TextStyle(fontSize: 20.0),
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}
