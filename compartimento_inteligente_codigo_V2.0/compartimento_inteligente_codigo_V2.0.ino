#include <WiFi.h>
#include <PubSubClient.h>
#include <WiFiClientSecure.h>
#include <DHT.h>

// Configurações de rede Wi-Fi
const char* ssid = "Starlink_CIT";
const char* password = "Ufrr@2024Cit";

// Configurações do HiveMQ Broker
const char* mqtt_server = "a75c63a4fa874ed09517714e6df8d815.s1.eu.hivemq.cloud";
const char* mqtt_topic = "Test";
const char* mqtt_username = "hivemq.webclient.1739908772463";
const char* mqtt_password = "nI$?fQdxD@&83AFB1mw5";
const int mqtt_port = 8883;

WiFiClientSecure espClient;
PubSubClient client(espClient);

// Definição dos pinos
#define led_remedio1 32
#define led_remedio2 22
#define buzzer 21
#define trigPin 18        // Pino de Trigger do HC-SR04
#define echoPin 19        // Pino de Echo do HC-SR04
#define dhtPin 33         // Pino de dados do DHT11

DHT dht(dhtPin, DHT11);

// Função de callback para receber mensagens MQTT
void callback(char* topic, byte* payload, unsigned int length) {
  Serial.print("Mensagem recebida: ");
  String message;
  for (int i = 0; i < length; i++) {
    message += (char)payload[i];
  }
  Serial.println(message);

  // Aciona os LEDs e o buzzer com base no tópico recebido
  if (message == "remedio1") {
    acionaLedEBuzzer(led_remedio1, "Remédio 1");
  } else if (message == "remedio2") {
    acionaLedEBuzzer(led_remedio2, "Remédio 2");
  }
}

// Função para conectar ao Wi-Fi
void setup_wifi() {
  delay(10);
  Serial.println("Conectando ao Wi-Fi...");
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("");
  Serial.println("Wi-Fi conectado.");
}

// Função para reconectar ao broker MQTT
void reconnect() {
  while (!client.connected()) {
    Serial.print("Tentando se reconectar ao MQTT...");
    if (client.connect("ESP32Client", mqtt_username, mqtt_password)) {
      Serial.println("Conectado.");
      client.subscribe(mqtt_topic);  // Inscreve-se no tópico
    } else {
      Serial.print("Falha, rc=");
      Serial.print(client.state());
      Serial.println(" tentando novamente em 5 segundos.");
      delay(5000);
    }
  }
}

// Função para acionar o LED e o buzzer
void acionaLedEBuzzer(int ledPin, const char* nomeRemedio) {
  Serial.println("Entrou");
  digitalWrite(ledPin, HIGH);  // Liga o LED
  tone(buzzer, 5000);          // Aciona o buzzer (5000Hz)
  Serial.println(nomeRemedio);

  // Fica verificando a distância até ser 5 cm ou menos
  while (medirDistancia() > 5) {
    // Continua com o LED aceso e buzzer ligado enquanto a distância for maior que 5 cm
    delay(100);  // Pequeno delay para não sobrecarregar o loop
  }

  // Quando a distância for 5 cm ou menos, desliga o LED e buzzer
  digitalWrite(ledPin, LOW);   // Desliga o LED
  noTone(buzzer);              // Desliga o buzzer
  Serial.println("Distância atingida, desligando LED e buzzer.");
}

// Função para medir a distância com o HC-SR04
long medirDistancia() {
  digitalWrite(trigPin, LOW);
  delayMicroseconds(2);
  digitalWrite(trigPin, HIGH);
  delayMicroseconds(10);
  digitalWrite(trigPin, LOW);
  
  long duracao = pulseIn(echoPin, HIGH);
  long distancia = (duracao / 2) * 0.0343; // Calcula a distância em cm
  return distancia;
}

// Função para ler dados do DHT11
void lerTemperaturaEUmidade() {
  float temperatura = dht.readTemperature();  // Lê a temperatura em °C
  float umidade = dht.readHumidity();         // Lê a umidade relativa
  
  if (isnan(temperatura) || isnan(umidade)) {
    Serial.println("Falha ao ler do DHT11");
  } else {
    Serial.print("Temperatura: ");
    Serial.print(temperatura);
    Serial.print("°C  Umidade: ");
    Serial.print(umidade);
    Serial.println("%");

    // Verifica se a umidade está acima de 60%
    if (umidade > 80) {
      Serial.println("Alerta: Umidade acima de 80%");
      tone(buzzer, 1000);  // Buzzer soa a 1000Hz
      client.publish("alerta/umidade", "Umidade acima de 80%");  // Publica mensagem MQTT
    } else {
      noTone(buzzer);  // Desliga o buzzer se a umidade não estiver alta
    }
  }
}

void setup() {
  Serial.begin(115200);

  // Configura os pinos dos LEDs como saída
  pinMode(led_remedio1, OUTPUT);
  pinMode(led_remedio2, OUTPUT);
  pinMode(buzzer, OUTPUT);
  pinMode(23, OUTPUT);
  pinMode(trigPin, OUTPUT);   // Configura o pino de Trigger como saída
  pinMode(echoPin, INPUT);    // Configura o pino de Echo como entrada

  // Inicializa o sensor DHT11
  dht.begin();

  // Conexão ao Wi-Fi e MQTT
  setup_wifi();
  espClient.setInsecure();
  client.setServer(mqtt_server, mqtt_port);
  client.setCallback(callback);
}

void loop() {
  if (!client.connected()) {
    reconnect();
  }
  client.loop();

  // Medir distância a cada 5 segundos
  long distancia = medirDistancia();
  Serial.print("Distância: ");
  Serial.print(distancia);
  Serial.println(" cm");
  
  // Ler dados de temperatura e umidade a cada 5 segundos
  lerTemperaturaEUmidade();
  
  delay(5000);  // Aguarda 5 segundos antes de fazer a próxima leitura

}
