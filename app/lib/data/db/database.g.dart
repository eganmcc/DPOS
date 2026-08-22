// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $CatalogCacheTable extends CatalogCache
    with TableInfo<$CatalogCacheTable, CatalogCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CatalogCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _outletIdMeta =
      const VerificationMeta('outletId');
  @override
  late final GeneratedColumn<String> outletId = GeneratedColumn<String>(
      'outlet_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadMeta =
      const VerificationMeta('payload');
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
      'payload', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [outletId, payload, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'catalog_cache';
  @override
  VerificationContext validateIntegrity(Insertable<CatalogCacheData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('outlet_id')) {
      context.handle(_outletIdMeta,
          outletId.isAcceptableOrUnknown(data['outlet_id']!, _outletIdMeta));
    } else if (isInserting) {
      context.missing(_outletIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta,
          payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {outletId};
  @override
  CatalogCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CatalogCacheData(
      outletId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}outlet_id'])!,
      payload: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $CatalogCacheTable createAlias(String alias) {
    return $CatalogCacheTable(attachedDatabase, alias);
  }
}

class CatalogCacheData extends DataClass
    implements Insertable<CatalogCacheData> {
  final String outletId;
  final String payload;
  final DateTime updatedAt;
  const CatalogCacheData(
      {required this.outletId, required this.payload, required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['outlet_id'] = Variable<String>(outletId);
    map['payload'] = Variable<String>(payload);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CatalogCacheCompanion toCompanion(bool nullToAbsent) {
    return CatalogCacheCompanion(
      outletId: Value(outletId),
      payload: Value(payload),
      updatedAt: Value(updatedAt),
    );
  }

  factory CatalogCacheData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CatalogCacheData(
      outletId: serializer.fromJson<String>(json['outletId']),
      payload: serializer.fromJson<String>(json['payload']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'outletId': serializer.toJson<String>(outletId),
      'payload': serializer.toJson<String>(payload),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CatalogCacheData copyWith(
          {String? outletId, String? payload, DateTime? updatedAt}) =>
      CatalogCacheData(
        outletId: outletId ?? this.outletId,
        payload: payload ?? this.payload,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  CatalogCacheData copyWithCompanion(CatalogCacheCompanion data) {
    return CatalogCacheData(
      outletId: data.outletId.present ? data.outletId.value : this.outletId,
      payload: data.payload.present ? data.payload.value : this.payload,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CatalogCacheData(')
          ..write('outletId: $outletId, ')
          ..write('payload: $payload, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(outletId, payload, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CatalogCacheData &&
          other.outletId == this.outletId &&
          other.payload == this.payload &&
          other.updatedAt == this.updatedAt);
}

class CatalogCacheCompanion extends UpdateCompanion<CatalogCacheData> {
  final Value<String> outletId;
  final Value<String> payload;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CatalogCacheCompanion({
    this.outletId = const Value.absent(),
    this.payload = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CatalogCacheCompanion.insert({
    required String outletId,
    required String payload,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : outletId = Value(outletId),
        payload = Value(payload),
        updatedAt = Value(updatedAt);
  static Insertable<CatalogCacheData> custom({
    Expression<String>? outletId,
    Expression<String>? payload,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (outletId != null) 'outlet_id': outletId,
      if (payload != null) 'payload': payload,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CatalogCacheCompanion copyWith(
      {Value<String>? outletId,
      Value<String>? payload,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return CatalogCacheCompanion(
      outletId: outletId ?? this.outletId,
      payload: payload ?? this.payload,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (outletId.present) {
      map['outlet_id'] = Variable<String>(outletId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
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
    return (StringBuffer('CatalogCacheCompanion(')
          ..write('outletId: $outletId, ')
          ..write('payload: $payload, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingOrdersTable extends PendingOrders
    with TableInfo<$PendingOrdersTable, PendingOrder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingOrdersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _clientOrderIdMeta =
      const VerificationMeta('clientOrderId');
  @override
  late final GeneratedColumn<String> clientOrderId = GeneratedColumn<String>(
      'client_order_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _outletIdMeta =
      const VerificationMeta('outletId');
  @override
  late final GeneratedColumn<String> outletId = GeneratedColumn<String>(
      'outlet_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadMeta =
      const VerificationMeta('payload');
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
      'payload', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('pending'));
  static const VerificationMeta _serverOrderIdMeta =
      const VerificationMeta('serverOrderId');
  @override
  late final GeneratedColumn<String> serverOrderId = GeneratedColumn<String>(
      'server_order_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _resultPayloadMeta =
      const VerificationMeta('resultPayload');
  @override
  late final GeneratedColumn<String> resultPayload = GeneratedColumn<String>(
      'result_payload', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _lastErrorMeta =
      const VerificationMeta('lastError');
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
      'last_error', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        clientOrderId,
        outletId,
        payload,
        status,
        serverOrderId,
        resultPayload,
        lastError,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_orders';
  @override
  VerificationContext validateIntegrity(Insertable<PendingOrder> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_order_id')) {
      context.handle(
          _clientOrderIdMeta,
          clientOrderId.isAcceptableOrUnknown(
              data['client_order_id']!, _clientOrderIdMeta));
    } else if (isInserting) {
      context.missing(_clientOrderIdMeta);
    }
    if (data.containsKey('outlet_id')) {
      context.handle(_outletIdMeta,
          outletId.isAcceptableOrUnknown(data['outlet_id']!, _outletIdMeta));
    } else if (isInserting) {
      context.missing(_outletIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta,
          payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('server_order_id')) {
      context.handle(
          _serverOrderIdMeta,
          serverOrderId.isAcceptableOrUnknown(
              data['server_order_id']!, _serverOrderIdMeta));
    }
    if (data.containsKey('result_payload')) {
      context.handle(
          _resultPayloadMeta,
          resultPayload.isAcceptableOrUnknown(
              data['result_payload']!, _resultPayloadMeta));
    }
    if (data.containsKey('last_error')) {
      context.handle(_lastErrorMeta,
          lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {clientOrderId};
  @override
  PendingOrder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingOrder(
      clientOrderId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}client_order_id'])!,
      outletId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}outlet_id'])!,
      payload: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      serverOrderId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}server_order_id']),
      resultPayload: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}result_payload']),
      lastError: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_error']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $PendingOrdersTable createAlias(String alias) {
    return $PendingOrdersTable(attachedDatabase, alias);
  }
}

class PendingOrder extends DataClass implements Insertable<PendingOrder> {
  final String clientOrderId;
  final String outletId;
  final String payload;
  final String status;
  final String? serverOrderId;
  final String? resultPayload;
  final String? lastError;
  final DateTime createdAt;
  const PendingOrder(
      {required this.clientOrderId,
      required this.outletId,
      required this.payload,
      required this.status,
      this.serverOrderId,
      this.resultPayload,
      this.lastError,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['client_order_id'] = Variable<String>(clientOrderId);
    map['outlet_id'] = Variable<String>(outletId);
    map['payload'] = Variable<String>(payload);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || serverOrderId != null) {
      map['server_order_id'] = Variable<String>(serverOrderId);
    }
    if (!nullToAbsent || resultPayload != null) {
      map['result_payload'] = Variable<String>(resultPayload);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PendingOrdersCompanion toCompanion(bool nullToAbsent) {
    return PendingOrdersCompanion(
      clientOrderId: Value(clientOrderId),
      outletId: Value(outletId),
      payload: Value(payload),
      status: Value(status),
      serverOrderId: serverOrderId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverOrderId),
      resultPayload: resultPayload == null && nullToAbsent
          ? const Value.absent()
          : Value(resultPayload),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      createdAt: Value(createdAt),
    );
  }

  factory PendingOrder.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingOrder(
      clientOrderId: serializer.fromJson<String>(json['clientOrderId']),
      outletId: serializer.fromJson<String>(json['outletId']),
      payload: serializer.fromJson<String>(json['payload']),
      status: serializer.fromJson<String>(json['status']),
      serverOrderId: serializer.fromJson<String?>(json['serverOrderId']),
      resultPayload: serializer.fromJson<String?>(json['resultPayload']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'clientOrderId': serializer.toJson<String>(clientOrderId),
      'outletId': serializer.toJson<String>(outletId),
      'payload': serializer.toJson<String>(payload),
      'status': serializer.toJson<String>(status),
      'serverOrderId': serializer.toJson<String?>(serverOrderId),
      'resultPayload': serializer.toJson<String?>(resultPayload),
      'lastError': serializer.toJson<String?>(lastError),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PendingOrder copyWith(
          {String? clientOrderId,
          String? outletId,
          String? payload,
          String? status,
          Value<String?> serverOrderId = const Value.absent(),
          Value<String?> resultPayload = const Value.absent(),
          Value<String?> lastError = const Value.absent(),
          DateTime? createdAt}) =>
      PendingOrder(
        clientOrderId: clientOrderId ?? this.clientOrderId,
        outletId: outletId ?? this.outletId,
        payload: payload ?? this.payload,
        status: status ?? this.status,
        serverOrderId:
            serverOrderId.present ? serverOrderId.value : this.serverOrderId,
        resultPayload:
            resultPayload.present ? resultPayload.value : this.resultPayload,
        lastError: lastError.present ? lastError.value : this.lastError,
        createdAt: createdAt ?? this.createdAt,
      );
  PendingOrder copyWithCompanion(PendingOrdersCompanion data) {
    return PendingOrder(
      clientOrderId: data.clientOrderId.present
          ? data.clientOrderId.value
          : this.clientOrderId,
      outletId: data.outletId.present ? data.outletId.value : this.outletId,
      payload: data.payload.present ? data.payload.value : this.payload,
      status: data.status.present ? data.status.value : this.status,
      serverOrderId: data.serverOrderId.present
          ? data.serverOrderId.value
          : this.serverOrderId,
      resultPayload: data.resultPayload.present
          ? data.resultPayload.value
          : this.resultPayload,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingOrder(')
          ..write('clientOrderId: $clientOrderId, ')
          ..write('outletId: $outletId, ')
          ..write('payload: $payload, ')
          ..write('status: $status, ')
          ..write('serverOrderId: $serverOrderId, ')
          ..write('resultPayload: $resultPayload, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(clientOrderId, outletId, payload, status,
      serverOrderId, resultPayload, lastError, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingOrder &&
          other.clientOrderId == this.clientOrderId &&
          other.outletId == this.outletId &&
          other.payload == this.payload &&
          other.status == this.status &&
          other.serverOrderId == this.serverOrderId &&
          other.resultPayload == this.resultPayload &&
          other.lastError == this.lastError &&
          other.createdAt == this.createdAt);
}

class PendingOrdersCompanion extends UpdateCompanion<PendingOrder> {
  final Value<String> clientOrderId;
  final Value<String> outletId;
  final Value<String> payload;
  final Value<String> status;
  final Value<String?> serverOrderId;
  final Value<String?> resultPayload;
  final Value<String?> lastError;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const PendingOrdersCompanion({
    this.clientOrderId = const Value.absent(),
    this.outletId = const Value.absent(),
    this.payload = const Value.absent(),
    this.status = const Value.absent(),
    this.serverOrderId = const Value.absent(),
    this.resultPayload = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingOrdersCompanion.insert({
    required String clientOrderId,
    required String outletId,
    required String payload,
    this.status = const Value.absent(),
    this.serverOrderId = const Value.absent(),
    this.resultPayload = const Value.absent(),
    this.lastError = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  })  : clientOrderId = Value(clientOrderId),
        outletId = Value(outletId),
        payload = Value(payload),
        createdAt = Value(createdAt);
  static Insertable<PendingOrder> custom({
    Expression<String>? clientOrderId,
    Expression<String>? outletId,
    Expression<String>? payload,
    Expression<String>? status,
    Expression<String>? serverOrderId,
    Expression<String>? resultPayload,
    Expression<String>? lastError,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (clientOrderId != null) 'client_order_id': clientOrderId,
      if (outletId != null) 'outlet_id': outletId,
      if (payload != null) 'payload': payload,
      if (status != null) 'status': status,
      if (serverOrderId != null) 'server_order_id': serverOrderId,
      if (resultPayload != null) 'result_payload': resultPayload,
      if (lastError != null) 'last_error': lastError,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingOrdersCompanion copyWith(
      {Value<String>? clientOrderId,
      Value<String>? outletId,
      Value<String>? payload,
      Value<String>? status,
      Value<String?>? serverOrderId,
      Value<String?>? resultPayload,
      Value<String?>? lastError,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return PendingOrdersCompanion(
      clientOrderId: clientOrderId ?? this.clientOrderId,
      outletId: outletId ?? this.outletId,
      payload: payload ?? this.payload,
      status: status ?? this.status,
      serverOrderId: serverOrderId ?? this.serverOrderId,
      resultPayload: resultPayload ?? this.resultPayload,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientOrderId.present) {
      map['client_order_id'] = Variable<String>(clientOrderId.value);
    }
    if (outletId.present) {
      map['outlet_id'] = Variable<String>(outletId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (serverOrderId.present) {
      map['server_order_id'] = Variable<String>(serverOrderId.value);
    }
    if (resultPayload.present) {
      map['result_payload'] = Variable<String>(resultPayload.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingOrdersCompanion(')
          ..write('clientOrderId: $clientOrderId, ')
          ..write('outletId: $outletId, ')
          ..write('payload: $payload, ')
          ..write('status: $status, ')
          ..write('serverOrderId: $serverOrderId, ')
          ..write('resultPayload: $resultPayload, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CatalogCacheTable catalogCache = $CatalogCacheTable(this);
  late final $PendingOrdersTable pendingOrders = $PendingOrdersTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [catalogCache, pendingOrders];
}

typedef $$CatalogCacheTableCreateCompanionBuilder = CatalogCacheCompanion
    Function({
  required String outletId,
  required String payload,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$CatalogCacheTableUpdateCompanionBuilder = CatalogCacheCompanion
    Function({
  Value<String> outletId,
  Value<String> payload,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$CatalogCacheTableFilterComposer
    extends Composer<_$AppDatabase, $CatalogCacheTable> {
  $$CatalogCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get outletId => $composableBuilder(
      column: $table.outletId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$CatalogCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $CatalogCacheTable> {
  $$CatalogCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get outletId => $composableBuilder(
      column: $table.outletId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$CatalogCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $CatalogCacheTable> {
  $$CatalogCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get outletId =>
      $composableBuilder(column: $table.outletId, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CatalogCacheTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CatalogCacheTable,
    CatalogCacheData,
    $$CatalogCacheTableFilterComposer,
    $$CatalogCacheTableOrderingComposer,
    $$CatalogCacheTableAnnotationComposer,
    $$CatalogCacheTableCreateCompanionBuilder,
    $$CatalogCacheTableUpdateCompanionBuilder,
    (
      CatalogCacheData,
      BaseReferences<_$AppDatabase, $CatalogCacheTable, CatalogCacheData>
    ),
    CatalogCacheData,
    PrefetchHooks Function()> {
  $$CatalogCacheTableTableManager(_$AppDatabase db, $CatalogCacheTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CatalogCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CatalogCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CatalogCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> outletId = const Value.absent(),
            Value<String> payload = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CatalogCacheCompanion(
            outletId: outletId,
            payload: payload,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String outletId,
            required String payload,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              CatalogCacheCompanion.insert(
            outletId: outletId,
            payload: payload,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CatalogCacheTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CatalogCacheTable,
    CatalogCacheData,
    $$CatalogCacheTableFilterComposer,
    $$CatalogCacheTableOrderingComposer,
    $$CatalogCacheTableAnnotationComposer,
    $$CatalogCacheTableCreateCompanionBuilder,
    $$CatalogCacheTableUpdateCompanionBuilder,
    (
      CatalogCacheData,
      BaseReferences<_$AppDatabase, $CatalogCacheTable, CatalogCacheData>
    ),
    CatalogCacheData,
    PrefetchHooks Function()>;
typedef $$PendingOrdersTableCreateCompanionBuilder = PendingOrdersCompanion
    Function({
  required String clientOrderId,
  required String outletId,
  required String payload,
  Value<String> status,
  Value<String?> serverOrderId,
  Value<String?> resultPayload,
  Value<String?> lastError,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$PendingOrdersTableUpdateCompanionBuilder = PendingOrdersCompanion
    Function({
  Value<String> clientOrderId,
  Value<String> outletId,
  Value<String> payload,
  Value<String> status,
  Value<String?> serverOrderId,
  Value<String?> resultPayload,
  Value<String?> lastError,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$PendingOrdersTableFilterComposer
    extends Composer<_$AppDatabase, $PendingOrdersTable> {
  $$PendingOrdersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get clientOrderId => $composableBuilder(
      column: $table.clientOrderId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get outletId => $composableBuilder(
      column: $table.outletId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serverOrderId => $composableBuilder(
      column: $table.serverOrderId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get resultPayload => $composableBuilder(
      column: $table.resultPayload, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$PendingOrdersTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingOrdersTable> {
  $$PendingOrdersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get clientOrderId => $composableBuilder(
      column: $table.clientOrderId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get outletId => $composableBuilder(
      column: $table.outletId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serverOrderId => $composableBuilder(
      column: $table.serverOrderId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get resultPayload => $composableBuilder(
      column: $table.resultPayload,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$PendingOrdersTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingOrdersTable> {
  $$PendingOrdersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get clientOrderId => $composableBuilder(
      column: $table.clientOrderId, builder: (column) => column);

  GeneratedColumn<String> get outletId =>
      $composableBuilder(column: $table.outletId, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get serverOrderId => $composableBuilder(
      column: $table.serverOrderId, builder: (column) => column);

  GeneratedColumn<String> get resultPayload => $composableBuilder(
      column: $table.resultPayload, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$PendingOrdersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PendingOrdersTable,
    PendingOrder,
    $$PendingOrdersTableFilterComposer,
    $$PendingOrdersTableOrderingComposer,
    $$PendingOrdersTableAnnotationComposer,
    $$PendingOrdersTableCreateCompanionBuilder,
    $$PendingOrdersTableUpdateCompanionBuilder,
    (
      PendingOrder,
      BaseReferences<_$AppDatabase, $PendingOrdersTable, PendingOrder>
    ),
    PendingOrder,
    PrefetchHooks Function()> {
  $$PendingOrdersTableTableManager(_$AppDatabase db, $PendingOrdersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingOrdersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingOrdersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingOrdersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> clientOrderId = const Value.absent(),
            Value<String> outletId = const Value.absent(),
            Value<String> payload = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> serverOrderId = const Value.absent(),
            Value<String?> resultPayload = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PendingOrdersCompanion(
            clientOrderId: clientOrderId,
            outletId: outletId,
            payload: payload,
            status: status,
            serverOrderId: serverOrderId,
            resultPayload: resultPayload,
            lastError: lastError,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String clientOrderId,
            required String outletId,
            required String payload,
            Value<String> status = const Value.absent(),
            Value<String?> serverOrderId = const Value.absent(),
            Value<String?> resultPayload = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            required DateTime createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              PendingOrdersCompanion.insert(
            clientOrderId: clientOrderId,
            outletId: outletId,
            payload: payload,
            status: status,
            serverOrderId: serverOrderId,
            resultPayload: resultPayload,
            lastError: lastError,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PendingOrdersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PendingOrdersTable,
    PendingOrder,
    $$PendingOrdersTableFilterComposer,
    $$PendingOrdersTableOrderingComposer,
    $$PendingOrdersTableAnnotationComposer,
    $$PendingOrdersTableCreateCompanionBuilder,
    $$PendingOrdersTableUpdateCompanionBuilder,
    (
      PendingOrder,
      BaseReferences<_$AppDatabase, $PendingOrdersTable, PendingOrder>
    ),
    PendingOrder,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CatalogCacheTableTableManager get catalogCache =>
      $$CatalogCacheTableTableManager(_db, _db.catalogCache);
  $$PendingOrdersTableTableManager get pendingOrders =>
      $$PendingOrdersTableTableManager(_db, _db.pendingOrders);
}
