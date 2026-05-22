import 'dart:async';

import 'package:aed_map/bloc/edit/edit_cubit.dart';
import 'package:aed_map/bloc/edit/edit_state.dart';
import 'package:aed_map/bloc/points/points_state.dart';
import 'package:aed_map/constants.dart';
import 'package:aed_map/main.dart';
import 'package:aed_map/models/aed.dart';
import 'package:aed_map/models/pending_change.dart';
import 'package:aed_map/bloc/settings/settings_cubit.dart';
import 'package:aed_map/repositories/geolocation_repository.dart';
import 'package:aed_map/repositories/points_repository.dart';
import 'package:aed_map/shared/utils.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/svg.dart';
import 'package:latlong2/latlong.dart';

class PointsCubit extends Cubit<PointsState> {
  PointsCubit({
    required this.pointsRepository,
    required this.geolocationRepository,
    required this.editCubit,
    required this.settingsCubit,
  }) : super(PointsLoadInProgress()) {
    _editSubscription = editCubit.stream
        .distinct((previous, current) =>
            previous.pendingChanges == current.pendingChanges)
        .listen((editState) => applyPendingChanges(editState.pendingChanges));
    _settingsSubscription = settingsCubit.stream
        .distinct((previous, current) => previous.themeMode == current.themeMode)
        .listen((_) => rebuildMarkers());
  }

  final PointsRepository pointsRepository;
  final GeolocationRepository geolocationRepository;
  final EditCubit editCubit;
  final SettingsCubit settingsCubit;
  late final StreamSubscription<EditState> _editSubscription;
  late final StreamSubscription<SettingsState> _settingsSubscription;

  @override
  Future<void> close() {
    _editSubscription.cancel();
    _settingsSubscription.cancel();
    return super.close();
  }

  Future<void> load() async {
    var position = (await geolocationRepository.locate()).location;
    final (nearbyDefibrillators, defibrillatorsCount, closestToUser) = await pointsRepository
        .loadDefibrillators(LatLng(position.latitude, position.longitude), LatLng(position.latitude, position.longitude));
    await editCubit.reconcilePendingChanges(nearbyDefibrillators);
    final pendingChanges = editCubit.state.pendingChanges;
    final (mergedDefibrillators, pendingIds) =
        mergeWithPendingChanges(nearbyDefibrillators, pendingChanges, LatLng(position.latitude, position.longitude));
    emit(PointsLoadSuccess(
        defibrillators: mergedDefibrillators,
        defibrillatorsCount: defibrillatorsCount,
        selected: closestToUser,
        closest: closestToUser,
        markers: buildMarkers(mergedDefibrillators, pendingIds),
        lastUpdateTime: await pointsRepository.getLastUpdateTime(),
        refreshing: false,
        pendingIds: pendingIds,
        hash: generateRandomString(32)));
  }

  Future<void> refresh() async {
    var s = state;
    if (s is PointsLoadSuccess) {
      emit(s.copyWith(refreshing: true));
    }
    await pointsRepository.updateDefibrillators();
    var position = (await geolocationRepository.locate()).location;
    final (nearbyDefibrillators, defibrillatorsCount, closestToUser) = await pointsRepository
        .loadDefibrillators(LatLng(position.latitude, position.longitude), LatLng(position.latitude, position.longitude));
    await editCubit.reconcilePendingChanges(nearbyDefibrillators);
    final pendingChanges = editCubit.state.pendingChanges;
    final (mergedDefibrillators, pendingIds) =
        mergeWithPendingChanges(nearbyDefibrillators, pendingChanges, LatLng(position.latitude, position.longitude));
    emit(PointsLoadSuccess(
        defibrillators: mergedDefibrillators,
        defibrillatorsCount: defibrillatorsCount,
        selected: s is PointsLoadSuccess ? s.selected : closestToUser,
        closest: closestToUser,
        markers: buildMarkers(mergedDefibrillators, pendingIds),
        lastUpdateTime: await pointsRepository.getLastUpdateTime(),
        refreshing: false,
        pendingIds: pendingIds,
        hash: generateRandomString(32)));
  }

  Future<void> fetchForLocation(LatLng location) async {
    var s = state;
    if (s is PointsLoadSuccess) {
      var position = (await geolocationRepository.locate()).location;
      final (nearbyDefibrillators, defibrillatorsCount, closestToUser) = await pointsRepository
          .loadDefibrillators(location, position);
      await editCubit.reconcilePendingChanges(nearbyDefibrillators);
      final pendingChanges = editCubit.state.pendingChanges;
      final (mergedDefibrillators, pendingIds) =
          mergeWithPendingChanges(nearbyDefibrillators, pendingChanges, location);
      
      // Keep the same selected marker if it still exists in the new list, or keep the old one anyway to preserve the 'nearest to GPS' AED
      Defibrillator newSelected;
      try {
        newSelected = mergedDefibrillators.firstWhere((d) => d.id == s.selected.id);
      } catch (_) {
        newSelected = s.selected;
      }

      emit(s.copyWith(
          defibrillators: mergedDefibrillators,
          defibrillatorsCount: defibrillatorsCount,
          selected: newSelected,
          closest: closestToUser,
          markers: buildMarkers(mergedDefibrillators, pendingIds),
          pendingIds: pendingIds,
          hash: generateRandomString(32)));
    }
  }

  Future<void> applyPendingChanges(List<PendingChange> pendingChanges) async {
    var s = state;
    if (s is! PointsLoadSuccess) return;
    final baseDefibrillators = s.defibrillators
        .where((defibrillator) => !pendingChanges
            .any((change) => change.defibrillatorId == defibrillator.id))
        .toList();
    var position = (await geolocationRepository.locate()).location;
    final (mergedDefibrillators, pendingIds) =
        mergeWithPendingChanges(baseDefibrillators, pendingChanges, position);
    emit(s.copyWith(
        defibrillators: mergedDefibrillators,
        markers: buildMarkers(mergedDefibrillators, pendingIds),
        pendingIds: pendingIds,
        hash: generateRandomString(32)));
  }

  (List<Defibrillator>, Set<int>) mergeWithPendingChanges(
      List<Defibrillator> defibrillators, List<PendingChange> pendingChanges, LatLng position) {
    final deleteIds = pendingChanges
        .where((change) => change.type == PendingChangeType.delete)
        .map((change) => change.defibrillatorId)
        .toSet();

    var merged = defibrillators
        .where((defibrillator) => !deleteIds.contains(defibrillator.id))
        .toList();

    final pendingIds = <int>{};
    for (final change in pendingChanges) {
      if (change.type == PendingChangeType.delete) continue;
      pendingIds.add(change.defibrillatorId);
      merged.removeWhere(
          (defibrillator) => defibrillator.id == change.defibrillatorId);
      var snapshot = change.snapshot;
      const Distance distanceCalculator = Distance(calculator: Haversine());
      snapshot.distance = distanceCalculator(position, snapshot.location).ceil();
      merged.add(snapshot);
    }
    merged.sort((a, b) => (a.distance ?? 999999999).compareTo(b.distance ?? 999999999));

    return (merged, pendingIds);
  }

  void select(Defibrillator defibrillator) {
    FirebaseAnalytics.instance.logSelectContent(
        contentType: 'aed', itemId: defibrillator.id.toString());
    HapticFeedback.mediumImpact();
    analytics.event(name: selectEvent);
    mixpanel.track(selectEvent, properties: defibrillator.getEventProperties());
    if (state is PointsLoadSuccess) {
      emit((state as PointsLoadSuccess).copyWith(
          selected: defibrillator,
          hash: generateRandomString(32),
          selectedHash: generateRandomString(32)));
    }
  }

  void update(Defibrillator defibrillator) {
    if (state is PointsLoadSuccess) {
      final currentState = state as PointsLoadSuccess;
      if (defibrillator.id == 0) {
        var newDefibrillators =
            List<Defibrillator>.from(currentState.defibrillators)
              ..insert(0, defibrillator);
        emit(currentState.copyWith(
            defibrillators: newDefibrillators,
            markers: buildMarkers(newDefibrillators, currentState.pendingIds),
            selected: defibrillator));
      } else {
        var updatedDefibrillators =
            List<Defibrillator>.from(currentState.defibrillators)
              ..removeWhere((existing) => existing.id == defibrillator.id)
              ..insert(0, defibrillator);
        emit(currentState.copyWith(
            selected: defibrillator,
            defibrillators: updatedDefibrillators,
            markers:
                buildMarkers(updatedDefibrillators, currentState.pendingIds)));
      }
    }
  }

  void rebuildMarkers() {
    if (state is PointsLoadSuccess) {
      final s = state as PointsLoadSuccess;
      emit(s.copyWith(
          markers: buildMarkers(s.defibrillators, s.pendingIds)));
    }
  }

  List<Marker> buildMarkers(
      List<Defibrillator> defibrillators, Set<int> pendingIds) {
    var systemBrightness = MediaQueryData.fromView(
            WidgetsBinding.instance.platformDispatcher.views.single)
        .platformBrightness;
    var brightness = settingsCubit.state.themeMode == ThemeMode.light
        ? Brightness.light
        : settingsCubit.state.themeMode == ThemeMode.dark
            ? Brightness.dark
            : systemBrightness;

    return defibrillators
        .take(visiblePointsCount)
        .map((defibrillator) {
          final isPending = pendingIds.contains(defibrillator.id);
          final svgAsset = 'assets/${defibrillator.getIconFilename()}';
          return Marker(
            point: defibrillator.location,
            key: Key('${defibrillators.indexOf(defibrillator)}_$brightness'),
            child: isPending
                ? DottedBorder(
                    options: RoundedRectDottedBorderOptions(
                      radius: const Radius.circular(8),
                      dashPattern: const [4, 3],
                      color: brightness == Brightness.light
                          ? Colors.black
                          : Colors.white,
                      strokeWidth: 2,
                    ),
                    child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SvgPicture.asset(svgAsset)),
                  )
                : Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: brightness == Brightness.light
                              ? Colors.black
                              : Colors.white,
                          width: 2),
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                    ),
                    child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SvgPicture.asset(svgAsset)),
                  ),
          );
        })
        .cast<Marker>()
        .toList();
  }
}
