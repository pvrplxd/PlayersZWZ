import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../app/playerszwz_app.dart';

class LaunchScreen extends StatelessWidget {
  const LaunchScreen({super.key, this.identity, this.loading = false});
  final String? identity;
  final bool loading;
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
            child: Column(children: [
          const Expanded(child: Center(child: BrandMark(size: 128))),
          if (identity != null)
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: const Color(0xFF151917),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: appSuccess.withValues(alpha: .2))),
                    child: Row(children: [
                      const Icon(CupertinoIcons.checkmark_shield_fill,
                          color: appSuccess, size: 30),
                      const SizedBox(width: 16),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                            const Text('Signed in as',
                                style: TextStyle(
                                    fontSize: 13, color: Colors.white54)),
                            const SizedBox(height: 5),
                            Text(identity!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.w600)),
                          ])),
                    ]))),
          if (loading)
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Column(children: [
                  CupertinoActivityIndicator(color: Colors.white70),
                  SizedBox(height: 12),
                  Text('Loading your account…',
                      style: TextStyle(fontSize: 13, color: Colors.white54)),
                ]))
          else
            const SizedBox(height: 48),
        ])),
      );
}
