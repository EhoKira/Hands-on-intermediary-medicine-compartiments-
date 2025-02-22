import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

// 🔹 Conexão MQTT
const String mqttServer = "URL";
const int mqttPort = 8883;
const String mqttUser = "USER";
const String mqttPassword = "PASSWORD";  
const String mqttTopic = "TOPIC";

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Garante inicialização correta do Flutter antes de chamadas assíncronas
  await conectarMQTT();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('MQTT')),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                enviarMensagem("Teste de notificação");
              },
              child: const Text('Enviar Notificação'),
            ),
            const Center(child: Text('Esperando mensagens MQTT...')),
          ],
        ),
      ),
    );
  }
}

// 🔹 Conexão MQTT
Future<void> conectarMQTT() async {
  final client = MqttServerClient(mqttServer, 'flutter_client');
  client.port = mqttPort;
  client.secure = true;
  client.setProtocolV311();
  client.logging(on: false);

  final connMessage = MqttConnectMessage()
      .withClientIdentifier('flutter_client')
      .authenticateAs(mqttUser, mqttPassword)
      .startClean();

  client.connectionMessage = connMessage;

  try {
    await client.connect();
    print('✅ Conectado ao MQTT');

    client.subscribe(mqttTopic, MqttQos.atLeastOnce);
    client.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? event) {
      if (event != null && event.isNotEmpty) {
        final recMessage = event[0].payload as MqttPublishMessage;
        final payload =
            MqttPublishPayload.bytesToStringAsString(recMessage.payload.message);

        print('📩 Mensagem recebida: $payload');
      }
    });
  } catch (e) {
    print('❌ Erro na conexão MQTT: $e');
    client.disconnect();
  }
}

// 🔹 Enviar mensagem MQTT
void enviarMensagem(String mensagem) {
  final client = MqttServerClient(mqttServer, 'flutter_client');
  final builder = MqttClientPayloadBuilder();
  builder.addString(mensagem);

  client.publishMessage(mqttTopic, MqttQos.atLeastOnce, builder.payload!);
}
