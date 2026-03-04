# Chat Viewer

A beautiful Flutter app for visualizing WhatsApp chat exports. Import your chat history and view it with rich formatting, search capabilities, and intuitive UI.

## Features

- **Import WhatsApp Chats**: Select .txt chat export files and import them
- **Rich Message Display**: View all message types including text, media omitted markers, system events, and missed calls
- **Call Detection**: Automatically identifies and displays call events from your chat
- **Message Editing**: Shows which messages have been edited with visual indicators
- **Text Formatting**: Renders bold (*text*), italic (_text_), and strikethrough (~text~) formatting
- **Full-Text Search**: Find any message instantly with real-time highlighting and jump-to-result navigation
- **Performance Optimized**: Handles large chat histories (7000+ messages) smoothly using isolates and efficient rendering
- **Multi-Participant Support**: Works with individual and group chats
- **Beautiful UI**: WhatsApp-inspired theme with authentic chat bubble design

## Installation

```bash
flutter pub get
flutter run
```

## How to Use

1. **Export your WhatsApp chat**:
   - Open WhatsApp > Select a chat > Menu > More > Export chat > Without media
   - Save the .txt file to your device

2. **Import in Chat Viewer**:
   - Tap the floating action button
   - Select WhatsApp
   - Follow the on-screen instructions
   - Choose your user name (how you appear in the chat)
   - Tap "Generate" to import

3. **View and Search**:
   - Tap on any imported chat to view messages
   - Tap the search icon to find specific messages
   - Use ↑/↓ arrows to navigate between results
   - Scroll back to latest message with the floating action button

## Architecture

- **Storage**: SharedPreferences for metadata, local file system for full conversations (JSON)
- **Parsing**: Custom regex-based WhatsApp chat parser with isolate support
- **Rendering**: Reverse ListViews for performance, rich TextSpans for formatting
- **Search**: Real-time RegExp matching with yellow highlight and automatic scrolling
