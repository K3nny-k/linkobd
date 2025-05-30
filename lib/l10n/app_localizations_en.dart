// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get fetch => 'Fetch';

  @override
  String get copy => 'Copy';

  @override
  String get send => 'Send';

  @override
  String get notConnected => 'Not connected';

  @override
  String get copied => 'Copied';

  @override
  String get sent => 'Sent';

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
  String get clear => 'Clear';

  @override
  String sentBytes(Object count) {
    return 'Sent $count bytes';
  }
}
