import 'package:medboxapp/main.dart';

class remedio {
  int? id;
  String nome;
  String horario;

  remedio({this.id, required this.nome, required this.horario});

  // Converter um objeto Medicina para um Map (SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'horario': horario,
    };
  }

  // Criar um objeto Medicina a partir de um Map (SQLite)
  factory remedio.fromMap(Map<String, dynamic> map) {
    return remedio(
      id: map['id'],
      nome: map['nome'],
      horario: map['horario'],
    );
  }
}