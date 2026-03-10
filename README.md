# Chat Viewer

A beautiful Flutter app for visualizing and analyzing chat exports from your favorite messaging platforms. Import conversations, explore them with powerful search, and view messages with rich formatting support. Perfect for reviewing chat history, analyzing conversations, or simply re-reading important moments from your chats.

**Currently supports WhatsApp** • Instagram, Telegram & Facebook coming soon

## Features

### 📱 Import & Display
- **Multi-Platform Support**: Import chat exports from WhatsApp, Instagram, Telegram, and more with a simple multi-step flow (WhatsApp available now)
- **Rich Message Rendering**: Handles all message types (text, media markers, system events, missed calls)
- **Call Event Detection**: Automatically identifies and prettifies call logs ("You called him" / "Called you")
- **Message Editing Indicators**: Shows which messages have been edited with visual chips
- **Text Formatting Support**: Renders bold (`*text*`), italic (`_text_`), and strikethrough (`~text~`) formatting

### 🔍 Search & Navigation
- **Full-Text Search**: Search any message with real-time results as you type
- **Smart Highlighting**: Matched text highlighted in yellow; current result in bright amber
- **Result Navigation**: Jump between search results with ↑/↓ arrow buttons
- **Result Counter**: Shows "X / Y" current position in search results
- **Auto-Scroll**: Automatically scrolls to each result with smooth animation

### ⚡ Performance
- **Isolate-Based Processing**: Parsing and deserialization offloaded to background threads to prevent UI freezing
- **Handles Large Chats**: Optimized for chats with 7000+ messages without lag
- **Efficient Rendering**: Reverse ListView with selective item rendering (only visible items drawn)

### 👥 Multi-Chat & Organization
- **Chat List Screen**: View all imported chats with platform badges
- **Multi-Participant Support**: Works seamlessly with individual and group chats
- **Participant Tracking**: Correctly identifies and displays message senders
- **Chat Metadata**: Stores message count, participants, and import timestamps

### 🎨 Beautiful UI
- **Platform-Authentic Themes**: Chat bubble design matches each platform's aesthetic with proper alignment (sent/received)
- **Material 3 Design**: Modern, clean interface with smooth animations
- **Date Separators**: Clear visual breaks between conversation dates ("Today", "Yesterday", dates)
- **Read-Only Viewer**: Safe, non-destructive chat visualization

## Installation

### Requirements
- Flutter SDK (3.10.1 or later)
- Android SDK (for Android builds) or Xcode (for iOS)

### Setup

```bash
# Clone the repository
cd chat_viewer

# Get dependencies
flutter pub get

# Run the app
flutter run
```

## How to Use

### Step 1: Export WhatsApp Chat
1. Open WhatsApp on your phone
2. Select the chat you want to export
3. Tap **Menu** (⋮) → **More** → **Export chat**
4. Choose **Without media** (media files are not needed for this viewer)
5. Save the .txt file to your device

### Step 2: Import into Chat Viewer
1. Open Chat Viewer app
2. Tap the **+ Floating Action Button** (bottom right)
3. Select **WhatsApp** platform
4. Read the export instructions
5. Choose your .txt file using the file picker
6. Select **your name** from the participant list
7. Tap **Generate** to import the conversation

### Step 3: View & Search
1. Tap on an imported chat to open it
2. **Browse**: Scroll through messages naturally
3. **Search**: Tap the 🔍 search icon at top
4. **Type**: Your search query updates in real-time
5. **Navigate**: Use ↑/↓ arrows to jump between matches
6. **Exit**: Tap ← back button to close search
7. **Bottom**: Tap ↓ to jump back to latest messages

## Architecture

### State Management
- **StatefulWidget + setState**: Simple, performant state management for chat display
- **TextEditingController**: Search input handling with real-time callbacks
- **ScrollController**: Precise scroll position tracking and animation control

### Data Layer
- **Storage**: 
  - SharedPreferences stores chat metadata (title, participants, message count, timestamps)
  - Local file system stores full conversation JSON (one file per chat)
- **Models**:
  - `ChatMessage`: Individual message with 8 types (text, media, system, missedCall, callEvent, poll, deletedMessage)
  - `ChatConversation`: Multi-participant conversation with myName identity
  - `Platform`: Enum for import platform support (currently: WhatsApp; extensible for Instagram, Telegram, Facebook)

### Processing
- **Parsing**: Platform-specific parsers (currently WhatsApp regex-based)
  - WhatsApp regex: `DD/MM/YYYY, HH:MM AM/PM - Sender: Message`
  - Handles multi-line messages, timestamps, sender extraction
  - Extensible architecture for adding new platform parsers
  - Isolates parsing to background thread via `compute()` to prevent UI freezing
- **Format Detection**: Automatically identifies bold, italic, strikethrough via regex
- **Type Detection**: Detects call events, edited markers, system messages, media omissions

### Search Engine
- **Real-Time Matching**: RegExp-based substring search (case-insensitive)
- **Highlight Rendering**: Dual-pass TextSpan builder for formatting + search highlights
- **Colors**: 
  - Pale yellow (#FFE082) for all matches
  - Bright amber (#F9A825) for current result
- **Navigation**: Modulo-based cycling through results, global key-based scroll targeting
- **Scroll Strategy**: Manual offset calculation (not `ensureVisible`) for reliable jumps in large lists

### UI Components
- **ChatScreen**: Main conversation view with reverse ListView (performance optimization)
- **ChatBubble**: Renders individual messages with appropriate styling
- **RichMessageText**: Combines formatting parsing with search highlighting
- **CallTile**: Special rendering for call events and missed calls
- **DateSeparator**: Visual date breaks between conversation days
- **ImportBottomSheet**: Multi-step import dialog with platform selection

### Performance Optimizations
- **Isolate Offloading**: `compute(_isolateParse, content)` for parsing large chats
- **Reverse ListView**: Renders only visible items from bottom; natural chat pagination
- **Item Caching**: Local `_items` list prevents rebuild overhead
- **Lazy GlobalKeys**: Creates GlobalKey only for matched search items

## Dependencies

```yaml
# UI
flutter:
  sdk: flutter

# State Management
provider: ^6.4.0

# File I/O
file_picker: ^8.0.0
path_provider: ^2.1.0

# Storage
shared_preferences: ^2.3.0

# Utilities
intl: ^0.19.0
uuid: ^4.0.0
```

## Roadmap

- ✅ WhatsApp .txt exports (current)
- 🔄 Instagram chat exports (coming soon)
- 🔄 Telegram JSON exports (coming soon)
- 🔄 Facebook message exports (coming soon)

## Known Limitations

- Media files are not displayed (only markers like `<Media omitted>`)
- Chat history is read-only (cannot modify or delete messages from the app)
- UI search is limited to message text content (not metadata like timestamps)
- Currently only supports text-based chat exports (phone would support any platform where export is available)
