import 'package:flutter/material.dart';
import 'live_radar_screen.dart';

void main() {
  runApp(const PlayersZWZApp());
}

class PlayersZWZApp extends StatelessWidget {
  const PlayersZWZApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PlayersZWZ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFDAF51E), // Neon Lime
          secondary: Colors.redAccent,
        ),
      ),
      home: const InitializationGateway(),
    );
  }
}

class InitializationGateway extends StatefulWidget {
  const InitializationGateway({Key? key}) : super(key: key);

  @override
  _InitializationGatewayState createState() => _InitializationGatewayState();
}

class _InitializationGatewayState extends State<InitializationGateway> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _idController = TextEditingController();

  void _deployRadar() {
    if (_formKey.currentState!.validate()) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LiveRadarScreen(
            userId: _idController.text.trim(),
            playerName: _nameController.text.trim(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lime = Theme.of(context).colorScheme.primary;
    
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.radar, size: 80, color: lime),
                const SizedBox(height: 16),
                Text('PLAYERS_ZWZ', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: lime, letterSpacing: 4)),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Player Display Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (val) => val == null || val.isEmpty ? 'Callsign required' : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _idController,
                  decoration: const InputDecoration(
                    labelText: 'Unique Device ID',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.fingerprint),
                  ),
                  validator: (val) => val == null || val.isEmpty ? 'Device ID required' : null,
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: lime,
                      foregroundColor: Colors.black,
                      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 2),
                    ),
                    onPressed: _deployRadar,
                    child: const Text('INITIALIZE UPLINK'),
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