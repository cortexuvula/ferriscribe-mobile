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

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ServerConfigsTable serverConfigs = $ServerConfigsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [serverConfigs];
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

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ServerConfigsTableTableManager get serverConfigs =>
      $$ServerConfigsTableTableManager(_db, _db.serverConfigs);
}
