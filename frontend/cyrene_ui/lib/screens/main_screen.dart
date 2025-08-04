import 'package:cyrene_ui/screens/profile/profile_screen.dart';
import 'package:cyrene_ui/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../config/app_config.dart';
import 'agents/agent_list_screen.dart';
import 'agents/create_agent_screen.dart';
import 'chat/chat_screen.dart';
import 'dashboard/dashboard_screen.dart';
import '../widgets/common/custom_drawer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings/settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  String? _selectedAgentId;
  String? _selectedAgentName;
  late TabController _tabController;

  final List<NavigationItem> _navigationItems = [
    NavigationItem(
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      label: 'Dashboard',
    ),
    NavigationItem(
      icon: Icons.smart_toy_outlined,
      selectedIcon: Icons.smart_toy,
      label: 'Agents',
    ),
    NavigationItem(
      icon: Icons.add_circle_outline,
      selectedIcon: Icons.add_circle,
      label: 'Create',
    ),
    NavigationItem(
      icon: Icons.chat_bubble_outline,
      selectedIcon: Icons.chat_bubble,
      label: 'Chat',
    ),
  ];
  Future<void> _initializeDefaultAgent() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final apiService = ApiService(authService.token!);
    final agents = await apiService.getAgents();

    if (agents.isEmpty) {
      // No agents at all — nothing to select
      return;
    }

    // Pick “Cyrene” if it exists, otherwise just the first one
    final defaultAgent = agents.firstWhere(
      (a) => a.name.toLowerCase() == 'cyrene',
      orElse: () => agents.first,
    );

    setState(() {
      _selectedAgentId = defaultAgent.id;
      _selectedAgentName = defaultAgent.name;
    });
  }

  void _loadLastTabIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIndex = prefs.getInt('last_tab_index') ?? 0;
    setState(() {
      _selectedIndex = savedIndex;
      _tabController.index = savedIndex;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadLastTabIndex();
    _loadLastTabIndex();

    _tabController = TabController(
      length: _navigationItems.length,
      vsync: this,
    );
    _initializeDefaultAgent();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onAgentSelected(String agentId, String agentName) {
    setState(() {
      _selectedAgentId = agentId;
      _selectedAgentName = agentName;
      _selectedIndex = 3; // Switch to chat tab
      _tabController.animateTo(3);
    });
  }

  void _onNavigationTapped(int index) async {
    if (index == 3 && _selectedAgentId == null) {
      _showSelectAgentDialog();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('last_tab_index', index);

    setState(() {
      _selectedIndex = index;
      _tabController.animateTo(index);
    });
  }

  void _showSelectAgentDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('No Agent Selected'),
        content: const Text(
          'Please select an agent from the Agents tab first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Navigation Rail for larger screens
          if (MediaQuery.of(context).size.width > 800) _buildNavigationRail(),

          // Main content
          Expanded(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      const DashboardScreen(),
                      AgentListScreen(onAgentSelected: _onAgentSelected),
                      const CreateAgentScreen(),
                      ChatScreen(
                        agentId: _selectedAgentId,
                        agentName: _selectedAgentName,
                        showAllHistory: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      // Bottom Navigation for smaller screens
      bottomNavigationBar: MediaQuery.of(context).size.width <= 800
          ? _buildBottomNavigationBar()
          : null,

      // Drawer for mobile
      drawer: MediaQuery.of(context).size.width <= 600
          ? CustomDrawer(
              selectedIndex: _selectedIndex,
              onItemSelected: _onNavigationTapped,
              selectedAgentName: _selectedAgentName,
            )
          : null,
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          if (MediaQuery.of(context).size.width <= 600)
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),

          Text(
            _getScreenTitle(),
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
          ),

          if (_selectedIndex == 3 && _selectedAgentName != null)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _selectedAgentName!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ),

          const Spacer(),

          // User menu
          _buildUserMenu(),
        ],
      ),
    );
  }

  Widget _buildNavigationRail() {
    return Container(
      width: 80,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: NavigationRail(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onNavigationTapped,
        labelType: NavigationRailLabelType.selected,
        destinations: _navigationItems
            .map(
              (item) => NavigationRailDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selectedIcon),
                label: Text(item.label),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: _onNavigationTapped,
      destinations: _navigationItems
          .map(
            (item) => NavigationDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.selectedIcon),
              label: item.label,
            ),
          )
          .toList(),
    );
  }

  Widget _buildUserMenu() {
    return Consumer<AuthService>(
      builder: (context, auth, child) {
        return PopupMenuButton<String>(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  auth.user?.username.substring(0, 1).toUpperCase() ?? 'U',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (MediaQuery.of(context).size.width > 600)
                Text(
                  auth.user?.displayName ?? 'User',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'profile',
              child: ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Profile'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'settings',
              child: ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Settings'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'logout',
              child: ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  'Sign Out',
                  style: TextStyle(color: Colors.red),
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
          onSelected: (value) async {
            switch (value) {
              case 'profile':
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
                break;
              case 'settings':
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
                break;
              case 'logout':
                await auth.logout();
                if (context.mounted) {
                  Navigator.of(context).pushReplacementNamed(Routes.login);
                }
                break;
            }
          },
        );
      },
    );
  }

  String _getScreenTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'AI Agents';
      case 2:
        return 'Create Agent';
      case 3:
        return 'Chat';
      default:
        return AppConfig.appName;
    }
  }
}

class NavigationItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  NavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}
