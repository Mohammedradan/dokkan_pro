import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

/// بوابة القفل: تعرض شاشة إدخال الرقم السري عند تفعيل القفل،
/// وتعيد القفل تلقائياً عند العودة للتطبيق من الخلفية.
class PinGate extends StatefulWidget {
  final Widget child;

  const PinGate({super.key, required this.child});

  @override
  State<PinGate> createState() => _PinGateState();
}

class _PinGateState extends State<PinGate> with WidgetsBindingObserver {
  bool _unlocked = false;
  bool _inBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _inBackground = true;
    } else if (state == AppLifecycleState.resumed) {
      if (_inBackground) {
        _inBackground = false;
        final pinEnabled = context.read<AppState>().pinEnabled;
        if (pinEnabled && mounted) {
          setState(() => _unlocked = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pinEnabled = context.watch<AppState>().pinEnabled;
    if (pinEnabled && !_unlocked) {
      return PinLockScreen(
        onUnlocked: () => setState(() => _unlocked = true),
      );
    }
    return widget.child;
  }
}

/// شاشة إدخال الرقم السري لفتح التطبيق.
class PinLockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const PinLockScreen({super.key, required this.onUnlocked});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  final TextEditingController _pin = TextEditingController();
  bool _error = false;
  bool _checking = false;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final state = context.read<AppState>();
    final input = _pin.text.trim();
    if (input.isEmpty) return;
    setState(() {
      _checking = true;
      _error = false;
    });
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    if (state.verifyPin(input)) {
      _pin.clear();
      widget.onUnlocked();
    } else {
      _pin.clear();
      setState(() => _error = true);
    }
    setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: scheme.primaryContainer,
                  child: Icon(Icons.storefront,
                      size: 40, color: scheme.onPrimaryContainer),
                ),
                const SizedBox(height: 20),
                const Text(
                  'دكاني مقفل',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'أدخل الرقم السري لفتح التطبيق',
                  style: TextStyle(
                      fontSize: 13, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _pin,
                  autofocus: true,
                  obscureText: true,
                  maxLength: 6,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 22, letterSpacing: 10),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '••••',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    errorText: _error ? 'رقم سري غير صحيح' : null,
                    errorStyle: const TextStyle(fontSize: 12.5),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _checking ? null : _submit,
                    icon: _checking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.lock_open_outlined),
                    label: const Text('فتح'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
