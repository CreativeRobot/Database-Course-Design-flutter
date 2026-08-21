class Captcha {
  const Captcha({
    required this.captchaId,
    required this.imageBase64,
    required this.expiresInSeconds,
  });

  factory Captcha.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('验证码响应格式不正确');
    }

    final captchaId = json['captchaId'];
    final imageBase64 = json['imageBase64'];
    final expiresInSeconds = json['expiresInSeconds'];
    if (captchaId is! String ||
        imageBase64 is! String ||
        expiresInSeconds is! num) {
      throw const FormatException('验证码响应字段不完整');
    }

    return Captcha(
      captchaId: captchaId,
      imageBase64: imageBase64,
      expiresInSeconds: expiresInSeconds.toInt(),
    );
  }

  final String captchaId;
  final String imageBase64;
  final int expiresInSeconds;
}
