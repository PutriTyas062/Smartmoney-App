import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../utils/google_signin_debugger.dart';
import '../utils/auth_error_handler.dart';

class AuthDebugPage extends ConsumerStatefulWidget {
  const AuthDebugPage({super.key});

  @override
  ConsumerState<AuthDebugPage> createState() => _AuthDebugPageState();
}

class _AuthDebugPageState extends ConsumerState<AuthDebugPage> {
  Map<String, dynamic>? _debugInfo;
  bool _isLoading = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _loadDebugInfo();
  }

  Future<void> _loadDebugInfo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final debugInfo = await GoogleSignInDebugger.getDebugInfo();
      setState(() {
        _debugInfo = debugInfo;
      });
    } catch (e) {
      setState(() {
        _debugInfo = {'error': e.toString()};
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testGoogleSignIn() async {
    setState(() {
      _testResult = 'Testing...';
    });

    try {
      final authService = ref.read(authServiceProvider);
      await authService.initialize();

      final userCredential = await authService.signInWithGoogle();

      if (userCredential != null) {
        setState(() {
          _testResult = 'SUCCESS: Signed in as ${userCredential.user?.email}';
        });
      } else {
        setState(() {
          _testResult = 'CANCELLED: User cancelled sign in';
        });
      }
    } catch (error) {
      setState(() {
        _testResult = 'ERROR: ${AuthErrorHandler.getReadableError(error)}';
      });
    }
  }

  Future<void> _copyDebugInfo() async {
    if (_debugInfo != null) {
      final debugText = await GoogleSignInDebugger.getFormattedDebugInfo();
      await Clipboard.setData(ClipboardData(text: debugText));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debug info copied to clipboard'),
          ),
        );
      }
    }
  }

  Widget _buildDebugInfoCard(String title, dynamic value) {
    Color cardColor = Colors.grey.shade100;
    Color textColor = Colors.black87;
    IconData icon = Icons.info;

    if (value is bool) {
      if (value) {
        cardColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        icon = Icons.check_circle;
      } else {
        cardColor = Colors.red.shade100;
        textColor = Colors.red.shade800;
        icon = Icons.error;
      }
    } else if (value.toString().toLowerCase().contains('error')) {
      cardColor = Colors.red.shade100;
      textColor = Colors.red.shade800;
      icon = Icons.error;
    } else if (value.toString().toLowerCase().contains('unknown')) {
      cardColor = Colors.orange.shade100;
      textColor = Colors.orange.shade800;
      icon = Icons.warning;
    }

    return Card(
      color: cardColor,
      child: ListTile(
        leading: Icon(icon, color: textColor),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        subtitle: Text(
          value.toString(),
          style: TextStyle(color: textColor),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auth Debug'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDebugInfo,
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _copyDebugInfo,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Quick Test',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _testGoogleSignIn,
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Test Google Sign In'),
                          ),
                          if (_testResult != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _testResult!.startsWith('SUCCESS')
                                    ? Colors.green.shade100
                                    : _testResult!.startsWith('ERROR')
                                        ? Colors.red.shade100
                                        : Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _testResult!,
                                style: TextStyle(
                                  color: _testResult!.startsWith('SUCCESS')
                                      ? Colors.green.shade800
                                      : _testResult!.startsWith('ERROR')
                                          ? Colors.red.shade800
                                          : Colors.orange.shade800,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Debug Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_debugInfo != null)
                    ..._debugInfo!.entries.map(
                      (entry) => _buildDebugInfoCard(entry.key, entry.value),
                    ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Troubleshooting Tips',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '1. Make sure Google Play Services is installed\n'
                            '2. Check SHA-1 certificate in Firebase Console\n'
                            '3. Verify package name matches\n'
                            '4. Enable Google Sign-In in Firebase Console\n'
                            '5. Test on physical device, not emulator\n'
                            '6. Check internet connection',
                            style: TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: const Text('Back to App'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
