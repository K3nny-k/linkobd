import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'BlinkOBD'**
  String get appTitle;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @notConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get notConnected;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get connecting;

  /// No description provided for @disconnecting.
  ///
  /// In en, this message translates to:
  /// **'Disconnecting...'**
  String get disconnecting;

  /// No description provided for @scan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get scan;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @fetch.
  ///
  /// In en, this message translates to:
  /// **'Fetch'**
  String get fetch;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @sent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get sent;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @failedToFetch.
  ///
  /// In en, this message translates to:
  /// **'Failed to fetch'**
  String get failedToFetch;

  /// No description provided for @failedToSend.
  ///
  /// In en, this message translates to:
  /// **'Failed to send'**
  String get failedToSend;

  /// No description provided for @receivedData.
  ///
  /// In en, this message translates to:
  /// **'Received Data'**
  String get receivedData;

  /// No description provided for @inputData.
  ///
  /// In en, this message translates to:
  /// **'Input Data'**
  String get inputData;

  /// No description provided for @pasteHexTextHere.
  ///
  /// In en, this message translates to:
  /// **'Paste hex / text here'**
  String get pasteHexTextHere;

  /// No description provided for @deviceResponseWillAppearHere.
  ///
  /// In en, this message translates to:
  /// **'Device response will appear here...'**
  String get deviceResponseWillAppearHere;

  /// No description provided for @invalidHex.
  ///
  /// In en, this message translates to:
  /// **'Invalid hex'**
  String get invalidHex;

  /// No description provided for @sendFailed.
  ///
  /// In en, this message translates to:
  /// **'Send failed'**
  String get sendFailed;

  /// No description provided for @sentBytes.
  ///
  /// In en, this message translates to:
  /// **'Sent {count} bytes'**
  String sentBytes(Object count);

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @diagnosis.
  ///
  /// In en, this message translates to:
  /// **'Diagnosis'**
  String get diagnosis;

  /// No description provided for @sfd.
  ///
  /// In en, this message translates to:
  /// **'SFD'**
  String get sfd;

  /// No description provided for @maintenanceReset.
  ///
  /// In en, this message translates to:
  /// **'Maintenance Reset'**
  String get maintenanceReset;

  /// No description provided for @resetClearDtc.
  ///
  /// In en, this message translates to:
  /// **'Reset/Clear DTC'**
  String get resetClearDtc;

  /// No description provided for @udsDiag.
  ///
  /// In en, this message translates to:
  /// **'UDS DIAG'**
  String get udsDiag;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @chinese.
  ///
  /// In en, this message translates to:
  /// **'中文'**
  String get chinese;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @obdDongleInfo.
  ///
  /// In en, this message translates to:
  /// **'OBD Dongle Information'**
  String get obdDongleInfo;

  /// No description provided for @serialNumber.
  ///
  /// In en, this message translates to:
  /// **'Serial Number'**
  String get serialNumber;

  /// No description provided for @firmwareVersion.
  ///
  /// In en, this message translates to:
  /// **'Firmware Version'**
  String get firmwareVersion;

  /// No description provided for @deviceNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Device not connected'**
  String get deviceNotConnected;

  /// No description provided for @pleaseConnectFirst.
  ///
  /// In en, this message translates to:
  /// **'Please connect device first'**
  String get pleaseConnectFirst;

  /// No description provided for @operationSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Operation successful'**
  String get operationSuccessful;

  /// No description provided for @operationFailed.
  ///
  /// In en, this message translates to:
  /// **'Operation failed'**
  String get operationFailed;

  /// No description provided for @diagnosisResults.
  ///
  /// In en, this message translates to:
  /// **'Diagnosis Results'**
  String get diagnosisResults;

  /// No description provided for @noDiagnosisData.
  ///
  /// In en, this message translates to:
  /// **'No diagnosis data available'**
  String get noDiagnosisData;

  /// No description provided for @startDiagnosis.
  ///
  /// In en, this message translates to:
  /// **'Start Diagnosis'**
  String get startDiagnosis;

  /// No description provided for @diagnosisInProgress.
  ///
  /// In en, this message translates to:
  /// **'Diagnosis in progress...'**
  String get diagnosisInProgress;

  /// No description provided for @diagnosisCompleted.
  ///
  /// In en, this message translates to:
  /// **'Diagnosis completed successfully'**
  String get diagnosisCompleted;

  /// No description provided for @clearingDtc.
  ///
  /// In en, this message translates to:
  /// **'Clearing DTCs...'**
  String get clearingDtc;

  /// No description provided for @dtcCleared.
  ///
  /// In en, this message translates to:
  /// **'DTCs cleared'**
  String get dtcCleared;

  /// No description provided for @ecuReset.
  ///
  /// In en, this message translates to:
  /// **'ECU Reset'**
  String get ecuReset;

  /// No description provided for @clearAllDtc.
  ///
  /// In en, this message translates to:
  /// **'Clear All DTC'**
  String get clearAllDtc;

  /// No description provided for @resetEcu.
  ///
  /// In en, this message translates to:
  /// **'Reset ECU'**
  String get resetEcu;

  /// No description provided for @configurationSent.
  ///
  /// In en, this message translates to:
  /// **'Configuration sent'**
  String get configurationSent;

  /// No description provided for @waitingResponse.
  ///
  /// In en, this message translates to:
  /// **'Waiting for response...'**
  String get waitingResponse;

  /// No description provided for @sourceAddress.
  ///
  /// In en, this message translates to:
  /// **'Source Address'**
  String get sourceAddress;

  /// No description provided for @targetAddress.
  ///
  /// In en, this message translates to:
  /// **'Target Address'**
  String get targetAddress;

  /// No description provided for @dataBytes.
  ///
  /// In en, this message translates to:
  /// **'Data Bytes'**
  String get dataBytes;

  /// No description provided for @responseData.
  ///
  /// In en, this message translates to:
  /// **'Response Data'**
  String get responseData;

  /// No description provided for @sendingFrame.
  ///
  /// In en, this message translates to:
  /// **'Sending frame'**
  String get sendingFrame;

  /// No description provided for @framesSent.
  ///
  /// In en, this message translates to:
  /// **'Frames sent'**
  String get framesSent;

  /// No description provided for @transportMode.
  ///
  /// In en, this message translates to:
  /// **'Transport Mode'**
  String get transportMode;

  /// No description provided for @diagnosticFirewall.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic Firewall'**
  String get diagnosticFirewall;

  /// No description provided for @activated.
  ///
  /// In en, this message translates to:
  /// **'Activated'**
  String get activated;

  /// No description provided for @notActivated.
  ///
  /// In en, this message translates to:
  /// **'Not Activated'**
  String get notActivated;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @closed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get closed;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @statusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Status Unknown'**
  String get statusUnknown;

  /// No description provided for @noActionNeeded.
  ///
  /// In en, this message translates to:
  /// **'No Action Needed'**
  String get noActionNeeded;

  /// No description provided for @checkAndRetry.
  ///
  /// In en, this message translates to:
  /// **'Check and Retry'**
  String get checkAndRetry;

  /// No description provided for @vin.
  ///
  /// In en, this message translates to:
  /// **'VIN'**
  String get vin;

  /// No description provided for @vehicleInfo.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Info'**
  String get vehicleInfo;

  /// No description provided for @calibrationId.
  ///
  /// In en, this message translates to:
  /// **'Calibration ID'**
  String get calibrationId;

  /// No description provided for @systemName.
  ///
  /// In en, this message translates to:
  /// **'System Name'**
  String get systemName;

  /// No description provided for @developmentData.
  ///
  /// In en, this message translates to:
  /// **'Development Data'**
  String get developmentData;

  /// No description provided for @dtcStatus.
  ///
  /// In en, this message translates to:
  /// **'DTC Status'**
  String get dtcStatus;

  /// No description provided for @auditSystemName.
  ///
  /// In en, this message translates to:
  /// **'Audi System Name'**
  String get auditSystemName;

  /// No description provided for @seatSystemName.
  ///
  /// In en, this message translates to:
  /// **'Seat System Name'**
  String get seatSystemName;

  /// No description provided for @systemSupplier.
  ///
  /// In en, this message translates to:
  /// **'System Supplier'**
  String get systemSupplier;

  /// No description provided for @connectToDevice.
  ///
  /// In en, this message translates to:
  /// **'Connect to Device'**
  String get connectToDevice;

  /// No description provided for @disconnectDevice.
  ///
  /// In en, this message translates to:
  /// **'Disconnect Device'**
  String get disconnectDevice;

  /// No description provided for @scanningDevices.
  ///
  /// In en, this message translates to:
  /// **'Scanning devices...'**
  String get scanningDevices;

  /// No description provided for @noDevicesFound.
  ///
  /// In en, this message translates to:
  /// **'No devices found'**
  String get noDevicesFound;

  /// No description provided for @connectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get connectionFailed;

  /// No description provided for @connectionSuccess.
  ///
  /// In en, this message translates to:
  /// **'Connection successful'**
  String get connectionSuccess;

  /// No description provided for @performingReset.
  ///
  /// In en, this message translates to:
  /// **'Performing reset...'**
  String get performingReset;

  /// No description provided for @resetComplete.
  ///
  /// In en, this message translates to:
  /// **'Reset complete'**
  String get resetComplete;

  /// No description provided for @clearingCodes.
  ///
  /// In en, this message translates to:
  /// **'Clearing codes...'**
  String get clearingCodes;

  /// No description provided for @codesCleared.
  ///
  /// In en, this message translates to:
  /// **'Codes cleared'**
  String get codesCleared;

  /// No description provided for @selectEcu.
  ///
  /// In en, this message translates to:
  /// **'Select ECU'**
  String get selectEcu;

  /// No description provided for @ecuSelection.
  ///
  /// In en, this message translates to:
  /// **'ECU Selection'**
  String get ecuSelection;

  /// No description provided for @optionalSelection.
  ///
  /// In en, this message translates to:
  /// **'Optional selection'**
  String get optionalSelection;

  /// No description provided for @tapToConnect.
  ///
  /// In en, this message translates to:
  /// **'Tap to connect'**
  String get tapToConnect;

  /// No description provided for @connectedTo.
  ///
  /// In en, this message translates to:
  /// **'Connected to'**
  String get connectedTo;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'coming soon'**
  String get comingSoon;

  /// No description provided for @pleaseConnectToDeviceFirst.
  ///
  /// In en, this message translates to:
  /// **'Please connect to OBD device first'**
  String get pleaseConnectToDeviceFirst;

  /// No description provided for @readingOBDDongleInfo.
  ///
  /// In en, this message translates to:
  /// **'Reading OBD Dongle Info'**
  String get readingOBDDongleInfo;

  /// No description provided for @queryingHardwareInfo.
  ///
  /// In en, this message translates to:
  /// **'Querying hardware information...'**
  String get queryingHardwareInfo;

  /// No description provided for @hardwareInfoRetrieved.
  ///
  /// In en, this message translates to:
  /// **'Hardware information retrieved successfully'**
  String get hardwareInfoRetrieved;

  /// No description provided for @aboutBlinkOBD.
  ///
  /// In en, this message translates to:
  /// **'About BlinkOBD'**
  String get aboutBlinkOBD;

  /// No description provided for @advancedOBDTool.
  ///
  /// In en, this message translates to:
  /// **'Advanced OBD Diagnostic Tool'**
  String get advancedOBDTool;

  /// No description provided for @forVWAudiPorsche.
  ///
  /// In en, this message translates to:
  /// **'For VW/Audi/Porsche Vehicles'**
  String get forVWAudiPorsche;

  /// No description provided for @copyright.
  ///
  /// In en, this message translates to:
  /// **'Copyright © BlinkOBD Solutions'**
  String get copyright;

  /// No description provided for @professionalDiagnosticTool.
  ///
  /// In en, this message translates to:
  /// **'Professional automotive diagnostic tool with Bluetooth connectivity, featuring SFD activation, maintenance reset, and comprehensive diagnosis capabilities.'**
  String get professionalDiagnosticTool;

  /// No description provided for @clearAllDTC.
  ///
  /// In en, this message translates to:
  /// **'Clear All DTC'**
  String get clearAllDTC;

  /// No description provided for @resetECUToDefaults.
  ///
  /// In en, this message translates to:
  /// **'Reset Electronic Control Unit to factory defaults'**
  String get resetECUToDefaults;

  /// No description provided for @clearAllDiagnosticCodes.
  ///
  /// In en, this message translates to:
  /// **'Clear all Diagnostic Trouble Codes from memory'**
  String get clearAllDiagnosticCodes;

  /// No description provided for @performingECUReset.
  ///
  /// In en, this message translates to:
  /// **'Performing ECU reset...'**
  String get performingECUReset;

  /// No description provided for @ecuResetCompleted.
  ///
  /// In en, this message translates to:
  /// **'ECU reset completed successfully'**
  String get ecuResetCompleted;

  /// No description provided for @clearingAllDTCs.
  ///
  /// In en, this message translates to:
  /// **'Clearing all DTCs...'**
  String get clearingAllDTCs;

  /// No description provided for @allDTCsCleared.
  ///
  /// In en, this message translates to:
  /// **'All DTCs cleared successfully'**
  String get allDTCsCleared;

  /// No description provided for @warning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get warning;

  /// No description provided for @operationWarning.
  ///
  /// In en, this message translates to:
  /// **'These operations will modify ECU settings. Use with caution and ensure you understand the implications.'**
  String get operationWarning;

  /// No description provided for @importantNotice.
  ///
  /// In en, this message translates to:
  /// **'Important Notice'**
  String get importantNotice;

  /// No description provided for @openEngineHood.
  ///
  /// In en, this message translates to:
  /// **'Please open the engine hood before performing maintenance reset operations.'**
  String get openEngineHood;

  /// No description provided for @disableFirewall.
  ///
  /// In en, this message translates to:
  /// **'Disable the diagnostic firewall to allow access'**
  String get disableFirewall;

  /// No description provided for @firewallClosed.
  ///
  /// In en, this message translates to:
  /// **'Firewall Closed'**
  String get firewallClosed;

  /// No description provided for @firewallOpen.
  ///
  /// In en, this message translates to:
  /// **'Firewall Open'**
  String get firewallOpen;

  /// No description provided for @instrumentClusterReset.
  ///
  /// In en, this message translates to:
  /// **'Instrument Cluster Reset'**
  String get instrumentClusterReset;

  /// No description provided for @resetKombi17.
  ///
  /// In en, this message translates to:
  /// **'Reset Kombi 17 maintenance indicators'**
  String get resetKombi17;

  /// No description provided for @audioHeadUnitReset.
  ///
  /// In en, this message translates to:
  /// **'Audio Head Unit Reset'**
  String get audioHeadUnitReset;

  /// No description provided for @resetHeadunit5F.
  ///
  /// In en, this message translates to:
  /// **'Reset Headunit 5F maintenance settings'**
  String get resetHeadunit5F;

  /// No description provided for @transportModeQuery.
  ///
  /// In en, this message translates to:
  /// **'Transport Mode Query'**
  String get transportModeQuery;

  /// No description provided for @queryTransportMode.
  ///
  /// In en, this message translates to:
  /// **'Query vehicle transport mode status'**
  String get queryTransportMode;

  /// No description provided for @transportModeClose.
  ///
  /// In en, this message translates to:
  /// **'Transport Mode Close'**
  String get transportModeClose;

  /// No description provided for @closeTransportMode.
  ///
  /// In en, this message translates to:
  /// **'Close vehicle transport mode'**
  String get closeTransportMode;

  /// No description provided for @transportModeNotActivated.
  ///
  /// In en, this message translates to:
  /// **'Transport mode: Not activated'**
  String get transportModeNotActivated;

  /// No description provided for @transportModeActivated.
  ///
  /// In en, this message translates to:
  /// **'Transport mode: Activated'**
  String get transportModeActivated;

  /// No description provided for @failedCheckSFD.
  ///
  /// In en, this message translates to:
  /// **'Failed, Check SFD and Retry'**
  String get failedCheckSFD;

  /// No description provided for @sfdStatus.
  ///
  /// In en, this message translates to:
  /// **'SFD Status'**
  String get sfdStatus;

  /// No description provided for @selectECUOptional.
  ///
  /// In en, this message translates to:
  /// **'Select ECU (Optional)'**
  String get selectECUOptional;

  /// No description provided for @diagnosisCanRun.
  ///
  /// In en, this message translates to:
  /// **'Diagnosis can run without ECU selection'**
  String get diagnosisCanRun;

  /// No description provided for @noDiagnosisResults.
  ///
  /// In en, this message translates to:
  /// **'No diagnosis results yet...'**
  String get noDiagnosisResults;

  /// No description provided for @diagnose.
  ///
  /// In en, this message translates to:
  /// **'Diagnose'**
  String get diagnose;

  /// No description provided for @starting.
  ///
  /// In en, this message translates to:
  /// **'Starting'**
  String get starting;

  /// No description provided for @startingDiagnosis.
  ///
  /// In en, this message translates to:
  /// **'Starting diagnosis...'**
  String get startingDiagnosis;

  /// No description provided for @diagnosisFailed.
  ///
  /// In en, this message translates to:
  /// **'Diagnosis failed'**
  String get diagnosisFailed;

  /// No description provided for @messagesCleared.
  ///
  /// In en, this message translates to:
  /// **'Messages cleared'**
  String get messagesCleared;

  /// No description provided for @pleaseConnectDeviceFirst.
  ///
  /// In en, this message translates to:
  /// **'Please connect to a device first'**
  String get pleaseConnectDeviceFirst;

  /// No description provided for @pleaseSelectDeviceFirst.
  ///
  /// In en, this message translates to:
  /// **'Please select a device first.'**
  String get pleaseSelectDeviceFirst;

  /// No description provided for @sessionStatus.
  ///
  /// In en, this message translates to:
  /// **'Session Status'**
  String get sessionStatus;

  /// No description provided for @vinExtended.
  ///
  /// In en, this message translates to:
  /// **'VIN Extended'**
  String get vinExtended;

  /// No description provided for @activeDiagnosticInfo.
  ///
  /// In en, this message translates to:
  /// **'Active Diagnostic Info'**
  String get activeDiagnosticInfo;

  /// No description provided for @vwSystemName.
  ///
  /// In en, this message translates to:
  /// **'VW System Name'**
  String get vwSystemName;

  /// No description provided for @unknownCategory.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknownCategory;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @scanningForDevices.
  ///
  /// In en, this message translates to:
  /// **'Scanning for devices...'**
  String get scanningForDevices;

  /// No description provided for @execute.
  ///
  /// In en, this message translates to:
  /// **'Execute'**
  String get execute;

  /// No description provided for @query.
  ///
  /// In en, this message translates to:
  /// **'Query'**
  String get query;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @disableTransportMode.
  ///
  /// In en, this message translates to:
  /// **'Disable vehicle transport mode restrictions'**
  String get disableTransportMode;

  /// No description provided for @closingTransportMode.
  ///
  /// In en, this message translates to:
  /// **'Closing transport mode...'**
  String get closingTransportMode;

  /// No description provided for @transportModeClosed.
  ///
  /// In en, this message translates to:
  /// **'Transport mode closed successfully'**
  String get transportModeClosed;

  /// No description provided for @queryingTransportMode.
  ///
  /// In en, this message translates to:
  /// **'Querying transport mode status...'**
  String get queryingTransportMode;

  /// No description provided for @transportModeStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Transport mode status: Unknown'**
  String get transportModeStatusUnknown;

  /// No description provided for @clearResponse.
  ///
  /// In en, this message translates to:
  /// **'Clear response'**
  String get clearResponse;

  /// No description provided for @enterSourceAddress.
  ///
  /// In en, this message translates to:
  /// **'Enter source address'**
  String get enterSourceAddress;

  /// No description provided for @enterTargetAddress.
  ///
  /// In en, this message translates to:
  /// **'Enter target address'**
  String get enterTargetAddress;

  /// No description provided for @enterHexDataBytes.
  ///
  /// In en, this message translates to:
  /// **'Enter hex data bytes (e.g., 22 F1 90)'**
  String get enterHexDataBytes;

  /// No description provided for @responseDataHex.
  ///
  /// In en, this message translates to:
  /// **'Response Data(HEX)'**
  String get responseDataHex;

  /// No description provided for @responseDataWillAppearHere.
  ///
  /// In en, this message translates to:
  /// **'Response data will appear here...'**
  String get responseDataWillAppearHere;

  /// No description provided for @sending.
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get sending;

  /// No description provided for @notConnectedToOBDDevice.
  ///
  /// In en, this message translates to:
  /// **'Not connected to OBD device'**
  String get notConnectedToOBDDevice;

  /// No description provided for @pleaseFillInAllFields.
  ///
  /// In en, this message translates to:
  /// **'Please fill in all fields'**
  String get pleaseFillInAllFields;

  /// No description provided for @invalidAddressFormat.
  ///
  /// In en, this message translates to:
  /// **'Invalid address format'**
  String get invalidAddressFormat;

  /// No description provided for @configResponseTimeout.
  ///
  /// In en, this message translates to:
  /// **'Config response timeout'**
  String get configResponseTimeout;

  /// No description provided for @invalidDataBytesFormat.
  ///
  /// In en, this message translates to:
  /// **'Invalid data bytes format'**
  String get invalidDataBytesFormat;

  /// No description provided for @scanAgain.
  ///
  /// In en, this message translates to:
  /// **'Scan Again'**
  String get scanAgain;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
