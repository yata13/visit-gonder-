// Unified error class for the whole app

class AppError {
  final String message;
  final String? code;

  const AppError(this.message, {this.code});

  // Common errors
  static const notFound    = AppError('Item not found', code: 'NOT_FOUND');
  static const noInternet  = AppError('No internet connection', code: 'NO_INTERNET');
  static const serverError = AppError('Server error. Please try again.', code: 'SERVER_ERROR');
  static const authError   = AppError('Please sign in to continue', code: 'AUTH_ERROR');

  @override
  String toString() => 'AppError[$code]: $message';
}
