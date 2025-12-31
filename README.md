# ChiroTrack

A desktop practice management app for chiropractic clinics. Built with Flutter for Windows.

## Features

### Patient Management
- Add, edit, and delete patients
- Store patient details (name, date of birth, phone, email, address)
- Patient profile view with appointment history and billing

### Appointment Scheduling
- Calendar-based appointment booking
- Per-appointment pricing and service descriptions
- Default appointment duration (configurable)
- Add multiple patients to the same time slot

### Billing & Receipts
- Generate HTML receipts for single or multiple appointments
- Customizable clinic name, address, and pricing
- Per-appointment price override
- Receipt preview before generation
- Billing history per patient

### Metrics Dashboard
- Monthly/yearly appointment trends
- Revenue tracking with charts
- Patient statistics

### Data Management
- Auto-backup on app close (keeps last 5 backups)
- Manual backup export to any folder
- Restore from backup
- SQLite database storage

### Settings
- Clinic information (name, address)
- Default pricing and service description
- Default appointment duration
- Backup management

## Prerequisites

- Flutter SDK (^3.5.1)
- Windows 10/11

## Setup

```bash
# Install dependencies
flutter pub get

# Run in development
flutter run -d windows

# Or use make
make run
```

## Building for Release

```bash
# Build Windows release
flutter build windows --release

# Build MSIX installer
flutter pub run msix:create
```

See [RELEASING.md](RELEASING.md) for full release and update instructions.

## Project Structure

```
lib/
├── main.dart              # App entry point
├── models/                # Data models (Patient, Appointment, Receipt)
├── screens/               # UI screens
│   ├── patients.dart      # Patient list
│   ├── appointments.dart  # Calendar & scheduling
│   ├── metrics.dart       # Dashboard & charts
│   └── settings.dart      # App settings
├── widgets/               # Reusable components
│   ├── sidebar.dart
│   ├── patient_profile.dart
│   └── ...
├── utils/
│   ├── database_helper.dart  # SQLite operations
│   ├── backup_helper.dart    # Backup/restore logic
│   └── receipt_helper.dart   # Receipt generation
└── theme/
    └── app_theme.dart     # Colors, typography, spacing
```

## Data Storage

Database location: `%APPDATA%\chirotrack\chiropractic_app.db`

Backups location: `%APPDATA%\chirotrack\backups\`

Data persists across app updates.
