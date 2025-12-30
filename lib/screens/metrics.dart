import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/appointment.dart';
import '../models/patient.dart';
import '../utils/database_helper.dart';
import '../theme/app_theme.dart';
import 'patient_profile.dart';

enum TimePeriod { thisMonth, thisQuarter, thisYear }

class MetricsScreen extends StatefulWidget {
  const MetricsScreen({super.key});

  @override
  State<MetricsScreen> createState() => _MetricsScreenState();
}

class _MetricsScreenState extends State<MetricsScreen> {
  TimePeriod _selectedPeriod = TimePeriod.thisMonth;
  List<Appointment> _appointments = [];
  bool _loading = true;
  int _totalPatients = 0;
  int _activePatientsCount = 0;
  int _newPatientsCount = 0;
  int _activeSeriesCount = 0;
  double _unitPrice = 40.0;

  // Birthday and unpaid visits data
  List<(Patient, int)> _pastWeekBirthdays = [];
  List<(Patient, int)> _upcomingBirthdays = [];
  List<Map<String, dynamic>> _oldestUnpaid = [];

  // Pagination for birthday and unpaid lists
  static const int _pageSize = 5;
  int _pastBirthdayPage = 0;
  int _upcomingBirthdayPage = 0;
  int _unpaidPage = 0;

  List<(Patient, int)> get _paginatedPastBirthdays {
    final start = _pastBirthdayPage * _pageSize;
    final end = (start + _pageSize).clamp(0, _pastWeekBirthdays.length);
    if (start >= _pastWeekBirthdays.length) return [];
    return _pastWeekBirthdays.sublist(start, end);
  }

  int get _totalPastBirthdayPages => (_pastWeekBirthdays.length / _pageSize).ceil().clamp(1, 999);

  List<(Patient, int)> get _paginatedUpcomingBirthdays {
    final start = _upcomingBirthdayPage * _pageSize;
    final end = (start + _pageSize).clamp(0, _upcomingBirthdays.length);
    if (start >= _upcomingBirthdays.length) return [];
    return _upcomingBirthdays.sublist(start, end);
  }

  int get _totalUpcomingBirthdayPages => (_upcomingBirthdays.length / _pageSize).ceil().clamp(1, 999);

  List<Map<String, dynamic>> get _paginatedUnpaid {
    final start = _unpaidPage * _pageSize;
    final end = (start + _pageSize).clamp(0, _oldestUnpaid.length);
    if (start >= _oldestUnpaid.length) return [];
    return _oldestUnpaid.sublist(start, end);
  }

  int get _totalUnpaidPages => (_oldestUnpaid.length / _pageSize).ceil().clamp(1, 999);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Get date range for selected period
  (DateTime, DateTime) _getDateRange() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case TimePeriod.thisMonth:
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 1);
        return (start, end);
      case TimePeriod.thisQuarter:
        final quarterStart = ((now.month - 1) ~/ 3) * 3 + 1;
        final start = DateTime(now.year, quarterStart, 1);
        final end = DateTime(now.year, quarterStart + 3, 1);
        return (start, end);
      case TimePeriod.thisYear:
        final start = DateTime(now.year, 1, 1);
        final end = DateTime(now.year + 1, 1, 1);
        return (start, end);
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final db = DatabaseHelper();
    final (start, end) = _getDateRange();

    final settings = await db.getAllSettings();
    _unitPrice = double.tryParse(settings[SettingsKeys.unitPrice] ?? '') ?? 40.0;

    final appointments = await db.getAppointmentsInRange(start, end);
    final totalPatients = await db.getTotalPatientCount();
    final activePatients = await db.getActivePatientsInRange(start, end);
    final newPatients = await db.getNewPatientsInRange(start, end);
    final activeSeries = await db.getActiveSeriesCount();
    final pastWeekBirthdays = await db.getPatientsWithBirthdayInPastWeek();
    final upcomingBirthdays = await db.getPatientsWithBirthdayInNextWeek();
    final oldestUnpaid = await db.getOldestUnpaidAppointments(limit: 100);

    setState(() {
      _appointments = appointments;
      _totalPatients = totalPatients;
      _activePatientsCount = activePatients;
      _newPatientsCount = newPatients;
      _activeSeriesCount = activeSeries;
      _pastWeekBirthdays = pastWeekBirthdays;
      _upcomingBirthdays = upcomingBirthdays;
      _oldestUnpaid = oldestUnpaid;
      _loading = false;
    });
  }

  /// Calculate metrics from appointments
  int get _totalAppointments => _appointments.length;

  int get _paidCount => _appointments.where((a) => a.paid).length;

  List<Appointment> get _pastAppointments {
    final now = DateTime.now();
    return _appointments.where((a) => a.dateTime.isBefore(now)).toList();
  }

  int get _unpaidPastCount =>
      _pastAppointments.where((a) => !a.paid).length;

  double get _revenue => _paidCount * _unitPrice;

  double get _outstanding => _unpaidPastCount * _unitPrice;

  double get _paidRate {
    final past = _pastAppointments.length;
    if (past == 0) return 100.0;
    return (_pastAppointments.where((a) => a.paid).length / past) * 100;
  }

  /// Get busiest day of week
  String get _busiestDay {
    if (_appointments.isEmpty) return 'N/A';
    final dayCount = <int, int>{};
    for (final a in _appointments) {
      final day = a.dateTime.weekday;
      dayCount[day] = (dayCount[day] ?? 0) + 1;
    }
    final maxDay = dayCount.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    const days = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[maxDay];
  }

  /// Get peak hour
  String get _peakHour {
    if (_appointments.isEmpty) return 'N/A';
    final hourCount = <int, int>{};
    for (final a in _appointments) {
      final hour = a.dateTime.hour;
      hourCount[hour] = (hourCount[hour] ?? 0) + 1;
    }
    final maxHour = hourCount.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    final time = TimeOfDay(hour: maxHour, minute: 0);
    return '${time.hourOfPeriod}:00 ${time.period == DayPeriod.am ? 'AM' : 'PM'}';
  }

  /// Get monthly trend data for last 6 months
  Future<List<(String, int)>> _getMonthlyTrend() async {
    final db = DatabaseHelper();
    final now = DateTime.now();
    final results = <(String, int)>[];

    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final nextMonth = DateTime(month.year, month.month + 1, 1);
      final appointments = await db.getAppointmentsInRange(month, nextMonth);
      final monthName = DateFormat.MMM().format(month);
      results.add((monthName, appointments.length));
    }

    return results;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with period selector
            _buildHeader(),
            const SizedBox(height: AppSpacing.xl),

            // Summary tiles
            _buildSummarySection(),
            const SizedBox(height: AppSpacing.lg),

            // Detail cards row
            _buildDetailCardsRow(),
            const SizedBox(height: AppSpacing.lg),

            // Birthdays and Unpaid row
            _buildBirthdayAndUnpaidRow(),
            const SizedBox(height: AppSpacing.lg),

            // Monthly trend chart
            _buildTrendCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.md,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              'Business Metrics',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            SegmentedButton<TimePeriod>(
              segments: const [
                ButtonSegment(
                  value: TimePeriod.thisMonth,
                  label: Text('Month'),
                ),
                ButtonSegment(
                  value: TimePeriod.thisQuarter,
                  label: Text('Quarter'),
                ),
                ButtonSegment(
                  value: TimePeriod.thisYear,
                  label: Text('Year'),
                ),
              ],
              selected: {_selectedPeriod},
              onSelectionChanged: (Set<TimePeriod> selected) {
                setState(() {
                  _selectedPeriod = selected.first;
                });
                _loadData();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection() {
    if (_loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Wrap(
          spacing: AppSpacing.xl,
          runSpacing: AppSpacing.lg,
          alignment: WrapAlignment.spaceEvenly,
          children: [
            _buildSummaryTile(
              icon: Icons.event,
              value: _totalAppointments.toString(),
              label: 'Appointments',
            ),
            _buildSummaryTile(
              icon: Icons.attach_money,
              value: '\$${_revenue.toStringAsFixed(0)}',
              label: 'Revenue',
              valueColor: AppColors.successGreen,
            ),
            _buildSummaryTile(
              icon: Icons.percent,
              value: '${_paidRate.toStringAsFixed(0)}%',
              label: 'Paid Rate',
              valueColor: _paidRate >= 80 ? AppColors.successGreen : AppColors.warningAmber,
            ),
            _buildSummaryTile(
              icon: Icons.pending_actions,
              value: '\$${_outstanding.toStringAsFixed(0)}',
              label: 'Outstanding',
              valueColor: _outstanding > 0 ? AppColors.warningAmber : null,
            ),
            _buildSummaryTile(
              icon: Icons.people,
              value: _activePatientsCount.toString(),
              label: 'Patients Seen',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryTile({
    required IconData icon,
    required String value,
    required String label,
    Color? valueColor,
  }) {
    return SizedBox(
      width: 120,
      child: Column(
        children: [
          Icon(icon, size: 24, color: AppColors.textSecondary),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCardsRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildPeriodDetailsCard()),
        const SizedBox(width: AppSpacing.lg),
        Expanded(child: _buildSchedulingInsightsCard()),
      ],
    );
  }

  Widget _buildPeriodDetailsCard() {
    final periodLabel = switch (_selectedPeriod) {
      TimePeriod.thisMonth => 'This Month',
      TimePeriod.thisQuarter => 'This Quarter',
      TimePeriod.thisYear => 'This Year',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              periodLabel,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else ...[
              _buildDetailRow(Icons.event, '$_totalAppointments appointments'),
              _buildDetailRow(Icons.attach_money, '\$${_revenue.toStringAsFixed(2)} revenue'),
              _buildDetailRow(Icons.people, '$_activePatientsCount patients seen'),
              _buildDetailRow(Icons.person_add, '$_newPatientsCount new patients'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSchedulingInsightsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Scheduling Insights',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else ...[
              _buildDetailRow(Icons.calendar_today, 'Busiest Day: $_busiestDay'),
              _buildDetailRow(Icons.access_time, 'Peak Hour: $_peakHour'),
              _buildDetailRow(Icons.repeat, '$_activeSeriesCount active series'),
              _buildDetailRow(Icons.groups, '$_totalPatients total patients'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.md),
          Text(
            text,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildBirthdayAndUnpaidRow() {
    return Column(
      children: [
        // Birthday panels row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildPastBirthdaysCard()),
            const SizedBox(width: AppSpacing.lg),
            Expanded(child: _buildUpcomingBirthdaysCard()),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        // Unpaid visits (full width)
        _buildUnpaidCard(),
      ],
    );
  }

  Widget _buildPastBirthdaysCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with pagination
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.cake, size: 20, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Recent Birthdays (${_pastWeekBirthdays.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (_totalPastBirthdayPages > 1)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, size: 20),
                        onPressed: _pastBirthdayPage > 0
                            ? () => setState(() => _pastBirthdayPage--)
                            : null,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                      Text(
                        '${_pastBirthdayPage + 1} / $_totalPastBirthdayPages',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, size: 20),
                        onPressed: _pastBirthdayPage < _totalPastBirthdayPages - 1
                            ? () => setState(() => _pastBirthdayPage++)
                            : null,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Past 7 days including today',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_pastWeekBirthdays.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Center(
                  child: Text(
                    'No recent birthdays',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              )
            else
              ..._paginatedPastBirthdays.map((entry) => _buildBirthdayItem(entry.$1, entry.$2, isPast: true)),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingBirthdaysCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with pagination
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.cake_outlined, size: 20, color: AppColors.infoBlue),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Upcoming Birthdays (${_upcomingBirthdays.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (_totalUpcomingBirthdayPages > 1)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, size: 20),
                        onPressed: _upcomingBirthdayPage > 0
                            ? () => setState(() => _upcomingBirthdayPage--)
                            : null,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                      Text(
                        '${_upcomingBirthdayPage + 1} / $_totalUpcomingBirthdayPages',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, size: 20),
                        onPressed: _upcomingBirthdayPage < _totalUpcomingBirthdayPages - 1
                            ? () => setState(() => _upcomingBirthdayPage++)
                            : null,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Next 7 days',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_upcomingBirthdays.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Center(
                  child: Text(
                    'No upcoming birthdays',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              )
            else
              ..._paginatedUpcomingBirthdays.map((entry) => _buildBirthdayItem(entry.$1, entry.$2, isPast: false)),
          ],
        ),
      ),
    );
  }

  Widget _buildBirthdayItem(Patient patient, int daysDiff, {required bool isPast}) {
    final age = _calculateAge(patient.dob, daysDiff: daysDiff, isPast: isPast);

    String subtitle;
    if (isPast) {
      if (daysDiff == 0) {
        subtitle = age != null ? 'Today! Turning $age' : 'Today!';
      } else if (daysDiff == 1) {
        subtitle = age != null ? 'Yesterday • Turned $age' : 'Yesterday';
      } else {
        subtitle = age != null ? '$daysDiff days ago • Turned $age' : '$daysDiff days ago';
      }
    } else {
      if (daysDiff == 1) {
        subtitle = age != null ? 'Tomorrow • Turning $age' : 'Tomorrow';
      } else {
        subtitle = age != null ? 'In $daysDiff days • Turning $age' : 'In $daysDiff days';
      }
    }

    return InkWell(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PatientProfileScreen(patient: patient),
          ),
        );
        _loadData();
      },
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: (isPast ? Theme.of(context).colorScheme.primary : AppColors.infoBlue).withValues(alpha: 0.1),
              child: Text(
                patient.firstName.isNotEmpty ? patient.firstName[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isPast ? Theme.of(context).colorScheme.primary : AppColors.infoBlue,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${patient.firstName} ${patient.lastName}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  int? _calculateAge(String? dob, {required int daysDiff, required bool isPast}) {
    if (dob == null || dob.isEmpty) return null;
    try {
      final birthDate = DateTime.parse(dob);
      final now = DateTime.now();
      // Calculate age on the birthday date
      final birthdayDate = isPast
          ? now.subtract(Duration(days: daysDiff))
          : now.add(Duration(days: daysDiff));
      int age = birthdayDate.year - birthDate.year;
      return age;
    } catch (_) {
      return null;
    }
  }

  Widget _buildUnpaidCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with pagination
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.pending_actions, size: 20, color: AppColors.warningAmber),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Oldest Unpaid Visits (${_oldestUnpaid.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (_totalUnpaidPages > 1)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, size: 20),
                        onPressed: _unpaidPage > 0
                            ? () => setState(() => _unpaidPage--)
                            : null,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                      Text(
                        '${_unpaidPage + 1} / $_totalUnpaidPages',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, size: 20),
                        onPressed: _unpaidPage < _totalUnpaidPages - 1
                            ? () => setState(() => _unpaidPage++)
                            : null,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_oldestUnpaid.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Center(
                  child: Text(
                    'No unpaid visits',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              )
            else
              // Table header
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                      horizontal: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text('Patient', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text('Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                        ),
                        Expanded(
                          child: Text('Days Ago', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                        ),
                        SizedBox(width: 32), // Space for chevron
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  ..._paginatedUnpaid.map((row) => _buildUnpaidRow(row)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnpaidRow(Map<String, dynamic> row) {
    final patientName = '${row['first_name']} ${row['last_name']}';
    final dateTime = DateTime.parse(row['datetime'] as String);
    final dateStr = DateFormat.yMMMd().format(dateTime);
    final daysAgo = DateTime.now().difference(dateTime).inDays;

    return InkWell(
      onTap: () async {
        // Navigate to patient profile
        final patient = Patient(
          id: row['patient_id'] as int,
          firstName: row['first_name'] as String,
          lastName: row['last_name'] as String,
          phone: row['phone'] as String?,
        );
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PatientProfileScreen(patient: patient),
          ),
        );
        _loadData();
      },
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm,
          horizontal: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                patientName,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                dateStr,
                style: const TextStyle(fontSize: 13),
              ),
            ),
            Expanded(
              child: Text(
                '$daysAgo',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: daysAgo > 30 ? AppColors.errorRed : AppColors.warningAmber,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Monthly Trend (Last 6 Months)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 200,
              child: FutureBuilder<List<(String, int)>>(
                future: _getMonthlyTrend(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final data = snapshot.data!;
                  final maxY = data.map((e) => e.$2).reduce((a, b) => a > b ? a : b).toDouble();

                  return BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxY > 0 ? maxY * 1.2 : 10,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => AppColors.textPrimary,
                          tooltipPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            return BarTooltipItem(
                              '${data[group.x.toInt()].$1}: ${rod.toY.toInt()}',
                              const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index >= 0 && index < data.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                                  child: Text(
                                    data[index].$1,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                );
                              }
                              return const Text('');
                            },
                            reservedSize: 30,
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                value.toInt().toString(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              );
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: maxY > 0 ? (maxY / 4).ceilToDouble() : 2,
                        getDrawingHorizontalLine: (value) => const FlLine(
                          color: AppColors.borderLight,
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: data.asMap().entries.map((entry) {
                        return BarChartGroupData(
                          x: entry.key,
                          barRods: [
                            BarChartRodData(
                              toY: entry.value.$2.toDouble(),
                              color: Theme.of(context).colorScheme.primary,
                              width: 24,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(AppRadius.sm),
                                topRight: Radius.circular(AppRadius.sm),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
