import 'package:flutter/material.dart';

import '../main.dart';
import '../models/client.dart';
import 'client_form_screen.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  late Future<List<Client>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Client>> _load() async {
    final rows = await supabase.from('clients').select().order('name');
    return (rows as List).map((row) => Client.fromMap(row)).toList();
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clients')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final addedId = await Navigator.of(context).push<String>(
            MaterialPageRoute(builder: (_) => const ClientFormScreen()),
          );
          if (addedId != null) _refresh();
        },
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<Client>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final clients = snapshot.data!;
          if (clients.isEmpty) {
            return const Center(child: Text('No clients yet. Tap + to add one.'));
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              itemCount: clients.length,
              itemBuilder: (context, index) {
                final client = clients[index];
                return ListTile(
                  title: Text(client.name),
                  subtitle: Text([
                    if (client.address != null) client.address!,
                    if (client.meterNumber != null) 'Meter ${client.meterNumber}',
                  ].join(' · ')),
                  trailing: client.hasLocation
                      ? const Icon(Icons.location_on, color: Colors.green)
                      : const Icon(Icons.location_off, color: Colors.grey),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
