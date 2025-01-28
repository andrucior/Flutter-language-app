import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FlashcardReviewScreen extends StatefulWidget {
  const FlashcardReviewScreen({super.key});

  @override
  State<FlashcardReviewScreen> createState() => _FlashcardReviewScreenState();
}

class _FlashcardReviewScreenState extends State<FlashcardReviewScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, String>> _flashcards = [];
  bool _isLoading = true;
  int _currentIndex = 0;
  bool _isFlipped = false;
  late AnimationController _controller;
  late Animation<double> _flipAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fetchFlashcards();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(begin: Offset.zero, end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  Future<void> _fetchFlashcards() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception("No user logged in");
      }

      final flashcardsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('flashcards')
          .get();

      final flashcards = flashcardsSnapshot.docs.map((doc) {
        return {
          'caption': doc['caption'] as String,
          'translation': doc['translation'] as String,
        };
      }).toList();

      setState(() {
        _flashcards = flashcards;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading flashcards: $error")),
        );
      }
    }
  }

  Future<void> _addFlashcard(String caption, String translation) async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception("No user logged in");
      }

      final newFlashcard = {'caption': caption, 'translation': translation};

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('flashcards')
          .add(newFlashcard);

      setState(() {
        _flashcards.add(newFlashcard);
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error adding flashcard: $error")),
        );
      }
    }
  }

  void _showNextFlashcard({required bool isKnown}) {
    setState(() {
      _isFlipped = false;
      _controller.reset();
      if (_currentIndex < _flashcards.length - 1) {
        _currentIndex++;
      } else {
        _currentIndex++;
      }
    });
  }

  void _flipCard() {
    setState(() {
      _isFlipped = !_isFlipped;
      if (_isFlipped) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showAddFlashcardDialog() {
    final captionController = TextEditingController();
    final translationController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Add Flashcard"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: captionController,
                decoration: const InputDecoration(labelText: "Caption"),
              ),
              TextField(
                controller: translationController,
                decoration: const InputDecoration(labelText: "Translation"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final caption = captionController.text.trim();
                final translation = translationController.text.trim();

                if (caption.isNotEmpty && translation.isNotEmpty) {
                  // Close the dialog before making the async call.
                  Navigator.pop(context);

                  // Access the ScaffoldMessenger outside the async gap.
                  final messenger = ScaffoldMessenger.of(context);

                  try {
                    await _addFlashcard(caption, translation);
                  } catch (error) {
                    messenger.showSnackBar(
                      SnackBar(content: Text("Error adding flashcard: $error")),
                    );
                  }
                } else {
                  // No async gap here, so it's safe to use `context`.
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Please fill in both fields"),
                    ),
                  );
                }
              },
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final bool hasCompletedReview = _currentIndex >= _flashcards.length;
    double height = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Review Flashcards"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : hasCompletedReview
          ? const Center(
        child: Text(
          "You've reviewed all the flashcards! Keep learning to meet your "
              "language goals!",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      )
          : Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: _flipCard,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final isFrontVisible = _flipAnimation.value <= 0.5;
                final flashcard = _flashcards[_currentIndex];
                return Dismissible(
                  key: Key('flashcard_$_currentIndex'),
                  direction: DismissDirection.horizontal,
                  onDismissed: (direction) {
                    if (direction == DismissDirection.endToStart) {
                      _showNextFlashcard(isKnown: true);
                    } else if (direction == DismissDirection.startToEnd) {
                      _showNextFlashcard(isKnown: false);
                    }
                  },
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerLeft,
                    child: const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Icon(Icons.close, color: Colors.white),
                    ),
                  ),
                  secondaryBackground: Container(
                    color: Colors.green,
                    alignment: Alignment.centerRight,
                    child: const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Icon(Icons.check, color: Colors.white),
                    ),
                  ),
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Transform(
                      transform: Matrix4.rotationY(_flipAnimation.value * 3.14159),
                      alignment: Alignment.center,
                      child: Card(
                        elevation: 4,
                        margin: const EdgeInsets.all(16.0),
                        child: Container(
                          width: double.infinity,
                          height: height / 3,
                          alignment: Alignment.center,
                          child: isFrontVisible
                              ? Text(
                            flashcard['caption'] ?? '',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          )
                              : Transform(
                            transform: Matrix4.rotationY(3.14159),
                            alignment: Alignment.center,
                            child: Text(
                              flashcard['translation'] ?? '',
                              style: const TextStyle(
                                fontSize: 22,
                                fontStyle: FontStyle.italic,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () => _showNextFlashcard(isKnown: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text(
                  "I know this word",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => _showNextFlashcard(isKnown: false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text(
                  "Prefer to review",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddFlashcardDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
