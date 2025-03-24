**LingApp**

LingApp is a cross-platform language immersion application designed to help users improve their language skills by providing interactive and media-rich content. The app integrates YouTube videos, Spotify songs, flashcards, and other learning tools to create an engaging and personalized language learning experience.

**Features**

Current Features:

-_YouTube Video Search:_ Search and browse YouTube videos in the target language to improve listening comprehension. Subtitles displayed in real-time with the option to translate and add a word to flashcards (Note: subtitles are not available on the deployed version due to Youtube API restrictions, to use this feature you have to run the app and server locally, more on this: https://github.com/jdepoix/youtube-transcript-api/issues/303)

-_Spotify Song Search:_ Search for songs using the Spotify API, with song metadata retrieved from Genius. Note: Podcasts and Spotify playback have not yet been implemented. Subtitles are retrieved for the whole song and paginated (Note: this feature also works only locally, since the app would need to be Spotify-verified first)

-_Flashcard Review_: Save and review vocabulary words as interactive flashcards.

-_Authentication_: Sign in or register with Firebase Authentication to save progress across devices.

**Cross-Platform Support:**

-Fully supported on Android and web (Note: use "flutter run -d chrome --web-renderer html" when run locally on web).

-Should be compatible with iOS (requires macOS for testing).

-Partial support for Windows (only flashcards).

**Planned Features:**

-_Grammar Explanation:_ Provide on-demand grammar explanations linked to words or phrases (not yet implemented).

-_Interactive Exercises:_ Enable exercises to reinforce vocabulary, comprehension, and grammar concepts.

-_Pronunciation Practice:_ Use speech recognition to provide feedback on pronunciation.

**Screens and Navigation**

Main Screen (Home)

Review Flashcards: Opens the flashcard review module to practice saved vocabulary.

Learn grammar: A placeholder screen for content to be developed in the future.

Browse Videos: Opens the YouTube video search module to discover content in the target language.

Spotify: Allows users to search for songs in the selected language. (Playback not implemented.)

**Authentication**

Login and Sign Up: Integrated with Firebase Authentication.

**Technologies and Tools**

Frontend: Flutter (Dart)
Backend: Firebase for authentication and database management. Python flask API for retrieving necessary data.

<img src="https://github.com/user-attachments/assets/c526e5f2-f202-41a9-8761-d1796212f79f" width="50%"/>

