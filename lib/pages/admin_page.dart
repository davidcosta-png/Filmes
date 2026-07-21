import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../main.dart';

// Admin page integrated with backend prototype
class AdminPage extends StatefulWidget {
  @override
  _AdminPageState createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  List<dynamic> _users = [];
  bool _loading = false;
  final _service = AuthService();

  Future<void> _fetchUsers() async {
    setState(() => _loading = true);
    try {
      final auth = Provider.of<AuthNotifier>(context, listen: false);
      if (auth.token == null) {
        // no backend token: show example fallback
        _users = [
          {'username': 'admin', 'role': 'admin', 'paused': false},
          {'username': 'user1', 'role': 'user', 'paused': false},
        ];
      } else {
        _users = await _service.getUsers(auth.token!);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao obter usuários: $e')));
    }
    setState(() => _loading = false);
  }

  Future<void> _togglePause(int index) async {
    final u = _users[index];
    final username = u['username'];
    final newPaused = !(u['paused'] == true);
    setState(() => _users[index]['paused'] = newPaused);
    try {
      final auth = Provider.of<AuthNotifier>(context, listen: false);
      if (auth.token != null) {
        await _service.pauseUser(auth.token!, username, newPaused);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao pausar usuário: $e')));
    }
  }

  Future<void> _deleteUser(int index) async {
    final username = _users[index]['username'];
    final auth = Provider.of<AuthNotifier>(context, listen: false);
    try {
      if (auth.token != null) {
        await _service.deleteUser(auth.token!, username);
        setState(() => _users.removeAt(index));
      } else {
        setState(() => _users.removeAt(index));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao deletar usuário: $e')));
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchUsers());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Painel Admin')),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchUsers,
              child: ListView.builder(
                itemCount: _users.length,
                itemBuilder: (context, i) {
                  final u = _users[i];
                  return ListTile(
                    title: Text(u['username']),
                    subtitle: Text('Role: ${u['role']} — Paused: ${u['paused']}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.pause),
                          onPressed: () => _togglePause(i),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete),
                          onPressed: () => _deleteUser(i),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () async {
          // simple create user dialog (creates via backend if token present)
          final result = await showDialog<Map<String, String>>(context: context, builder: (ctx) {
            final userController = TextEditingController();
            final passController = TextEditingController();
            return AlertDialog(
              title: Text('Criar usuário'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: userController, decoration: InputDecoration(labelText: 'Usuário')),
                  TextField(controller: passController, decoration: InputDecoration(labelText: 'Senha')),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Cancelar')),
                ElevatedButton(onPressed: () => Navigator.of(ctx).pop({'u': userController.text, 'p': passController.text}), child: Text('Criar')),
              ],
            );
          });
          if (result != null) {
            final auth = Provider.of<AuthNotifier>(context, listen: false);
            try {
              if (auth.token != null) {
                await _service.createUser(auth.token!, result['u']!, result['p']!);
                await _fetchUsers();
              } else {
                setState(() => _users.add({'username': result['u'], 'role': 'user', 'paused': false}));
              }
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao criar usuário: $e')));
            }
          }
        },
      ),
    );
  }
}

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com> 