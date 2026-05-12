import 'package:flutter/material.dart';
import '../../models/index.dart';
import '../../utils/app_colors.dart';

class UserManagementScreen extends StatefulWidget {
  final Language language;

  const UserManagementScreen({
    Key? key,
    required this.language,
  }) : super(key: key);

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'all';
  List<User> _users = []; // Mock data

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  void _loadUsers() {
    // Mock data - replace with actual API call
    setState(() {
      _users = List.generate(20, (index) => User(
        id: 'user_$index',
        phone: '987654321$index',
        name: 'User $index',
        role: UserRole.values[index % 3],
        region: 'Region ${index % 5}',
        enrollmentDate: '2023-${(index % 12) + 1}-${(index % 28) + 1}',
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(
          widget.language == Language.en ? 'User Management' : 'వినియోగదారు నిర్వహణ',
          style: const TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _showAddUserDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          Expanded(
            child: _buildUsersList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: widget.language == Language.en
                  ? 'Search users...'
                  : 'వినియోగదారులను వెతకండి...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedFilter,
                  decoration: InputDecoration(
                    labelText: widget.language == Language.en
                        ? 'Filter by Role'
                        : 'పాత్ర ద్వారా ఫిల్టర్ చేయండి',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text(
                        widget.language == Language.en ? 'All Users' : 'అన్ని వినియోగదారులు',
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'public',
                      child: Text(
                        widget.language == Language.en ? 'Public' : 'ప్రజా',
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'cadre',
                      child: Text(
                        widget.language == Language.en ? 'Cadre' : 'కేడర్',
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'admin',
                      child: Text(
                        widget.language == Language.en ? 'Admin' : 'అడ్మిన్',
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedFilter = value!;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList() {
    final filteredUsers = _users.where((user) {
      final matchesSearch = user.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          user.phone.contains(_searchQuery);
      final matchesFilter = _selectedFilter == 'all' || user.role.name == _selectedFilter;
      return matchesSearch && matchesFilter;
    }).toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredUsers.length,
      itemBuilder: (context, index) {
        final user = filteredUsers[index];
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getRoleColor(user.role),
              child: Text(
                user.name[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              user.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.phone),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getRoleColor(user.role).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        user.role.name.toUpperCase(),
                        style: TextStyle(
                          color: _getRoleColor(user.role),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (user.region != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        user.region!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                _handleUserAction(value, user);
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Text(
                    widget.language == Language.en ? 'Edit' : 'సవరించండి',
                  ),
                ),
                PopupMenuItem(
                  value: 'view',
                  child: Text(
                    widget.language == Language.en ? 'View Details' : 'వివరాలను చూడండి',
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    widget.language == Language.en ? 'Delete' : 'తొలగించండి',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.public:
        return AppColors.primary;
      case UserRole.cadre:
        return Colors.green;
      case UserRole.admin:
        return Colors.red;
    }
  }

  void _handleUserAction(String action, User user) {
    switch (action) {
      case 'edit':
        _showEditUserDialog(user);
        break;
      case 'view':
        _showUserDetails(user);
        break;
      case 'delete':
        _showDeleteConfirmation(user);
        break;
    }
  }

  void _showAddUserDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          widget.language == Language.en ? 'Add New User' : 'కొత్త వినియోగదారుని జోడించండి',
        ),
        content: const Text('Add user form will be implemented here'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              widget.language == Language.en ? 'Cancel' : 'రద్దు చేయండి',
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Add user logic
            },
            child: Text(
              widget.language == Language.en ? 'Add' : 'జోడించండి',
            ),
          ),
        ],
      ),
    );
  }

  void _showEditUserDialog(User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          widget.language == Language.en ? 'Edit User' : 'వినియోగదారుని సవరించండి',
        ),
        content: Text('Edit form for ${user.name}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              widget.language == Language.en ? 'Cancel' : 'రద్దు చేయండి',
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Update user logic
            },
            child: Text(
              widget.language == Language.en ? 'Save' : 'సేవ్ చేయండి',
            ),
          ),
        ],
      ),
    );
  }

  void _showUserDetails(User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Phone: ${user.phone}'),
            Text('Role: ${user.role.name}'),
            if (user.region != null) Text('Region: ${user.region}'),
            if (user.enrollmentDate != null) Text('Enrolled: ${user.enrollmentDate}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              widget.language == Language.en ? 'Close' : 'మూసివేయండి',
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          widget.language == Language.en ? 'Delete User' : 'వినియోగదారుని తొలగించండి',
        ),
        content: Text(
          widget.language == Language.en
              ? 'Are you sure you want to delete ${user.name}?'
              : 'మీరు ${user.name}ని తొలగించాలని ఖచ్చితంగా అనుకుంటున్నారా?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              widget.language == Language.en ? 'Cancel' : 'రద్దు చేయండి',
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Delete user logic
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    widget.language == Language.en
                        ? 'User deleted successfully'
                        : 'వినియోగదారు విజయవంతంగా తొలగించబడ్డారు',
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              widget.language == Language.en ? 'Delete' : 'తొలగించండి',
            ),
          ),
        ],
      ),
    );
  }
}
