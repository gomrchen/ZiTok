final RegExp _phoneCN = RegExp(r'^(?:\+?86\s*)?1[3-9]\d{9}$');
final RegExp _passwordMix = RegExp(r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d]{8,20}$');
final RegExp _otp6Digits = RegExp(r'^\d{6}$');

bool isValidMainlandPhone(String phone) {
  return _phoneCN.hasMatch(phone.trim());
}

bool isValidPassword(String password) {
  return _passwordMix.hasMatch(password);
}

bool isValidOtp(String otp) {
  return _otp6Digits.hasMatch(otp.trim());
}