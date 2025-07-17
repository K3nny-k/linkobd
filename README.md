# LinkOBD - Flutter OBD-II Scanner App

A modern Flutter application for OBD-II vehicle diagnostics with Bluetooth Low Energy (BLE) connectivity.

## Features

### 🚗 Core Functionality
- **Bluetooth LE Connection**: Connect to OBD-II adapters via BLE
- **Real-time Diagnostics**: Live vehicle data monitoring
- **Hex Console**: Send raw commands and view responses
- **SFD (Storage File Data)**: Advanced ECU data management
- **Multi-language Support**: Currently supports English with i18n framework

### 🔧 Advanced Features
- **ECU Selection**: Searchable dropdown with 30+ ECU types
- **Data Streaming**: Real-time data reception and display
- **MTU Negotiation**: Automatic BLE MTU optimization
- **Connection Management**: Robust connection state tracking
- **Error Handling**: Comprehensive error management and user feedback

### 📱 User Interface
- **Material Design 3**: Modern, clean interface
- **Responsive Layout**: Optimized for mobile devices
- **Dark/Light Theme**: System theme support
- **Intuitive Navigation**: Easy-to-use navigation structure

## Screenshots

*Screenshots will be added here*

## Getting Started

### Prerequisites
- Flutter SDK (3.22.0 or higher)
- Android Studio / VS Code
- Android device with BLE support
- OBD-II BLE adapter

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/linkobd.git
   cd linkobd
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

### Building for Release

```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release
```

## Architecture

### Project Structure
```
lib/
├── data/
│   ├── ble/              # BLE service implementations
│   └── ecu/              # ECU data models and repository
├── domain/               # Business logic and entities
├── presentation/
│   ├── screens/          # UI screens
│   ├── widgets/          # Reusable widgets
│   └── view_models/      # State management
├── l10n/                 # Internationalization
└── main.dart            # App entry point
```

### Key Components

- **BleTransport**: Core BLE communication layer
- **BluetoothViewModel**: State management for BLE operations
- **EcuRepository**: ECU data management from CSV
- **SearchableEcuSelector**: Advanced ECU selection widget

## Dependencies

### Core Dependencies
- `flutter_blue_plus`: BLE connectivity
- `provider`: State management
- `csv`: ECU data parsing
- `permission_handler`: BLE permissions

### Development Dependencies
- `flutter_test`: Unit testing
- `flutter_lints`: Code quality

## Usage

### Connecting to OBD-II Device

1. **Enable Bluetooth** on your device
2. **Grant permissions** when prompted
3. **Tap Connect** on the home screen
4. **Select your OBD-II adapter** from the list
5. **Wait for connection** confirmation

### Using SFD (Storage File Data)

1. **Connect to device** first
2. **Navigate to SFD** screen
3. **Select ECU** from the dropdown (search by name or ID)
4. **Fetch data** from the selected ECU
5. **Send commands** using hex format

### Hex Console

1. **Connect to device**
2. **Navigate to Hex Console**
3. **Send raw commands** in hex format
4. **View responses** in real-time

## ECU Support

The app supports 30+ ECU types including:
- Engine Control Module (0001)
- ABS/ESP System (0012)
- Transmission Control (0002)
- Airbag Control Unit (0003)
- And many more...

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Testing

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage
```

## Known Issues

- Some OBD-II adapters may require specific initialization commands
- BLE connection stability depends on adapter quality
- Large data transfers may require chunking (automatically handled)

## Roadmap

- [ ] iOS support
- [ ] Additional OBD-II protocols
- [ ] Data logging and export
- [ ] Vehicle-specific diagnostics
- [ ] Cloud sync capabilities

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Flutter team for the excellent framework
- flutter_blue_plus contributors for BLE support
- OBD-II community for protocol documentation

## Support

If you encounter any issues or have questions:
1. Check the [Issues](https://github.com/yourusername/linkobd/issues) page
2. Create a new issue with detailed information
3. Include device model, Android version, and adapter type

---

**Note**: This app is for educational and diagnostic purposes. Always follow local regulations when using OBD-II diagnostic tools.
# linkobd
