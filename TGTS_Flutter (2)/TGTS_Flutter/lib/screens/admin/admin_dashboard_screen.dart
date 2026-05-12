import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/index.dart';
import '../../utils/app_colors.dart';

class AdminDashboardScreen extends StatefulWidget {
  final Language language;

  const AdminDashboardScreen({
    Key? key,
    required this.language,
  }) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(
          widget.language == Language.en ? 'Admin Dashboard' : 'అడ్మిన్ డాష్‌బోర్డ్',
          style: const TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: () {
              // Show notifications
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle, color: Colors.white),
            onPressed: () {
              // Show profile menu
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatsCards(),
            const SizedBox(height: 24),
            _buildQuickActions(),
            const SizedBox(height: 24),
            _buildRecentActivity(),
            const SizedBox(height: 24),
            _buildChartsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    final stats = [
      {
        'title': widget.language == Language.en ? 'Total Users' : 'మొత్తం వినియోగదారులు',
        'value': '12,456',
        'icon': Icons.people,
        'color': AppColors.primary,
        'change': '+12%',
      },
      {
        'title': widget.language == Language.en ? 'Active Events' : 'క్రియాశీల కార్యక్రమాలు',
        'value': '8',
        'icon': Icons.event,
        'color': Colors.green,
        'change': '+3',
      },
      {
        'title': widget.language == Language.en ? 'Media Items' : 'మీడియా అంశాలు',
        'value': '1,234',
        'icon': Icons.photo_library,
        'color': Colors.purple,
        'change': '+45',
      },
      {
        'title': widget.language == Language.en ? 'Documents' : 'పత్రాలు',
        'value': '567',
        'icon': Icons.folder,
        'color': Colors.orange,
        'change': '+8',
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.2,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];
        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(
                      stat['icon'] as IconData,
                      color: stat['color'] as Color,
                      size: 32,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        stat['change'] as String,
                        style: TextStyle(
                          color: Colors.green[800],
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  stat['value'] as String,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  stat['title'] as String,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      {
        'title': widget.language == Language.en ? 'User Management' : 'వినియోగదారు నిర్వహణ',
        'icon': Icons.people,
        'color': AppColors.primary,
        'route': '/admin/users',
      },
      {
        'title': widget.language == Language.en ? 'Content Push' : 'కంటెంట్ పుష్',
        'icon': Icons.send,
        'color': Colors.green,
        'route': '/admin/content',
      },
      {
        'title': widget.language == Language.en ? 'Event Management' : 'కార్యక్రమ నిర్వహణ',
        'icon': Icons.event,
        'color': Colors.purple,
        'route': '/admin/events',
      },
      {
        'title': widget.language == Language.en ? 'Analytics' : 'విశ్లేషణ',
        'icon': Icons.analytics,
        'color': Colors.orange,
        'route': '/admin/analytics',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.language == Language.en ? 'Quick Actions' : 'త్వరిత చర్యలు',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.5,
          ),
          itemCount: actions.length,
          itemBuilder: (context, index) {
            final action = actions[index];
            return GestureDetector(
              onTap: () {
                // Navigate to respective screen
                // Use push instead of go to ensure navigation works consistently
                // This creates a new route entry, ensuring it works every time
                if (context.mounted) {
                  context.push(action['route'] as String);
                }
              },
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        (action['color'] as Color).withOpacity(0.1),
                        (action['color'] as Color).withOpacity(0.05),
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        action['icon'] as IconData,
                        size: 32,
                        color: action['color'] as Color,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        action['title'] as String,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.language == Language.en ? 'Recent Activity' : 'ఇటీవలి కార్యకలాపం',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 5, // Mock data
            itemBuilder: (context, index) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primaryLight.withOpacity(0.2),
                  child: Icon(
                    Icons.person,
                    color: AppColors.primary,
                  ),
                ),
                title: Text(
                  widget.language == Language.en
                      ? 'New user registered'
                      : 'కొత్త వినియోగదారు నమోదు చేయబడ్డారు',
                ),
                subtitle: Text('2 hours ago'),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[400],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildChartsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.language == Language.en ? 'Analytics Overview' : 'విశ్లేషణ అవలోకనం',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            height: 200,
            padding: const EdgeInsets.all(16),
            child: const Center(
              child: Text(
                'Charts will be implemented here',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
