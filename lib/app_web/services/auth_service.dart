class AuthService {
  // Pre-created department accounts
  static final Map<String, String> _departments = {
    'Majlis Bandaraya Pulau Pinang': 'mbpp123',
    'Jabatan Kerja Raya': 'jkr123',
    'Tenaga Nasional Berhad': 'tnb123',
  };

  // Department code mapping
  static final Map<String, String> _departmentCodes = {
    'Majlis Bandaraya Pulau Pinang': 'MBPP',
    'Jabatan Kerja Raya': 'JKR',
    'Tenaga Nasional Berhad': 'TNB',
  };

  static bool login(String department, String password) {
    return _departments[department] == password;
  }

  static List<String> get departments => _departments.keys.toList();

  static String getDepartmentCode(String departmentName) {
    return _departmentCodes[departmentName] ?? departmentName;
  }
}
