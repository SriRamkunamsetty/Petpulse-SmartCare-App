import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// A minimal MJPEG viewer: opens `GET [url]`, scans the byte stream for
/// JPEG SOI/EOI markers (0xFFD8 ... 0xFFD9) and repaints on every complete
/// frame. This is the same framing convention ESP32-CAM firmware and the
/// mock server (`mock_server/camera.js`) both use, so no multipart-boundary
/// parsing is needed and no extra package dependency either.
class MjpegView extends StatefulWidget {
  const MjpegView({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.headers = const {},
  });

  final String url;
  final BoxFit fit;
  final Widget? placeholder;
  final Map<String, String> headers;

  @override
  State<MjpegView> createState() => _MjpegViewState();
}

class _MjpegViewState extends State<MjpegView> {
  http.Client? _client;
  StreamSubscription<List<int>>? _sub;
  final List<int> _buffer = [];
  Uint8List? _frame;
  bool _connecting = true;
  bool _failed = false;

  static const _maxBufferBytes = 4 * 1024 * 1024;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void didUpdateWidget(covariant MjpegView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _teardown();
      _connect();
    }
  }

  Future<void> _connect() async {
    _failed = false;
    _connecting = true;
    _buffer.clear();
    final client = http.Client();
    _client = client;
    try {
      final request = http.Request('GET', Uri.parse(widget.url));
      request.headers.addAll(widget.headers);
      final response = await client.send(request);
      if (response.statusCode != 200) {
        throw http.ClientException('HTTP ${response.statusCode}');
      }
      if (mounted) setState(() => _connecting = false);
      _sub = response.stream.listen(
        _onData,
        onError: (_) => _onFailure(),
        onDone: _onFailure,
        cancelOnError: true,
      );
    } catch (_) {
      _onFailure();
    }
  }

  void _onData(List<int> chunk) {
    _buffer.addAll(chunk);
    _extractFrames();
    if (_buffer.length > _maxBufferBytes) {
      _buffer.clear(); // Lost sync — resets and waits for the next SOI.
    }
  }

  void _extractFrames() {
    Uint8List? latest;
    while (true) {
      final start = _indexOfMarker(_buffer, 0xFF, 0xD8, from: 0);
      if (start == -1) {
        if (_buffer.length > 2) _buffer.removeRange(0, _buffer.length - 2);
        break;
      }
      if (start > 0) _buffer.removeRange(0, start);
      final end = _indexOfMarker(_buffer, 0xFF, 0xD9, from: 2);
      if (end == -1) break; // Frame not complete yet.
      latest = Uint8List.fromList(_buffer.sublist(0, end + 2));
      _buffer.removeRange(0, end + 2);
    }
    if (latest != null && mounted) {
      setState(() => _frame = latest);
    }
  }

  int _indexOfMarker(List<int> bytes, int a, int b, {required int from}) {
    for (var i = from; i < bytes.length - 1; i++) {
      if (bytes[i] == a && bytes[i + 1] == b) return i;
    }
    return -1;
  }

  void _onFailure() {
    if (!mounted) return;
    setState(() {
      _failed = true;
      _connecting = false;
    });
  }

  void _teardown() {
    _sub?.cancel();
    _sub = null;
    _client?.close();
    _client = null;
  }

  @override
  void dispose() {
    _teardown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_frame != null) {
      return Image.memory(_frame!, fit: widget.fit, gaplessPlayback: true);
    }
    if (_failed) {
      return _StreamMessage(
        icon: Icons.videocam_off_rounded,
        label: 'Camera unreachable',
        onRetry: _connect,
      );
    }
    if (_connecting) {
      return widget.placeholder ??
          const Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white70));
    }
    return widget.placeholder ?? const SizedBox.shrink();
  }
}

class _StreamMessage extends StatelessWidget {
  const _StreamMessage({required this.icon, required this.label, this.onRetry});
  final IconData icon;
  final String label;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white54, size: 28),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ],
      ),
    );
  }
}
