import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'spotify_player.dart';

class SongSearchScreen extends StatefulWidget {
  const SongSearchScreen({super.key});

  @override
  _SongSearchScreenState createState() => _SongSearchScreenState();
}

class _SongSearchScreenState extends State<SongSearchScreen> {
  final TextEditingController _queryController = TextEditingController();
  bool _isLoading = false;
  List<dynamic> _songs = [];
  String _selectedLanguage = "es";

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


  Future<void> searchSongs(String query) async {
    setState(() {
      _isLoading = true;
    });

    Uri uri = Uri.parse("http://127.0.0.1:8000/search_tracks?query=$query"
        "&language=$_selectedLanguage");

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _songs = data; // Directly assign the list of songs
        });
      } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Error: ${response.statusCode}")),
            );
          }
      }
    } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to fetch songs.")),
          );
        }
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Spotify Song Search'),
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
              controller: _queryController,
              decoration: InputDecoration(
                labelText: 'Search for songs',
                border: OutlineInputBorder(),
              ),
              onSubmitted: searchSongs,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => searchSongs(_queryController.text),
              child: Text('Search'),
            ),
            const SizedBox(height: 16),
            _isLoading
                ? CircularProgressIndicator()
                : Expanded(
              child: ListView.builder(
                itemCount: _songs.length,
                itemBuilder: (context, index) {
                  final song = _songs[index];
                  final songArtists = (song["artists"] as List<dynamic>).join(", "); // Join artist names

                  return ListTile(
                    title: Text(song["name"] ?? "Unknown Song"),
                    subtitle: Text(
                      "$songArtists • ${song["album"] ?? "Unknown Album"}",
                    ),
                    trailing: song["preview_url"] != null
                        ? Icon(Icons.play_arrow) // Icon indicates that the song has a preview
                        : null,
                    onTap: () {
                      // Redirect to SpotifyPlayerScreen on tap
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SpotifyPlayerScreen(
                            songName: song["name"] ?? "Unknown Song",
                            artistName: songArtists,
                            albumName: song["album"] ?? "Unknown Album",
                            spotifyUrl: song["preview_url"] ?? "",
                            previewUrl: song["preview_url"], // Optional, for preview functionality
                            selectedLanguage: _selectedLanguage,
                          ),
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
}
