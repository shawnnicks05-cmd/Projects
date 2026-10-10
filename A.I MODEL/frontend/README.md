# ai_model_frontend

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Run locally

Create `frontend/.env` with the API address:

```text
API_BASE_URL=http://127.0.0.1:4000
```

Start the backend from `backend` in one terminal:

```powershell
npm install
npm start
```

Then start Flutter from `frontend` in another terminal:

```powershell
flutter pub get
flutter run
```

For an Android emulator, use `API_BASE_URL=http://10.0.2.2:4000`. Keep the
DeepSeek key in `backend/.env`; never put that key in the Flutter `.env`.

## Edit workspace files

Open a folder in the Workspace view and select a file. From the General AI
panel, enter the requested change and choose `Edit selected file`. The result
is loaded into the editor for review; choose `Save` to write it to disk.
