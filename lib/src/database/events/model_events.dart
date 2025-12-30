import '../../events/magic_event.dart';
import '../eloquent/model.dart';

/// Base class for all model events.
abstract class ModelEvent extends MagicEvent {
  final Model model;
  ModelEvent(this.model);
}

/// Fired before a model is saved (created or updated).
class ModelSaving extends ModelEvent {
  ModelSaving(super.model);
}

/// Fired after a model has been saved (created or updated).
class ModelSaved extends ModelEvent {
  ModelSaved(super.model);
}

/// Fired before a new model is created.
class ModelCreating extends ModelEvent {
  ModelCreating(super.model);
}

/// Fired after a new model has been created.
class ModelCreated extends ModelEvent {
  ModelCreated(super.model);
}

/// Fired before an existing model is updated.
class ModelUpdating extends ModelEvent {
  ModelUpdating(super.model);
}

/// Fired after an existing model has been updated.
class ModelUpdated extends ModelEvent {
  ModelUpdated(super.model);
}

/// Fired after a model has been deleted.
class ModelDeleted extends ModelEvent {
  ModelDeleted(super.model);
}
