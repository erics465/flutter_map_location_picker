import 'flutter_map_location_picker.dart';

class MapLocationPickerController {
  MapLocationPickerState? _state;

  void registerState(MapLocationPickerState state) {
    _state = state;
  }

  Future<void> autocompleteSearch(String query) async {
    if (_state != null) {
      await _state!.triggerAutocompleteSearch(query);
    }
  }

  void dispose() {
    _state = null;
  }
}