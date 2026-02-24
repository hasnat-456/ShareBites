class NotificationConfig {

  static const String ONESIGNAL_APP_ID = 'f6247933-589a-4de0-9892-8748a32ebc27';

  static const String ONESIGNAL_REST_API_KEY = 'wjeqbrtqkemymfbaahjh5el53';

  static const String SUPABASE_URL = 'https://hzhfovvmbncwkffdnpli.supabase.co';

  static const String SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh6aGZvdnZtYm5jd2tmZmRucGxpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEwNDIxNjYsImV4cCI6MjA4NjYxODE2Nn0.R-SmMrqonLENC858haq8Gen-WGfci4Hil0X4VjC0HiY';

  static const String SUPABASE_SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh6aGZvdnZtYm5jd2tmZmRucGxpIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MTA0MjE2NiwiZXhwIjoyMDg2NjE4MTY2fQ.-qjRNOh_1mvGjKx1GM8SWCQM09P-fhrqP8WYfR-CDGc';

  static const bool NOTIFICATIONS_ENABLED = true;

  static const bool DEBUG_MODE = true;

  static const String DEFAULT_SOUND = 'default';

  static const String NOTIFICATION_CHANNEL_ID = 'sharebites_notifications';

  static bool isConfigured() {
    return ONESIGNAL_APP_ID != 'YOUR_ONESIGNAL_APP_ID' &&
        SUPABASE_URL != 'YOUR_SUPABASE_PROJECT_URL' &&
        SUPABASE_ANON_KEY != 'YOUR_SUPABASE_ANON_KEY';
  }

  static String getConfigurationStatus() {
    final List<String> missing = [];

    if (ONESIGNAL_APP_ID == 'YOUR_ONESIGNAL_APP_ID') {
      missing.add('OneSignal App ID');
    }
    if (ONESIGNAL_REST_API_KEY == 'YOUR_ONESIGNAL_REST_API_KEY') {
      missing.add('OneSignal REST API Key');
    }
    if (SUPABASE_URL == 'YOUR_SUPABASE_PROJECT_URL') {
      missing.add('Supabase URL');
    }
    if (SUPABASE_ANON_KEY == 'YOUR_SUPABASE_ANON_KEY') {
      missing.add('Supabase Anon Key');
    }

    if (missing.isEmpty) {
      return '[SUCCESS] All configuration values are set';
    } else {
      return '[ERROR] Missing configuration: ${missing.join(', ')}';
    }
  }
}