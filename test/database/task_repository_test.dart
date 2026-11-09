import 'package:drift/native.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myflow/database/app_database.dart';
import 'package:myflow/database/responsibility_repository_impl.dart';
import 'package:myflow/database/task_repository_impl.dart';
import 'package:myflow/shared/enums/app_enums.dart';

void main() {
  late AppDatabase db;
  late DriftTaskRepository repository;

  final DateTime today = DateTime(2026, 11, 5);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final DriftResponsibilityRepository responsibilities =
        DriftResponsibilityRepository(db);
    await responsibilities.insertResponsibility(
      id: 'resp-1',
      name: 'دانشجو',
      color: const Color(0xFF3B82F6),
    );
    repository = DriftTaskRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  List<String> titlesOf(List<Task> tasks) =>
      tasks.map((Task task) => task.title).toList();

  group('ساخت و خواندن', () {
    test('وظیفه با همه‌ی فیلدها ذخیره و خوانده می‌شود', () async {
      final Task created = await repository.insertTask(
        responsibilityId: 'resp-1',
        title: '  ارسال گزارش  ',
        priority: Priority.high,
        dueDate: today,
        dueTime: '09:05',
        estimatedMinutes: 45,
      );

      expect(created.title, 'ارسال گزارش');
      expect(created.priority, Priority.high);
      expect(created.status, TaskStatus.todo);
      expect(created.dueDate, '2026-11-05');
      expect(created.dueTime, '09:05:00');
      expect(created.estimatedMinutes, 45);
      expect(created.archivedAt, isNull);

      final Task? loaded = await repository.getTaskById(created.id);
      expect(loaded?.title, 'ارسال گزارش');
    });

    test('وظیفه‌ی بدون تاریخ ذخیره می‌شود', () async {
      final Task created = await repository.insertTask(
        responsibilityId: 'resp-1',
        title: 'خواندن مقاله',
      );

      expect(created.dueDate, isNull);
      expect(created.dueTime, isNull);
      expect(created.estimatedMinutes, isNull);
    });
  });

  group('اعتبارسنجی', () {
    test('عنوان خالی رد می‌شود', () {
      expect(
        () => repository.insertTask(
          responsibilityId: 'resp-1',
          title: '   ',
        ),
        throwsA(isA<TaskValidationException>()),
      );
    });

    test('عنوان بلندتر از ۲۰۰ کاراکتر رد می‌شود', () {
      expect(
        () => repository.insertTask(
          responsibilityId: 'resp-1',
          title: 'ا' * 201,
        ),
        throwsA(isA<TaskValidationException>()),
      );
    });

    test('زمان تخمینی صفر رد می‌شود', () {
      expect(
        () => repository.insertTask(
          responsibilityId: 'resp-1',
          title: 'کار',
          estimatedMinutes: 0,
        ),
        throwsA(isA<TaskValidationException>()),
      );
    });

    test('ساعت بدون تاریخ سررسید رد می‌شود', () {
      expect(
        () => repository.insertTask(
          responsibilityId: 'resp-1',
          title: 'کار',
          dueTime: '10:00',
        ),
        throwsA(isA<TaskValidationException>()),
      );
    });

    test('ساعت نامعتبر رد می‌شود', () {
      expect(
        () => repository.insertTask(
          responsibilityId: 'resp-1',
          title: 'کار',
          dueDate: today,
          dueTime: '25:00',
        ),
        throwsA(isA<TaskValidationException>()),
      );
    });

    test('مسئولیت ناموجود با خطای کلید خارجی رد می‌شود', () async {
      await expectLater(
        repository.insertTask(
          responsibilityId: 'missing',
          title: 'کار',
        ),
        throwsA(anything),
      );
    });
  });

  group('فیلترها', () {
    setUp(() async {
      await repository.insertTask(
        responsibilityId: 'resp-1',
        title: 'امروز',
        dueDate: today,
      );
      await repository.insertTask(
        responsibilityId: 'resp-1',
        title: 'آینده',
        dueDate: DateTime(2026, 11, 9),
      );
      await repository.insertTask(
        responsibilityId: 'resp-1',
        title: 'عقب‌افتاده',
        dueDate: DateTime(2026, 11, 1),
      );
      await repository.insertTask(
        responsibilityId: 'resp-1',
        title: 'انجام‌شده',
        dueDate: DateTime(2026, 11, 4),
        status: TaskStatus.completed,
      );
    });

    test('فهرست کامل مرتب بر اساس سررسید است', () async {
      final List<Task> tasks = await repository.getTasks(today: today);
      expect(titlesOf(tasks), <String>[
        'عقب‌افتاده',
        'انجام‌شده',
        'امروز',
        'آینده',
      ]);
    });

    test('فیلتر امروز فقط سررسید امروز را می‌دهد', () async {
      final List<Task> tasks = await repository.getTasks(
        filter: TaskFilter.today,
        today: today,
      );
      expect(titlesOf(tasks), <String>['امروز']);
    });

    test('فیلتر آینده وظیفه‌های انجام‌نشده‌ی بعد از امروز را می‌دهد', () async {
      final List<Task> tasks = await repository.getTasks(
        filter: TaskFilter.upcoming,
        today: today,
      );
      expect(titlesOf(tasks), <String>['آینده']);
    });

    test('فیلتر عقب‌افتاده وظیفه‌ی تکمیل‌شده را حساب نمی‌کند', () async {
      final List<Task> tasks = await repository.getTasks(
        filter: TaskFilter.overdue,
        today: today,
      );
      expect(titlesOf(tasks), <String>['عقب‌افتاده']);
    });

    test('فیلتر تکمیل‌شده فقط وظیفه‌های تمام‌شده را می‌دهد', () async {
      final List<Task> tasks = await repository.getTasks(
        filter: TaskFilter.completed,
        today: today,
      );
      expect(titlesOf(tasks), <String>['انجام‌شده']);
    });
  });

  group('تکمیل و بازگشایی', () {
    test('تکمیل، مهر زمان می‌گذارد و بازگشایی آن را پاک می‌کند', () async {
      final Task task = await repository.insertTask(
        responsibilityId: 'resp-1',
        title: 'کار',
        dueDate: today,
      );
      expect(task.completedAtUtc, isNull);

      await repository.completeTask(task.id);
      final Task? completed = await repository.getTaskById(task.id);
      expect(completed?.status, TaskStatus.completed);
      expect(completed?.completedAtUtc, isNotNull);

      await repository.reopenTask(task.id);
      final Task? reopened = await repository.getTaskById(task.id);
      expect(reopened?.status, TaskStatus.todo);
      expect(reopened?.completedAtUtc, isNull);
    });

    test('ویرایش وضعیت به تکمیل‌شده، مهر زمان را هم می‌نویسد', () async {
      final Task task = await repository.insertTask(
        responsibilityId: 'resp-1',
        title: 'کار',
      );
      await repository.updateTask(id: task.id, status: TaskStatus.completed);

      final Task? updated = await repository.getTaskById(task.id);
      expect(updated?.status, TaskStatus.completed);
      expect(updated?.completedAtUtc, isNotNull);
    });
  });

  group('ویرایش و بایگانی', () {
    test('ویرایش عنوان و سررسید ذخیره می‌شود', () async {
      final Task task = await repository.insertTask(
        responsibilityId: 'resp-1',
        title: 'قدیمی',
      );
      await repository.updateTask(
        id: task.id,
        title: 'جدید',
        dueDate: DateTime(2026, 12, 1),
        priority: Priority.low,
      );

      final Task? updated = await repository.getTaskById(task.id);
      expect(updated?.title, 'جدید');
      expect(updated?.dueDate, '2026-12-01');
      expect(updated?.priority, Priority.low);
    });

    test('پاک کردن سررسید با clearDueDate کار می‌کند', () async {
      final Task task = await repository.insertTask(
        responsibilityId: 'resp-1',
        title: 'کار',
        dueDate: today,
      );
      await repository.updateTask(id: task.id, clearDueDate: true);

      final Task? updated = await repository.getTaskById(task.id);
      expect(updated?.dueDate, isNull);
    });

    test('ویرایش وظیفه‌ی ناموجود خطا می‌دهد', () {
      expect(
        () => repository.updateTask(id: 'missing', title: 'کار'),
        throwsA(isA<TaskNotFoundException>()),
      );
    });

    test('بایگانی وظیفه را از فهرست و خواندن بیرون می‌برد', () async {
      final Task task = await repository.insertTask(
        responsibilityId: 'resp-1',
        title: 'کار',
      );
      await repository.archiveTask(task.id);

      expect(await repository.getTasks(), isEmpty);
      expect(await repository.getTaskById(task.id), isNull);
    });

    test('حذف کامل ردیف را پاک می‌کند', () async {
      final Task task = await repository.insertTask(
        responsibilityId: 'resp-1',
        title: 'کار',
      );
      await repository.permanentlyDeleteTask(task.id);
      expect(await repository.getTaskById(task.id), isNull);
    });
  });

  group('کوئری بازه‌ای تاریخ سررسید', () {
    test('فقط وظایف داخل بازه با ترتیب تاریخ و ساعت برمی‌گردند', () async {
      await repository.insertTask(
        responsibilityId: 'resp-1',
        title: 'دوم',
        dueDate: DateTime(2026, 11, 6),
        dueTime: '08:00',
      );
      await repository.insertTask(
        responsibilityId: 'resp-1',
        title: 'اول-بعدازظهر',
        dueDate: DateTime(2026, 11, 5),
        dueTime: '15:00',
      );
      await repository.insertTask(
        responsibilityId: 'resp-1',
        title: 'اول-صبح',
        dueDate: DateTime(2026, 11, 5),
        dueTime: '09:00',
      );
      await repository.insertTask(
        responsibilityId: 'resp-1',
        title: 'بیرون از بازه',
        dueDate: DateTime(2026, 11, 9),
      );

      final List<Task> range = await repository.getTasksDueBetween(
        fromDay: DateTime(2026, 11, 5),
        toDay: DateTime(2026, 11, 7),
      );

      expect(
        titlesOf(range),
        <String>['اول-صبح', 'اول-بعدازظهر', 'دوم'],
      );
    });

    test('وظیفه‌ی بدون تاریخ و بایگانی‌شده در بازه نمی‌آید', () async {
      await repository.insertTask(
        responsibilityId: 'resp-1',
        title: 'بدون تاریخ',
      );
      final Task archived = await repository.insertTask(
        responsibilityId: 'resp-1',
        title: 'بایگانی‌شده',
        dueDate: DateTime(2026, 11, 5),
      );
      await repository.archiveTask(archived.id);

      final List<Task> range = await repository.getTasksDueBetween(
        fromDay: DateTime(2026, 11, 5),
        toDay: DateTime(2026, 11, 5),
      );

      expect(range, isEmpty);
    });
  });
}
