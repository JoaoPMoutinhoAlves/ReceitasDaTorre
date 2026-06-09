# Recipe Manager

A multi-platform recipe manager with AI-powered import from Instagram, TikTok, and any recipe URL.

## Architecture

- **Backend**: FastAPI + SQLite, runs as a native Home Assistant add-on (no Docker setup needed)
- **App**: Flutter (Android + Web)
- **AI parsing**: Claude API — converts shared captions/text into structured recipes

---

## 1. Install the backend on Home Assistant OS

### Prerequisites
- A Claude API key from [console.anthropic.com](https://console.anthropic.com)
- Access to your Pi's `/config` folder (via Samba, SFTP, or the File Editor add-on)

### Steps

**1. Copy the add-on folder to your Pi**

Copy the `haos-addon/` folder from this repo into your HA config directory under `addons/local/`:

```
/config/addons/local/recipe_manager/   ← put the contents of haos-addon/ here
```

The easiest ways to do this:
- **Samba add-on**: Enable it in HA, then copy via Windows Explorer to `\\<PI_IP>\config\addons\local\recipe_manager\`
- **SFTP**: `scp -r haos-addon/ pi@<PI_IP>:/config/addons/local/recipe_manager/`
- **File Editor add-on**: Upload files one by one through the HA UI

**2. Reload add-ons in Home Assistant**

Go to **Settings → Add-ons → Add-on Store**, click the **⋮ menu** (top-right) → **Check for updates** (or **Reload**).

You should now see **Recipe Manager** under **Local add-ons**.

**3. Configure your API key**

Click **Recipe Manager → Configuration tab** and set:
- `claude_api_key`: your Anthropic API key
- `claude_model`: `claude-opus-4-6` (default, leave as-is)

**4. Start the add-on**

Go to the **Info tab** and click **Start**. Enable **Start on boot** and **Watchdog** while you're there.

Check the **Log tab** — you should see:
```
INFO: Starting Recipe Manager...
INFO: API will be available on port 8000
```

The API is now at `http://<PI_IP>:8000`. The SQLite database is stored at `/data/recipes.db` inside the add-on and persists across restarts and updates.

> **Tip**: Interactive API docs are available at `http://<PI_IP>:8000/docs`

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
