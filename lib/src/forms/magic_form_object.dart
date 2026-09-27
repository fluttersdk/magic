import '../actions/runs_actions.dart';
import '../concerns/validates_requests.dart';
import '../foundation/magic.dart';
import '../http/magic_controller.dart';
import '../ui/magic_form_data.dart';
import '../validation/exceptions/validation_exception.dart';
import '../validation/form_request.dart';

/// A Livewire-style Form object: one field-bound, validated, persistable
/// unit for a single screen's write.
///
/// Subclass and supply the three pieces of the contract:
///
/// ```dart
/// class MonitorFormObject extends MagicFormObject {
///   MonitorFormObject({this.editing});
///
///   final Monitor? editing;
///
///   @override
///   Map<String, dynamic> get initial => {
///     'name': editing?.name ?? '',
///     'url': editing?.url ?? '',
///   };
///
///   @override
///   FormRequest get request =>
///       editing == null ? const StoreMonitorRequest() : const UpdateMonitorRequest();
///
///   @override
///   Future<bool> persist(Map<String, dynamic> validated) async {
///     final monitor = editing ?? Monitor();
///     monitor.fill(validated, strict: true);
///     return monitor.save();
///   }
/// }
/// ```
///
/// Create ONE instance per `State` (`late final form = MonitorFormObject();`)
/// and call `form.dispose()` from that `State`'s `onClose`. Never register a
/// [MagicFormObject] in the container via `Magic.put`/`findOrPut`: it is
/// scoped to a single screen's lifetime, not the app's, and [onClose] asserts
/// (in debug) that it never ended up there.
abstract class MagicFormObject extends MagicController
    with ValidatesRequests, CollapsesIndexedErrorKeys, RunsActions {
  /// The field seeds handed to [data]. Read once, at [data]'s first access.
  Map<String, dynamic> get initial;

  /// The [FormRequest] [submit] validates the current [data] against before
  /// [persist] ever runs.
  FormRequest get request;

  /// Writes [validated] (the [request]-approved payload). Throw
  /// [ValidationException] to report a server-side 422 back onto [data]'s
  /// fields; otherwise answer whether the write succeeded.
  Future<bool> persist(Map<String, dynamic> validated);

  /// The bound field store. Wired to `this` so a field's error auto-clears
  /// the moment its value changes (see [MagicFormData]'s per-field
  /// listeners).
  late final MagicFormData data = MagicFormData(initial, controller: this);

  /// Validates [data] against [request], then [persist]s the approved
  /// payload. Answers whether the write went through.
  ///
  /// 1. Clears stale errors so a resubmit does not carry a rejection from a
  ///    previous attempt.
  /// 2. Runs [request] through [validateRequest], which paints a failing
  ///    client rule onto [data]'s fields and stops before [persist] is ever
  ///    called.
  /// 3. Routes the write through [MagicFormData.process] so
  ///    [MagicFormData.isProcessing] covers it, catching a server-side
  ///    [ValidationException] from [persist] the same way step 2 catches a
  ///    client one.
  Future<bool> submit() async {
    clearErrors();

    final Map<String, dynamic> validated;
    try {
      validated = validateRequest(request, data.data);
    } on ValidationException {
      return false;
    }

    try {
      return await data.process(() => persist(validated));
    } on ValidationException catch (e) {
      setErrorsFromMap(
        e.errors.map((field, message) => MapEntry(field, [message])),
      );
      return false;
    }
  }

  @override
  void onClose() {
    assert(
      !Magic.controllers.contains(this),
      'MagicFormObject must never be registered via Magic.put/findOrPut: '
      'create one per State (`late final form = MyForm();`) and call '
      'form.dispose() from that State\'s onClose.',
    );
    data.dispose();
    super.onClose();
  }
}
