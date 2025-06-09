class NotaAsistencia {
  final String? idNota;
  final int? valorNota;
  final String descripcionNota;

  NotaAsistencia({this.idNota, this.valorNota, required this.descripcionNota});

  Map<String, dynamic> toMap() {
    return {
      'idNota': idNota,
      'valorNota': valorNota,
      'descripcionNota': descripcionNota,
    };
  }

  factory NotaAsistencia.fromMap(Map<String, dynamic> map) {
    return NotaAsistencia(
      idNota: map['idNota'],
      valorNota: map['valorNota'],
      descripcionNota: map['descripcionNota'],
    );
  }

  NotaAsistencia copyWith({
    String? idNota,
    int? valorNota,
    String? descripcionNota,
  }) {
    return NotaAsistencia(
      idNota: idNota ?? this.idNota,
      valorNota: valorNota ?? this.valorNota,
      descripcionNota: descripcionNota ?? this.descripcionNota,
    );
  }
}

class Usuario {
  final int? idUsuario;
  final String? nombreCompleto;
  final String tipoSexo;
  final String fechaNacimiento;

  Usuario({
    this.idUsuario,
    required this.nombreCompleto,
    required this.tipoSexo,
    required this.fechaNacimiento,
  });

  Map<String, dynamic> toMap() {
    return {
      // 'idUsuario': idUsuario,
      'nombreCompleto': nombreCompleto,
      'tipoSexo': tipoSexo,
      'fechaNacimiento': fechaNacimiento,
    };
  }

  factory Usuario.fromMap(Map<String, dynamic> map) {
    return Usuario(
      idUsuario: map['idUsuario'],
      nombreCompleto: map['nombreCompleto'],
      tipoSexo: map['tipoSexo'],
      fechaNacimiento: map['fechaNacimiento'],
    );
  }

  Usuario copyWith({
    int? idUsuario,
    String? nombreCmpleto,
    String? tipoSexo,
    String? fechaNacimiento,
  }) {
    return Usuario(
      idUsuario: idUsuario ?? this.idUsuario,
      nombreCompleto: nombreCompleto ?? this.nombreCompleto,
      tipoSexo: tipoSexo ?? this.tipoSexo,
      fechaNacimiento: fechaNacimiento ?? this.fechaNacimiento,
    );
  }
}

class Asistencia {
  final int? idAsistencia;
  final int usuarioId;
  final String consagracionDomingo; // Se mantiene String, "" = no registrado
  final DateTime? fechaConsagracionD; // CAMBIADO A DateTime?
  final String escuelaDominical;
  final DateTime? fechaEscuelaD; // CAMBIADO A DateTime?
  final String ensayoMartes;
  final DateTime? fechaEnsayoMartes; // CAMBIADO A DateTime?
  final String ensayoMiercoles;
  final DateTime? fechaEnsayoMiercoles; // CAMBIADO A DateTime?
  final String servicioJueves;
  final DateTime? fechaServicioJueves; // CAMBIADO A DateTime?
  final int? totalAsistencia;
  final DateTime inicioSemana; // Esta y finSemana pueden seguir siendo required
  final DateTime finSemana;
  final String? nombreExtraN1;
  final int? extraN1;
  final String? nombreExtraN2;
  final int? extraN2;
  final String? estado;

  Asistencia({
    this.idAsistencia,
    required this.usuarioId,
    required this.consagracionDomingo, // Sigue required, se inicializará con ""
    this.fechaConsagracionD, // Ahora es opcional
    required this.escuelaDominical,
    this.fechaEscuelaD,
    required this.ensayoMartes,
    this.fechaEnsayoMartes,
    required this.ensayoMiercoles,
    this.fechaEnsayoMiercoles,
    required this.servicioJueves,
    this.fechaServicioJueves,
    this.totalAsistencia,
    required this.inicioSemana,
    required this.finSemana,
    this.nombreExtraN1,
    this.extraN1,
    this.nombreExtraN2,
    this.extraN2,
    this.estado,
  });

  Map<String, dynamic> toMap() {
    return {
      'usuarioId': usuarioId,
      'consagracionDomingo': consagracionDomingo,
      'fechaConsagracionD': fechaConsagracionD?.toIso8601String(), // Usar ?.
      'escuelaDominical': escuelaDominical,
      'fechaEscuelaD': fechaEscuelaD?.toIso8601String(),
      'ensayoMartes': ensayoMartes,
      'fechaEnsayoMartes': fechaEnsayoMartes?.toIso8601String(),
      'ensayoMiercoles': ensayoMiercoles,
      'fechaEnsayoMiercoles': fechaEnsayoMiercoles?.toIso8601String(),
      'servicioJueves': servicioJueves,
      'fechaServicioJueves': fechaServicioJueves?.toIso8601String(),
      'totalAsistencia': totalAsistencia,
      'inicioSemana': inicioSemana.toIso8601String(),
      'finSemana': finSemana.toIso8601String(),
      'nombreExtraN1': nombreExtraN1,
      'extraN1': extraN1,
      'nombreExtraN2': nombreExtraN2,
      'extraN2': extraN2,
      'estado': estado,
    };
  }

  factory Asistencia.fromMap(Map<String, dynamic> map) {
    DateTime? parseNullableDateTime(String? dateString) {
      return dateString != null
          ? DateTime.tryParse(dateString)?.toLocal()
          : null;
    }

    return Asistencia(
      idAsistencia: map['idAsistencia'] as int?,
      usuarioId: map['usuarioId'] as int,
      consagracionDomingo: map['consagracionDomingo'] as String? ?? "",
      fechaConsagracionD: parseNullableDateTime(
        map['fechaConsagracionD'] as String?,
      ),
      escuelaDominical: map['escuelaDominical'] as String? ?? "",
      fechaEscuelaD: parseNullableDateTime(map['fechaEscuelaD'] as String?),
      ensayoMartes: map['ensayoMartes'] as String? ?? "",
      fechaEnsayoMartes: parseNullableDateTime(
        map['fechaEnsayoMartes'] as String?,
      ),
      ensayoMiercoles: map['ensayoMiercoles'] as String? ?? "",
      fechaEnsayoMiercoles: parseNullableDateTime(
        map['fechaEnsayoMiercoles'] as String?,
      ),
      servicioJueves: map['servicioJueves'] as String? ?? "",
      fechaServicioJueves: parseNullableDateTime(
        map['fechaServicioJueves'] as String?,
      ),
      totalAsistencia: map['totalAsistencia'] as int?,
      // inicioSemana y finSemana no pueden ser null según el modelo, así que parse directo
      inicioSemana: DateTime.parse(map['inicioSemana'] as String).toLocal(),
      finSemana: DateTime.parse(map['finSemana'] as String).toLocal(),
      nombreExtraN1: map['nombreExtraN1'] as String?,
      extraN1: map['extraN1'] as int?,
      nombreExtraN2: map['nombreExtraN2'] as String?,
      extraN2: map['extraN2'] as int?,
      estado: map['estado'] as String?,
    );
  }

  Asistencia copyWith({
    int? idAsistencia,
    int? usuarioId,
    String? consagracionDomingo,
    DateTime? fechaConsagracionD, // Ya es nulable
    String? escuelaDominical,
    DateTime? fechaEscuelaD,
    String? ensayoMartes,
    DateTime? fechaEnsayoMartes,
    String? ensayoMiercoles,
    DateTime? fechaEnsayoMiercoles,
    String? servicioJueves,
    DateTime? fechaServicioJueves,
    int? totalAsistencia,
    DateTime? inicioSemana,
    DateTime? finSemana,
    String? nombreExtraN1,
    int? extraN1,
    String? nombreExtraN2,
    int? extraN2,
    String? estado,
  }) {
    return Asistencia(
      idAsistencia: idAsistencia ?? this.idAsistencia,
      usuarioId: usuarioId ?? this.usuarioId,
      consagracionDomingo: consagracionDomingo ?? this.consagracionDomingo,
      fechaConsagracionD: fechaConsagracionD ?? this.fechaConsagracionD,
      escuelaDominical: escuelaDominical ?? this.escuelaDominical,
      fechaEscuelaD: fechaEscuelaD ?? this.fechaEscuelaD,
      ensayoMartes: ensayoMartes ?? this.ensayoMartes,
      fechaEnsayoMartes: fechaEnsayoMartes ?? this.fechaEnsayoMartes,
      ensayoMiercoles: ensayoMiercoles ?? this.ensayoMiercoles,
      fechaEnsayoMiercoles: fechaEnsayoMiercoles ?? this.fechaEnsayoMiercoles,
      servicioJueves: servicioJueves ?? this.servicioJueves,
      fechaServicioJueves: fechaServicioJueves ?? this.fechaServicioJueves,
      totalAsistencia: totalAsistencia ?? this.totalAsistencia,
      inicioSemana: inicioSemana ?? this.inicioSemana,
      finSemana: finSemana ?? this.finSemana,
      nombreExtraN1: nombreExtraN1 ?? this.nombreExtraN1,
      extraN1: extraN1 ?? this.extraN1,
      nombreExtraN2: nombreExtraN2 ?? this.nombreExtraN2,
      extraN2: extraN2 ?? this.extraN2,
      estado: estado ?? this.estado,
    );
  }
}

class Autorizaciones {
  final int? id;
  final String contrasena;
  final String repetirContrasena;
  final int intentos;

  Autorizaciones({
    this.id,
    required this.contrasena,
    required this.repetirContrasena,
    required this.intentos,
  });

  Map<String, dynamic> toMap() {
    return {
      // 'id': id,
      'contrasena': contrasena,
      'repetirContrasena': repetirContrasena,
      'intentos': intentos,
    };
  }

  factory Autorizaciones.fromMap(Map<String, dynamic> map) {
    return Autorizaciones(
      id: map['id'] as int?,
      contrasena: map['contrasena'] as String,
      repetirContrasena: map['repetirContrasena'] as String,
      intentos: map['intentos'] as int? ?? 0, // Asignar 0 si es null
    );
  }

  Autorizaciones copyWith({
    int? id,
    String? contrasena,
    String? repetirContrasena,
    int? intentos,
  }) {
    return Autorizaciones(
      id: id ?? this.id,
      contrasena: contrasena ?? this.contrasena,
      repetirContrasena: repetirContrasena ?? this.repetirContrasena,
      intentos: intentos ?? this.intentos,
    );
  }
}

// models/person_data.dart (o como prefieras llamarlo)
// class PersonData {
//   final String initials;
//   final String name;
//   final int age;
//   final String phone;
//   final List<String> letters; // Para A, E, A, N, A
//   final String totalPercentage;
//   final String totalLabel;

//   PersonData({
//     required this.initials,
//     required this.name,
//     required this.age,
//     required this.phone,
//     required this.letters,
//     this.totalPercentage = "80 %", // Valor por defecto
//     this.totalLabel = "Total", // Valor por defecto
//   });
// }
