# RouteSafe - Smart School Bus Tracking System

RouteSafe is a comprehensive smart school bus tracking system built with Flutter, Python Flask, and MySQL.

---

## 🛠️ Technology Stack
- **Mobile App**: Flutter / Dart
- **Backend API**: Python / Flask
- **Database**: MySQL 8.0
- **Containerization**: Docker & Docker Compose

---

## 🐳 Docker Deployment & Commands

### 1. Build Containers
```bash
docker compose build
```

### 2. Start Services (Backend + Database)
```bash
docker compose up -d
```

### 3. View Logs
```bash
docker compose logs -f
```

### 4. Stop Services
```bash
docker compose down
```

### 5. Check Health & Backend API
Visit the health endpoint in your browser or curl:
```bash
curl http://localhost:5000/
```

**Response**:
```json
{
  "message": "RouteSafe backend is running",
  "success": true
}
```

---

## 📱 Connecting the Flutter App to Dockerized Backend

When developing locally with the Flutter app:

1. **Android Emulator**:
   - Use API Base URL: `http://10.0.2.2:5000`

2. **Physical Android Device (connected via USB/Wi-Fi)**:
   - Use your host machine's local IP address, e.g. `http://192.168.x.x:5000` or `http://127.0.0.1:5000` via ADB port forwarding:
     ```bash
     adb reverse tcp:5000 tcp:5000
     ```

3. **Desktop / Web**:
   - Use API Base URL: `http://localhost:5000` or `http://127.0.0.1:5000`

---

## 🧪 Integration Testing
Run the full integration test suite on your connected device:
```bash
flutter test integration_test/app_test.dart
flutter test integration_test/validation_test.dart
flutter test integration_test/parent_dashboard_test.dart
flutter test integration_test/driver_dashboard_test.dart
flutter test integration_test/admin_dashboard_test.dart
```