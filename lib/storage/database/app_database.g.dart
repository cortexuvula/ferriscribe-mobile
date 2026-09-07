// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ServerConfigsTable extends ServerConfigs
    with TableInfo<$ServerConfigsTable, ServerConfig> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ServerConfigsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _tailscaleHostMeta = const VerificationMeta(
    'tailscaleHost',
  );
  @override
  late final GeneratedColumn<String> tailscaleHost = GeneratedColumn<String>(
    'tailscale_host',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lanHostMeta = const VerificationMeta(
    'lanHost',
  );
  @override
  late final GeneratedColumn<String> lanHost = GeneratedColumn<String>(
    'lan_host',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pairingPortMeta = const VerificationMeta(
    'pairingPort',
  );
  @override
  late final GeneratedColumn<int> pairingPort = GeneratedColumn<int>(
    'pairing_port',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(kDefaultPairingPort),
  );
  static const VerificationMeta _dataPortMeta = const VerificationMeta(
    'dataPort',
  );
  @override
  late final GeneratedColumn<int> dataPort = GeneratedColumn<int>(
    'data_port',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(kDefaultDataPort),
  );
  static const VerificationMeta _pairedAtMeta = const VerificationMeta(
    'pairedAt',
  );
  @override
  late final GeneratedColumn<DateTime> pairedAt = GeneratedColumn<DateTime>(
    'paired_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    label,
    tailscaleHost,
    lanHost,
    pairingPort,
    dataPort,
    pairedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'server_configs';
  @override
  VerificationContext validateIntegrity(
    Insertable<ServerConfig> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    }
    if (data.containsKey('tailscale_host')) {
      context.handle(
        _tailscaleHostMeta,
        tailscaleHost.isAcceptableOrUnknown(
          data['tailscale_host']!,
          _tailscaleHostMeta,
        ),
      );
    }
    if (data.containsKey('lan_host')) {
      context.handle(
        _lanHostMeta,
        lanHost.isAcceptableOrUnknown(data['lan_host']!, _lanHostMeta),
      );
    }
    if (data.containsKey('pairing_port')) {
      context.handle(
        _pairingPortMeta,
        pairingPort.isAcceptableOrUnknown(
          data['pairing_port']!,
          _pairingPortMeta,
        ),
      );
    }
    if (data.containsKey('data_port')) {
      context.handle(
        _dataPortMeta,
        dataPort.isAcceptableOrUnknown(data['data_port']!, _dataPortMeta),
      );
    }
    if (data.containsKey('paired_at')) {
      context.handle(
        _pairedAtMeta,
        pairedAt.isAcceptableOrUnknown(data['paired_at']!, _pairedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_pairedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ServerConfig map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ServerConfig(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      tailscaleHost: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tailscale_host'],
      ),
      lanHost: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lan_host'],
      ),
      pairingPort: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pairing_port'],
      )!,
      dataPort: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}data_port'],
      )!,
      pairedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}paired_at'],
      )!,
    );
  }

  @override
  $ServerConfigsTable createAlias(String alias) {
    return $ServerConfigsTable(attachedDatabase, alias);
  }
}

class ServerConfig extends DataClass implements Insertable<ServerConfig> {
  final int id;
  final String label;
  final String? tailscaleHost;
  final String? lanHost;
  final int pairingPort;
  final int dataPort;
  final DateTime pairedAt;
  const ServerConfig({
    required this.id,
    required this.label,
    this.tailscaleHost,
    this.lanHost,
    required this.pairingPort,
    required this.dataPort,
    required this.pairedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['label'] = Variable<String>(label);
    if (!nullToAbsent || tailscaleHost != null) {
      map['tailscale_host'] = Variable<String>(tailscaleHost);
    }
    if (!nullToAbsent || lanHost != null) {
      map['lan_host'] = Variable<String>(lanHost);
    }
    map['pairing_port'] = Variable<int>(pairingPort);
    map['data_port'] = Variable<int>(dataPort);
    map['paired_at'] = Variable<DateTime>(pairedAt);
    return map;
  }

  ServerConfigsCompanion toCompanion(bool nullToAbsent) {
    return ServerConfigsCompanion(
      id: Value(id),
      label: Value(label),
      tailscaleHost: tailscaleHost == null && nullToAbsent
          ? const Value.absent()
          : Value(tailscaleHost),
      lanHost: lanHost == null && nullToAbsent
          ? const Value.absent()
          : Value(lanHost),
      pairingPort: Value(pairingPort),
      dataPort: Value(dataPort),
      pairedAt: Value(pairedAt),
    );
  }

  factory ServerConfig.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ServerConfig(
      id: serializer.fromJson<int>(json['id']),
      label: serializer.fromJson<String>(json['label']),
      tailscaleHost: serializer.fromJson<String?>(json['tailscaleHost']),
      lanHost: serializer.fromJson<String?>(json['lanHost']),
      pairingPort: serializer.fromJson<int>(json['pairingPort']),
      dataPort: serializer.fromJson<int>(json['dataPort']),
      pairedAt: serializer.fromJson<DateTime>(json['pairedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'label': serializer.toJson<String>(label),
      'tailscaleHost': serializer.toJson<String?>(tailscaleHost),
      'lanHost': serializer.toJson<String?>(lanHost),
      'pairingPort': serializer.toJson<int>(pairingPort),
      'dataPort': serializer.toJson<int>(dataPort),
      'pairedAt': serializer.toJson<DateTime>(pairedAt),
    };
  }

  ServerConfig copyWith({
    int? id,
    String? label,
    Value<String?> tailscaleHost = const Value.absent(),
    Value<String?> lanHost = const Value.absent(),
    int? pairingPort,
    int? dataPort,
    DateTime? pairedAt,
  }) => ServerConfig(
    id: id ?? this.id,
    label: label ?? this.label,
    tailscaleHost: tailscaleHost.present
        ? tailscaleHost.value
        : this.tailscaleHost,
    lanHost: lanHost.present ? lanHost.value : this.lanHost,
    pairingPort: pairingPort ?? this.pairingPort,
    dataPort: dataPort ?? this.dataPort,
    pairedAt: pairedAt ?? this.pairedAt,
  );
  ServerConfig copyWithCompanion(ServerConfigsCompanion data) {
    return ServerConfig(
      id: data.id.present ? data.id.value : this.id,
      label: data.label.present ? data.label.value : this.label,
      tailscaleHost: data.tailscaleHost.present
          ? data.tailscaleHost.value
          : this.tailscaleHost,
      lanHost: data.lanHost.present ? data.lanHost.value : this.lanHost,
      pairingPort: data.pairingPort.present
          ? data.pairingPort.value
          : this.pairingPort,
      dataPort: data.dataPort.present ? data.dataPort.value : this.dataPort,
      pairedAt: data.pairedAt.present ? data.pairedAt.value : this.pairedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ServerConfig(')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('tailscaleHost: $tailscaleHost, ')
          ..write('lanHost: $lanHost, ')
          ..write('pairingPort: $pairingPort, ')
          ..write('dataPort: $dataPort, ')
          ..write('pairedAt: $pairedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    label,
    tailscaleHost,
    lanHost,
    pairingPort,
    dataPort,
    pairedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ServerConfig &&
          other.id == this.id &&
          other.label == this.label &&
          other.tailscaleHost == this.tailscaleHost &&
          other.lanHost == this.lanHost &&
          other.pairingPort == this.pairingPort &&
          other.dataPort == this.dataPort &&
          other.pairedAt == this.pairedAt);
}

class ServerConfigsCompanion extends UpdateCompanion<ServerConfig> {
  final Value<int> id;
  final Value<String> label;
  final Value<String?> tailscaleHost;
  final Value<String?> lanHost;
  final Value<int> pairingPort;
  final Value<int> dataPort;
  final Value<DateTime> pairedAt;
  const ServerConfigsCompanion({
    this.id = const Value.absent(),
    this.label = const Value.absent(),
    this.tailscaleHost = const Value.absent(),
    this.lanHost = const Value.absent(),
    this.pairingPort = const Value.absent(),
    this.dataPort = const Value.absent(),
    this.pairedAt = const Value.absent(),
  });
  ServerConfigsCompanion.insert({
    this.id = const Value.absent(),
    this.label = const Value.absent(),
    this.tailscaleHost = const Value.absent(),
    this.lanHost = const Value.absent(),
    this.pairingPort = const Value.absent(),
    this.dataPort = const Value.absent(),
    required DateTime pairedAt,
  }) : pairedAt = Value(pairedAt);
  static Insertable<ServerConfig> custom({
    Expression<int>? id,
    Expression<String>? label,
    Expression<String>? tailscaleHost,
    Expression<String>? lanHost,
    Expression<int>? pairingPort,
    Expression<int>? dataPort,
    Expression<DateTime>? pairedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (label != null) 'label': label,
      if (tailscaleHost != null) 'tailscale_host': tailscaleHost,
      if (lanHost != null) 'lan_host': lanHost,
      if (pairingPort != null) 'pairing_port': pairingPort,
      if (dataPort != null) 'data_port': dataPort,
      if (pairedAt != null) 'paired_at': pairedAt,
    });
  }

  ServerConfigsCompanion copyWith({
    Value<int>? id,
    Value<String>? label,
    Value<String?>? tailscaleHost,
    Value<String?>? lanHost,
    Value<int>? pairingPort,
    Value<int>? dataPort,
    Value<DateTime>? pairedAt,
  }) {
    return ServerConfigsCompanion(
      id: id ?? this.id,
      label: label ?? this.label,
      tailscaleHost: tailscaleHost ?? this.tailscaleHost,
      lanHost: lanHost ?? this.lanHost,
      pairingPort: pairingPort ?? this.pairingPort,
      dataPort: dataPort ?? this.dataPort,
      pairedAt: pairedAt ?? this.pairedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (tailscaleHost.present) {
      map['tailscale_host'] = Variable<String>(tailscaleHost.value);
    }
    if (lanHost.present) {
      map['lan_host'] = Variable<String>(lanHost.value);
    }
    if (pairingPort.present) {
      map['pairing_port'] = Variable<int>(pairingPort.value);
    }
    if (dataPort.present) {
      map['data_port'] = Variable<int>(dataPort.value);
    }
    if (pairedAt.present) {
      map['paired_at'] = Variable<DateTime>(pairedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ServerConfigsCompanion(')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('tailscaleHost: $tailscaleHost, ')
          ..write('lanHost: $lanHost, ')
          ..write('pairingPort: $pairingPort, ')
          ..write('dataPort: $dataPort, ')
          ..write('pairedAt: $pairedAt')
          ..write(')'))
        .toString();
  }
}

class $CachedRecordingsTable extends CachedRecordings
    with TableInfo<$CachedRecordingsTable, CachedRecording> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedRecordingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filenameMeta = const VerificationMeta(
    'filename',
  );
  @override
  late final GeneratedColumn<String> filename = GeneratedColumn<String>(
    'filename',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _patientNameMeta = const VerificationMeta(
    'patientName',
  );
  @override
  late final GeneratedColumn<String> patientName = GeneratedColumn<String>(
    'patient_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta(
    'durationSeconds',
  );
  @override
  late final GeneratedColumn<double> durationSeconds = GeneratedColumn<double>(
    'duration_seconds',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sttProviderMeta = const VerificationMeta(
    'sttProvider',
  );
  @override
  late final GeneratedColumn<String> sttProvider = GeneratedColumn<String>(
    'stt_provider',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    filename,
    patientName,
    createdAt,
    updatedAt,
    durationSeconds,
    sttProvider,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_recordings';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedRecording> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('filename')) {
      context.handle(
        _filenameMeta,
        filename.isAcceptableOrUnknown(data['filename']!, _filenameMeta),
      );
    } else if (isInserting) {
      context.missing(_filenameMeta);
    }
    if (data.containsKey('patient_name')) {
      context.handle(
        _patientNameMeta,
        patientName.isAcceptableOrUnknown(
          data['patient_name']!,
          _patientNameMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(
          data['duration_seconds']!,
          _durationSecondsMeta,
        ),
      );
    }
    if (data.containsKey('stt_provider')) {
      context.handle(
        _sttProviderMeta,
        sttProvider.isAcceptableOrUnknown(
          data['stt_provider']!,
          _sttProviderMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedRecording map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedRecording(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      filename: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}filename'],
      )!,
      patientName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}patient_name'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      durationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}duration_seconds'],
      ),
      sttProvider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stt_provider'],
      ),
    );
  }

  @override
  $CachedRecordingsTable createAlias(String alias) {
    return $CachedRecordingsTable(attachedDatabase, alias);
  }
}

class CachedRecording extends DataClass implements Insertable<CachedRecording> {
  final String id;
  final String filename;
  final String? patientName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double? durationSeconds;
  final String? sttProvider;
  const CachedRecording({
    required this.id,
    required this.filename,
    this.patientName,
    required this.createdAt,
    required this.updatedAt,
    this.durationSeconds,
    this.sttProvider,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['filename'] = Variable<String>(filename);
    if (!nullToAbsent || patientName != null) {
      map['patient_name'] = Variable<String>(patientName);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || durationSeconds != null) {
      map['duration_seconds'] = Variable<double>(durationSeconds);
    }
    if (!nullToAbsent || sttProvider != null) {
      map['stt_provider'] = Variable<String>(sttProvider);
    }
    return map;
  }

  CachedRecordingsCompanion toCompanion(bool nullToAbsent) {
    return CachedRecordingsCompanion(
      id: Value(id),
      filename: Value(filename),
      patientName: patientName == null && nullToAbsent
          ? const Value.absent()
          : Value(patientName),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      durationSeconds: durationSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(durationSeconds),
      sttProvider: sttProvider == null && nullToAbsent
          ? const Value.absent()
          : Value(sttProvider),
    );
  }

  factory CachedRecording.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedRecording(
      id: serializer.fromJson<String>(json['id']),
      filename: serializer.fromJson<String>(json['filename']),
      patientName: serializer.fromJson<String?>(json['patientName']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      durationSeconds: serializer.fromJson<double?>(json['durationSeconds']),
      sttProvider: serializer.fromJson<String?>(json['sttProvider']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'filename': serializer.toJson<String>(filename),
      'patientName': serializer.toJson<String?>(patientName),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'durationSeconds': serializer.toJson<double?>(durationSeconds),
      'sttProvider': serializer.toJson<String?>(sttProvider),
    };
  }

  CachedRecording copyWith({
    String? id,
    String? filename,
    Value<String?> patientName = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<double?> durationSeconds = const Value.absent(),
    Value<String?> sttProvider = const Value.absent(),
  }) => CachedRecording(
    id: id ?? this.id,
    filename: filename ?? this.filename,
    patientName: patientName.present ? patientName.value : this.patientName,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    durationSeconds: durationSeconds.present
        ? durationSeconds.value
        : this.durationSeconds,
    sttProvider: sttProvider.present ? sttProvider.value : this.sttProvider,
  );
  CachedRecording copyWithCompanion(CachedRecordingsCompanion data) {
    return CachedRecording(
      id: data.id.present ? data.id.value : this.id,
      filename: data.filename.present ? data.filename.value : this.filename,
      patientName: data.patientName.present
          ? data.patientName.value
          : this.patientName,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      sttProvider: data.sttProvider.present
          ? data.sttProvider.value
          : this.sttProvider,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedRecording(')
          ..write('id: $id, ')
          ..write('filename: $filename, ')
          ..write('patientName: $patientName, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('sttProvider: $sttProvider')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    filename,
    patientName,
    createdAt,
    updatedAt,
    durationSeconds,
    sttProvider,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedRecording &&
          other.id == this.id &&
          other.filename == this.filename &&
          other.patientName == this.patientName &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.durationSeconds == this.durationSeconds &&
          other.sttProvider == this.sttProvider);
}

class CachedRecordingsCompanion extends UpdateCompanion<CachedRecording> {
  final Value<String> id;
  final Value<String> filename;
  final Value<String?> patientName;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<double?> durationSeconds;
  final Value<String?> sttProvider;
  final Value<int> rowid;
  const CachedRecordingsCompanion({
    this.id = const Value.absent(),
    this.filename = const Value.absent(),
    this.patientName = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.sttProvider = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedRecordingsCompanion.insert({
    required String id,
    required String filename,
    this.patientName = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.durationSeconds = const Value.absent(),
    this.sttProvider = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       filename = Value(filename),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<CachedRecording> custom({
    Expression<String>? id,
    Expression<String>? filename,
    Expression<String>? patientName,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<double>? durationSeconds,
    Expression<String>? sttProvider,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (filename != null) 'filename': filename,
      if (patientName != null) 'patient_name': patientName,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (sttProvider != null) 'stt_provider': sttProvider,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedRecordingsCompanion copyWith({
    Value<String>? id,
    Value<String>? filename,
    Value<String?>? patientName,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<double?>? durationSeconds,
    Value<String?>? sttProvider,
    Value<int>? rowid,
  }) {
    return CachedRecordingsCompanion(
      id: id ?? this.id,
      filename: filename ?? this.filename,
      patientName: patientName ?? this.patientName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      sttProvider: sttProvider ?? this.sttProvider,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (filename.present) {
      map['filename'] = Variable<String>(filename.value);
    }
    if (patientName.present) {
      map['patient_name'] = Variable<String>(patientName.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<double>(durationSeconds.value);
    }
    if (sttProvider.present) {
      map['stt_provider'] = Variable<String>(sttProvider.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedRecordingsCompanion(')
          ..write('id: $id, ')
          ..write('filename: $filename, ')
          ..write('patientName: $patientName, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('sttProvider: $sttProvider, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedDocumentsTable extends CachedDocuments
    with TableInfo<$CachedDocumentsTable, CachedDocument> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedDocumentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _recordingIdMeta = const VerificationMeta(
    'recordingId',
  );
  @override
  late final GeneratedColumn<String> recordingId = GeneratedColumn<String>(
    'recording_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _docTypeMeta = const VerificationMeta(
    'docType',
  );
  @override
  late final GeneratedColumn<String> docType = GeneratedColumn<String>(
    'doc_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    recordingId,
    docType,
    content,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_documents';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedDocument> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('recording_id')) {
      context.handle(
        _recordingIdMeta,
        recordingId.isAcceptableOrUnknown(
          data['recording_id']!,
          _recordingIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recordingIdMeta);
    }
    if (data.containsKey('doc_type')) {
      context.handle(
        _docTypeMeta,
        docType.isAcceptableOrUnknown(data['doc_type']!, _docTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_docTypeMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {recordingId, docType};
  @override
  CachedDocument map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedDocument(
      recordingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recording_id'],
      )!,
      docType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}doc_type'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CachedDocumentsTable createAlias(String alias) {
    return $CachedDocumentsTable(attachedDatabase, alias);
  }
}

class CachedDocument extends DataClass implements Insertable<CachedDocument> {
  final String recordingId;
  final String docType;
  final String content;
  final DateTime updatedAt;
  const CachedDocument({
    required this.recordingId,
    required this.docType,
    required this.content,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['recording_id'] = Variable<String>(recordingId);
    map['doc_type'] = Variable<String>(docType);
    map['content'] = Variable<String>(content);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CachedDocumentsCompanion toCompanion(bool nullToAbsent) {
    return CachedDocumentsCompanion(
      recordingId: Value(recordingId),
      docType: Value(docType),
      content: Value(content),
      updatedAt: Value(updatedAt),
    );
  }

  factory CachedDocument.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedDocument(
      recordingId: serializer.fromJson<String>(json['recordingId']),
      docType: serializer.fromJson<String>(json['docType']),
      content: serializer.fromJson<String>(json['content']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'recordingId': serializer.toJson<String>(recordingId),
      'docType': serializer.toJson<String>(docType),
      'content': serializer.toJson<String>(content),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CachedDocument copyWith({
    String? recordingId,
    String? docType,
    String? content,
    DateTime? updatedAt,
  }) => CachedDocument(
    recordingId: recordingId ?? this.recordingId,
    docType: docType ?? this.docType,
    content: content ?? this.content,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CachedDocument copyWithCompanion(CachedDocumentsCompanion data) {
    return CachedDocument(
      recordingId: data.recordingId.present
          ? data.recordingId.value
          : this.recordingId,
      docType: data.docType.present ? data.docType.value : this.docType,
      content: data.content.present ? data.content.value : this.content,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedDocument(')
          ..write('recordingId: $recordingId, ')
          ..write('docType: $docType, ')
          ..write('content: $content, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(recordingId, docType, content, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedDocument &&
          other.recordingId == this.recordingId &&
          other.docType == this.docType &&
          other.content == this.content &&
          other.updatedAt == this.updatedAt);
}

class CachedDocumentsCompanion extends UpdateCompanion<CachedDocument> {
  final Value<String> recordingId;
  final Value<String> docType;
  final Value<String> content;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CachedDocumentsCompanion({
    this.recordingId = const Value.absent(),
    this.docType = const Value.absent(),
    this.content = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedDocumentsCompanion.insert({
    required String recordingId,
    required String docType,
    required String content,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : recordingId = Value(recordingId),
       docType = Value(docType),
       content = Value(content),
       updatedAt = Value(updatedAt);
  static Insertable<CachedDocument> custom({
    Expression<String>? recordingId,
    Expression<String>? docType,
    Expression<String>? content,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (recordingId != null) 'recording_id': recordingId,
      if (docType != null) 'doc_type': docType,
      if (content != null) 'content': content,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedDocumentsCompanion copyWith({
    Value<String>? recordingId,
    Value<String>? docType,
    Value<String>? content,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CachedDocumentsCompanion(
      recordingId: recordingId ?? this.recordingId,
      docType: docType ?? this.docType,
      content: content ?? this.content,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (recordingId.present) {
      map['recording_id'] = Variable<String>(recordingId.value);
    }
    if (docType.present) {
      map['doc_type'] = Variable<String>(docType.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedDocumentsCompanion(')
          ..write('recordingId: $recordingId, ')
          ..write('docType: $docType, ')
          ..write('content: $content, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PatientContextsTable extends PatientContexts
    with TableInfo<$PatientContextsTable, PatientContext> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PatientContextsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _recordingIdMeta = const VerificationMeta(
    'recordingId',
  );
  @override
  late final GeneratedColumn<String> recordingId = GeneratedColumn<String>(
    'recording_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _patientNameMeta = const VerificationMeta(
    'patientName',
  );
  @override
  late final GeneratedColumn<String> patientName = GeneratedColumn<String>(
    'patient_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _medicationsJsonMeta = const VerificationMeta(
    'medicationsJson',
  );
  @override
  late final GeneratedColumn<String> medicationsJson = GeneratedColumn<String>(
    'medications_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _conditionsJsonMeta = const VerificationMeta(
    'conditionsJson',
  );
  @override
  late final GeneratedColumn<String> conditionsJson = GeneratedColumn<String>(
    'conditions_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _allergiesJsonMeta = const VerificationMeta(
    'allergiesJson',
  );
  @override
  late final GeneratedColumn<String> allergiesJson = GeneratedColumn<String>(
    'allergies_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _priorSoapNotesJsonMeta =
      const VerificationMeta('priorSoapNotesJson');
  @override
  late final GeneratedColumn<String> priorSoapNotesJson =
      GeneratedColumn<String>(
        'prior_soap_notes_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  @override
  List<GeneratedColumn> get $columns => [
    recordingId,
    patientName,
    medicationsJson,
    conditionsJson,
    allergiesJson,
    priorSoapNotesJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'patient_contexts';
  @override
  VerificationContext validateIntegrity(
    Insertable<PatientContext> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('recording_id')) {
      context.handle(
        _recordingIdMeta,
        recordingId.isAcceptableOrUnknown(
          data['recording_id']!,
          _recordingIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recordingIdMeta);
    }
    if (data.containsKey('patient_name')) {
      context.handle(
        _patientNameMeta,
        patientName.isAcceptableOrUnknown(
          data['patient_name']!,
          _patientNameMeta,
        ),
      );
    }
    if (data.containsKey('medications_json')) {
      context.handle(
        _medicationsJsonMeta,
        medicationsJson.isAcceptableOrUnknown(
          data['medications_json']!,
          _medicationsJsonMeta,
        ),
      );
    }
    if (data.containsKey('conditions_json')) {
      context.handle(
        _conditionsJsonMeta,
        conditionsJson.isAcceptableOrUnknown(
          data['conditions_json']!,
          _conditionsJsonMeta,
        ),
      );
    }
    if (data.containsKey('allergies_json')) {
      context.handle(
        _allergiesJsonMeta,
        allergiesJson.isAcceptableOrUnknown(
          data['allergies_json']!,
          _allergiesJsonMeta,
        ),
      );
    }
    if (data.containsKey('prior_soap_notes_json')) {
      context.handle(
        _priorSoapNotesJsonMeta,
        priorSoapNotesJson.isAcceptableOrUnknown(
          data['prior_soap_notes_json']!,
          _priorSoapNotesJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {recordingId};
  @override
  PatientContext map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PatientContext(
      recordingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recording_id'],
      )!,
      patientName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}patient_name'],
      ),
      medicationsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}medications_json'],
      )!,
      conditionsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conditions_json'],
      )!,
      allergiesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}allergies_json'],
      )!,
      priorSoapNotesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prior_soap_notes_json'],
      )!,
    );
  }

  @override
  $PatientContextsTable createAlias(String alias) {
    return $PatientContextsTable(attachedDatabase, alias);
  }
}

class PatientContext extends DataClass implements Insertable<PatientContext> {
  final String recordingId;
  final String? patientName;
  final String medicationsJson;
  final String conditionsJson;
  final String allergiesJson;
  final String priorSoapNotesJson;
  const PatientContext({
    required this.recordingId,
    this.patientName,
    required this.medicationsJson,
    required this.conditionsJson,
    required this.allergiesJson,
    required this.priorSoapNotesJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['recording_id'] = Variable<String>(recordingId);
    if (!nullToAbsent || patientName != null) {
      map['patient_name'] = Variable<String>(patientName);
    }
    map['medications_json'] = Variable<String>(medicationsJson);
    map['conditions_json'] = Variable<String>(conditionsJson);
    map['allergies_json'] = Variable<String>(allergiesJson);
    map['prior_soap_notes_json'] = Variable<String>(priorSoapNotesJson);
    return map;
  }

  PatientContextsCompanion toCompanion(bool nullToAbsent) {
    return PatientContextsCompanion(
      recordingId: Value(recordingId),
      patientName: patientName == null && nullToAbsent
          ? const Value.absent()
          : Value(patientName),
      medicationsJson: Value(medicationsJson),
      conditionsJson: Value(conditionsJson),
      allergiesJson: Value(allergiesJson),
      priorSoapNotesJson: Value(priorSoapNotesJson),
    );
  }

  factory PatientContext.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PatientContext(
      recordingId: serializer.fromJson<String>(json['recordingId']),
      patientName: serializer.fromJson<String?>(json['patientName']),
      medicationsJson: serializer.fromJson<String>(json['medicationsJson']),
      conditionsJson: serializer.fromJson<String>(json['conditionsJson']),
      allergiesJson: serializer.fromJson<String>(json['allergiesJson']),
      priorSoapNotesJson: serializer.fromJson<String>(
        json['priorSoapNotesJson'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'recordingId': serializer.toJson<String>(recordingId),
      'patientName': serializer.toJson<String?>(patientName),
      'medicationsJson': serializer.toJson<String>(medicationsJson),
      'conditionsJson': serializer.toJson<String>(conditionsJson),
      'allergiesJson': serializer.toJson<String>(allergiesJson),
      'priorSoapNotesJson': serializer.toJson<String>(priorSoapNotesJson),
    };
  }

  PatientContext copyWith({
    String? recordingId,
    Value<String?> patientName = const Value.absent(),
    String? medicationsJson,
    String? conditionsJson,
    String? allergiesJson,
    String? priorSoapNotesJson,
  }) => PatientContext(
    recordingId: recordingId ?? this.recordingId,
    patientName: patientName.present ? patientName.value : this.patientName,
    medicationsJson: medicationsJson ?? this.medicationsJson,
    conditionsJson: conditionsJson ?? this.conditionsJson,
    allergiesJson: allergiesJson ?? this.allergiesJson,
    priorSoapNotesJson: priorSoapNotesJson ?? this.priorSoapNotesJson,
  );
  PatientContext copyWithCompanion(PatientContextsCompanion data) {
    return PatientContext(
      recordingId: data.recordingId.present
          ? data.recordingId.value
          : this.recordingId,
      patientName: data.patientName.present
          ? data.patientName.value
          : this.patientName,
      medicationsJson: data.medicationsJson.present
          ? data.medicationsJson.value
          : this.medicationsJson,
      conditionsJson: data.conditionsJson.present
          ? data.conditionsJson.value
          : this.conditionsJson,
      allergiesJson: data.allergiesJson.present
          ? data.allergiesJson.value
          : this.allergiesJson,
      priorSoapNotesJson: data.priorSoapNotesJson.present
          ? data.priorSoapNotesJson.value
          : this.priorSoapNotesJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PatientContext(')
          ..write('recordingId: $recordingId, ')
          ..write('patientName: $patientName, ')
          ..write('medicationsJson: $medicationsJson, ')
          ..write('conditionsJson: $conditionsJson, ')
          ..write('allergiesJson: $allergiesJson, ')
          ..write('priorSoapNotesJson: $priorSoapNotesJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    recordingId,
    patientName,
    medicationsJson,
    conditionsJson,
    allergiesJson,
    priorSoapNotesJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PatientContext &&
          other.recordingId == this.recordingId &&
          other.patientName == this.patientName &&
          other.medicationsJson == this.medicationsJson &&
          other.conditionsJson == this.conditionsJson &&
          other.allergiesJson == this.allergiesJson &&
          other.priorSoapNotesJson == this.priorSoapNotesJson);
}

class PatientContextsCompanion extends UpdateCompanion<PatientContext> {
  final Value<String> recordingId;
  final Value<String?> patientName;
  final Value<String> medicationsJson;
  final Value<String> conditionsJson;
  final Value<String> allergiesJson;
  final Value<String> priorSoapNotesJson;
  final Value<int> rowid;
  const PatientContextsCompanion({
    this.recordingId = const Value.absent(),
    this.patientName = const Value.absent(),
    this.medicationsJson = const Value.absent(),
    this.conditionsJson = const Value.absent(),
    this.allergiesJson = const Value.absent(),
    this.priorSoapNotesJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PatientContextsCompanion.insert({
    required String recordingId,
    this.patientName = const Value.absent(),
    this.medicationsJson = const Value.absent(),
    this.conditionsJson = const Value.absent(),
    this.allergiesJson = const Value.absent(),
    this.priorSoapNotesJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : recordingId = Value(recordingId);
  static Insertable<PatientContext> custom({
    Expression<String>? recordingId,
    Expression<String>? patientName,
    Expression<String>? medicationsJson,
    Expression<String>? conditionsJson,
    Expression<String>? allergiesJson,
    Expression<String>? priorSoapNotesJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (recordingId != null) 'recording_id': recordingId,
      if (patientName != null) 'patient_name': patientName,
      if (medicationsJson != null) 'medications_json': medicationsJson,
      if (conditionsJson != null) 'conditions_json': conditionsJson,
      if (allergiesJson != null) 'allergies_json': allergiesJson,
      if (priorSoapNotesJson != null)
        'prior_soap_notes_json': priorSoapNotesJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PatientContextsCompanion copyWith({
    Value<String>? recordingId,
    Value<String?>? patientName,
    Value<String>? medicationsJson,
    Value<String>? conditionsJson,
    Value<String>? allergiesJson,
    Value<String>? priorSoapNotesJson,
    Value<int>? rowid,
  }) {
    return PatientContextsCompanion(
      recordingId: recordingId ?? this.recordingId,
      patientName: patientName ?? this.patientName,
      medicationsJson: medicationsJson ?? this.medicationsJson,
      conditionsJson: conditionsJson ?? this.conditionsJson,
      allergiesJson: allergiesJson ?? this.allergiesJson,
      priorSoapNotesJson: priorSoapNotesJson ?? this.priorSoapNotesJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (recordingId.present) {
      map['recording_id'] = Variable<String>(recordingId.value);
    }
    if (patientName.present) {
      map['patient_name'] = Variable<String>(patientName.value);
    }
    if (medicationsJson.present) {
      map['medications_json'] = Variable<String>(medicationsJson.value);
    }
    if (conditionsJson.present) {
      map['conditions_json'] = Variable<String>(conditionsJson.value);
    }
    if (allergiesJson.present) {
      map['allergies_json'] = Variable<String>(allergiesJson.value);
    }
    if (priorSoapNotesJson.present) {
      map['prior_soap_notes_json'] = Variable<String>(priorSoapNotesJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PatientContextsCompanion(')
          ..write('recordingId: $recordingId, ')
          ..write('patientName: $patientName, ')
          ..write('medicationsJson: $medicationsJson, ')
          ..write('conditionsJson: $conditionsJson, ')
          ..write('allergiesJson: $allergiesJson, ')
          ..write('priorSoapNotesJson: $priorSoapNotesJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ServerConfigsTable serverConfigs = $ServerConfigsTable(this);
  late final $CachedRecordingsTable cachedRecordings = $CachedRecordingsTable(
    this,
  );
  late final $CachedDocumentsTable cachedDocuments = $CachedDocumentsTable(
    this,
  );
  late final $PatientContextsTable patientContexts = $PatientContextsTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    serverConfigs,
    cachedRecordings,
    cachedDocuments,
    patientContexts,
  ];
}

typedef $$ServerConfigsTableCreateCompanionBuilder =
    ServerConfigsCompanion Function({
      Value<int> id,
      Value<String> label,
      Value<String?> tailscaleHost,
      Value<String?> lanHost,
      Value<int> pairingPort,
      Value<int> dataPort,
      required DateTime pairedAt,
    });
typedef $$ServerConfigsTableUpdateCompanionBuilder =
    ServerConfigsCompanion Function({
      Value<int> id,
      Value<String> label,
      Value<String?> tailscaleHost,
      Value<String?> lanHost,
      Value<int> pairingPort,
      Value<int> dataPort,
      Value<DateTime> pairedAt,
    });

class $$ServerConfigsTableFilterComposer
    extends Composer<_$AppDatabase, $ServerConfigsTable> {
  $$ServerConfigsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tailscaleHost => $composableBuilder(
    column: $table.tailscaleHost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lanHost => $composableBuilder(
    column: $table.lanHost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pairingPort => $composableBuilder(
    column: $table.pairingPort,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dataPort => $composableBuilder(
    column: $table.dataPort,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get pairedAt => $composableBuilder(
    column: $table.pairedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ServerConfigsTableOrderingComposer
    extends Composer<_$AppDatabase, $ServerConfigsTable> {
  $$ServerConfigsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tailscaleHost => $composableBuilder(
    column: $table.tailscaleHost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lanHost => $composableBuilder(
    column: $table.lanHost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pairingPort => $composableBuilder(
    column: $table.pairingPort,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dataPort => $composableBuilder(
    column: $table.dataPort,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get pairedAt => $composableBuilder(
    column: $table.pairedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ServerConfigsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ServerConfigsTable> {
  $$ServerConfigsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get tailscaleHost => $composableBuilder(
    column: $table.tailscaleHost,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lanHost =>
      $composableBuilder(column: $table.lanHost, builder: (column) => column);

  GeneratedColumn<int> get pairingPort => $composableBuilder(
    column: $table.pairingPort,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dataPort =>
      $composableBuilder(column: $table.dataPort, builder: (column) => column);

  GeneratedColumn<DateTime> get pairedAt =>
      $composableBuilder(column: $table.pairedAt, builder: (column) => column);
}

class $$ServerConfigsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ServerConfigsTable,
          ServerConfig,
          $$ServerConfigsTableFilterComposer,
          $$ServerConfigsTableOrderingComposer,
          $$ServerConfigsTableAnnotationComposer,
          $$ServerConfigsTableCreateCompanionBuilder,
          $$ServerConfigsTableUpdateCompanionBuilder,
          (
            ServerConfig,
            BaseReferences<_$AppDatabase, $ServerConfigsTable, ServerConfig>,
          ),
          ServerConfig,
          PrefetchHooks Function()
        > {
  $$ServerConfigsTableTableManager(_$AppDatabase db, $ServerConfigsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ServerConfigsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ServerConfigsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ServerConfigsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<String?> tailscaleHost = const Value.absent(),
                Value<String?> lanHost = const Value.absent(),
                Value<int> pairingPort = const Value.absent(),
                Value<int> dataPort = const Value.absent(),
                Value<DateTime> pairedAt = const Value.absent(),
              }) => ServerConfigsCompanion(
                id: id,
                label: label,
                tailscaleHost: tailscaleHost,
                lanHost: lanHost,
                pairingPort: pairingPort,
                dataPort: dataPort,
                pairedAt: pairedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<String?> tailscaleHost = const Value.absent(),
                Value<String?> lanHost = const Value.absent(),
                Value<int> pairingPort = const Value.absent(),
                Value<int> dataPort = const Value.absent(),
                required DateTime pairedAt,
              }) => ServerConfigsCompanion.insert(
                id: id,
                label: label,
                tailscaleHost: tailscaleHost,
                lanHost: lanHost,
                pairingPort: pairingPort,
                dataPort: dataPort,
                pairedAt: pairedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ServerConfigsTable, ServerConfig>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ServerConfigsTable,
                    ServerConfig
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ServerConfigsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ServerConfigsTable,
      ServerConfig,
      $$ServerConfigsTableFilterComposer,
      $$ServerConfigsTableOrderingComposer,
      $$ServerConfigsTableAnnotationComposer,
      $$ServerConfigsTableCreateCompanionBuilder,
      $$ServerConfigsTableUpdateCompanionBuilder,
      (
        ServerConfig,
        BaseReferences<_$AppDatabase, $ServerConfigsTable, ServerConfig>,
      ),
      ServerConfig,
      PrefetchHooks Function()
    >;
typedef $$CachedRecordingsTableCreateCompanionBuilder =
    CachedRecordingsCompanion Function({
      required String id,
      required String filename,
      Value<String?> patientName,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<double?> durationSeconds,
      Value<String?> sttProvider,
      Value<int> rowid,
    });
typedef $$CachedRecordingsTableUpdateCompanionBuilder =
    CachedRecordingsCompanion Function({
      Value<String> id,
      Value<String> filename,
      Value<String?> patientName,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<double?> durationSeconds,
      Value<String?> sttProvider,
      Value<int> rowid,
    });

class $$CachedRecordingsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedRecordingsTable> {
  $$CachedRecordingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filename => $composableBuilder(
    column: $table.filename,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get patientName => $composableBuilder(
    column: $table.patientName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sttProvider => $composableBuilder(
    column: $table.sttProvider,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedRecordingsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedRecordingsTable> {
  $$CachedRecordingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filename => $composableBuilder(
    column: $table.filename,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get patientName => $composableBuilder(
    column: $table.patientName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sttProvider => $composableBuilder(
    column: $table.sttProvider,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedRecordingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedRecordingsTable> {
  $$CachedRecordingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get filename =>
      $composableBuilder(column: $table.filename, builder: (column) => column);

  GeneratedColumn<String> get patientName => $composableBuilder(
    column: $table.patientName,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<double> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sttProvider => $composableBuilder(
    column: $table.sttProvider,
    builder: (column) => column,
  );
}

class $$CachedRecordingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedRecordingsTable,
          CachedRecording,
          $$CachedRecordingsTableFilterComposer,
          $$CachedRecordingsTableOrderingComposer,
          $$CachedRecordingsTableAnnotationComposer,
          $$CachedRecordingsTableCreateCompanionBuilder,
          $$CachedRecordingsTableUpdateCompanionBuilder,
          (
            CachedRecording,
            BaseReferences<
              _$AppDatabase,
              $CachedRecordingsTable,
              CachedRecording
            >,
          ),
          CachedRecording,
          PrefetchHooks Function()
        > {
  $$CachedRecordingsTableTableManager(
    _$AppDatabase db,
    $CachedRecordingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedRecordingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedRecordingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedRecordingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> filename = const Value.absent(),
                Value<String?> patientName = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<double?> durationSeconds = const Value.absent(),
                Value<String?> sttProvider = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedRecordingsCompanion(
                id: id,
                filename: filename,
                patientName: patientName,
                createdAt: createdAt,
                updatedAt: updatedAt,
                durationSeconds: durationSeconds,
                sttProvider: sttProvider,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String filename,
                Value<String?> patientName = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<double?> durationSeconds = const Value.absent(),
                Value<String?> sttProvider = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedRecordingsCompanion.insert(
                id: id,
                filename: filename,
                patientName: patientName,
                createdAt: createdAt,
                updatedAt: updatedAt,
                durationSeconds: durationSeconds,
                sttProvider: sttProvider,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CachedRecordingsTable, CachedRecording>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $CachedRecordingsTable,
                    CachedRecording
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedRecordingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedRecordingsTable,
      CachedRecording,
      $$CachedRecordingsTableFilterComposer,
      $$CachedRecordingsTableOrderingComposer,
      $$CachedRecordingsTableAnnotationComposer,
      $$CachedRecordingsTableCreateCompanionBuilder,
      $$CachedRecordingsTableUpdateCompanionBuilder,
      (
        CachedRecording,
        BaseReferences<_$AppDatabase, $CachedRecordingsTable, CachedRecording>,
      ),
      CachedRecording,
      PrefetchHooks Function()
    >;
typedef $$CachedDocumentsTableCreateCompanionBuilder =
    CachedDocumentsCompanion Function({
      required String recordingId,
      required String docType,
      required String content,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$CachedDocumentsTableUpdateCompanionBuilder =
    CachedDocumentsCompanion Function({
      Value<String> recordingId,
      Value<String> docType,
      Value<String> content,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$CachedDocumentsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedDocumentsTable> {
  $$CachedDocumentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get recordingId => $composableBuilder(
    column: $table.recordingId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get docType => $composableBuilder(
    column: $table.docType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedDocumentsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedDocumentsTable> {
  $$CachedDocumentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get recordingId => $composableBuilder(
    column: $table.recordingId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get docType => $composableBuilder(
    column: $table.docType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedDocumentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedDocumentsTable> {
  $$CachedDocumentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get recordingId => $composableBuilder(
    column: $table.recordingId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get docType =>
      $composableBuilder(column: $table.docType, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CachedDocumentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedDocumentsTable,
          CachedDocument,
          $$CachedDocumentsTableFilterComposer,
          $$CachedDocumentsTableOrderingComposer,
          $$CachedDocumentsTableAnnotationComposer,
          $$CachedDocumentsTableCreateCompanionBuilder,
          $$CachedDocumentsTableUpdateCompanionBuilder,
          (
            CachedDocument,
            BaseReferences<
              _$AppDatabase,
              $CachedDocumentsTable,
              CachedDocument
            >,
          ),
          CachedDocument,
          PrefetchHooks Function()
        > {
  $$CachedDocumentsTableTableManager(
    _$AppDatabase db,
    $CachedDocumentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedDocumentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedDocumentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedDocumentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> recordingId = const Value.absent(),
                Value<String> docType = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedDocumentsCompanion(
                recordingId: recordingId,
                docType: docType,
                content: content,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String recordingId,
                required String docType,
                required String content,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedDocumentsCompanion.insert(
                recordingId: recordingId,
                docType: docType,
                content: content,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CachedDocumentsTable, CachedDocument>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $CachedDocumentsTable,
                    CachedDocument
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedDocumentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedDocumentsTable,
      CachedDocument,
      $$CachedDocumentsTableFilterComposer,
      $$CachedDocumentsTableOrderingComposer,
      $$CachedDocumentsTableAnnotationComposer,
      $$CachedDocumentsTableCreateCompanionBuilder,
      $$CachedDocumentsTableUpdateCompanionBuilder,
      (
        CachedDocument,
        BaseReferences<_$AppDatabase, $CachedDocumentsTable, CachedDocument>,
      ),
      CachedDocument,
      PrefetchHooks Function()
    >;
typedef $$PatientContextsTableCreateCompanionBuilder =
    PatientContextsCompanion Function({
      required String recordingId,
      Value<String?> patientName,
      Value<String> medicationsJson,
      Value<String> conditionsJson,
      Value<String> allergiesJson,
      Value<String> priorSoapNotesJson,
      Value<int> rowid,
    });
typedef $$PatientContextsTableUpdateCompanionBuilder =
    PatientContextsCompanion Function({
      Value<String> recordingId,
      Value<String?> patientName,
      Value<String> medicationsJson,
      Value<String> conditionsJson,
      Value<String> allergiesJson,
      Value<String> priorSoapNotesJson,
      Value<int> rowid,
    });

class $$PatientContextsTableFilterComposer
    extends Composer<_$AppDatabase, $PatientContextsTable> {
  $$PatientContextsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get recordingId => $composableBuilder(
    column: $table.recordingId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get patientName => $composableBuilder(
    column: $table.patientName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get medicationsJson => $composableBuilder(
    column: $table.medicationsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conditionsJson => $composableBuilder(
    column: $table.conditionsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get allergiesJson => $composableBuilder(
    column: $table.allergiesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get priorSoapNotesJson => $composableBuilder(
    column: $table.priorSoapNotesJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PatientContextsTableOrderingComposer
    extends Composer<_$AppDatabase, $PatientContextsTable> {
  $$PatientContextsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get recordingId => $composableBuilder(
    column: $table.recordingId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get patientName => $composableBuilder(
    column: $table.patientName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get medicationsJson => $composableBuilder(
    column: $table.medicationsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conditionsJson => $composableBuilder(
    column: $table.conditionsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get allergiesJson => $composableBuilder(
    column: $table.allergiesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get priorSoapNotesJson => $composableBuilder(
    column: $table.priorSoapNotesJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PatientContextsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PatientContextsTable> {
  $$PatientContextsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get recordingId => $composableBuilder(
    column: $table.recordingId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get patientName => $composableBuilder(
    column: $table.patientName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get medicationsJson => $composableBuilder(
    column: $table.medicationsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get conditionsJson => $composableBuilder(
    column: $table.conditionsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get allergiesJson => $composableBuilder(
    column: $table.allergiesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get priorSoapNotesJson => $composableBuilder(
    column: $table.priorSoapNotesJson,
    builder: (column) => column,
  );
}

class $$PatientContextsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PatientContextsTable,
          PatientContext,
          $$PatientContextsTableFilterComposer,
          $$PatientContextsTableOrderingComposer,
          $$PatientContextsTableAnnotationComposer,
          $$PatientContextsTableCreateCompanionBuilder,
          $$PatientContextsTableUpdateCompanionBuilder,
          (
            PatientContext,
            BaseReferences<
              _$AppDatabase,
              $PatientContextsTable,
              PatientContext
            >,
          ),
          PatientContext,
          PrefetchHooks Function()
        > {
  $$PatientContextsTableTableManager(
    _$AppDatabase db,
    $PatientContextsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PatientContextsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PatientContextsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PatientContextsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> recordingId = const Value.absent(),
                Value<String?> patientName = const Value.absent(),
                Value<String> medicationsJson = const Value.absent(),
                Value<String> conditionsJson = const Value.absent(),
                Value<String> allergiesJson = const Value.absent(),
                Value<String> priorSoapNotesJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PatientContextsCompanion(
                recordingId: recordingId,
                patientName: patientName,
                medicationsJson: medicationsJson,
                conditionsJson: conditionsJson,
                allergiesJson: allergiesJson,
                priorSoapNotesJson: priorSoapNotesJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String recordingId,
                Value<String?> patientName = const Value.absent(),
                Value<String> medicationsJson = const Value.absent(),
                Value<String> conditionsJson = const Value.absent(),
                Value<String> allergiesJson = const Value.absent(),
                Value<String> priorSoapNotesJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PatientContextsCompanion.insert(
                recordingId: recordingId,
                patientName: patientName,
                medicationsJson: medicationsJson,
                conditionsJson: conditionsJson,
                allergiesJson: allergiesJson,
                priorSoapNotesJson: priorSoapNotesJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PatientContextsTable, PatientContext>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $PatientContextsTable,
                    PatientContext
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PatientContextsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PatientContextsTable,
      PatientContext,
      $$PatientContextsTableFilterComposer,
      $$PatientContextsTableOrderingComposer,
      $$PatientContextsTableAnnotationComposer,
      $$PatientContextsTableCreateCompanionBuilder,
      $$PatientContextsTableUpdateCompanionBuilder,
      (
        PatientContext,
        BaseReferences<_$AppDatabase, $PatientContextsTable, PatientContext>,
      ),
      PatientContext,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ServerConfigsTableTableManager get serverConfigs =>
      $$ServerConfigsTableTableManager(_db, _db.serverConfigs);
  $$CachedRecordingsTableTableManager get cachedRecordings =>
      $$CachedRecordingsTableTableManager(_db, _db.cachedRecordings);
  $$CachedDocumentsTableTableManager get cachedDocuments =>
      $$CachedDocumentsTableTableManager(_db, _db.cachedDocuments);
  $$PatientContextsTableTableManager get patientContexts =>
      $$PatientContextsTableTableManager(_db, _db.patientContexts);
}
