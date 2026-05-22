import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class GeocodingResult {
  final String name;
  final String displayName;
  final LatLng location;

  GeocodingResult({
    required this.name,
    required this.displayName,
    required this.location,
  });

  factory GeocodingResult.fromJson(Map<String, dynamic> json) {
    return GeocodingResult(
      name: json['name'] ?? json['display_name'],
      displayName: json['display_name'],
      location: LatLng(
        double.parse(json['lat']),
        double.parse(json['lon']),
      ),
    );
  }
}

class SearchState {
  final bool isLoading;
  final List<GeocodingResult> results;
  final String error;
  final LatLng? selectedLocation;

  const SearchState({
    this.isLoading = false,
    this.results = const [],
    this.error = '',
    this.selectedLocation,
  });

  SearchState copyWith({
    bool? isLoading,
    List<GeocodingResult>? results,
    String? error,
    LatLng? selectedLocation,
  }) {
    return SearchState(
      isLoading: isLoading ?? this.isLoading,
      results: results ?? this.results,
      error: error ?? this.error,
      selectedLocation: selectedLocation ?? this.selectedLocation,
    );
  }
}

class SearchCubit extends Cubit<SearchState> {
  SearchCubit() : super(const SearchState());

  Future<void> search(String query, String locale) async {
    if (query.isEmpty) {
      emit(state.copyWith(results: [], isLoading: false, error: ''));
      return;
    }

    emit(state.copyWith(isLoading: true, error: ''));

    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5&addressdetails=1');
      final response = await http.get(url, headers: {
        'User-Agent': 'pl.enteam.aed_map',
        'Accept-Language': locale,
      });

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final results = data.map((json) => GeocodingResult.fromJson(json)).toList();
        emit(state.copyWith(results: results, isLoading: false));
      } else {
        emit(state.copyWith(
            error: 'Błąd pobierania danych', isLoading: false, results: []));
      }
    } catch (e) {
      emit(state.copyWith(error: e.toString(), isLoading: false, results: []));
    }
  }

  void selectLocation(LatLng location) {
    emit(state.copyWith(selectedLocation: location));
    // Clear selection after a short delay so we can select the same again if needed
    Future.delayed(const Duration(milliseconds: 100), () {
      emit(SearchState(
          isLoading: state.isLoading,
          results: state.results,
          error: state.error,
          selectedLocation: null));
    });
  }

  void clear() {
    emit(const SearchState());
  }
}
