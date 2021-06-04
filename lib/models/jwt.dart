part of appwrite;

class JwtModel {
    late final String jwt;

    JwtModel({
        required this.jwt,
    });

    factory JwtModel.fromMap(Map<String, dynamic> map) {
        return JwtModel(
            jwt: map['jwt'],
        );
    }

    Map<String, dynamic> toMap() {
        return {
            "jwt": jwt,
        };
    }

}

