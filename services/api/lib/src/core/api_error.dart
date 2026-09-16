class ApiError implements Exception {
  const ApiError(this.status, this.code, this.message);
  final int status;
  final String code;
  final String message;
}
