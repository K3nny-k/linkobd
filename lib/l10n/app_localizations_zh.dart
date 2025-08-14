// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'BlinkOBD';

  @override
  String get connect => '连接';

  @override
  String get disconnect => '断开连接';

  @override
  String get connected => '已连接';

  @override
  String get notConnected => '未连接';

  @override
  String get connecting => '正在连接...';

  @override
  String get disconnecting => '断开连接中...';

  @override
  String get scan => '扫描';

  @override
  String get clear => '清除';

  @override
  String get send => '发送';

  @override
  String get cancel => '取消';

  @override
  String get ok => '确定';

  @override
  String get retry => '重试';

  @override
  String get fetch => '获取';

  @override
  String get copy => '复制';

  @override
  String get sent => 'Sent';

  @override
  String get copied => '已复制';

  @override
  String get failedToFetch => '获取失败';

  @override
  String get failedToSend => '发送失败';

  @override
  String get receivedData => '接收的数据';

  @override
  String get inputData => '输入数据';

  @override
  String get pasteHexTextHere => '在此粘贴十六进制文本';

  @override
  String get deviceResponseWillAppearHere => '设备响应将显示在此处...';

  @override
  String get invalidHex => '无效的十六进制数据';

  @override
  String get sendFailed => '发送失败';

  @override
  String sentBytes(Object count) {
    return '已发送 $count 字节';
  }

  @override
  String get settings => '设置';

  @override
  String get diagnosis => '诊断';

  @override
  String get sfd => 'SFD存储';

  @override
  String get maintenanceReset => '维护重置';

  @override
  String get resetClearDtc => '重置/清除故障码';

  @override
  String get udsDiag => 'UDS诊断';

  @override
  String get language => '语言';

  @override
  String get theme => '主题';

  @override
  String get about => '关于';

  @override
  String get version => '版本';

  @override
  String get english => 'English';

  @override
  String get chinese => '中文';

  @override
  String get light => '浅色';

  @override
  String get dark => '深色';

  @override
  String get system => '跟随系统';

  @override
  String get obdDongleInfo => 'OBD适配器信息';

  @override
  String get serialNumber => '序列号';

  @override
  String get firmwareVersion => '固件版本';

  @override
  String get deviceNotConnected => '设备未连接';

  @override
  String get pleaseConnectFirst => '请先连接设备';

  @override
  String get operationSuccessful => '操作成功';

  @override
  String get operationFailed => '操作失败';

  @override
  String get diagnosisResults => '诊断结果';

  @override
  String get noDiagnosisData => '暂无诊断数据';

  @override
  String get startDiagnosis => '开始诊断';

  @override
  String get diagnosisInProgress => '正在诊断...';

  @override
  String get diagnosisCompleted => '诊断完成';

  @override
  String get clearingDtc => '正在清除故障码...';

  @override
  String get dtcCleared => '故障码已清除';

  @override
  String get ecuReset => 'ECU重置';

  @override
  String get clearAllDtc => '清除所有故障码';

  @override
  String get resetEcu => '重置ECU';

  @override
  String get configurationSent => '配置已发送';

  @override
  String get waitingResponse => '等待响应...';

  @override
  String get sourceAddress => '源地址';

  @override
  String get targetAddress => '目标地址';

  @override
  String get dataBytes => '数据字节';

  @override
  String get responseData => '响应数据';

  @override
  String get sendingFrame => '正在发送帧';

  @override
  String get framesSent => '帧已发送';

  @override
  String get transportMode => '运输模式';

  @override
  String get diagnosticFirewall => '诊断防火墙';

  @override
  String get activated => '已激活';

  @override
  String get notActivated => '未激活';

  @override
  String get open => '已开启';

  @override
  String get closed => '已关闭';

  @override
  String get unknown => '未知';

  @override
  String get statusUnknown => '状态未知';

  @override
  String get noActionNeeded => '无需操作';

  @override
  String get checkAndRetry => '检查并重试';

  @override
  String get vin => '车辆识别号';

  @override
  String get vehicleInfo => '车辆信息';

  @override
  String get calibrationId => '标定ID';

  @override
  String get systemName => '系统名称';

  @override
  String get developmentData => '开发数据';

  @override
  String get dtcStatus => '故障码状态';

  @override
  String get auditSystemName => '奥迪系统名称';

  @override
  String get seatSystemName => '西雅特系统名称';

  @override
  String get systemSupplier => '系统供应商';

  @override
  String get connectToDevice => '连接设备';

  @override
  String get disconnectDevice => '断开设备';

  @override
  String get scanningDevices => '正在扫描设备...';

  @override
  String get noDevicesFound => '未找到设备';

  @override
  String get connectionFailed => '连接失败';

  @override
  String get connectionSuccess => '连接成功';

  @override
  String get performingReset => '正在执行重置...';

  @override
  String get resetComplete => '重置完成';

  @override
  String get clearingCodes => '正在清除代码...';

  @override
  String get codesCleared => '代码已清除';

  @override
  String get selectEcu => '选择ECU';

  @override
  String get ecuSelection => 'ECU选择';

  @override
  String get optionalSelection => '可选择项';

  @override
  String get tapToConnect => '点击连接';

  @override
  String get connectedTo => '已连接至';

  @override
  String get comingSoon => '即将推出';

  @override
  String get pleaseConnectToDeviceFirst => '请先连接到OBD设备';

  @override
  String get readingOBDDongleInfo => '正在读取OBD适配器信息';

  @override
  String get queryingHardwareInfo => '正在查询硬件信息...';

  @override
  String get hardwareInfoRetrieved => '硬件信息获取成功';

  @override
  String get aboutBlinkOBD => '关于BlinkOBD';

  @override
  String get advancedOBDTool => '高级OBD诊断工具';

  @override
  String get forVWAudiPorsche => '适用于大众/奥迪/保时捷车辆';

  @override
  String get copyright => '版权所有 © BlinkOBD Solutions';

  @override
  String get professionalDiagnosticTool =>
      '专业的汽车诊断工具，支持蓝牙连接，具备SFD激活、维护重置和全面诊断功能。';

  @override
  String get clearAllDTC => '清除所有故障码';

  @override
  String get resetECUToDefaults => '将电子控制单元重置为出厂默认设置';

  @override
  String get clearAllDiagnosticCodes => '清除所有诊断故障代码';

  @override
  String get performingECUReset => '正在执行ECU重置...';

  @override
  String get ecuResetCompleted => 'ECU重置完成';

  @override
  String get clearingAllDTCs => '正在清除所有故障码...';

  @override
  String get allDTCsCleared => '所有故障码已清除';

  @override
  String get warning => '警告';

  @override
  String get operationWarning => '这些操作将修改ECU设置。请谨慎使用，确保您了解操作的后果。';

  @override
  String get importantNotice => '重要提示';

  @override
  String get openEngineHood => '请在执行维护重置操作前打开发动机舱盖。';

  @override
  String get disableFirewall => '禁用诊断防火墙以允许访问';

  @override
  String get firewallClosed => '防火墙已关闭';

  @override
  String get firewallOpen => '防火墙开启';

  @override
  String get instrumentClusterReset => '仪表盘重置';

  @override
  String get resetKombi17 => '重置Kombi 17维护指示器';

  @override
  String get audioHeadUnitReset => '音响主机重置';

  @override
  String get resetHeadunit5F => '重置Headunit 5F维护设置';

  @override
  String get transportModeQuery => '运输模式查询';

  @override
  String get queryTransportMode => '查询车辆运输模式状态';

  @override
  String get transportModeClose => '运输模式关闭';

  @override
  String get closeTransportMode => '关闭车辆运输模式';

  @override
  String get transportModeNotActivated => '运输模式未激活';

  @override
  String get transportModeActivated => '运输模式已激活';

  @override
  String get failedCheckSFD => '失败，请检查SFD并重试';

  @override
  String get sfdStatus => 'SFD状态';

  @override
  String get selectECUOptional => '选择ECU（可选）';

  @override
  String get diagnosisCanRun => '诊断可以在不选择ECU的情况下运行';

  @override
  String get noDiagnosisResults => '暂无诊断结果...';

  @override
  String get diagnose => '诊断';

  @override
  String get starting => '开始中';

  @override
  String get startingDiagnosis => '开始诊断...';

  @override
  String get diagnosisFailed => '诊断失败';

  @override
  String get messagesCleared => '消息已清除';

  @override
  String get pleaseConnectDeviceFirst => '请先连接设备';

  @override
  String get pleaseSelectDeviceFirst => '请先选择设备。';

  @override
  String get sessionStatus => '会话状态';

  @override
  String get vinExtended => 'VIN扩展';

  @override
  String get activeDiagnosticInfo => '活动诊断信息';

  @override
  String get vwSystemName => '大众系统名称';

  @override
  String get unknownCategory => '未知类别';

  @override
  String get refresh => '刷新';

  @override
  String get scanningForDevices => '正在扫描设备...';

  @override
  String get execute => '执行';

  @override
  String get query => '查询';

  @override
  String get close => '关闭';

  @override
  String get disableTransportMode => '禁用车辆运输模式限制';

  @override
  String get closingTransportMode => '正在关闭运输模式...';

  @override
  String get transportModeClosed => '运输模式已关闭';

  @override
  String get queryingTransportMode => '正在查询运输模式状态...';

  @override
  String get transportModeStatusUnknown => '运输模式状态未知';

  @override
  String get clearResponse => '清除响应';

  @override
  String get enterSourceAddress => '输入源地址';

  @override
  String get enterTargetAddress => '输入目标地址';

  @override
  String get enterHexDataBytes => '输入十六进制数据字节（例如：22 F1 90）';

  @override
  String get responseDataHex => '响应数据（十六进制）';

  @override
  String get responseDataWillAppearHere => '响应数据将在此显示...';

  @override
  String get sending => '正在发送...';

  @override
  String get notConnectedToOBDDevice => '未连接到OBD设备';

  @override
  String get pleaseFillInAllFields => '请填写所有字段';

  @override
  String get invalidAddressFormat => '地址格式无效';

  @override
  String get configResponseTimeout => '配置响应超时';

  @override
  String get invalidDataBytesFormat => '数据字节格式无效';

  @override
  String get scanAgain => '重新扫描';
}
