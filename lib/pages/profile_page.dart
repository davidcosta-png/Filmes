import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';

class ProfilePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthNotifier>(context);
    return Scaffold(
      appBar: AppBar(title: Text('Perfil')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Usuário: ${auth.username ?? "—"}', style: TextStyle(fontSize: 18)),
            SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                await auth.logout();
              },
              child: Text('Sair'),
            ),
          ],
        ),
      ),
    );
  }
}

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com> 