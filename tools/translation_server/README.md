# Local Translation Server

This server keeps your OpenAI API key off the mobile app. The Flutter app calls
this server, and the server calls OpenAI.

## Setup

1) Create a new OpenAI API key (do not share it inside the app).
2) Export environment variables:

```bash
export OPENAI_API_KEY="YOUR_KEY"
export OPENAI_MODEL="gpt-4.1-mini"
export PORT=8787
```

3) Start the server:

```bash
node tools/translation_server/server.mjs
```

## App connection

Run the app with a translation URL:

```bash
flutter run --dart-define=TRANSLATION_API_URL=http://YOUR_MAC_IP:8787/translate
```

For iOS devices, use your Mac's local IP address.
