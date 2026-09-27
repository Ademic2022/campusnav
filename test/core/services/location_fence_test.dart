import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:oau_navigator/core/services/campus_boundary_service.dart';
import 'package:oau_navigator/core/services/location_service.dart';

/// Exercises the fence hysteresis contract without a device, by reimplementing
/// [LocationService]'s classify step against an injected ring.
///
/// This is the part most likely to regress: a fence that flaps on GPS jitter
/// spams the transition banner, so the dead zone is asserted explicitly.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A ~1 km square fence, 0.009 deg per side, so the buffer maths is legible.
  const half = 0.0045; // ~500 m from centre to edge
  final fence = <List<double>>[
    [4.5228 - half, 7.5177 - half],
    [4.5228 - half, 7.5177 + half],
    [4.5228 + half, 7.5177 + half],
    [4.5228 + half, 7.5177 - half],
  ];

  const centreLat = 7.5177;
  const centreLng = 4.5228;

  setUp(() => CampusBoundary.instance.debugReset());

  setUpAll(() {
    // Pin the thresholds to the service's own values so this test fails if they
    // are retuned without reconsidering the dead zone.
    expect(LocationService.enterBufferMetres, 20.0);
    expect(LocationService.exitBufferMetres, 60.0);
  });

  /// Mirrors the buffer logic the service applies to a signed fence distance.
  ({bool onCampus, CampusTransitionEvent? event}) step({
    required bool wasOnCampus,
    required bool armed,
    required double lat,
    required double lng,
  }) {
    CampusBoundary.instance.debugSetRing(fence);
    final signed = CampusBoundary.instance.signedDistanceMetres(lat, lng);
    expect(signed, isNot(double.infinity));

    if (!armed) return (onCampus: signed <= 0, event: null);

    final next = wasOnCampus
        ? (signed > LocationService.exitBufferMetres ? false : wasOnCampus)
        : (signed <= -LocationService.enterBufferMetres ? true : wasOnCampus);

    if (next == wasOnCampus) return (onCampus: next, event: null);
    return (
      onCampus: next,
      event: CampusTransitionEvent(
        transition: next ? CampusTransition.entered : CampusTransition.exited,
        position: _pos(lat, lng),
        distanceToFenceMetres: signed,
      ),
    );
  }

  group('arming', () {
    test('outside reports off-campus and fires nothing', () {
      final r = step(wasOnCampus: false, armed: false, lat: 7.50, lng: 4.50);
      expect(r.onCampus, isFalse);
      expect(r.event, isNull, reason: 'launching off campus must not fire');
    });

    test('inside reports on-campus and fires nothing', () {
      final r = step(
          wasOnCampus: false, armed: false, lat: centreLat, lng: centreLng);
      expect(r.onCampus, isTrue);
      expect(r.event, isNull);
    });
  });

  group('hysteresis', () {
    test('a single fix just outside does not declare an exit', () {
      // ~30 m beyond the northern edge: inside the dead zone, so still on
      // campus. Offsets are from the EDGE, not the centre.
      final r = step(
        wasOnCampus: true,
        armed: true,
        lat: centreLat + half + 0.00027,
        lng: centreLng,
      );
      expect(r.onCampus, isTrue);
      expect(r.event, isNull);
    });

    test('clearing the exit buffer declares the exit', () {
      final r = step(
        wasOnCampus: true,
        armed: true,
        lat: centreLat + half + 0.001, // ~110 m beyond the edge
        lng: centreLng,
      );
      expect(r.onCampus, isFalse);
      expect(r.event?.transition, CampusTransition.exited);
    });

    test('a single fix just inside does not declare an entry', () {
      // ~10 m inside the northern edge: still in the dead zone.
      final r = step(
        wasOnCampus: false,
        armed: true,
        lat: centreLat + half - 0.00009,
        lng: centreLng,
      );
      expect(r.onCampus, isFalse);
      expect(r.event, isNull);
    });

    test('clearing the entry buffer declares the entry', () {
      final r = step(
        wasOnCampus: false,
        armed: true,
        lat: centreLat + half - 0.0005, // ~55 m inside the edge
        lng: centreLng,
      );
      expect(r.onCampus, isTrue);
      expect(r.event?.transition, CampusTransition.entered);
    });
  });

  group('stability', () {
    test('a device loitering on the boundary does not flap', () {
      var onCampus = true;
      var armed = true;
      var events = 0;

      for (var i = 0; i < 40; i++) {
        // Alternate ~24 m outside / ~24 m inside the northern edge, straddling
        // the fence line the way real GPS noise does.
        final wobble = i.isEven ? 0.00022 : -0.00022;
        final r = step(
          wasOnCampus: onCampus,
          armed: armed,
          lat: centreLat + half + wobble,
          lng: centreLng,
        );
        onCampus = r.onCampus;
        armed = true;
        if (r.event != null) events++;
      }

      expect(events, 0, reason: 'jitter inside the dead zone must not fire');
    });

    test('a genuine crossing fires once per direction', () {
      var onCampus = true;
      var armed = true;
      final seen = <CampusTransition>[];

      // Deep inside, well outside, still outside, then deep inside twice.
      for (final lat in [
        centreLat,
        centreLat + half + 0.001,
        centreLat + half + 0.001,
        centreLat + half - 0.0005,
        centreLat + half - 0.0005,
      ]) {
        final r = step(
            wasOnCampus: onCampus, armed: armed, lat: lat, lng: centreLng);
        onCampus = r.onCampus;
        armed = true;
        if (r.event != null) seen.add(r.event!.transition);
      }

      expect(seen, [CampusTransition.exited, CampusTransition.entered]);
    });

    test('the event carries the distance that justified it', () {
      final r = step(
        wasOnCampus: true,
        armed: true,
        lat: centreLat + half + 0.001,
        lng: centreLng,
      );
      final event = r.event!;
      // Outside, so positive, and past the exit buffer by construction.
      expect(event.distanceToFenceMetres,
          greaterThan(LocationService.exitBufferMetres));
      expect(event.position.latitude, centreLat + half + 0.001);
    });

    test('the dead zone is wide enough to absorb GPS accuracy', () {
      expect(
        LocationService.exitBufferMetres - LocationService.enterBufferMetres,
        greaterThanOrEqualTo(30.0),
      );
    });
  });
}

Position _pos(double lat, double lng) => Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime(2026),
      accuracy: 0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
