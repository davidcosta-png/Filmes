import 'package:flutter/material.dart';

class PlayerPage extends StatelessWidget {
  final Map<String, dynamic> item;
  const PlayerPage({Key? key, required this.item}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final title = item['title'] ?? item['name'] ?? 'Reprodução';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_circle_outline, size: 120),
            SizedBox(height: 16),
            Text('Player placeholder', style: TextStyle(fontSize: 18)),
            SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text('Aqui exibirá o player com stream válido (DRM, HLS, etc.) em produção.'),
            ),
          ],
        ),
      ),
    );
  }
}

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com> 