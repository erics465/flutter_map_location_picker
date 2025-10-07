library flutter_map_location_picker;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_picker/location_with_placemark.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';

typedef GeocodingProvider = Future<List<Location>> Function(String address);

/// Change the Map Tiles for OSM
enum MapType { normal, satelite }

/// Location Result contains:
/// * [latitude] as [double]
/// * [longitude] as [double]
/// * [completeAddress] as [String]
/// * [placemark] as [Placemark]
class LocationResult {
  /// the latitude of the picked location
  double? latitude;

  /// the longitude of the picked location
  double? longitude;

  /// the complete address of the picked location
  String? completeAddress;

  /// the location name of the picked location
  String? locationName;

  /// the placemark infomation of the picked location
  Placemark? placemark;

  LocationResult(
      {required this.latitude,
      required this.longitude,
      this.completeAddress,
      this.placemark, this.locationName});
}

class MapLocationPicker extends StatefulWidget {
  /// The initial longitude
  final double? initialLongitude;

  /// The initial latitude
  final double? initialLatitude;

  /// Pre-set name
  final String? initialLocationName;

  /// callback when location is picked
  final Function(LocationResult onPicked) onPicked;
  final Color? backgroundColor;

  /// The setLocaleIdentifier with the localeIdentifier parameter can be used to enforce the results to be formatted (and translated) according to the specified locale. The localeIdentifier should be formatted using the syntax: [languageCode]_[countryCode]. Use the ISO 639-1 or ISO 639-2 standard for the language code and the 2 letter ISO 3166-1 standard for the country code.
  final String? locale;

  final Color? indicatorColor;
  final Color? sideButtonsColor;
  final Color? sideButtonsIconColor;

  final TextStyle? locationNameTextStyle;
  final TextStyle? addressTextStyle;
  final TextStyle? searchTextStyle;
  final TextStyle? buttonTextStyle;
  final Widget? centerWidget;
  final double? initialZoom;
  final Color? buttonColor;
  final String? buttonText;
  final Widget? leadingIcon;
  final InputDecoration? searchBarDecoration;
  final bool myLocationButtonEnabled;
  final bool zoomButtonEnabled;
  final bool searchBarEnabled;
  final bool switchMapTypeEnabled;
  final MapType? mapType;
  final Widget Function(LocationResult locationResult)? customButton;
  final Widget Function(
      LocationResult locationResult, MapController mapController)? customFooter;
  final Widget Function(
      LocationResult locationResult, MapController mapController)? sideWidget;
  final GeocodingProvider? geocodingProvider;
  final String? editLocationDialogTitle;
  final String? editLocationDialogOkText;
  final String? editLocationDialogCancelText;
  final TileLayer? tileLayer;

  /// [onPicked] action on click select Location
  /// [initialLatitude] the latitude of the initial location
  /// [initialLongitude] the longitude of the initial location
  const MapLocationPicker(
      {super.key,
      required this.initialLatitude,
      required this.initialLongitude,
      required this.onPicked,
      this.initialLocationName,
      this.backgroundColor,
      this.indicatorColor,
      this.addressTextStyle,
      this.searchTextStyle,
      this.centerWidget,
      this.buttonColor,
      this.buttonText,
      this.leadingIcon,
      this.searchBarDecoration,
      this.myLocationButtonEnabled = true,
      this.searchBarEnabled = true,
      this.sideWidget,
      this.customButton,
      this.customFooter,
      this.buttonTextStyle,
      this.zoomButtonEnabled = true,
      this.initialZoom,
      this.switchMapTypeEnabled = true,
      this.mapType,
      this.sideButtonsColor,
      this.sideButtonsIconColor,
      this.locationNameTextStyle,
      this.locale,
      this.geocodingProvider,
      this.editLocationDialogTitle,
      this.editLocationDialogCancelText,
      this.editLocationDialogOkText,
      this.tileLayer
    });

  @override
  State<MapLocationPicker> createState() => _MapLocationPickerState();
}

class _MapLocationPickerState extends State<MapLocationPicker> {
  bool _error = false;
  bool _move = false;
  bool _locked = false;
  bool popupHidden = true;
  Timer? _timer;
  final MapController _controller = MapController();
  final List<Location> _locationList = [];
  MapType _mapType = MapType.normal;
  String? lastSearchedValue;
  String? autocompleteSearchBuffer;
  TextEditingController searchFieldController = TextEditingController();
  bool isFieldEmpty = true;

  LocationResult? _locationResult;

  double _latitude = -6.984072660841485;
  double _longitude = 110.40950678599624;

  @override
  void initState() {
    super.initState();
    _latitude = widget.initialLatitude ?? -6.984072660841485;
    _longitude = widget.initialLongitude ?? 110.40950678599624;

    //Set existing location if available
    if (widget.initialLocationName != null) {
      _locationResult = LocationResult(
        latitude: _latitude,
        longitude: _longitude, 
        locationName: widget.initialLocationName
      );
      _locked = true;
    } else {
      _setupInitalLocation();
    }

    if (widget.mapType != null) {
      _mapType = widget.mapType!;
    }
  }

  _setupInitalLocation() async{
    if(widget.locale != null){
      await setLocaleIdentifier(widget.locale!);

    }
    _locationResult = LocationResult(
        latitude: _latitude,
        longitude: _longitude,
        completeAddress: null,
        locationName: null,
        placemark: null);
    _getLocationResult();
  }

  _getLocationResult({Placemark? placemark}) async {
    _locationResult = await getLocationResult(latitude: _latitude, longitude: _longitude, placemark: placemark);
    setState(() {popupHidden = false;});
  }

  _autocompleteSearch(String query) async {
    lastSearchedValue = query;

    if (query.isNotEmpty) {
      setState(() {
        _error = false;
      });

      late List<Location> newLocations;
      try {
        if (widget.geocodingProvider != null) {
          newLocations = await widget.geocodingProvider!(query);
        } else {
          newLocations = await locationFromAddress(query);
        }
      } catch (e) {
        _error = true;
      }

      setState(() {
        _locationList.clear();
        _locationList.addAll(newLocations);

        if (_locationList.isEmpty) {
          _error = true;
        }
      });
    } else{
      _locationList.clear();
      _error = false;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);

    Widget searchBar() {
      return widget.searchBarEnabled
          ? Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
              children: [
                TextField(
                  style: widget.searchTextStyle,
                  controller: searchFieldController,
                  textInputAction: TextInputAction.search,
                  onChanged: (value) {
                    setState(() => isFieldEmpty = value.isEmpty);
                    Future.delayed(const Duration(seconds: 1), () {
                      return value;
                    }).then((completion) {
                      if (completion == searchFieldController.text) {
                        _autocompleteSearch(completion);
                      }
                    });
                  },
                  onSubmitted: _autocompleteSearch,
                  decoration: widget.searchBarDecoration ??
                      InputDecoration(
                        prefixIcon: Icon(
                          Icons.search,
                          color: widget.indicatorColor,
                        ),
                        border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                        fillColor: widget.backgroundColor ?? theme.colorScheme.surfaceContainerHigh.withAlpha(200),
                        filled: true,
                        suffixIcon: (isFieldEmpty) ? null : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              searchFieldController.clear();
                              isFieldEmpty = true;
                              _locationList.clear();
                            });
                          },
                        )
                      ),
                  
                ),
                _locationList.isNotEmpty
                    ? SizedBox(
                      height: 200,
                      child: ListView(
                      padding: EdgeInsets.only(top: 0.0),
                        children: [
                          for (Location location in _locationList)
                           LocationItem(
                            key: ValueKey(LatLng(location.latitude, location.longitude)),
                            data: location,
                            backgroundColor: widget.backgroundColor,
                            locationNameTextStyle:
                                widget.locationNameTextStyle,
                            addressTextStyle: widget.addressTextStyle,
                            onResultClicked: (LocationResult result) {
                              setState(() {
                                _latitude = result.latitude ?? 0;
                                _longitude = result.longitude ?? 0;
                                _move = true;
                                _controller.move(LatLng(_latitude, _longitude), 16);
                                _locationResult = result;
                                _locationList.clear();
                              });
                            },
                          )
                        ]
                      ))
                    : Container(),
                _error
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        color: widget.backgroundColor ?? theme.colorScheme.surfaceContainerHigh,
                        child: Text(
                          "Location not found",
                          style: widget.searchTextStyle,
                        ),
                      )
                    : Container()
              ],
            )
          : Container();
    }

    Widget viewLocationName() {
      return widget.customFooter != null
          ? widget.customFooter!(_locationResult ?? LocationResult(latitude: _latitude, longitude: _longitude, completeAddress: null, placemark: null,locationName: null), _controller)
          : Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.zero,
                color: widget.backgroundColor ?? theme.colorScheme.surfaceContainerHigh.withAlpha(200),
              ),
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  Row(
                    children: [
                      widget.leadingIcon ??
                          Icon(
                            Icons.location_city,
                            color: widget.indicatorColor,
                          ),
                      const SizedBox(
                        width: 10,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              mainAxisSize: MainAxisSize.max,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(child: Text(
                                  _locationResult?.locationName ??
                                      "Location not found",
                                  style: widget.locationNameTextStyle ??
                                      Theme.of(context).textTheme.titleMedium,
                                )),
                                IconButton(
                                  iconSize: 14,
                                  onPressed: () async {
                                    String? result = await EditTextDialog.show(
                                      context,
                                      _locationResult?.locationName ?? "",
                                      widget.editLocationDialogTitle ?? "Edit name",
                                      widget.editLocationDialogCancelText ?? "Cancel",
                                      widget.editLocationDialogOkText ?? "Ok"
                                    );

                                    if (result != null) {
                                      if (_locationResult == null) {
                                        _locationResult = LocationResult(latitude: _latitude, longitude: _longitude, completeAddress: "", placemark: Placemark(name: ""), locationName: result);
                                      } else {
                                        _locationResult?.locationName = result;
                                      }

                                      if (mounted && context.mounted) {
                                        setState(() {});
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.edit),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              mainAxisSize: MainAxisSize.max,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(_locationResult?.completeAddress ?? "-",
                                    style: widget.addressTextStyle ?? Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                              ]
                            ),
                          ],
                        )
                      ),
                      widget.customButton != null ? widget.customButton!(_locationResult ?? LocationResult(latitude: _latitude, longitude: _longitude, completeAddress: null, placemark: null,locationName: null))
                        : IconButton.filled(
                          iconSize: 32,
                          selectedIcon: Icon(Icons.check),
                          isSelected: !_locked,
                          onPressed: () {
                            _locked = !_locked;
                            setState(() {});
                            widget.onPicked(_locationResult ?? LocationResult(latitude: _latitude, longitude: _longitude, completeAddress: null, placemark: null,locationName: null));
                          },
                          style: !_locked ? ElevatedButton.styleFrom(backgroundColor: widget.buttonColor) : null,
                          icon: const Icon(Icons.delete_outline),
                        ),
                    ],
                  ),
                ],
              ),
            );
    }

    Widget sideButton() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Visibility(
            visible: widget.switchMapTypeEnabled,
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: TextButton(
                onPressed: () {
                  setState(() {
                    if (_mapType == MapType.normal) {
                      _mapType = MapType.satelite;
                    } else {
                      _mapType = MapType.normal;
                    }
                  });
                },
                style: TextButton.styleFrom(
                    backgroundColor: widget.sideButtonsColor ??
                        theme.colorScheme.surfaceContainerHighest,
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(10)),
                child: Icon(Icons.layers,
                    color: widget.sideButtonsIconColor ?? theme.colorScheme.onSurface),
              ),
            ),
          ),
          Visibility(
            visible: widget.zoomButtonEnabled,
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: TextButton(
                onPressed: () {
                  if (_controller.camera.zoom < 17) {
                    _move = true;
                    _controller.move(LatLng(_latitude, _longitude),
                        _controller.camera.zoom + 1);
                  }
                },
                style: TextButton.styleFrom(
                    backgroundColor: widget.sideButtonsColor ??
                        Theme.of(context).primaryColor,
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(10)),
                child: Icon(Icons.zoom_in_map,
                    color: widget.sideButtonsIconColor ?? theme.colorScheme.onSurface),
              ),
            ),
          ),
          Visibility(
            visible: widget.zoomButtonEnabled,
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: TextButton(
                onPressed: () {
                  if (_controller.camera.zoom > 0) {
                    _move = true;
                    _controller.move(LatLng(_latitude, _longitude),
                        _controller.camera.zoom - 1);
                  }
                },
                style: TextButton.styleFrom(
                    backgroundColor: widget.sideButtonsColor ??
                        theme.colorScheme.surfaceContainerHighest,
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(10)),
                child: Icon(Icons.zoom_out_map,
                    color: widget.sideButtonsIconColor ?? theme.colorScheme.onSurface),
              ),
            ),
          ),
          Visibility(
            visible: widget.myLocationButtonEnabled,
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: TextButton(
                onPressed: () {
                  setState(() {
                    if (widget.initialLatitude != null && widget.initialLongitude != null) {
                      _latitude = widget.initialLatitude ?? -6.970136294118362;
                      _longitude = widget.initialLongitude ?? 110.40326425161746;
                      _move = true;
                      _controller.move(LatLng(_latitude, _longitude), 16);
                      _getLocationResult();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Could not get intial location")),
                      );
                    }
                  });
                },
                style: TextButton.styleFrom(
                    backgroundColor: widget.sideButtonsColor ??
                        theme.colorScheme.surfaceContainerHighest,
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(10)),
                child: Icon(Icons.my_location,
                    color: widget.sideButtonsIconColor ?? theme.colorScheme.onSurface),
              ),
            ),
          ),
          widget.sideWidget != null
              ? widget.sideWidget!(_locationResult ?? LocationResult(latitude: _latitude, longitude: _longitude, completeAddress: null, placemark: null,locationName: null), _controller)
              : Container(),
        ],
      );
    }

    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: LatLng(_latitude, _longitude),
        initialZoom: 16,
        maxZoom: 18,
        onMapReady: () {
          _controller.mapEventStream.listen((evt) async {
            _timer?.cancel();
            if (!_move) {
              _timer = Timer(const Duration(milliseconds: 200), () {
                if (!_locked) {
                  _latitude = evt.camera.center.latitude;
                  _longitude = evt.camera.center.longitude;
                  _getLocationResult();
                }
              });
            } else {
              _move = false;
            }

            setState(() {popupHidden = false;});
          });
        },
      ),
      children: [
        widget.tileLayer ?? TileLayer(
          urlTemplate: _mapType == MapType.normal
              ? "http://tile.openstreetmap.org/{z}/{x}/{y}.png"
              : 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}.jpg',
          userAgentPackageName: 'app.groupya.flutter_app',
        ),
        if (_locked)
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(_latitude, _longitude),
                child: Icon(
                  Icons.location_on_rounded,
                  size: 60,
                  color: widget.indicatorColor != null
                      ? widget.indicatorColor!
                      : Theme.of(context).colorScheme.primary,
                ),
              )
            ]
          ),
        Stack(
          children: [
            if (!_locked)
              Center(
                child: widget.centerWidget != null
                    ? widget.centerWidget!
                    : Icon(
                  Icons.location_on_rounded,
                  size: 60,
                  color: widget.indicatorColor != null
                      ? widget.indicatorColor!
                      : Theme.of(context).colorScheme.primary,
                )),
            Positioned(top: 10, left: 10, right: 10, child: searchBar()),
            Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: sideButton(),
                      ),
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    if (!popupHidden)
                      viewLocationName(),
                  ],
                )),
          ],
        )
      ],
    );
  }
}

/// Widget for showing the picked location address
class LocationItem extends StatefulWidget {
  /// Background color for the container
  final Color? backgroundColor;

  /// Indicator color for the container
  final Color? indicatorColor;

  /// Text Style for the address text
  final TextStyle? addressTextStyle;

  /// Text Style for the location name text
  final TextStyle? locationNameTextStyle;

  /// The location data for the picked location
  final Location data;

  final Function(LocationResult locationResult) onResultClicked;

  const LocationItem(
      {super.key,
      required this.data,
      this.backgroundColor,
      this.addressTextStyle,
      this.indicatorColor,
      this.locationNameTextStyle, required this.onResultClicked});

  @override
  State<LocationItem> createState() => _LocationItemState();
}

class _LocationItemState extends State<LocationItem> {
  List<Placemark> _placemarks = [];

  _getLocationResult() async {
    if (widget.data is LocationWithPlacemark) {
      _placemarks = [(widget.data as LocationWithPlacemark).placemark];
    } else {
      _placemarks = await placemarkFromCoordinates(widget.data.latitude, widget.data.longitude);
    }
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _getLocationResult();
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);

    if (_placemarks.isEmpty) {
      return Container(
        color: widget.backgroundColor ?? theme.colorScheme.surfaceContainerLow,
        padding: const EdgeInsets.all(10),
        child: const Center(child: SizedBox(width: 20,height: 20,child: CircularProgressIndicator(),)),
      );
    }
    return Container(
        color: widget.backgroundColor ?? theme.colorScheme.surfaceContainer,
        padding: const EdgeInsets.all(10),
        margin: EdgeInsets.zero,
        child: GestureDetector(
      onTap: () {
        widget.onResultClicked(LocationResult(
          latitude: widget.data.latitude,
          longitude: widget.data.longitude,
          completeAddress: getCompleteAdress(placemark: _placemarks[0]),
          placemark: _placemarks[0],
          locationName: getLocationName(placemark: _placemarks[0])
        ));
      },
      child: Row(
          children: [
            Icon(
              Icons.location_on_rounded,
              color: widget.indicatorColor,
            ),
            const SizedBox(
              width: 10,
            ),
            Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      getLocationName(placemark: _placemarks[0]),
                      style: widget.locationNameTextStyle ??
                          Theme.of(context).textTheme.titleMedium,
                    ),              Text(
                      getCompleteAdress(placemark: _placemarks[0]),
                      style: widget.addressTextStyle ??
                          Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ))
          ],
        ),
      ),
    );
  }
}


Future<LocationResult> getLocationResult({required double latitude, required double longitude, Placemark? placemark}) async {
  try {
    List<Placemark> placemarks;
    
    if (placemark == null) {
      placemarks = await placemarkFromCoordinates(latitude, longitude);
    } else {
      placemarks = [placemark];
    }
    if (placemarks.isNotEmpty) {
      return LocationResult(
          latitude: latitude,
          longitude: longitude,
          locationName: getLocationName(placemark: placemarks.first),
          completeAddress: getCompleteAdress(placemark: placemarks.first),
          placemark: placemarks.first);
    } else {
      return LocationResult(
          latitude: latitude,
          longitude: longitude,
          completeAddress: null,
          placemark: null,locationName: null);
    }
  } catch (e) {
    return LocationResult(
        latitude: latitude,
        longitude: longitude,
        completeAddress: null,
        placemark: null, locationName: null);
  }
}

String getLocationName({required Placemark placemark}) {
  /// Returns throughfare or subLocality if name is an unreadable street code
  if(isStreetCode(placemark.name ?? "")) {
    if((placemark.thoroughfare ?? "").isEmpty){
      return placemark.subLocality ?? "-";
    } else{
      return placemark.thoroughfare ?? "=";
    }
  }

  /// Returns name if it is same with street
  else if(placemark.name == placemark.street){
    return placemark.name ?? "-";
  }

  /// Returns street if name is part of name (like house number)
  else if(placemark.street?.toLowerCase().contains(placemark.name?.toLowerCase() ?? "") == true){
    return placemark.street ?? "-";
  }
  return placemark.name ?? "-";

}

String getCompleteAdress({required Placemark placemark}) {
  List<String> parts = [];
  if (placemark.thoroughfare != null) {
    parts.add(placemark.thoroughfare!);
  } else if (placemark.street != null) {
    parts.add(placemark.street!);
  }
  if (placemark.subAdministrativeArea != null) {
    parts.add(placemark.subAdministrativeArea!);
  }
  if (placemark.administrativeArea != null) {
    parts.add(placemark.administrativeArea!);
  }
  if (placemark.country != null) {
    parts.add(placemark.country!);
  }

  return parts.join(", ");

}

bool isStreetCode(String text) {
  final streetCodeRegex = RegExp(r"^[A-Z0-9\-+]+$"); // Matches all uppercase letters, digits, hyphens, and plus signs
  return streetCodeRegex.hasMatch(text);
}

// Main widget to trigger the dialog
class EditTextDialog {
  static Future<String?> show(BuildContext context, String text, String title, String cancelText, String okText) {
    TextEditingController inputController = TextEditingController(text: text);
    bool empty = inputController.text.isEmpty;

    return showDialog<String?>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: inputController,
                  onChanged: (value) {
                    setState(() => empty = value.isEmpty);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                child: Text(cancelText),
                onPressed: () => Navigator.pop(context),
              ),
              FilledButton(
                onPressed: (!empty) ? () {Navigator.pop(context, inputController.text);} : null,
                child: Text(okText),
              ),
            ],
          ),
        );
      },
    );
  }
}
