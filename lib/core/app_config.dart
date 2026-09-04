/// App-wide configuration. Override at build time with --dart-define.
class AppConfig {
  AppConfig._();

  static const String appName = 'FoodShare';
  static const String tagline = 'Sharing Is Caring';

  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: 'AIzaSyBy2JgA4aaE_zjLT1oxCyWXUMQD54dHkYw',
  );

  static const String cloudinaryCloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
    defaultValue: 'dtcrhkwxv',
  );

  static const String cloudinaryUploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
    defaultValue: 'fyp_posts_preset',
  );

  static bool get hasGeminiKey =>
      geminiApiKey.isNotEmpty && !geminiApiKey.startsWith('REPLACE_');
}
