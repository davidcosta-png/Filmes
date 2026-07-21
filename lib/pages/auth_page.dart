import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/auth_service.dart';

class AuthPage extends StatefulWidget {
  @override
  _AuthPageState createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  String _username = '';
  String _password = '';
  bool _isLoading = false;

  // NOTE: Prototype: accepts any username/password except empty.
  // Admin account: username "admin" password "admin" (see README)

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _isLoading = true);

    final authService = AuthService();
    try {
      final result = await authService.login(_username, _password);
      final token = result['token'];
      final refresh = result['refreshToken'];
      final profile = await authService.me(token);
      final auth = Provider.of<AuthNotifier>(context, listen: false);
      await auth.loginWithProfile(token, profile, refresh: refresh);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao entrar: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Entrar')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    decoration: InputDecoration(labelText: 'Usuário'),
                    onSaved: (v) => _username = v!.trim(),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe usuário' : null,
                  ),
                  TextFormField(
                    decoration: InputDecoration(labelText: 'Senha'),
                    obscureText: true,
                    onSaved: (v) => _password = v ?? '',
                    validator: (v) => (v == null || v.isEmpty) ? 'Informe senha' : null,
                  ),
                  SizedBox(height: 16),
                  _isLoading
                      ? CircularProgressIndicator()
                      : ElevatedButton(onPressed: _submit, child: Text('Entrar')),
                  SizedBox(height: 8),
                  Text('Conta admin de teste: usuário=admin senha=admin', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com> 