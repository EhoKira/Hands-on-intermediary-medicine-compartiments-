import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

// 🔹 Configuração MQTT
const String mqttServer = "URL_DO_SERVIDOR_MQTT";
const int mqttPort = 8883;
const String mqttUser = "USER_MQTT";
const String mqttPassword = "PASSWORD_MQTT";
const String mqttTopicUmidade = "TOPIC1";  // Tópico para receber umidade
const String mqttTopicRemedio = "TOPIC2"; // Tópico para registrar remédio

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: RemedioScreen(),
    );
  }
}

class RemedioScreen extends StatefulWidget {
  @override
  _RemedioScreenState createState() => _RemedioScreenState();
}

class _RemedioScreenState extends State<RemedioScreen> {
  late MqttServerClient client;
  String mensagemRecebida = "Aguardando notificações...";
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    configurarNotificacoes();
    conectarMQTT();
  }

  // 🔹 Configuração de notificações locais
  void configurarNotificacoes() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> exibirNotificacao(String titulo, String mensagem) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'canal_alertas',
      'Alertas de Sensor',
      importance: Importance.high,
      priority: Priority.high,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      0,
      titulo,
      mensagem,
      platformChannelSpecifics,
    );
  }

  // 🔹 Conectar ao MQTT e escutar mensagens
  Future<void> conectarMQTT() async {
    client = MqttServerClient(mqttServer, 'flutter_client');
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

      // 🔹 Escutar mensagens de umidade e remédio
      client.subscribe(mqttTopicUmidade, MqttQos.atLeastOnce);
      client.subscribe(mqttTopicRemedio, MqttQos.atLeastOnce);
      
      client.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? event) {
        if (event != null && event.isNotEmpty) {
          final recMessage = event[0].payload as MqttPublishMessage;
          final payload =
              MqttPublishPayload.bytesToStringAsString(recMessage.payload.message);

          print('📩 Mensagem recebida: $payload');
          
          if (event[0].topic == mqttTopicUmidade && payload.contains("alta")) {
            exibirNotificacao("🚨 Alerta!", "Nivel de umidade elevado na caixa!");
          }
          
          if (event[0].topic == mqttTopicRemedio && payload.contains("apagado")) {
            exibirNotificacao("✅ Confirmação", "Remedio tomado e LEDs apagados.");
          }
          
          setState(() {
            mensagemRecebida = payload;
          });
        }
      });
    } catch (e) {
      print('❌ Erro na conexão MQTT: $e');
      client.disconnect();
    }
  }

  // 🔹 Enviar mensagem ao MQTT
  void enviarMensagem(String remedio) {
    final builder = MqttClientPayloadBuilder();
    builder.addString("Remedio registrado: $remedio");

    client.publishMessage(mqttTopicRemedio, MqttQos.atLeastOnce, builder.payload!);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("💊 $remedio registrado e enviado ao MQTT")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Monitor de Remédios')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => enviarMensagem("Remedio 1"),
              child: const Text('💊 Registrar Remédio 1'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => enviarMensagem("Remedio 2"),
              child: const Text('💊 Registrar Remédio 2'),
            ),
            SizedBox(height: 40),
            Text(
              "📡 Última Notificação:\n$mensagemRecebida",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
} 

