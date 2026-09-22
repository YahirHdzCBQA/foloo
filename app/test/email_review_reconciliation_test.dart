/// Verifies PLT-08/SAL-01 semantic Review reconciliation before send intent.
///
/// Manual literals remain durable while canonical D-14 variables continue to
/// follow the current Lead, seller and Content selection independently.
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/data/local/app_database.dart';
import 'package:foloo/data/repositories/local_repositories.dart';
import 'package:foloo/models/app_event.dart';
import 'package:foloo/models/email_template.dart';
import 'package:foloo/models/lead_draft.dart';

const _owner = 'seller-a';
const _leadId = '11111111-1111-4111-8111-111111111111';
const _eventId = '22222222-2222-4222-8222-222222222222';
const _seller = DemoProfile(name: 'Ana', company: 'Foloo');

LeadDraft _lead({
  String name = 'Pedro',
  String lastName = 'Uno',
  String company = 'Empresa Uno',
  String role = 'Compras',
  String eventName = 'Expo Uno',
  String email = 'pedro@example.com',
  List<String> contentIds = const ['content-a', 'content-b'],
  List<String> contentNames = const ['Ficha A', 'Ficha B'],
}) => LeadDraft(
  name: name,
  lastName: lastName,
  role: role,
  company: company,
  email: email,
  phone: '',
  type: LeadType.customer,
  interest: InterestLevel.high,
  note: '',
  originKind: LeadOriginKind.event,
  eventLocalId: _eventId,
  eventName: eventName,
  audioSeconds: 0,
  contentFileIds: contentIds,
  contentNames: contentNames,
);

Future<void> _seed(AppDatabase database) async {
  final now = DateTime.utc(2026, 9, 22);
  await database.eventDao.upsert(
    LocalEventsCompanion.insert(
      localId: _eventId,
      ownerUserId: const Value(_owner),
      name: 'Expo Uno',
      startsOn: now,
      endsOn: now,
      createdAt: now,
      updatedAt: now,
    ),
  );
  await database.leadDao.insertLead(
    LocalLeadsCompanion.insert(
      localId: _leadId,
      ownerUserId: const Value(_owner),
      capturedAt: now,
      capturedBy: _seller.name,
      originKind: 'event',
      eventLocalId: const Value(_eventId),
      eventNameSnapshot: const Value('Expo Uno'),
      name: 'Pedro',
      lastName: 'Uno',
      role: 'Compras',
      company: 'Empresa Uno',
      email: 'pedro@example.com',
      phone: '',
      leadType: 'customer',
      interestLevel: 'high',
      note: '',
      createdAt: now,
      updatedAt: now,
    ),
  );
  await EmailTemplateRepository(database).save(
    _owner,
    const EmailTemplateData(
      origin: 'event',
      language: 'es',
      subject: 'Damos seguimiento, {nombre}',
      body:
          'Hola {nombre} {apellido},\n{empresa}|{puesto}|{evento}\n{contenido}',
      signature: '{nombreVendedor}|{empresaVendedor}',
    ),
  );
}

void main() {
  test(
    'body-only Review edit keeps literals and rerenders every D-14 variable',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await _seed(database);
      final repository = EmailDeliveryRepository(database);

      final initial = await repository.prepareForLead(
        owner: _owner,
        leadId: _leadId,
        lead: _lead(name: 'Juan', email: 'juan@example.com'),
        seller: _seller,
        language: 'es',
      );
      final pedro = await repository.prepareForLead(
        owner: _owner,
        leadId: _leadId,
        lead: _lead(),
        seller: _seller,
        language: 'es',
        reconcileExisting: true,
      );
      expect(pedro!.localId, initial!.localId);
      expect(pedro.recipientAddress, 'pedro@example.com');
      expect(pedro.subject, 'Damos seguimiento, Pedro');
      expect(pedro.plainBody, contains('Hola Pedro Uno,'));

      final editedBody = pedro.plainBody
          .replaceFirst('Pedro', 'Pedro ❤️❤️')
          .replaceFirst(
            '\nAna|Foloo',
            '\nHablé con Pedro de logística.\nAna|Foloo',
          );
      await repository.updatePreparation(
        owner: _owner,
        followUpId: pedro.localId,
        subject: pedro.subject,
        plainBody: editedBody,
        lead: _lead(),
        seller: _seller,
      );

      final currentLead = _lead(
        name: 'Carlos',
        lastName: 'Dos',
        company: 'Empresa Dos',
        role: 'Calidad',
        eventName: 'Expo Dos',
        email: 'carlos@example.com',
        contentIds: const ['content-c'],
        contentNames: const ['Ficha C'],
      );
      final reconciled = await repository.prepareForLead(
        owner: _owner,
        leadId: _leadId,
        lead: currentLead,
        seller: const DemoProfile(name: 'Bea', company: 'Nueva Empresa'),
        language: 'es',
        reconcileExisting: true,
      );

      expect(reconciled!.localId, pedro.localId);
      expect(reconciled.recipientAddress, 'carlos@example.com');
      expect(reconciled.subject, 'Damos seguimiento, Carlos');
      expect(reconciled.plainBody, contains('Hola Carlos ❤️❤️ Dos,'));
      expect(reconciled.plainBody, contains('Empresa Dos|Calidad|Expo Dos'));
      expect(reconciled.plainBody, contains('Ficha C'));
      expect(reconciled.plainBody, contains('Hablé con Pedro de logística.'));
      expect(reconciled.plainBody, endsWith('Bea|Nueva Empresa'));
      expect(jsonDecode(reconciled.contentFileIdsJson), ['content-c']);
      expect(jsonDecode(reconciled.contentNamesJson), ['Ficha C']);
      expect(await repository.list(_owner), hasLength(1));

      final stored = await database.emailDeliveryDao.followUpById(
        _owner,
        pedro.localId,
      );
      expect(stored!.subjectManuallyEdited, isFalse);
      expect(stored.bodyManuallyEdited, isTrue);
    },
  );

  test(
    'subject-only and both-field edits retain independent semantics',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await _seed(database);
      final repository = EmailDeliveryRepository(database);
      final prepared = await repository.prepareForLead(
        owner: _owner,
        leadId: _leadId,
        lead: _lead(),
        seller: _seller,
        language: 'es',
      );

      await repository.updatePreparation(
        owner: _owner,
        followUpId: prepared!.localId,
        subject: '⭐ ${prepared.subject}',
        plainBody: prepared.plainBody,
        lead: _lead(),
        seller: _seller,
      );
      final subjectOnly = await repository.prepareForLead(
        owner: _owner,
        leadId: _leadId,
        lead: _lead(name: 'Carlos'),
        seller: _seller,
        language: 'es',
        reconcileExisting: true,
      );
      expect(subjectOnly!.subject, '⭐ Damos seguimiento, Carlos');
      expect(subjectOnly.plainBody, contains('Hola Carlos Uno,'));
      expect(subjectOnly.subjectManuallyEdited, isTrue);
      expect(subjectOnly.bodyManuallyEdited, isFalse);

      await repository.updatePreparation(
        owner: _owner,
        followUpId: prepared.localId,
        subject: '${subjectOnly.subject} ✅',
        plainBody: '${subjectOnly.plainBody}\nNota manual ❤️',
        lead: _lead(name: 'Carlos'),
        seller: _seller,
      );
      final both = await repository.prepareForLead(
        owner: _owner,
        leadId: _leadId,
        lead: _lead(name: 'María', lastName: 'Tres'),
        seller: _seller,
        language: 'es',
        reconcileExisting: true,
      );
      expect(both!.subject, '⭐ Damos seguimiento, María ✅');
      expect(both.plainBody, contains('Hola María Tres,'));
      expect(both.plainBody, endsWith('Nota manual ❤️'));
      expect(both.subjectManuallyEdited, isTrue);
      expect(both.bodyManuallyEdited, isTrue);
    },
  );

  test('semantic Review metadata survives database close and reopen', () async {
    final directory = await Directory.systemTemp.createTemp(
      'foloo_email_review_',
    );
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final file = File('${directory.path}/foloo.sqlite');
    var database = AppDatabase(NativeDatabase(file));
    await _seed(database);
    var repository = EmailDeliveryRepository(database);
    final prepared = await repository.prepareForLead(
      owner: _owner,
      leadId: _leadId,
      lead: _lead(),
      seller: _seller,
      language: 'es',
    );
    await repository.updatePreparation(
      owner: _owner,
      followUpId: prepared!.localId,
      subject: prepared.subject,
      plainBody: prepared.plainBody.replaceFirst('Pedro', 'Pedro ❤️'),
      lead: _lead(),
      seller: _seller,
    );
    await database.close();

    database = AppDatabase(NativeDatabase(file));
    addTearDown(database.close);
    repository = EmailDeliveryRepository(database);
    final reopened = await repository.prepareForLead(
      owner: _owner,
      leadId: _leadId,
      lead: _lead(name: 'Carlos', email: 'carlos@example.com'),
      seller: _seller,
      language: 'es',
      reconcileExisting: true,
    );
    expect(reopened!.localId, prepared.localId);
    expect(reopened.recipientAddress, 'carlos@example.com');
    expect(reopened.subject, 'Damos seguimiento, Carlos');
    expect(reopened.plainBody, contains('Hola Carlos ❤️ Uno,'));
    expect(reopened.bodyManuallyEdited, isTrue);

    final intentId = await repository.confirm(
      owner: _owner,
      followUpId: reopened.localId,
    );
    await repository.confirm(
      owner: _owner,
      followUpId: reopened.localId,
      intentId: intentId,
    );
    expect(await repository.intents(_owner), hasLength(1));
    final frozen = (await repository.list(_owner)).single;
    expect(frozen.subject, 'Damos seguimiento, Carlos');
    expect(frozen.plainBody, contains('Hola Carlos ❤️ Uno,'));
  });
}
