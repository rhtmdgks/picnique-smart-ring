// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_db.dart';

// ignore_for_file: type=lint
class $SleepDetailsTable extends SleepDetails
    with TableInfo<$SleepDetailsTable, SleepDetail> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SleepDetailsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startMeta = const VerificationMeta('start');
  @override
  late final GeneratedColumn<DateTime> start = GeneratedColumn<DateTime>(
    'start',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endMeta = const VerificationMeta('end');
  @override
  late final GeneratedColumn<DateTime> end = GeneratedColumn<DateTime>(
    'end',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<int> type = GeneratedColumn<int>(
    'type',
    aliasedName,
    false,
    check: () => type.isIn([2, 3, 4, 5]),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, date, start, end, type];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sleep_details';
  @override
  VerificationContext validateIntegrity(
    Insertable<SleepDetail> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('start')) {
      context.handle(
        _startMeta,
        start.isAcceptableOrUnknown(data['start']!, _startMeta),
      );
    } else if (isInserting) {
      context.missing(_startMeta);
    }
    if (data.containsKey('end')) {
      context.handle(
        _endMeta,
        end.isAcceptableOrUnknown(data['end']!, _endMeta),
      );
    } else if (isInserting) {
      context.missing(_endMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {date, start, end, type},
  ];
  @override
  SleepDetail map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SleepDetail(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      start: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start'],
      )!,
      end: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}type'],
      )!,
    );
  }

  @override
  $SleepDetailsTable createAlias(String alias) {
    return $SleepDetailsTable(attachedDatabase, alias);
  }
}

class SleepDetail extends DataClass implements Insertable<SleepDetail> {
  final int id;
  final DateTime date;
  final DateTime start;
  final DateTime end;
  final int type;
  const SleepDetail({
    required this.id,
    required this.date,
    required this.start,
    required this.end,
    required this.type,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['date'] = Variable<DateTime>(date);
    map['start'] = Variable<DateTime>(start);
    map['end'] = Variable<DateTime>(end);
    map['type'] = Variable<int>(type);
    return map;
  }

  SleepDetailsCompanion toCompanion(bool nullToAbsent) {
    return SleepDetailsCompanion(
      id: Value(id),
      date: Value(date),
      start: Value(start),
      end: Value(end),
      type: Value(type),
    );
  }

  factory SleepDetail.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SleepDetail(
      id: serializer.fromJson<int>(json['id']),
      date: serializer.fromJson<DateTime>(json['date']),
      start: serializer.fromJson<DateTime>(json['start']),
      end: serializer.fromJson<DateTime>(json['end']),
      type: serializer.fromJson<int>(json['type']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'date': serializer.toJson<DateTime>(date),
      'start': serializer.toJson<DateTime>(start),
      'end': serializer.toJson<DateTime>(end),
      'type': serializer.toJson<int>(type),
    };
  }

  SleepDetail copyWith({
    int? id,
    DateTime? date,
    DateTime? start,
    DateTime? end,
    int? type,
  }) => SleepDetail(
    id: id ?? this.id,
    date: date ?? this.date,
    start: start ?? this.start,
    end: end ?? this.end,
    type: type ?? this.type,
  );
  SleepDetail copyWithCompanion(SleepDetailsCompanion data) {
    return SleepDetail(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      start: data.start.present ? data.start.value : this.start,
      end: data.end.present ? data.end.value : this.end,
      type: data.type.present ? data.type.value : this.type,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SleepDetail(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('start: $start, ')
          ..write('end: $end, ')
          ..write('type: $type')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, date, start, end, type);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SleepDetail &&
          other.id == this.id &&
          other.date == this.date &&
          other.start == this.start &&
          other.end == this.end &&
          other.type == this.type);
}

class SleepDetailsCompanion extends UpdateCompanion<SleepDetail> {
  final Value<int> id;
  final Value<DateTime> date;
  final Value<DateTime> start;
  final Value<DateTime> end;
  final Value<int> type;
  const SleepDetailsCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.start = const Value.absent(),
    this.end = const Value.absent(),
    this.type = const Value.absent(),
  });
  SleepDetailsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime date,
    required DateTime start,
    required DateTime end,
    required int type,
  }) : date = Value(date),
       start = Value(start),
       end = Value(end),
       type = Value(type);
  static Insertable<SleepDetail> custom({
    Expression<int>? id,
    Expression<DateTime>? date,
    Expression<DateTime>? start,
    Expression<DateTime>? end,
    Expression<int>? type,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (start != null) 'start': start,
      if (end != null) 'end': end,
      if (type != null) 'type': type,
    });
  }

  SleepDetailsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? date,
    Value<DateTime>? start,
    Value<DateTime>? end,
    Value<int>? type,
  }) {
    return SleepDetailsCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      start: start ?? this.start,
      end: end ?? this.end,
      type: type ?? this.type,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (start.present) {
      map['start'] = Variable<DateTime>(start.value);
    }
    if (end.present) {
      map['end'] = Variable<DateTime>(end.value);
    }
    if (type.present) {
      map['type'] = Variable<int>(type.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SleepDetailsCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('start: $start, ')
          ..write('end: $end, ')
          ..write('type: $type')
          ..write(')'))
        .toString();
  }
}

class $HeartDetailsTable extends HeartDetails
    with TableInfo<$HeartDetailsTable, HeartDetail> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HeartDetailsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bpmMeta = const VerificationMeta('bpm');
  @override
  late final GeneratedColumn<int> bpm = GeneratedColumn<int>(
    'bpm',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('firmwareAuto'),
  );
  static const VerificationMeta _dedupeKeyMeta = const VerificationMeta(
    'dedupeKey',
  );
  @override
  late final GeneratedColumn<String> dedupeKey = GeneratedColumn<String>(
    'dedupe_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ringSeqMeta = const VerificationMeta(
    'ringSeq',
  );
  @override
  late final GeneratedColumn<String> ringSeq = GeneratedColumn<String>(
    'ring_seq',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    date,
    bpm,
    source,
    dedupeKey,
    ringSeq,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'heart_details';
  @override
  VerificationContext validateIntegrity(
    Insertable<HeartDetail> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('bpm')) {
      context.handle(
        _bpmMeta,
        bpm.isAcceptableOrUnknown(data['bpm']!, _bpmMeta),
      );
    } else if (isInserting) {
      context.missing(_bpmMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('dedupe_key')) {
      context.handle(
        _dedupeKeyMeta,
        dedupeKey.isAcceptableOrUnknown(data['dedupe_key']!, _dedupeKeyMeta),
      );
    }
    if (data.containsKey('ring_seq')) {
      context.handle(
        _ringSeqMeta,
        ringSeq.isAcceptableOrUnknown(data['ring_seq']!, _ringSeqMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HeartDetail map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HeartDetail(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      bpm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bpm'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      dedupeKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dedupe_key'],
      ),
      ringSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ring_seq'],
      ),
    );
  }

  @override
  $HeartDetailsTable createAlias(String alias) {
    return $HeartDetailsTable(attachedDatabase, alias);
  }
}

class HeartDetail extends DataClass implements Insertable<HeartDetail> {
  final int id;
  final DateTime date;
  final int bpm;
  final String source;
  final String? dedupeKey;
  final String? ringSeq;
  const HeartDetail({
    required this.id,
    required this.date,
    required this.bpm,
    required this.source,
    this.dedupeKey,
    this.ringSeq,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['date'] = Variable<DateTime>(date);
    map['bpm'] = Variable<int>(bpm);
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || dedupeKey != null) {
      map['dedupe_key'] = Variable<String>(dedupeKey);
    }
    if (!nullToAbsent || ringSeq != null) {
      map['ring_seq'] = Variable<String>(ringSeq);
    }
    return map;
  }

  HeartDetailsCompanion toCompanion(bool nullToAbsent) {
    return HeartDetailsCompanion(
      id: Value(id),
      date: Value(date),
      bpm: Value(bpm),
      source: Value(source),
      dedupeKey: dedupeKey == null && nullToAbsent
          ? const Value.absent()
          : Value(dedupeKey),
      ringSeq: ringSeq == null && nullToAbsent
          ? const Value.absent()
          : Value(ringSeq),
    );
  }

  factory HeartDetail.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HeartDetail(
      id: serializer.fromJson<int>(json['id']),
      date: serializer.fromJson<DateTime>(json['date']),
      bpm: serializer.fromJson<int>(json['bpm']),
      source: serializer.fromJson<String>(json['source']),
      dedupeKey: serializer.fromJson<String?>(json['dedupeKey']),
      ringSeq: serializer.fromJson<String?>(json['ringSeq']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'date': serializer.toJson<DateTime>(date),
      'bpm': serializer.toJson<int>(bpm),
      'source': serializer.toJson<String>(source),
      'dedupeKey': serializer.toJson<String?>(dedupeKey),
      'ringSeq': serializer.toJson<String?>(ringSeq),
    };
  }

  HeartDetail copyWith({
    int? id,
    DateTime? date,
    int? bpm,
    String? source,
    Value<String?> dedupeKey = const Value.absent(),
    Value<String?> ringSeq = const Value.absent(),
  }) => HeartDetail(
    id: id ?? this.id,
    date: date ?? this.date,
    bpm: bpm ?? this.bpm,
    source: source ?? this.source,
    dedupeKey: dedupeKey.present ? dedupeKey.value : this.dedupeKey,
    ringSeq: ringSeq.present ? ringSeq.value : this.ringSeq,
  );
  HeartDetail copyWithCompanion(HeartDetailsCompanion data) {
    return HeartDetail(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      bpm: data.bpm.present ? data.bpm.value : this.bpm,
      source: data.source.present ? data.source.value : this.source,
      dedupeKey: data.dedupeKey.present ? data.dedupeKey.value : this.dedupeKey,
      ringSeq: data.ringSeq.present ? data.ringSeq.value : this.ringSeq,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HeartDetail(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('bpm: $bpm, ')
          ..write('source: $source, ')
          ..write('dedupeKey: $dedupeKey, ')
          ..write('ringSeq: $ringSeq')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, date, bpm, source, dedupeKey, ringSeq);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HeartDetail &&
          other.id == this.id &&
          other.date == this.date &&
          other.bpm == this.bpm &&
          other.source == this.source &&
          other.dedupeKey == this.dedupeKey &&
          other.ringSeq == this.ringSeq);
}

class HeartDetailsCompanion extends UpdateCompanion<HeartDetail> {
  final Value<int> id;
  final Value<DateTime> date;
  final Value<int> bpm;
  final Value<String> source;
  final Value<String?> dedupeKey;
  final Value<String?> ringSeq;
  const HeartDetailsCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.bpm = const Value.absent(),
    this.source = const Value.absent(),
    this.dedupeKey = const Value.absent(),
    this.ringSeq = const Value.absent(),
  });
  HeartDetailsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime date,
    required int bpm,
    this.source = const Value.absent(),
    this.dedupeKey = const Value.absent(),
    this.ringSeq = const Value.absent(),
  }) : date = Value(date),
       bpm = Value(bpm);
  static Insertable<HeartDetail> custom({
    Expression<int>? id,
    Expression<DateTime>? date,
    Expression<int>? bpm,
    Expression<String>? source,
    Expression<String>? dedupeKey,
    Expression<String>? ringSeq,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (bpm != null) 'bpm': bpm,
      if (source != null) 'source': source,
      if (dedupeKey != null) 'dedupe_key': dedupeKey,
      if (ringSeq != null) 'ring_seq': ringSeq,
    });
  }

  HeartDetailsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? date,
    Value<int>? bpm,
    Value<String>? source,
    Value<String?>? dedupeKey,
    Value<String?>? ringSeq,
  }) {
    return HeartDetailsCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      bpm: bpm ?? this.bpm,
      source: source ?? this.source,
      dedupeKey: dedupeKey ?? this.dedupeKey,
      ringSeq: ringSeq ?? this.ringSeq,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (bpm.present) {
      map['bpm'] = Variable<int>(bpm.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (dedupeKey.present) {
      map['dedupe_key'] = Variable<String>(dedupeKey.value);
    }
    if (ringSeq.present) {
      map['ring_seq'] = Variable<String>(ringSeq.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HeartDetailsCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('bpm: $bpm, ')
          ..write('source: $source, ')
          ..write('dedupeKey: $dedupeKey, ')
          ..write('ringSeq: $ringSeq')
          ..write(')'))
        .toString();
  }
}

class $StressDetailsTable extends StressDetails
    with TableInfo<$StressDetailsTable, StressDetail> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StressDetailsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stressMeta = const VerificationMeta('stress');
  @override
  late final GeneratedColumn<int> stress = GeneratedColumn<int>(
    'stress',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('firmwareAuto'),
  );
  static const VerificationMeta _dedupeKeyMeta = const VerificationMeta(
    'dedupeKey',
  );
  @override
  late final GeneratedColumn<String> dedupeKey = GeneratedColumn<String>(
    'dedupe_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ringSeqMeta = const VerificationMeta(
    'ringSeq',
  );
  @override
  late final GeneratedColumn<String> ringSeq = GeneratedColumn<String>(
    'ring_seq',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    date,
    stress,
    source,
    dedupeKey,
    ringSeq,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stress_details';
  @override
  VerificationContext validateIntegrity(
    Insertable<StressDetail> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('stress')) {
      context.handle(
        _stressMeta,
        stress.isAcceptableOrUnknown(data['stress']!, _stressMeta),
      );
    } else if (isInserting) {
      context.missing(_stressMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('dedupe_key')) {
      context.handle(
        _dedupeKeyMeta,
        dedupeKey.isAcceptableOrUnknown(data['dedupe_key']!, _dedupeKeyMeta),
      );
    }
    if (data.containsKey('ring_seq')) {
      context.handle(
        _ringSeqMeta,
        ringSeq.isAcceptableOrUnknown(data['ring_seq']!, _ringSeqMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StressDetail map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StressDetail(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      stress: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stress'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      dedupeKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dedupe_key'],
      ),
      ringSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ring_seq'],
      ),
    );
  }

  @override
  $StressDetailsTable createAlias(String alias) {
    return $StressDetailsTable(attachedDatabase, alias);
  }
}

class StressDetail extends DataClass implements Insertable<StressDetail> {
  final int id;
  final DateTime date;
  final int stress;
  final String source;
  final String? dedupeKey;
  final String? ringSeq;
  const StressDetail({
    required this.id,
    required this.date,
    required this.stress,
    required this.source,
    this.dedupeKey,
    this.ringSeq,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['date'] = Variable<DateTime>(date);
    map['stress'] = Variable<int>(stress);
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || dedupeKey != null) {
      map['dedupe_key'] = Variable<String>(dedupeKey);
    }
    if (!nullToAbsent || ringSeq != null) {
      map['ring_seq'] = Variable<String>(ringSeq);
    }
    return map;
  }

  StressDetailsCompanion toCompanion(bool nullToAbsent) {
    return StressDetailsCompanion(
      id: Value(id),
      date: Value(date),
      stress: Value(stress),
      source: Value(source),
      dedupeKey: dedupeKey == null && nullToAbsent
          ? const Value.absent()
          : Value(dedupeKey),
      ringSeq: ringSeq == null && nullToAbsent
          ? const Value.absent()
          : Value(ringSeq),
    );
  }

  factory StressDetail.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StressDetail(
      id: serializer.fromJson<int>(json['id']),
      date: serializer.fromJson<DateTime>(json['date']),
      stress: serializer.fromJson<int>(json['stress']),
      source: serializer.fromJson<String>(json['source']),
      dedupeKey: serializer.fromJson<String?>(json['dedupeKey']),
      ringSeq: serializer.fromJson<String?>(json['ringSeq']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'date': serializer.toJson<DateTime>(date),
      'stress': serializer.toJson<int>(stress),
      'source': serializer.toJson<String>(source),
      'dedupeKey': serializer.toJson<String?>(dedupeKey),
      'ringSeq': serializer.toJson<String?>(ringSeq),
    };
  }

  StressDetail copyWith({
    int? id,
    DateTime? date,
    int? stress,
    String? source,
    Value<String?> dedupeKey = const Value.absent(),
    Value<String?> ringSeq = const Value.absent(),
  }) => StressDetail(
    id: id ?? this.id,
    date: date ?? this.date,
    stress: stress ?? this.stress,
    source: source ?? this.source,
    dedupeKey: dedupeKey.present ? dedupeKey.value : this.dedupeKey,
    ringSeq: ringSeq.present ? ringSeq.value : this.ringSeq,
  );
  StressDetail copyWithCompanion(StressDetailsCompanion data) {
    return StressDetail(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      stress: data.stress.present ? data.stress.value : this.stress,
      source: data.source.present ? data.source.value : this.source,
      dedupeKey: data.dedupeKey.present ? data.dedupeKey.value : this.dedupeKey,
      ringSeq: data.ringSeq.present ? data.ringSeq.value : this.ringSeq,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StressDetail(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('stress: $stress, ')
          ..write('source: $source, ')
          ..write('dedupeKey: $dedupeKey, ')
          ..write('ringSeq: $ringSeq')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, date, stress, source, dedupeKey, ringSeq);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StressDetail &&
          other.id == this.id &&
          other.date == this.date &&
          other.stress == this.stress &&
          other.source == this.source &&
          other.dedupeKey == this.dedupeKey &&
          other.ringSeq == this.ringSeq);
}

class StressDetailsCompanion extends UpdateCompanion<StressDetail> {
  final Value<int> id;
  final Value<DateTime> date;
  final Value<int> stress;
  final Value<String> source;
  final Value<String?> dedupeKey;
  final Value<String?> ringSeq;
  const StressDetailsCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.stress = const Value.absent(),
    this.source = const Value.absent(),
    this.dedupeKey = const Value.absent(),
    this.ringSeq = const Value.absent(),
  });
  StressDetailsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime date,
    required int stress,
    this.source = const Value.absent(),
    this.dedupeKey = const Value.absent(),
    this.ringSeq = const Value.absent(),
  }) : date = Value(date),
       stress = Value(stress);
  static Insertable<StressDetail> custom({
    Expression<int>? id,
    Expression<DateTime>? date,
    Expression<int>? stress,
    Expression<String>? source,
    Expression<String>? dedupeKey,
    Expression<String>? ringSeq,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (stress != null) 'stress': stress,
      if (source != null) 'source': source,
      if (dedupeKey != null) 'dedupe_key': dedupeKey,
      if (ringSeq != null) 'ring_seq': ringSeq,
    });
  }

  StressDetailsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? date,
    Value<int>? stress,
    Value<String>? source,
    Value<String?>? dedupeKey,
    Value<String?>? ringSeq,
  }) {
    return StressDetailsCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      stress: stress ?? this.stress,
      source: source ?? this.source,
      dedupeKey: dedupeKey ?? this.dedupeKey,
      ringSeq: ringSeq ?? this.ringSeq,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (stress.present) {
      map['stress'] = Variable<int>(stress.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (dedupeKey.present) {
      map['dedupe_key'] = Variable<String>(dedupeKey.value);
    }
    if (ringSeq.present) {
      map['ring_seq'] = Variable<String>(ringSeq.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StressDetailsCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('stress: $stress, ')
          ..write('source: $source, ')
          ..write('dedupeKey: $dedupeKey, ')
          ..write('ringSeq: $ringSeq')
          ..write(')'))
        .toString();
  }
}

class $BloodOxygenDetailsTable extends BloodOxygenDetails
    with TableInfo<$BloodOxygenDetailsTable, BloodOxygenDetail> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BloodOxygenDetailsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _spo2Meta = const VerificationMeta('spo2');
  @override
  late final GeneratedColumn<int> spo2 = GeneratedColumn<int>(
    'spo2',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('firmwareAuto'),
  );
  static const VerificationMeta _dedupeKeyMeta = const VerificationMeta(
    'dedupeKey',
  );
  @override
  late final GeneratedColumn<String> dedupeKey = GeneratedColumn<String>(
    'dedupe_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ringSeqMeta = const VerificationMeta(
    'ringSeq',
  );
  @override
  late final GeneratedColumn<String> ringSeq = GeneratedColumn<String>(
    'ring_seq',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    date,
    spo2,
    source,
    dedupeKey,
    ringSeq,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'blood_oxygen_details';
  @override
  VerificationContext validateIntegrity(
    Insertable<BloodOxygenDetail> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('spo2')) {
      context.handle(
        _spo2Meta,
        spo2.isAcceptableOrUnknown(data['spo2']!, _spo2Meta),
      );
    } else if (isInserting) {
      context.missing(_spo2Meta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('dedupe_key')) {
      context.handle(
        _dedupeKeyMeta,
        dedupeKey.isAcceptableOrUnknown(data['dedupe_key']!, _dedupeKeyMeta),
      );
    }
    if (data.containsKey('ring_seq')) {
      context.handle(
        _ringSeqMeta,
        ringSeq.isAcceptableOrUnknown(data['ring_seq']!, _ringSeqMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BloodOxygenDetail map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BloodOxygenDetail(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      spo2: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}spo2'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      dedupeKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dedupe_key'],
      ),
      ringSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ring_seq'],
      ),
    );
  }

  @override
  $BloodOxygenDetailsTable createAlias(String alias) {
    return $BloodOxygenDetailsTable(attachedDatabase, alias);
  }
}

class BloodOxygenDetail extends DataClass
    implements Insertable<BloodOxygenDetail> {
  final int id;
  final DateTime date;
  final int spo2;
  final String source;
  final String? dedupeKey;
  final String? ringSeq;
  const BloodOxygenDetail({
    required this.id,
    required this.date,
    required this.spo2,
    required this.source,
    this.dedupeKey,
    this.ringSeq,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['date'] = Variable<DateTime>(date);
    map['spo2'] = Variable<int>(spo2);
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || dedupeKey != null) {
      map['dedupe_key'] = Variable<String>(dedupeKey);
    }
    if (!nullToAbsent || ringSeq != null) {
      map['ring_seq'] = Variable<String>(ringSeq);
    }
    return map;
  }

  BloodOxygenDetailsCompanion toCompanion(bool nullToAbsent) {
    return BloodOxygenDetailsCompanion(
      id: Value(id),
      date: Value(date),
      spo2: Value(spo2),
      source: Value(source),
      dedupeKey: dedupeKey == null && nullToAbsent
          ? const Value.absent()
          : Value(dedupeKey),
      ringSeq: ringSeq == null && nullToAbsent
          ? const Value.absent()
          : Value(ringSeq),
    );
  }

  factory BloodOxygenDetail.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BloodOxygenDetail(
      id: serializer.fromJson<int>(json['id']),
      date: serializer.fromJson<DateTime>(json['date']),
      spo2: serializer.fromJson<int>(json['spo2']),
      source: serializer.fromJson<String>(json['source']),
      dedupeKey: serializer.fromJson<String?>(json['dedupeKey']),
      ringSeq: serializer.fromJson<String?>(json['ringSeq']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'date': serializer.toJson<DateTime>(date),
      'spo2': serializer.toJson<int>(spo2),
      'source': serializer.toJson<String>(source),
      'dedupeKey': serializer.toJson<String?>(dedupeKey),
      'ringSeq': serializer.toJson<String?>(ringSeq),
    };
  }

  BloodOxygenDetail copyWith({
    int? id,
    DateTime? date,
    int? spo2,
    String? source,
    Value<String?> dedupeKey = const Value.absent(),
    Value<String?> ringSeq = const Value.absent(),
  }) => BloodOxygenDetail(
    id: id ?? this.id,
    date: date ?? this.date,
    spo2: spo2 ?? this.spo2,
    source: source ?? this.source,
    dedupeKey: dedupeKey.present ? dedupeKey.value : this.dedupeKey,
    ringSeq: ringSeq.present ? ringSeq.value : this.ringSeq,
  );
  BloodOxygenDetail copyWithCompanion(BloodOxygenDetailsCompanion data) {
    return BloodOxygenDetail(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      spo2: data.spo2.present ? data.spo2.value : this.spo2,
      source: data.source.present ? data.source.value : this.source,
      dedupeKey: data.dedupeKey.present ? data.dedupeKey.value : this.dedupeKey,
      ringSeq: data.ringSeq.present ? data.ringSeq.value : this.ringSeq,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BloodOxygenDetail(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('spo2: $spo2, ')
          ..write('source: $source, ')
          ..write('dedupeKey: $dedupeKey, ')
          ..write('ringSeq: $ringSeq')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, date, spo2, source, dedupeKey, ringSeq);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BloodOxygenDetail &&
          other.id == this.id &&
          other.date == this.date &&
          other.spo2 == this.spo2 &&
          other.source == this.source &&
          other.dedupeKey == this.dedupeKey &&
          other.ringSeq == this.ringSeq);
}

class BloodOxygenDetailsCompanion extends UpdateCompanion<BloodOxygenDetail> {
  final Value<int> id;
  final Value<DateTime> date;
  final Value<int> spo2;
  final Value<String> source;
  final Value<String?> dedupeKey;
  final Value<String?> ringSeq;
  const BloodOxygenDetailsCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.spo2 = const Value.absent(),
    this.source = const Value.absent(),
    this.dedupeKey = const Value.absent(),
    this.ringSeq = const Value.absent(),
  });
  BloodOxygenDetailsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime date,
    required int spo2,
    this.source = const Value.absent(),
    this.dedupeKey = const Value.absent(),
    this.ringSeq = const Value.absent(),
  }) : date = Value(date),
       spo2 = Value(spo2);
  static Insertable<BloodOxygenDetail> custom({
    Expression<int>? id,
    Expression<DateTime>? date,
    Expression<int>? spo2,
    Expression<String>? source,
    Expression<String>? dedupeKey,
    Expression<String>? ringSeq,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (spo2 != null) 'spo2': spo2,
      if (source != null) 'source': source,
      if (dedupeKey != null) 'dedupe_key': dedupeKey,
      if (ringSeq != null) 'ring_seq': ringSeq,
    });
  }

  BloodOxygenDetailsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? date,
    Value<int>? spo2,
    Value<String>? source,
    Value<String?>? dedupeKey,
    Value<String?>? ringSeq,
  }) {
    return BloodOxygenDetailsCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      spo2: spo2 ?? this.spo2,
      source: source ?? this.source,
      dedupeKey: dedupeKey ?? this.dedupeKey,
      ringSeq: ringSeq ?? this.ringSeq,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (spo2.present) {
      map['spo2'] = Variable<int>(spo2.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (dedupeKey.present) {
      map['dedupe_key'] = Variable<String>(dedupeKey.value);
    }
    if (ringSeq.present) {
      map['ring_seq'] = Variable<String>(ringSeq.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BloodOxygenDetailsCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('spo2: $spo2, ')
          ..write('source: $source, ')
          ..write('dedupeKey: $dedupeKey, ')
          ..write('ringSeq: $ringSeq')
          ..write(')'))
        .toString();
  }
}

class $SportDetailsTable extends SportDetails
    with TableInfo<$SportDetailsTable, SportDetail> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SportDetailsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timeIndexMeta = const VerificationMeta(
    'timeIndex',
  );
  @override
  late final GeneratedColumn<int> timeIndex = GeneratedColumn<int>(
    'time_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _walkStepsMeta = const VerificationMeta(
    'walkSteps',
  );
  @override
  late final GeneratedColumn<int> walkSteps = GeneratedColumn<int>(
    'walk_steps',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _runStepsMeta = const VerificationMeta(
    'runSteps',
  );
  @override
  late final GeneratedColumn<int> runSteps = GeneratedColumn<int>(
    'run_steps',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _distanceMeta = const VerificationMeta(
    'distance',
  );
  @override
  late final GeneratedColumn<int> distance = GeneratedColumn<int>(
    'distance',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _calorieMeta = const VerificationMeta(
    'calorie',
  );
  @override
  late final GeneratedColumn<int> calorie = GeneratedColumn<int>(
    'calorie',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    date,
    timeIndex,
    walkSteps,
    runSteps,
    distance,
    calorie,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sport_details';
  @override
  VerificationContext validateIntegrity(
    Insertable<SportDetail> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('time_index')) {
      context.handle(
        _timeIndexMeta,
        timeIndex.isAcceptableOrUnknown(data['time_index']!, _timeIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_timeIndexMeta);
    }
    if (data.containsKey('walk_steps')) {
      context.handle(
        _walkStepsMeta,
        walkSteps.isAcceptableOrUnknown(data['walk_steps']!, _walkStepsMeta),
      );
    } else if (isInserting) {
      context.missing(_walkStepsMeta);
    }
    if (data.containsKey('run_steps')) {
      context.handle(
        _runStepsMeta,
        runSteps.isAcceptableOrUnknown(data['run_steps']!, _runStepsMeta),
      );
    } else if (isInserting) {
      context.missing(_runStepsMeta);
    }
    if (data.containsKey('distance')) {
      context.handle(
        _distanceMeta,
        distance.isAcceptableOrUnknown(data['distance']!, _distanceMeta),
      );
    } else if (isInserting) {
      context.missing(_distanceMeta);
    }
    if (data.containsKey('calorie')) {
      context.handle(
        _calorieMeta,
        calorie.isAcceptableOrUnknown(data['calorie']!, _calorieMeta),
      );
    } else if (isInserting) {
      context.missing(_calorieMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {date, timeIndex},
  ];
  @override
  SportDetail map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SportDetail(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      timeIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}time_index'],
      )!,
      walkSteps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}walk_steps'],
      )!,
      runSteps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}run_steps'],
      )!,
      distance: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}distance'],
      )!,
      calorie: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}calorie'],
      )!,
    );
  }

  @override
  $SportDetailsTable createAlias(String alias) {
    return $SportDetailsTable(attachedDatabase, alias);
  }
}

class SportDetail extends DataClass implements Insertable<SportDetail> {
  final int id;
  final DateTime date;
  final int timeIndex;
  final int walkSteps;
  final int runSteps;
  final int distance;
  final int calorie;
  const SportDetail({
    required this.id,
    required this.date,
    required this.timeIndex,
    required this.walkSteps,
    required this.runSteps,
    required this.distance,
    required this.calorie,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['date'] = Variable<DateTime>(date);
    map['time_index'] = Variable<int>(timeIndex);
    map['walk_steps'] = Variable<int>(walkSteps);
    map['run_steps'] = Variable<int>(runSteps);
    map['distance'] = Variable<int>(distance);
    map['calorie'] = Variable<int>(calorie);
    return map;
  }

  SportDetailsCompanion toCompanion(bool nullToAbsent) {
    return SportDetailsCompanion(
      id: Value(id),
      date: Value(date),
      timeIndex: Value(timeIndex),
      walkSteps: Value(walkSteps),
      runSteps: Value(runSteps),
      distance: Value(distance),
      calorie: Value(calorie),
    );
  }

  factory SportDetail.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SportDetail(
      id: serializer.fromJson<int>(json['id']),
      date: serializer.fromJson<DateTime>(json['date']),
      timeIndex: serializer.fromJson<int>(json['timeIndex']),
      walkSteps: serializer.fromJson<int>(json['walkSteps']),
      runSteps: serializer.fromJson<int>(json['runSteps']),
      distance: serializer.fromJson<int>(json['distance']),
      calorie: serializer.fromJson<int>(json['calorie']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'date': serializer.toJson<DateTime>(date),
      'timeIndex': serializer.toJson<int>(timeIndex),
      'walkSteps': serializer.toJson<int>(walkSteps),
      'runSteps': serializer.toJson<int>(runSteps),
      'distance': serializer.toJson<int>(distance),
      'calorie': serializer.toJson<int>(calorie),
    };
  }

  SportDetail copyWith({
    int? id,
    DateTime? date,
    int? timeIndex,
    int? walkSteps,
    int? runSteps,
    int? distance,
    int? calorie,
  }) => SportDetail(
    id: id ?? this.id,
    date: date ?? this.date,
    timeIndex: timeIndex ?? this.timeIndex,
    walkSteps: walkSteps ?? this.walkSteps,
    runSteps: runSteps ?? this.runSteps,
    distance: distance ?? this.distance,
    calorie: calorie ?? this.calorie,
  );
  SportDetail copyWithCompanion(SportDetailsCompanion data) {
    return SportDetail(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      timeIndex: data.timeIndex.present ? data.timeIndex.value : this.timeIndex,
      walkSteps: data.walkSteps.present ? data.walkSteps.value : this.walkSteps,
      runSteps: data.runSteps.present ? data.runSteps.value : this.runSteps,
      distance: data.distance.present ? data.distance.value : this.distance,
      calorie: data.calorie.present ? data.calorie.value : this.calorie,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SportDetail(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('timeIndex: $timeIndex, ')
          ..write('walkSteps: $walkSteps, ')
          ..write('runSteps: $runSteps, ')
          ..write('distance: $distance, ')
          ..write('calorie: $calorie')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, date, timeIndex, walkSteps, runSteps, distance, calorie);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SportDetail &&
          other.id == this.id &&
          other.date == this.date &&
          other.timeIndex == this.timeIndex &&
          other.walkSteps == this.walkSteps &&
          other.runSteps == this.runSteps &&
          other.distance == this.distance &&
          other.calorie == this.calorie);
}

class SportDetailsCompanion extends UpdateCompanion<SportDetail> {
  final Value<int> id;
  final Value<DateTime> date;
  final Value<int> timeIndex;
  final Value<int> walkSteps;
  final Value<int> runSteps;
  final Value<int> distance;
  final Value<int> calorie;
  const SportDetailsCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.timeIndex = const Value.absent(),
    this.walkSteps = const Value.absent(),
    this.runSteps = const Value.absent(),
    this.distance = const Value.absent(),
    this.calorie = const Value.absent(),
  });
  SportDetailsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime date,
    required int timeIndex,
    required int walkSteps,
    required int runSteps,
    required int distance,
    required int calorie,
  }) : date = Value(date),
       timeIndex = Value(timeIndex),
       walkSteps = Value(walkSteps),
       runSteps = Value(runSteps),
       distance = Value(distance),
       calorie = Value(calorie);
  static Insertable<SportDetail> custom({
    Expression<int>? id,
    Expression<DateTime>? date,
    Expression<int>? timeIndex,
    Expression<int>? walkSteps,
    Expression<int>? runSteps,
    Expression<int>? distance,
    Expression<int>? calorie,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (timeIndex != null) 'time_index': timeIndex,
      if (walkSteps != null) 'walk_steps': walkSteps,
      if (runSteps != null) 'run_steps': runSteps,
      if (distance != null) 'distance': distance,
      if (calorie != null) 'calorie': calorie,
    });
  }

  SportDetailsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? date,
    Value<int>? timeIndex,
    Value<int>? walkSteps,
    Value<int>? runSteps,
    Value<int>? distance,
    Value<int>? calorie,
  }) {
    return SportDetailsCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      timeIndex: timeIndex ?? this.timeIndex,
      walkSteps: walkSteps ?? this.walkSteps,
      runSteps: runSteps ?? this.runSteps,
      distance: distance ?? this.distance,
      calorie: calorie ?? this.calorie,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (timeIndex.present) {
      map['time_index'] = Variable<int>(timeIndex.value);
    }
    if (walkSteps.present) {
      map['walk_steps'] = Variable<int>(walkSteps.value);
    }
    if (runSteps.present) {
      map['run_steps'] = Variable<int>(runSteps.value);
    }
    if (distance.present) {
      map['distance'] = Variable<int>(distance.value);
    }
    if (calorie.present) {
      map['calorie'] = Variable<int>(calorie.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SportDetailsCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('timeIndex: $timeIndex, ')
          ..write('walkSteps: $walkSteps, ')
          ..write('runSteps: $runSteps, ')
          ..write('distance: $distance, ')
          ..write('calorie: $calorie')
          ..write(')'))
        .toString();
  }
}

class $RosarySessionsTable extends RosarySessions
    with TableInfo<$RosarySessionsTable, RosarySession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RosarySessionsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _startAtMeta = const VerificationMeta(
    'startAt',
  );
  @override
  late final GeneratedColumn<DateTime> startAt = GeneratedColumn<DateTime>(
    'start_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endAtMeta = const VerificationMeta('endAt');
  @override
  late final GeneratedColumn<DateTime> endAt = GeneratedColumn<DateTime>(
    'end_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tapCountMeta = const VerificationMeta(
    'tapCount',
  );
  @override
  late final GeneratedColumn<int> tapCount = GeneratedColumn<int>(
    'tap_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wydDedicatedMeta = const VerificationMeta(
    'wydDedicated',
  );
  @override
  late final GeneratedColumn<bool> wydDedicated = GeneratedColumn<bool>(
    'wyd_dedicated',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("wyd_dedicated" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    startAt,
    endAt,
    tapCount,
    wydDedicated,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rosary_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<RosarySession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('start_at')) {
      context.handle(
        _startAtMeta,
        startAt.isAcceptableOrUnknown(data['start_at']!, _startAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startAtMeta);
    }
    if (data.containsKey('end_at')) {
      context.handle(
        _endAtMeta,
        endAt.isAcceptableOrUnknown(data['end_at']!, _endAtMeta),
      );
    } else if (isInserting) {
      context.missing(_endAtMeta);
    }
    if (data.containsKey('tap_count')) {
      context.handle(
        _tapCountMeta,
        tapCount.isAcceptableOrUnknown(data['tap_count']!, _tapCountMeta),
      );
    } else if (isInserting) {
      context.missing(_tapCountMeta);
    }
    if (data.containsKey('wyd_dedicated')) {
      context.handle(
        _wydDedicatedMeta,
        wydDedicated.isAcceptableOrUnknown(
          data['wyd_dedicated']!,
          _wydDedicatedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RosarySession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RosarySession(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      startAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_at'],
      )!,
      endAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_at'],
      )!,
      tapCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tap_count'],
      )!,
      wydDedicated: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}wyd_dedicated'],
      )!,
    );
  }

  @override
  $RosarySessionsTable createAlias(String alias) {
    return $RosarySessionsTable(attachedDatabase, alias);
  }
}

class RosarySession extends DataClass implements Insertable<RosarySession> {
  final int id;
  final DateTime startAt;
  final DateTime endAt;
  final int tapCount;
  final bool wydDedicated;
  const RosarySession({
    required this.id,
    required this.startAt,
    required this.endAt,
    required this.tapCount,
    required this.wydDedicated,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['start_at'] = Variable<DateTime>(startAt);
    map['end_at'] = Variable<DateTime>(endAt);
    map['tap_count'] = Variable<int>(tapCount);
    map['wyd_dedicated'] = Variable<bool>(wydDedicated);
    return map;
  }

  RosarySessionsCompanion toCompanion(bool nullToAbsent) {
    return RosarySessionsCompanion(
      id: Value(id),
      startAt: Value(startAt),
      endAt: Value(endAt),
      tapCount: Value(tapCount),
      wydDedicated: Value(wydDedicated),
    );
  }

  factory RosarySession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RosarySession(
      id: serializer.fromJson<int>(json['id']),
      startAt: serializer.fromJson<DateTime>(json['startAt']),
      endAt: serializer.fromJson<DateTime>(json['endAt']),
      tapCount: serializer.fromJson<int>(json['tapCount']),
      wydDedicated: serializer.fromJson<bool>(json['wydDedicated']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'startAt': serializer.toJson<DateTime>(startAt),
      'endAt': serializer.toJson<DateTime>(endAt),
      'tapCount': serializer.toJson<int>(tapCount),
      'wydDedicated': serializer.toJson<bool>(wydDedicated),
    };
  }

  RosarySession copyWith({
    int? id,
    DateTime? startAt,
    DateTime? endAt,
    int? tapCount,
    bool? wydDedicated,
  }) => RosarySession(
    id: id ?? this.id,
    startAt: startAt ?? this.startAt,
    endAt: endAt ?? this.endAt,
    tapCount: tapCount ?? this.tapCount,
    wydDedicated: wydDedicated ?? this.wydDedicated,
  );
  RosarySession copyWithCompanion(RosarySessionsCompanion data) {
    return RosarySession(
      id: data.id.present ? data.id.value : this.id,
      startAt: data.startAt.present ? data.startAt.value : this.startAt,
      endAt: data.endAt.present ? data.endAt.value : this.endAt,
      tapCount: data.tapCount.present ? data.tapCount.value : this.tapCount,
      wydDedicated: data.wydDedicated.present
          ? data.wydDedicated.value
          : this.wydDedicated,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RosarySession(')
          ..write('id: $id, ')
          ..write('startAt: $startAt, ')
          ..write('endAt: $endAt, ')
          ..write('tapCount: $tapCount, ')
          ..write('wydDedicated: $wydDedicated')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, startAt, endAt, tapCount, wydDedicated);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RosarySession &&
          other.id == this.id &&
          other.startAt == this.startAt &&
          other.endAt == this.endAt &&
          other.tapCount == this.tapCount &&
          other.wydDedicated == this.wydDedicated);
}

class RosarySessionsCompanion extends UpdateCompanion<RosarySession> {
  final Value<int> id;
  final Value<DateTime> startAt;
  final Value<DateTime> endAt;
  final Value<int> tapCount;
  final Value<bool> wydDedicated;
  const RosarySessionsCompanion({
    this.id = const Value.absent(),
    this.startAt = const Value.absent(),
    this.endAt = const Value.absent(),
    this.tapCount = const Value.absent(),
    this.wydDedicated = const Value.absent(),
  });
  RosarySessionsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime startAt,
    required DateTime endAt,
    required int tapCount,
    this.wydDedicated = const Value.absent(),
  }) : startAt = Value(startAt),
       endAt = Value(endAt),
       tapCount = Value(tapCount);
  static Insertable<RosarySession> custom({
    Expression<int>? id,
    Expression<DateTime>? startAt,
    Expression<DateTime>? endAt,
    Expression<int>? tapCount,
    Expression<bool>? wydDedicated,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (startAt != null) 'start_at': startAt,
      if (endAt != null) 'end_at': endAt,
      if (tapCount != null) 'tap_count': tapCount,
      if (wydDedicated != null) 'wyd_dedicated': wydDedicated,
    });
  }

  RosarySessionsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? startAt,
    Value<DateTime>? endAt,
    Value<int>? tapCount,
    Value<bool>? wydDedicated,
  }) {
    return RosarySessionsCompanion(
      id: id ?? this.id,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      tapCount: tapCount ?? this.tapCount,
      wydDedicated: wydDedicated ?? this.wydDedicated,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (startAt.present) {
      map['start_at'] = Variable<DateTime>(startAt.value);
    }
    if (endAt.present) {
      map['end_at'] = Variable<DateTime>(endAt.value);
    }
    if (tapCount.present) {
      map['tap_count'] = Variable<int>(tapCount.value);
    }
    if (wydDedicated.present) {
      map['wyd_dedicated'] = Variable<bool>(wydDedicated.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RosarySessionsCompanion(')
          ..write('id: $id, ')
          ..write('startAt: $startAt, ')
          ..write('endAt: $endAt, ')
          ..write('tapCount: $tapCount, ')
          ..write('wydDedicated: $wydDedicated')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SleepDetailsTable sleepDetails = $SleepDetailsTable(this);
  late final $HeartDetailsTable heartDetails = $HeartDetailsTable(this);
  late final $StressDetailsTable stressDetails = $StressDetailsTable(this);
  late final $BloodOxygenDetailsTable bloodOxygenDetails =
      $BloodOxygenDetailsTable(this);
  late final $SportDetailsTable sportDetails = $SportDetailsTable(this);
  late final $RosarySessionsTable rosarySessions = $RosarySessionsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    sleepDetails,
    heartDetails,
    stressDetails,
    bloodOxygenDetails,
    sportDetails,
    rosarySessions,
  ];
}

typedef $$SleepDetailsTableCreateCompanionBuilder =
    SleepDetailsCompanion Function({
      Value<int> id,
      required DateTime date,
      required DateTime start,
      required DateTime end,
      required int type,
    });
typedef $$SleepDetailsTableUpdateCompanionBuilder =
    SleepDetailsCompanion Function({
      Value<int> id,
      Value<DateTime> date,
      Value<DateTime> start,
      Value<DateTime> end,
      Value<int> type,
    });

class $$SleepDetailsTableFilterComposer
    extends Composer<_$AppDatabase, $SleepDetailsTable> {
  $$SleepDetailsTableFilterComposer({
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

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get start => $composableBuilder(
    column: $table.start,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get end => $composableBuilder(
    column: $table.end,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SleepDetailsTableOrderingComposer
    extends Composer<_$AppDatabase, $SleepDetailsTable> {
  $$SleepDetailsTableOrderingComposer({
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

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get start => $composableBuilder(
    column: $table.start,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get end => $composableBuilder(
    column: $table.end,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SleepDetailsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SleepDetailsTable> {
  $$SleepDetailsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<DateTime> get start =>
      $composableBuilder(column: $table.start, builder: (column) => column);

  GeneratedColumn<DateTime> get end =>
      $composableBuilder(column: $table.end, builder: (column) => column);

  GeneratedColumn<int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);
}

class $$SleepDetailsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SleepDetailsTable,
          SleepDetail,
          $$SleepDetailsTableFilterComposer,
          $$SleepDetailsTableOrderingComposer,
          $$SleepDetailsTableAnnotationComposer,
          $$SleepDetailsTableCreateCompanionBuilder,
          $$SleepDetailsTableUpdateCompanionBuilder,
          (
            SleepDetail,
            BaseReferences<_$AppDatabase, $SleepDetailsTable, SleepDetail>,
          ),
          SleepDetail,
          PrefetchHooks Function()
        > {
  $$SleepDetailsTableTableManager(_$AppDatabase db, $SleepDetailsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SleepDetailsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SleepDetailsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SleepDetailsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<DateTime> start = const Value.absent(),
                Value<DateTime> end = const Value.absent(),
                Value<int> type = const Value.absent(),
              }) => SleepDetailsCompanion(
                id: id,
                date: date,
                start: start,
                end: end,
                type: type,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime date,
                required DateTime start,
                required DateTime end,
                required int type,
              }) => SleepDetailsCompanion.insert(
                id: id,
                date: date,
                start: start,
                end: end,
                type: type,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SleepDetailsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SleepDetailsTable,
      SleepDetail,
      $$SleepDetailsTableFilterComposer,
      $$SleepDetailsTableOrderingComposer,
      $$SleepDetailsTableAnnotationComposer,
      $$SleepDetailsTableCreateCompanionBuilder,
      $$SleepDetailsTableUpdateCompanionBuilder,
      (
        SleepDetail,
        BaseReferences<_$AppDatabase, $SleepDetailsTable, SleepDetail>,
      ),
      SleepDetail,
      PrefetchHooks Function()
    >;
typedef $$HeartDetailsTableCreateCompanionBuilder =
    HeartDetailsCompanion Function({
      Value<int> id,
      required DateTime date,
      required int bpm,
      Value<String> source,
      Value<String?> dedupeKey,
      Value<String?> ringSeq,
    });
typedef $$HeartDetailsTableUpdateCompanionBuilder =
    HeartDetailsCompanion Function({
      Value<int> id,
      Value<DateTime> date,
      Value<int> bpm,
      Value<String> source,
      Value<String?> dedupeKey,
      Value<String?> ringSeq,
    });

class $$HeartDetailsTableFilterComposer
    extends Composer<_$AppDatabase, $HeartDetailsTable> {
  $$HeartDetailsTableFilterComposer({
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

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bpm => $composableBuilder(
    column: $table.bpm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dedupeKey => $composableBuilder(
    column: $table.dedupeKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ringSeq => $composableBuilder(
    column: $table.ringSeq,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HeartDetailsTableOrderingComposer
    extends Composer<_$AppDatabase, $HeartDetailsTable> {
  $$HeartDetailsTableOrderingComposer({
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

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bpm => $composableBuilder(
    column: $table.bpm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dedupeKey => $composableBuilder(
    column: $table.dedupeKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ringSeq => $composableBuilder(
    column: $table.ringSeq,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HeartDetailsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HeartDetailsTable> {
  $$HeartDetailsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get bpm =>
      $composableBuilder(column: $table.bpm, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get dedupeKey =>
      $composableBuilder(column: $table.dedupeKey, builder: (column) => column);

  GeneratedColumn<String> get ringSeq =>
      $composableBuilder(column: $table.ringSeq, builder: (column) => column);
}

class $$HeartDetailsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HeartDetailsTable,
          HeartDetail,
          $$HeartDetailsTableFilterComposer,
          $$HeartDetailsTableOrderingComposer,
          $$HeartDetailsTableAnnotationComposer,
          $$HeartDetailsTableCreateCompanionBuilder,
          $$HeartDetailsTableUpdateCompanionBuilder,
          (
            HeartDetail,
            BaseReferences<_$AppDatabase, $HeartDetailsTable, HeartDetail>,
          ),
          HeartDetail,
          PrefetchHooks Function()
        > {
  $$HeartDetailsTableTableManager(_$AppDatabase db, $HeartDetailsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HeartDetailsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HeartDetailsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HeartDetailsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<int> bpm = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> dedupeKey = const Value.absent(),
                Value<String?> ringSeq = const Value.absent(),
              }) => HeartDetailsCompanion(
                id: id,
                date: date,
                bpm: bpm,
                source: source,
                dedupeKey: dedupeKey,
                ringSeq: ringSeq,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime date,
                required int bpm,
                Value<String> source = const Value.absent(),
                Value<String?> dedupeKey = const Value.absent(),
                Value<String?> ringSeq = const Value.absent(),
              }) => HeartDetailsCompanion.insert(
                id: id,
                date: date,
                bpm: bpm,
                source: source,
                dedupeKey: dedupeKey,
                ringSeq: ringSeq,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HeartDetailsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HeartDetailsTable,
      HeartDetail,
      $$HeartDetailsTableFilterComposer,
      $$HeartDetailsTableOrderingComposer,
      $$HeartDetailsTableAnnotationComposer,
      $$HeartDetailsTableCreateCompanionBuilder,
      $$HeartDetailsTableUpdateCompanionBuilder,
      (
        HeartDetail,
        BaseReferences<_$AppDatabase, $HeartDetailsTable, HeartDetail>,
      ),
      HeartDetail,
      PrefetchHooks Function()
    >;
typedef $$StressDetailsTableCreateCompanionBuilder =
    StressDetailsCompanion Function({
      Value<int> id,
      required DateTime date,
      required int stress,
      Value<String> source,
      Value<String?> dedupeKey,
      Value<String?> ringSeq,
    });
typedef $$StressDetailsTableUpdateCompanionBuilder =
    StressDetailsCompanion Function({
      Value<int> id,
      Value<DateTime> date,
      Value<int> stress,
      Value<String> source,
      Value<String?> dedupeKey,
      Value<String?> ringSeq,
    });

class $$StressDetailsTableFilterComposer
    extends Composer<_$AppDatabase, $StressDetailsTable> {
  $$StressDetailsTableFilterComposer({
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

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stress => $composableBuilder(
    column: $table.stress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dedupeKey => $composableBuilder(
    column: $table.dedupeKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ringSeq => $composableBuilder(
    column: $table.ringSeq,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StressDetailsTableOrderingComposer
    extends Composer<_$AppDatabase, $StressDetailsTable> {
  $$StressDetailsTableOrderingComposer({
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

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stress => $composableBuilder(
    column: $table.stress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dedupeKey => $composableBuilder(
    column: $table.dedupeKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ringSeq => $composableBuilder(
    column: $table.ringSeq,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StressDetailsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StressDetailsTable> {
  $$StressDetailsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get stress =>
      $composableBuilder(column: $table.stress, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get dedupeKey =>
      $composableBuilder(column: $table.dedupeKey, builder: (column) => column);

  GeneratedColumn<String> get ringSeq =>
      $composableBuilder(column: $table.ringSeq, builder: (column) => column);
}

class $$StressDetailsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StressDetailsTable,
          StressDetail,
          $$StressDetailsTableFilterComposer,
          $$StressDetailsTableOrderingComposer,
          $$StressDetailsTableAnnotationComposer,
          $$StressDetailsTableCreateCompanionBuilder,
          $$StressDetailsTableUpdateCompanionBuilder,
          (
            StressDetail,
            BaseReferences<_$AppDatabase, $StressDetailsTable, StressDetail>,
          ),
          StressDetail,
          PrefetchHooks Function()
        > {
  $$StressDetailsTableTableManager(_$AppDatabase db, $StressDetailsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StressDetailsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StressDetailsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StressDetailsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<int> stress = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> dedupeKey = const Value.absent(),
                Value<String?> ringSeq = const Value.absent(),
              }) => StressDetailsCompanion(
                id: id,
                date: date,
                stress: stress,
                source: source,
                dedupeKey: dedupeKey,
                ringSeq: ringSeq,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime date,
                required int stress,
                Value<String> source = const Value.absent(),
                Value<String?> dedupeKey = const Value.absent(),
                Value<String?> ringSeq = const Value.absent(),
              }) => StressDetailsCompanion.insert(
                id: id,
                date: date,
                stress: stress,
                source: source,
                dedupeKey: dedupeKey,
                ringSeq: ringSeq,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StressDetailsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StressDetailsTable,
      StressDetail,
      $$StressDetailsTableFilterComposer,
      $$StressDetailsTableOrderingComposer,
      $$StressDetailsTableAnnotationComposer,
      $$StressDetailsTableCreateCompanionBuilder,
      $$StressDetailsTableUpdateCompanionBuilder,
      (
        StressDetail,
        BaseReferences<_$AppDatabase, $StressDetailsTable, StressDetail>,
      ),
      StressDetail,
      PrefetchHooks Function()
    >;
typedef $$BloodOxygenDetailsTableCreateCompanionBuilder =
    BloodOxygenDetailsCompanion Function({
      Value<int> id,
      required DateTime date,
      required int spo2,
      Value<String> source,
      Value<String?> dedupeKey,
      Value<String?> ringSeq,
    });
typedef $$BloodOxygenDetailsTableUpdateCompanionBuilder =
    BloodOxygenDetailsCompanion Function({
      Value<int> id,
      Value<DateTime> date,
      Value<int> spo2,
      Value<String> source,
      Value<String?> dedupeKey,
      Value<String?> ringSeq,
    });

class $$BloodOxygenDetailsTableFilterComposer
    extends Composer<_$AppDatabase, $BloodOxygenDetailsTable> {
  $$BloodOxygenDetailsTableFilterComposer({
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

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get spo2 => $composableBuilder(
    column: $table.spo2,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dedupeKey => $composableBuilder(
    column: $table.dedupeKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ringSeq => $composableBuilder(
    column: $table.ringSeq,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BloodOxygenDetailsTableOrderingComposer
    extends Composer<_$AppDatabase, $BloodOxygenDetailsTable> {
  $$BloodOxygenDetailsTableOrderingComposer({
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

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get spo2 => $composableBuilder(
    column: $table.spo2,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dedupeKey => $composableBuilder(
    column: $table.dedupeKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ringSeq => $composableBuilder(
    column: $table.ringSeq,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BloodOxygenDetailsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BloodOxygenDetailsTable> {
  $$BloodOxygenDetailsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get spo2 =>
      $composableBuilder(column: $table.spo2, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get dedupeKey =>
      $composableBuilder(column: $table.dedupeKey, builder: (column) => column);

  GeneratedColumn<String> get ringSeq =>
      $composableBuilder(column: $table.ringSeq, builder: (column) => column);
}

class $$BloodOxygenDetailsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BloodOxygenDetailsTable,
          BloodOxygenDetail,
          $$BloodOxygenDetailsTableFilterComposer,
          $$BloodOxygenDetailsTableOrderingComposer,
          $$BloodOxygenDetailsTableAnnotationComposer,
          $$BloodOxygenDetailsTableCreateCompanionBuilder,
          $$BloodOxygenDetailsTableUpdateCompanionBuilder,
          (
            BloodOxygenDetail,
            BaseReferences<
              _$AppDatabase,
              $BloodOxygenDetailsTable,
              BloodOxygenDetail
            >,
          ),
          BloodOxygenDetail,
          PrefetchHooks Function()
        > {
  $$BloodOxygenDetailsTableTableManager(
    _$AppDatabase db,
    $BloodOxygenDetailsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BloodOxygenDetailsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BloodOxygenDetailsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BloodOxygenDetailsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<int> spo2 = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> dedupeKey = const Value.absent(),
                Value<String?> ringSeq = const Value.absent(),
              }) => BloodOxygenDetailsCompanion(
                id: id,
                date: date,
                spo2: spo2,
                source: source,
                dedupeKey: dedupeKey,
                ringSeq: ringSeq,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime date,
                required int spo2,
                Value<String> source = const Value.absent(),
                Value<String?> dedupeKey = const Value.absent(),
                Value<String?> ringSeq = const Value.absent(),
              }) => BloodOxygenDetailsCompanion.insert(
                id: id,
                date: date,
                spo2: spo2,
                source: source,
                dedupeKey: dedupeKey,
                ringSeq: ringSeq,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BloodOxygenDetailsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BloodOxygenDetailsTable,
      BloodOxygenDetail,
      $$BloodOxygenDetailsTableFilterComposer,
      $$BloodOxygenDetailsTableOrderingComposer,
      $$BloodOxygenDetailsTableAnnotationComposer,
      $$BloodOxygenDetailsTableCreateCompanionBuilder,
      $$BloodOxygenDetailsTableUpdateCompanionBuilder,
      (
        BloodOxygenDetail,
        BaseReferences<
          _$AppDatabase,
          $BloodOxygenDetailsTable,
          BloodOxygenDetail
        >,
      ),
      BloodOxygenDetail,
      PrefetchHooks Function()
    >;
typedef $$SportDetailsTableCreateCompanionBuilder =
    SportDetailsCompanion Function({
      Value<int> id,
      required DateTime date,
      required int timeIndex,
      required int walkSteps,
      required int runSteps,
      required int distance,
      required int calorie,
    });
typedef $$SportDetailsTableUpdateCompanionBuilder =
    SportDetailsCompanion Function({
      Value<int> id,
      Value<DateTime> date,
      Value<int> timeIndex,
      Value<int> walkSteps,
      Value<int> runSteps,
      Value<int> distance,
      Value<int> calorie,
    });

class $$SportDetailsTableFilterComposer
    extends Composer<_$AppDatabase, $SportDetailsTable> {
  $$SportDetailsTableFilterComposer({
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

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timeIndex => $composableBuilder(
    column: $table.timeIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get walkSteps => $composableBuilder(
    column: $table.walkSteps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get runSteps => $composableBuilder(
    column: $table.runSteps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get distance => $composableBuilder(
    column: $table.distance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get calorie => $composableBuilder(
    column: $table.calorie,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SportDetailsTableOrderingComposer
    extends Composer<_$AppDatabase, $SportDetailsTable> {
  $$SportDetailsTableOrderingComposer({
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

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timeIndex => $composableBuilder(
    column: $table.timeIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get walkSteps => $composableBuilder(
    column: $table.walkSteps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get runSteps => $composableBuilder(
    column: $table.runSteps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get distance => $composableBuilder(
    column: $table.distance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get calorie => $composableBuilder(
    column: $table.calorie,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SportDetailsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SportDetailsTable> {
  $$SportDetailsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get timeIndex =>
      $composableBuilder(column: $table.timeIndex, builder: (column) => column);

  GeneratedColumn<int> get walkSteps =>
      $composableBuilder(column: $table.walkSteps, builder: (column) => column);

  GeneratedColumn<int> get runSteps =>
      $composableBuilder(column: $table.runSteps, builder: (column) => column);

  GeneratedColumn<int> get distance =>
      $composableBuilder(column: $table.distance, builder: (column) => column);

  GeneratedColumn<int> get calorie =>
      $composableBuilder(column: $table.calorie, builder: (column) => column);
}

class $$SportDetailsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SportDetailsTable,
          SportDetail,
          $$SportDetailsTableFilterComposer,
          $$SportDetailsTableOrderingComposer,
          $$SportDetailsTableAnnotationComposer,
          $$SportDetailsTableCreateCompanionBuilder,
          $$SportDetailsTableUpdateCompanionBuilder,
          (
            SportDetail,
            BaseReferences<_$AppDatabase, $SportDetailsTable, SportDetail>,
          ),
          SportDetail,
          PrefetchHooks Function()
        > {
  $$SportDetailsTableTableManager(_$AppDatabase db, $SportDetailsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SportDetailsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SportDetailsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SportDetailsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<int> timeIndex = const Value.absent(),
                Value<int> walkSteps = const Value.absent(),
                Value<int> runSteps = const Value.absent(),
                Value<int> distance = const Value.absent(),
                Value<int> calorie = const Value.absent(),
              }) => SportDetailsCompanion(
                id: id,
                date: date,
                timeIndex: timeIndex,
                walkSteps: walkSteps,
                runSteps: runSteps,
                distance: distance,
                calorie: calorie,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime date,
                required int timeIndex,
                required int walkSteps,
                required int runSteps,
                required int distance,
                required int calorie,
              }) => SportDetailsCompanion.insert(
                id: id,
                date: date,
                timeIndex: timeIndex,
                walkSteps: walkSteps,
                runSteps: runSteps,
                distance: distance,
                calorie: calorie,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SportDetailsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SportDetailsTable,
      SportDetail,
      $$SportDetailsTableFilterComposer,
      $$SportDetailsTableOrderingComposer,
      $$SportDetailsTableAnnotationComposer,
      $$SportDetailsTableCreateCompanionBuilder,
      $$SportDetailsTableUpdateCompanionBuilder,
      (
        SportDetail,
        BaseReferences<_$AppDatabase, $SportDetailsTable, SportDetail>,
      ),
      SportDetail,
      PrefetchHooks Function()
    >;
typedef $$RosarySessionsTableCreateCompanionBuilder =
    RosarySessionsCompanion Function({
      Value<int> id,
      required DateTime startAt,
      required DateTime endAt,
      required int tapCount,
      Value<bool> wydDedicated,
    });
typedef $$RosarySessionsTableUpdateCompanionBuilder =
    RosarySessionsCompanion Function({
      Value<int> id,
      Value<DateTime> startAt,
      Value<DateTime> endAt,
      Value<int> tapCount,
      Value<bool> wydDedicated,
    });

class $$RosarySessionsTableFilterComposer
    extends Composer<_$AppDatabase, $RosarySessionsTable> {
  $$RosarySessionsTableFilterComposer({
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

  ColumnFilters<DateTime> get startAt => $composableBuilder(
    column: $table.startAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endAt => $composableBuilder(
    column: $table.endAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tapCount => $composableBuilder(
    column: $table.tapCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get wydDedicated => $composableBuilder(
    column: $table.wydDedicated,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RosarySessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $RosarySessionsTable> {
  $$RosarySessionsTableOrderingComposer({
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

  ColumnOrderings<DateTime> get startAt => $composableBuilder(
    column: $table.startAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endAt => $composableBuilder(
    column: $table.endAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tapCount => $composableBuilder(
    column: $table.tapCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get wydDedicated => $composableBuilder(
    column: $table.wydDedicated,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RosarySessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RosarySessionsTable> {
  $$RosarySessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get startAt =>
      $composableBuilder(column: $table.startAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endAt =>
      $composableBuilder(column: $table.endAt, builder: (column) => column);

  GeneratedColumn<int> get tapCount =>
      $composableBuilder(column: $table.tapCount, builder: (column) => column);

  GeneratedColumn<bool> get wydDedicated => $composableBuilder(
    column: $table.wydDedicated,
    builder: (column) => column,
  );
}

class $$RosarySessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RosarySessionsTable,
          RosarySession,
          $$RosarySessionsTableFilterComposer,
          $$RosarySessionsTableOrderingComposer,
          $$RosarySessionsTableAnnotationComposer,
          $$RosarySessionsTableCreateCompanionBuilder,
          $$RosarySessionsTableUpdateCompanionBuilder,
          (
            RosarySession,
            BaseReferences<_$AppDatabase, $RosarySessionsTable, RosarySession>,
          ),
          RosarySession,
          PrefetchHooks Function()
        > {
  $$RosarySessionsTableTableManager(
    _$AppDatabase db,
    $RosarySessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RosarySessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RosarySessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RosarySessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> startAt = const Value.absent(),
                Value<DateTime> endAt = const Value.absent(),
                Value<int> tapCount = const Value.absent(),
                Value<bool> wydDedicated = const Value.absent(),
              }) => RosarySessionsCompanion(
                id: id,
                startAt: startAt,
                endAt: endAt,
                tapCount: tapCount,
                wydDedicated: wydDedicated,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime startAt,
                required DateTime endAt,
                required int tapCount,
                Value<bool> wydDedicated = const Value.absent(),
              }) => RosarySessionsCompanion.insert(
                id: id,
                startAt: startAt,
                endAt: endAt,
                tapCount: tapCount,
                wydDedicated: wydDedicated,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RosarySessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RosarySessionsTable,
      RosarySession,
      $$RosarySessionsTableFilterComposer,
      $$RosarySessionsTableOrderingComposer,
      $$RosarySessionsTableAnnotationComposer,
      $$RosarySessionsTableCreateCompanionBuilder,
      $$RosarySessionsTableUpdateCompanionBuilder,
      (
        RosarySession,
        BaseReferences<_$AppDatabase, $RosarySessionsTable, RosarySession>,
      ),
      RosarySession,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SleepDetailsTableTableManager get sleepDetails =>
      $$SleepDetailsTableTableManager(_db, _db.sleepDetails);
  $$HeartDetailsTableTableManager get heartDetails =>
      $$HeartDetailsTableTableManager(_db, _db.heartDetails);
  $$StressDetailsTableTableManager get stressDetails =>
      $$StressDetailsTableTableManager(_db, _db.stressDetails);
  $$BloodOxygenDetailsTableTableManager get bloodOxygenDetails =>
      $$BloodOxygenDetailsTableTableManager(_db, _db.bloodOxygenDetails);
  $$SportDetailsTableTableManager get sportDetails =>
      $$SportDetailsTableTableManager(_db, _db.sportDetails);
  $$RosarySessionsTableTableManager get rosarySessions =>
      $$RosarySessionsTableTableManager(_db, _db.rosarySessions);
}
