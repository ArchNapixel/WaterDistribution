import 'package:flutter/material.dart';

import 'clients_screen.dart';
import 'dashboard_screen.dart';
import 'map_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final _mapKey = GlobalKey<MapScreenState>();

  late final List<Widget> _pages = [
    DashboardScreen(onAddClient: _goToAddClient),
    const ClientsScreen(),
    MapScreen(key: _mapKey),
  ];

  void _goToAddClient() {
    setState(() => _index = 2);
    _mapKey.currentState?.openClientList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.people_outline), label: 'Clients'),
          NavigationDestination(icon: Icon(Icons.map_outlined), label: 'Map'),
        ],
      ),
    );
  }
}
