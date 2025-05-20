import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

class SignatureService {
  final _controller = SignatureController(
    penStrokeWidth: 5,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  Future<Uint8List?> getSignature(BuildContext context) async {
    final result = await showDialog<Uint8List>(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Sign here',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Container(
              height: 200,
              color: Colors.white,
              child: Signature(
                controller: _controller,
                backgroundColor: Colors.white,
              ),
            ),
            ButtonBar(
              children: [
                TextButton(
                  onPressed: () {
                    _controller.clear();
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    final bytes = await _controller.toPngBytes();
                    if (bytes != null) {
                      Navigator.pop(context, bytes);
                    }
                  },
                  child: const Text('Done'),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    _controller.clear();
    return result;
  }

  void dispose() {
    _controller.dispose();
  }
} 