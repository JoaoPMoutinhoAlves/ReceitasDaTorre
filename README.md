# Recipe Manager

A multi-platform recipe manager with AI-powered import from Instagram, TikTok, and any recipe URL.

## Architecture

- **Backend**: FastAPI + PostgreSQL, runs on your Raspberry Pi via Docker
- **App**: Flutter (Android + Web)
- **AI parsing**: Claude API — converts shared captions/text into structured recipes

---

## 1. Deploy the backend to Raspberry Pi

### Prerequisites
- Docker and Docker Compose installed on the Pi
- A Claude API key from [console.anthropic.com](https://console.anthropic.com)

### Steps

```bash
# 1. Copy the project to your Pi (or clone from git)
scp -r . pi@<PI_IP>:~/recipe-manager

# 2. Create your .env file
cd ~/recipe-manager
cp .env.example .env
nano .env   # Set your CLAUDE_API_KEY

# 3. Start the services
docker compose up -d

# 4. Verify
curl http://localhost:8000/health
# → {"status":"ok"}
```

The API will be available at `http://<PI_IP>:8000`.

> **Tip**: Make sure port 8000 is accessible on your local network.
> On Home Assistant OS, you can use the "Terminal & SSH" add-on to run the commands above.

---

## 2. Build & install the Flutter app

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) installed
- Android Studio or VS Code with Flutter extension
- Android device or emulator

```bash
cd recipe_app
flutter pub get
flutter run          # for development
flutter build apk    # for a release APK to sideload
```

### Configure the server URL
On first launch, tap the ⚙️ icon (top-right) and enter your Pi's IP:

```
http://192.168.1.XXX:8000
```

Tap **Test Connection** to verify, then **Save**.

---

## 3. Importing recipes from Instagram / TikTok

1. Open a recipe post in Instagram or TikTok
2. Tap **Share → Recipe App** (the app appears in the Android share sheet)
3. The app opens and Claude automatically extracts the recipe from the caption
4. Review and edit the extracted recipe, then tap **Save**

You can also manually add a recipe by tapping **+ Add Recipe** and pasting a URL or text.

---

## Recipe Format

All recipes are stored with this consistent structure:

| Field | Type | Description |
|---|---|---|
| `name` | string | Recipe title |
| `description` | string? | Short description |
| `category` | string? | e.g. Breakfast, Dinner, Dessert |
| `tags` | string[] | Free-form tags |
| `ingredients` | Ingredient[] | `{amount, unit, item, note}` |
| `steps` | string[] | Ordered steps |
| `prep_time_minutes` | int? | Prep time |
| `cook_time_minutes` | int? | Cook time |
| `total_time_minutes` | int? | Total time |
| `servings` | int? | Number of servings |
| `source_url` | string? | Original post/page URL |
| `source_platform` | string? | `instagram`, `tiktok`, `web`, or `manual` |
| `image_url` | string? | Cover image |

---

## API Reference (backend)

| Method | Path | Description |
|---|---|---|
| GET | `/health` | Health check |
| POST | `/api/parse` | Parse text/URL into recipe |
| GET | `/api/recipes` | List recipes (supports `?search=` and `?category=`) |
| GET | `/api/recipes/categories` | List all categories |
| GET | `/api/recipes/{id}` | Get a recipe |
| POST | `/api/recipes` | Create a recipe |
| PUT | `/api/recipes/{id}` | Update a recipe |
| DELETE | `/api/recipes/{id}` | Delete a recipe |

Interactive docs available at `http://<PI_IP>:8000/docs`.
