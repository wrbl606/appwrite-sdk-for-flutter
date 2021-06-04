part of appwrite;

class ErrorModel {
    late final String message;
    late final String code;
    late final String version;

    ErrorModel({
        required this.message,
        required this.code,
        required this.version,
    });

    factory ErrorModel.fromMap(Map<String, dynamic> map) {
        return ErrorModel(
            message: map['message'],
            code: map['code'],
            version: map['version'],
        );
    }

    Map<String, dynamic> toMap() {
        return {
            "message": message,
            "code": code,
            "version": version,
        };
    }

}

