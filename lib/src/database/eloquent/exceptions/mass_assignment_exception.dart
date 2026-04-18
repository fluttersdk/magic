/// Thrown by [Model.fill] when strict mode is enabled and a non-fillable
/// attribute is supplied.
class MassAssignmentException implements Exception {
  const MassAssignmentException(this.attribute, [this.modelType]);

  /// The attribute that violated the fillable guard.
  final String attribute;

  /// The model type the violation happened on, for friendlier error output.
  final Type? modelType;

  @override
  String toString() {
    final model = modelType == null ? 'model' : '$modelType';
    return 'MassAssignmentException: "$attribute" is not fillable on $model.';
  }
}
