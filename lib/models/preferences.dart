part of appwrite;

class PreferencesModel {
    late final Map<String, dynamic> data;

    PreferencesModel({
        required this.data,
    });

    factory PreferencesModel.fromMap(Map<String, dynamic> map) {
        return PreferencesModel(
            data: map,
        );
    }

    Map<String, dynamic> toMap() {
        return {
            "data": data,
        };
    }

    T convertTo<T>(T Function(Map) fromJson) => fromJson(data);
}

