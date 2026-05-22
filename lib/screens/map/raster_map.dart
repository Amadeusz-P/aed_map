import 'dart:async';
import 'package:aed_map/bloc/edit/edit_cubit.dart';
import 'package:aed_map/bloc/edit/edit_state.dart';
import 'package:aed_map/bloc/routing/routing_cubit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:flutter_map_supercluster/flutter_map_supercluster.dart';
import 'package:hue_rotation/hue_rotation.dart';
import 'package:latlong2/latlong.dart';

import '../../bloc/location/location_cubit.dart';
import '../../bloc/location/location_state.dart';
import '../../bloc/panel/panel_cubit.dart';
import '../../bloc/points/points_cubit.dart';
import '../../bloc/points/points_state.dart';
import '../../bloc/search/search_cubit.dart';
import '../../bloc/routing/routing_state.dart';
import '../../shared/cached_network_tile_provider.dart';
import '../../shared/utils.dart';

class RasterMap extends StatefulWidget {
  const RasterMap({super.key, this.floatingPanelPosition = 0});

  final double floatingPanelPosition;

  @override
  State<RasterMap> createState() => _RasterMapState();
}

class _RasterMapState extends State<RasterMap> with TickerProviderStateMixin {
  final MapController mapController = MapController();
  final SuperclusterMutableController markersController =
      SuperclusterMutableController();

  bool isMapInitialized = false;
  LatLng? lastFetchedCenter;
  Timer? _debounceFetch;

  @override
  void dispose() {
    _debounceFetch?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<EditCubit, EditState>(
      listener: (context, state) {
        if (state.enabled) {
          _animatedMapMove(state.cursor, 18);
        }
      },
      listenWhen: (previous, current) => !previous.enabled && current.enabled,
      child: BlocListener<SearchCubit, SearchState>(
        listener: (context, state) {
          if (state.selectedLocation != null) {
            _animatedMapMove(state.selectedLocation!, 16);
            context.read<PointsCubit>().fetchForLocation(state.selectedLocation!);
          }
        },
        listenWhen: (previous, current) => previous.selectedLocation != current.selectedLocation && current.selectedLocation != null,
        child: BlocListener<LocationCubit, LocationState>(
        listener: (BuildContext context, state) {
          if (state is LocationDetermined) {
            _animatedMapMove(state.center, 18);
          }
        },
        child: BlocListener<PointsCubit, PointsState>(
          listener: (BuildContext context, state) {
            if (state is PointsLoadSuccess) {
              markersController.replaceAll(state.markers);
            }
          },
          listenWhen: (previous, current) =>
              current is PointsLoadSuccess &&
              previous is PointsLoadSuccess &&
              ((current.defibrillators.length != previous.defibrillators.length) ||
                  (current.defibrillators.first.access != previous.defibrillators.first.access) ||
                  (current.defibrillators.first.id != previous.defibrillators.first.id) ||
                  !setEquals(current.pendingIds, previous.pendingIds) ||
                  current.markers != previous.markers),
          child: BlocListener<PointsCubit, PointsState>(
            listenWhen: (previous, current) {
              if (previous is! PointsLoadSuccess && current is PointsLoadSuccess) return true;
              if (previous is PointsLoadSuccess && current is PointsLoadSuccess) {
                return previous.selectedHash != current.selectedHash;
              }
              return false;
            },
            listener: (BuildContext context, PointsState state) {
              if (state is PointsLoadSuccess) {
                _animatedMapMove(state.selected.location, 18);
              }
            },
            child: SafeArea(
              top: false,
              bottom: false,
              child: Column(
                children: [
                  Flexible(
                      child: Stack(
                    children: [
                      BlocBuilder<LocationCubit, LocationState>(
                          builder: (context, state) {
                        if (state is LocationDetermined) {
                          return BlocBuilder<PointsCubit, PointsState>(
                              buildWhen: (previous, current) =>
                                  previous is! PointsLoadSuccess &&
                                  current is PointsLoadSuccess,
                              builder: (context, state) {
                            if (state is PointsLoadSuccess) {
                              return FlutterMap(
                                mapController: mapController,
                                options: MapOptions(
                                  onPositionChanged:
                                      (MapPosition position, bool gesture) {
                                    var center = position.center;
                                    if (center != null) {
                                      context
                                          .read<EditCubit>()
                                          .moveCursor(center);
                                          
                                      var pointsState = context.read<PointsCubit>().state;
                                      if (pointsState is PointsLoadSuccess) {
                                        if (lastFetchedCenter == null || const Distance().as(LengthUnit.Kilometer, lastFetchedCenter!, center) > 2) {
                                          if (_debounceFetch?.isActive ?? false) _debounceFetch!.cancel();
                                          _debounceFetch = Timer(const Duration(milliseconds: 500), () {
                                            lastFetchedCenter = center;
                                            context.read<PointsCubit>().fetchForLocation(center);
                                          });
                                        }
                                      }
                                    }
                                  },
                                  onMapReady: () {
                                    isMapInitialized = true;
                                    context.read<EditCubit>().moveCursor(
                                        mapController.camera.center);
                                  },
                                  initialCenter: state.selected.location,
                                  interactionOptions: InteractionOptions(
                                      flags: InteractiveFlag.all &
                                          ~InteractiveFlag.rotate),
                                  initialZoom: 18,
                                  maxZoom: 18,
                                  minZoom: 8,
                                ),
                                children: [
                                  HueRotation(
                                    degrees: MediaQuery.platformBrightnessOf(context) ==
                                            Brightness.dark
                                        ? 180
                                        : 0,
                                    child: Builder(builder: (context) {
                                      var map = TileLayer(
                                        userAgentPackageName:
                                            'pl.enteam.aed_map',
                                        tileProvider:
                                            CachedNetworkTileProvider(),
                                        urlTemplate:
                                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                      );
                                      if (MediaQuery.platformBrightnessOf(context) !=
                                          Brightness.dark) {
                                        return map;
                                      }
                                      return ColorFiltered(
                                        colorFilter: invert,
                                        child: map,
                                      );
                                    }),
                                  ),
                                  BlocListener<RoutingCubit, RoutingState>(
                                    listener: (BuildContext context,
                                        RoutingState state) {
                                      if (state is RoutingSuccess) {
                                        context.read<PanelCubit>().cancel();
                                        var start = decodePolyline(
                                                state.trip.shape,
                                                accuracyExponent: 6)
                                            .unpackPolyline()
                                            .first;
                                        _animatedMapMove(
                                            LatLng(start.latitude,
                                                start.longitude),
                                            18);
                                      }
                                    },
                                    child:
                                        BlocBuilder<RoutingCubit, RoutingState>(
                                            builder: (context, state) {
                                      if (state is RoutingSuccess) {
                                        return PolylineLayer(
                                          polylines: [
                                            Polyline(
                                                points: decodePolyline(
                                                        state.trip.shape,
                                                        accuracyExponent: 6)
                                                    .unpackPolyline(),
                                                color: Colors.blue,
                                                strokeWidth: 5,
                                                isDotted: true),
                                          ],
                                        );
                                      }
                                      return Container();
                                    }),
                                  ),
                                  CurrentLocationLayer(),
                                  SuperclusterLayer.mutable(
                                    initialMarkers: state.markers,
                                    loadingOverlayBuilder: (context) =>
                                        Container(),
                                    controller: markersController,
                                    minimumClusterSize: 3,
                                    onMarkerTap: (Marker marker) {
                                      var pointsState =
                                          context.read<PointsCubit>().state;
                                      if (pointsState is! PointsLoadSuccess) {
                                        return;
                                      }
                                      var defibrillator = pointsState
                                          .defibrillators[int.parse(marker.key
                                              .toString()
                                              .replaceAll('[<\'', '')
                                              .replaceAll('\'>]', '')
                                              .split('_')
                                              .first)];
                                      context.read<RoutingCubit>().cancel();
                                      context
                                          .read<PointsCubit>()
                                          .select(defibrillator);
                                    },
                                    clusterWidgetSize: const Size(40, 40),
                                    calculateAggregatedClusterData: true,
                                    builder: (context, position, markerCount,
                                        extraClusterData) {
                                      return Container(
                                        decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(20.0),
                                            color: Colors.brown),
                                        child: Center(
                                          child: Text(
                                            markerCount.toString(),
                                            style: const TextStyle(
                                                color: Colors.white),
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                ],
                              );
                            }
                            return Container();
                          });
                        }
                        return Container();
                      }),
                      Positioned(
                        right: 16,
                        bottom: 116 + (widget.floatingPanelPosition * 340),
                        child: SafeArea(
                          maintainBottomViewPadding: true,
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () {
                              var locState = context.read<LocationCubit>().state;
                              if (locState is LocationDetermined) {
                                _animatedMapMove(locState.center, 18);
                              }
                            },
                            child: Card(
                              color: CupertinoColors.secondarySystemBackground
                                  .resolveFrom(context),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Icon(
                                  CupertinoIcons.location,
                                  color:
                                      CupertinoColors.label.resolveFrom(context),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }

  void _animatedMapMove(LatLng destLocation, double destZoom) {
    if (!isMapInitialized) {
      return;
    }

    final distance = const Distance().as(
        LengthUnit.Kilometer, mapController.camera.center, destLocation);

    if (distance > 50) {
      mapController.move(destLocation, destZoom);
      return;
    }

    final latTween = Tween<double>(
        begin: mapController.camera.center.latitude,
        end: destLocation.latitude);
    final lngTween = Tween<double>(
        begin: mapController.camera.center.longitude,
        end: destLocation.longitude);
    final zoomTween =
        Tween<double>(begin: mapController.camera.zoom, end: destZoom);

    final controller = AnimationController(
        duration: const Duration(milliseconds: 500), vsync: this);
    final Animation<double> animation =
        CurvedAnimation(parent: controller, curve: Curves.fastOutSlowIn);
    controller.addListener(() {
      mapController.move(
          LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
          zoomTween.evaluate(animation));
    });
    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        controller.dispose();
      } else if (status == AnimationStatus.dismissed) {
        controller.dispose();
      }
    });
    controller.forward();
  }
}
