import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'video_search.dart';
import 'auth_screen.dart';
import 'firebase_options.dart';
import 'flashcard_review.dart';
import 'to_be_developed.dart';
import 'package:gif_view/gif_view.dart';
import 'spotify_search.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.amber,
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
      title: 'LingApp',
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.blue[100],
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
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasData) {
            return const HomeScreen();
          }
          return AuthScreen();
        },
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AuthScreen()),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final aspectRatio = screenSize.width / (0.8 * screenSize.height);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12.0),
              child: GifView.asset(
                '2576ab3a50ccdae861fc5abcfa20a1dc.gif',
                width: 50,
                height: 50,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 8.0),
            const Text('Home'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: MediaQuery
                .of(context)
                .size
                .height * 0.05,
          ),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              childAspectRatio: aspectRatio, // Adjust this value for rectangular tiles
              padding: const EdgeInsets.all(16.0),
              crossAxisSpacing: 16.0,
              mainAxisSpacing: 16.0,
              children: [
                _buildTile(
                  context,
                  icon: Icons.flash_on,
                  label: 'Review Flashcards',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => FlashcardReviewScreen()),
                    );
                  },
                ),
                _buildTile(
                  context,
                  icon: Icons.lightbulb,
                  label: 'Grammar rules',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => ToBeDevelopedScreen()),
                    );
                  },
                ),
                _buildTile(
                  context,
                  icon: Icons.video_library,
                  label: 'Browse Videos',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => VideoSearchScreen()),
                    );
                  },
                ),
                _buildTile(
                  context,
                  icon: Icons.library_music,
                  label: 'Spotify',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => SongSearchScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(BuildContext context,
      {required IconData icon, required String label, required VoidCallback onTap}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate the size to fit one quarter of the available screen space
        final double height = constraints.maxHeight;
        return GestureDetector(
          onTap: onTap,
          child: Card(
            elevation: 4.0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: height * 0.3, color: Colors.blueAccent),
                const SizedBox(height: 8.0),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: height * 0.08,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
