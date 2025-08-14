# 语言扩展指南 / Language Extension Guide

本文档说明如何为BlinkOBD应用添加新的语言支持。

## 添加新语言的步骤

### 1. 更新语言提供者 (lib/providers/language_provider.dart)

在 `supportedLanguages` 列表中添加新语言：

```dart
static const List<Locale> supportedLanguages = [
  Locale('en'), // English
  Locale('zh'), // Chinese
  Locale('de'), // German - 新添加
  Locale('fr'), // French - 新添加
  // 在此添加更多语言...
];
```

在 `getLanguageName` 方法中添加新语言名称：

```dart
String getLanguageName(Locale locale) {
  switch (locale.languageCode) {
    case 'en':
      return 'English';
    case 'zh':
      return '中文';
    case 'de':
      return 'Deutsch';
    case 'fr':
      return 'Français';
    // 添加更多语言名称...
    default:
      return locale.languageCode.toUpperCase();
  }
}
```

### 2. 创建新的ARB翻译文件

在 `lib/l10n/` 目录下创建新的ARB文件：

- 德语: `app_de.arb`
- 法语: `app_fr.arb`
- 日语: `app_ja.arb`

文件格式示例 (app_de.arb)：

```json
{
  "@@locale": "de",
  "appTitle": "BlinkOBD",
  "connect": "Verbinden",
  "disconnect": "Trennen",
  "connected": "Verbunden",
  "notConnected": "Nicht verbunden",
  "settings": "Einstellungen",
  "diagnosis": "Diagnose",
  "language": "Sprache",
  // ... 更多翻译
}
```

### 3. 重新生成本地化文件

```bash
flutter gen-l10n
```

### 4. 测试新语言

1. 运行应用
2. 进入设置 → 语言
3. 选择新添加的语言
4. 验证所有界面文本正确显示

## 当前支持的语言

- **English** (`en`) - 英语
- **中文** (`zh`) - 中文简体

## 准备添加的语言示例

以下是一些可以轻松添加的语言及其代码：

- **Deutsch** (`de`) - 德语
- **Français** (`fr`) - 法语  
- **Español** (`es`) - 西班牙语
- **日本語** (`ja`) - 日语
- **한국어** (`ko`) - 韩语
- **Italiano** (`it`) - 意大利语
- **Português** (`pt`) - 葡萄牙语
- **Русский** (`ru`) - 俄语

## 翻译质量标准

1. **专业性**: 使用汽车诊断行业标准术语
2. **一致性**: 保持术语翻译的统一性
3. **易读性**: 简洁明了，用户友好
4. **准确性**: 确保技术术语翻译正确

## 注意事项

- 所有新语言都会自动出现在语言选择器中
- 新语言需要翻译所有现有的键值对
- 建议请母语使用者审核翻译质量
- 技术术语可能需要保持英文原文以确保准确性

---

*此指南随着应用功能的扩展会持续更新。* 