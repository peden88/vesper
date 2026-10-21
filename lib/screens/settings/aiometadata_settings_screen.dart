import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/archive_service.dart';
import '../../services/archive_api_service.dart';

/// Add AIOMetadata as the primary catalog and metadata source.
class AioMetadataSettingsScreen extends StatefulWidget {
  const AioMetadataSettingsScreen({super.key});

  @override
  State<AioMetadataSettingsScreen> createState() =>
      _AioMetadataSettingsScreenState();
}

class _AioMetadataSettingsScreenState
    extends State<AioMetadataSettingsScreen> {
  final _url = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (_busy || _url.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final source = await context.read<ArchiveService>()
          .addMetadataSource(_url.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connected: ${source.name}')),
      );
      _url.clear();
    } on ArchiveApiException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Manifest is unavailable or incompatible.')),
      );
    } on StateError {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This provider is already configured.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not connect to AIOMetadata.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('AIOMetadata')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Enter your complete AIOMetadata manifest URL. '
                  'Existing IPTV and stream providers remain configured.'),
              const SizedBox(height: 16),
              TextField(
                controller: _url,
                decoration: const InputDecoration(
                  labelText: 'Manifest URL',
                  hintText: 'https://your-server/config/manifest.json',
                ),
                keyboardType: TextInputType.url,
                autocorrect: false,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _busy ? null : _connect,
                child: Text(_busy ? 'Connecting…' : 'Add primary metadata provider'),
              ),
            ],
          ),
        ),
      );
}
