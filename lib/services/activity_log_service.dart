class ActivityLog {
  final String title;
  final String description;
  final String timestamp;
  final String category; // 'Auth', 'Data', 'System'

  ActivityLog({
    required this.title,
    required this.description,
    required this.timestamp,
    required this.category,
  });
}

class ActivityLogService {
  static final List<ActivityLog> _logs = [
    ActivityLog(
      title: 'Administrator Access',
      description: 'ADMIN001 signed into the console.',
      timestamp: 'Just now',
      category: 'Auth',
    ),
    ActivityLog(
      title: 'Fetched Sheet Metadata',
      description: 'Loaded Sheet2 matching gid=751895921.',
      timestamp: '3 mins ago',
      category: 'System',
    ),
    ActivityLog(
      title: 'Data Range Verification',
      description: 'Verified worksheet margins and credential keys.',
      timestamp: '1 hour ago',
      category: 'System',
    ),
    ActivityLog(
      title: 'User Login Succeeded',
      description: 'EMP0000002 logged in from main terminal.',
      timestamp: '3 hours ago',
      category: 'Auth',
    ),
    ActivityLog(
      title: 'Row Modified in Sheet1',
      description: 'EMP0000002 edited record: IV-2009.',
      timestamp: '4 hours ago',
      category: 'Data',
    ),
  ];

  static List<ActivityLog> getLogs() {
    return List.from(_logs);
  }

  static void addLog({
    required String title,
    required String description,
    required String category,
  }) {
    _logs.insert(
      0,
      ActivityLog(
        title: title,
        description: description,
        timestamp: 'Just now',
        category: category,
      ),
    );
  }
}
