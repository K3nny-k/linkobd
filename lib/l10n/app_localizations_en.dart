// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'BlinkOBD';

  @override
  String get connect => 'Connect';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get connected => 'Connected';

  @override
  String get notConnected => 'Not connected';

  @override
  String get connecting => 'Connecting...';

  @override
  String get disconnecting => 'Disconnecting...';

  @override
  String get scan => 'Scan';

  @override
  String get clear => 'Clear';

  @override
  String get send => 'Send';

  @override
  String get cancel => 'Cancel';

  @override
  String get ok => 'OK';

  @override
  String get retry => 'Retry';

  @override
  String get fetch => 'Fetch';

  @override
  String get copy => 'Copy';

  @override
  String get sent => 'Sent';

  @override
  String get copied => 'Copied';

  @override
  String get failedToFetch => 'Failed to fetch';

  @override
  String get failedToSend => 'Failed to send';

  @override
  String get receivedData => 'Received Data';

  @override
  String get inputData => 'Input Data';

  @override
  String get pasteHexTextHere => 'Paste hex / text here';

  @override
  String get deviceResponseWillAppearHere =>
      'Device response will appear here...';

  @override
  String get invalidHex => 'Invalid hex';

  @override
  String get sendFailed => 'Send failed';

  @override
  String sentBytes(Object count) {
    return 'Sent $count bytes';
  }

  @override
  String get settings => 'Settings';

  @override
  String get diagnosis => 'Diagnosis';

  @override
  String get sfd => 'SFD';

  @override
  String get maintenanceReset => 'Maintenance Reset';

  @override
  String get resetClearDtc => 'Reset/Clear DTC';

  @override
  String get udsDiag => 'UDS DIAG';

  @override
  String get language => 'Language';

  @override
  String get theme => 'Theme';

  @override
  String get about => 'About';

  @override
  String get version => 'Version';

  @override
  String get english => 'English';

  @override
  String get chinese => '中文';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get system => 'System';

  @override
  String get obdDongleInfo => 'OBD Dongle Information';

  @override
  String get serialNumber => 'Serial Number';

  @override
  String get firmwareVersion => 'Firmware Version';

  @override
  String get deviceNotConnected => 'Device not connected';

  @override
  String get pleaseConnectFirst => 'Please connect device first';

  @override
  String get operationSuccessful => 'Operation successful';

  @override
  String get operationFailed => 'Operation failed';

  @override
  String get diagnosisResults => 'Diagnosis Results';

  @override
  String get noDiagnosisData => 'No diagnosis data available';

  @override
  String get startDiagnosis => 'Start Diagnosis';

  @override
  String get diagnosisInProgress => 'Diagnosis in progress...';

  @override
  String get diagnosisCompleted => 'Diagnosis completed successfully';

  @override
  String get clearingDtc => 'Clearing DTCs...';

  @override
  String get dtcCleared => 'DTCs cleared';

  @override
  String get ecuReset => 'ECU Reset';

  @override
  String get clearAllDtc => 'Clear All DTC';

  @override
  String get resetEcu => 'Reset ECU';

  @override
  String get configurationSent => 'Configuration sent';

  @override
  String get waitingResponse => 'Waiting for response...';

  @override
  String get sourceAddress => 'Source Address';

  @override
  String get targetAddress => 'Target Address';

  @override
  String get dataBytes => 'Data Bytes';

  @override
  String get responseData => 'Response Data';

  @override
  String get sendingFrame => 'Sending frame';

  @override
  String get framesSent => 'Frames sent';

  @override
  String get transportMode => 'Transport Mode';

  @override
  String get diagnosticFirewall => 'Diagnostic Firewall';

  @override
  String get activated => 'Activated';

  @override
  String get notActivated => 'Not Activated';

  @override
  String get open => 'Open';

  @override
  String get closed => 'Closed';

  @override
  String get unknown => 'Unknown';

  @override
  String get statusUnknown => 'Status Unknown';

  @override
  String get noActionNeeded => 'No Action Needed';

  @override
  String get checkAndRetry => 'Check and Retry';

  @override
  String get vin => 'VIN';

  @override
  String get vehicleInfo => 'Vehicle Info';

  @override
  String get calibrationId => 'Calibration ID';

  @override
  String get systemName => 'System Name';

  @override
  String get developmentData => 'Development Data';

  @override
  String get dtcStatus => 'DTC Status';

  @override
  String get auditSystemName => 'Audi System Name';

  @override
  String get seatSystemName => 'Seat System Name';

  @override
  String get systemSupplier => 'System Supplier';

  @override
  String get connectToDevice => 'Connect to Device';

  @override
  String get disconnectDevice => 'Disconnect Device';

  @override
  String get scanningDevices => 'Scanning devices...';

  @override
  String get noDevicesFound => 'No devices found';

  @override
  String get connectionFailed => 'Connection failed';

  @override
  String get connectionSuccess => 'Connection successful';

  @override
  String get performingReset => 'Performing reset...';

  @override
  String get resetComplete => 'Reset complete';

  @override
  String get clearingCodes => 'Clearing codes...';

  @override
  String get codesCleared => 'Codes cleared';

  @override
  String get selectEcu => 'Select ECU';

  @override
  String get ecuSelection => 'ECU Selection';

  @override
  String get optionalSelection => 'Optional selection';

  @override
  String get tapToConnect => 'Tap to connect';

  @override
  String get connectedTo => 'Connected to';

  @override
  String get comingSoon => 'coming soon';

  @override
  String get pleaseConnectToDeviceFirst => 'Please connect to OBD device first';

  @override
  String get readingOBDDongleInfo => 'Reading OBD Dongle Info';

  @override
  String get queryingHardwareInfo => 'Querying hardware information...';

  @override
  String get hardwareInfoRetrieved =>
      'Hardware information retrieved successfully';

  @override
  String get aboutBlinkOBD => 'About BlinkOBD';

  @override
  String get advancedOBDTool => 'Advanced OBD Diagnostic Tool';

  @override
  String get forVWAudiPorsche => 'For VW/Audi/Porsche Vehicles';

  @override
  String get copyright => 'Copyright © BlinkOBD Solutions';

  @override
  String get professionalDiagnosticTool =>
      'Professional automotive diagnostic tool with Bluetooth connectivity, featuring SFD activation, maintenance reset, and comprehensive diagnosis capabilities.';

  @override
  String get clearAllDTC => 'Clear All DTC';

  @override
  String get resetECUToDefaults =>
      'Reset Electronic Control Unit to factory defaults';

  @override
  String get clearAllDiagnosticCodes =>
      'Clear all Diagnostic Trouble Codes from memory';

  @override
  String get performingECUReset => 'Performing ECU reset...';

  @override
  String get ecuResetCompleted => 'ECU reset completed successfully';

  @override
  String get clearingAllDTCs => 'Clearing all DTCs...';

  @override
  String get allDTCsCleared => 'All DTCs cleared successfully';

  @override
  String get warning => 'Warning';

  @override
  String get operationWarning =>
      'These operations will modify ECU settings. Use with caution and ensure you understand the implications.';

  @override
  String get importantNotice => 'Important Notice';

  @override
  String get openEngineHood =>
      'Please open the engine hood before performing maintenance reset operations.';

  @override
  String get disableFirewall =>
      'Disable the diagnostic firewall to allow access';

  @override
  String get firewallClosed => 'Firewall Closed';

  @override
  String get firewallOpen => 'Firewall Open';

  @override
  String get instrumentClusterReset => 'Instrument Cluster Reset';

  @override
  String get resetKombi17 => 'Reset Kombi 17 maintenance indicators';

  @override
  String get audioHeadUnitReset => 'Audio Head Unit Reset';

  @override
  String get resetHeadunit5F => 'Reset Headunit 5F maintenance settings';

  @override
  String get transportModeQuery => 'Transport Mode Query';

  @override
  String get queryTransportMode => 'Query vehicle transport mode status';

  @override
  String get transportModeClose => 'Transport Mode Close';

  @override
  String get closeTransportMode => 'Close vehicle transport mode';

  @override
  String get transportModeNotActivated => 'Transport mode: Not activated';

  @override
  String get transportModeActivated => 'Transport mode: Activated';

  @override
  String get failedCheckSFD => 'Failed, Check SFD and Retry';

  @override
  String get sfdStatus => 'SFD Status';

  @override
  String get selectECUOptional => 'Select ECU (Optional)';

  @override
  String get diagnosisCanRun => 'Diagnosis can run without ECU selection';

  @override
  String get noDiagnosisResults => 'No diagnosis results yet...';

  @override
  String get diagnose => 'Diagnose';

  @override
  String get starting => 'Starting';

  @override
  String get startingDiagnosis => 'Starting diagnosis...';

  @override
  String get diagnosisFailed => 'Diagnosis failed';

  @override
  String get messagesCleared => 'Messages cleared';

  @override
  String get pleaseConnectDeviceFirst => 'Please connect to a device first';

  @override
  String get pleaseSelectDeviceFirst => 'Please select a device first.';

  @override
  String get sessionStatus => 'Session Status';

  @override
  String get vinExtended => 'VIN Extended';

  @override
  String get activeDiagnosticInfo => 'Active Diagnostic Info';

  @override
  String get vwSystemName => 'VW System Name';

  @override
  String get unknownCategory => 'Unknown';

  @override
  String get refresh => 'Refresh';

  @override
  String get scanningForDevices => 'Scanning for devices...';

  @override
  String get execute => 'Execute';

  @override
  String get query => 'Query';

  @override
  String get close => 'Close';

  @override
  String get disableTransportMode =>
      'Disable vehicle transport mode restrictions';

  @override
  String get closingTransportMode => 'Closing transport mode...';

  @override
  String get transportModeClosed => 'Transport mode closed successfully';

  @override
  String get queryingTransportMode => 'Querying transport mode status...';

  @override
  String get transportModeStatusUnknown => 'Transport mode status: Unknown';

  @override
  String get clearResponse => 'Clear response';

  @override
  String get enterSourceAddress => 'Enter source address';

  @override
  String get enterTargetAddress => 'Enter target address';

  @override
  String get enterHexDataBytes => 'Enter hex data bytes (e.g., 22 F1 90)';

  @override
  String get responseDataHex => 'Response Data(HEX)';

  @override
  String get responseDataWillAppearHere => 'Response data will appear here...';

  @override
  String get sending => 'Sending...';

  @override
  String get notConnectedToOBDDevice => 'Not connected to OBD device';

  @override
  String get pleaseFillInAllFields => 'Please fill in all fields';

  @override
  String get invalidAddressFormat => 'Invalid address format';

  @override
  String get configResponseTimeout => 'Config response timeout';

  @override
  String get invalidDataBytesFormat => 'Invalid data bytes format';

  @override
  String get scanAgain => 'Scan Again';
}
