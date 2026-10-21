import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:findr_application/models/claim.dart';
import 'package:findr_application/models/item_report.dart';
import 'package:findr_application/models/report_filter.dart';
import 'package:findr_application/services/firebase_service.dart';

// provides firebase service so screens can use it through riverpod
// instead of creating a new firebase service each time.
final firebaseServiceProvider = Provider<FirebaseService>((ref) {
  return FirebaseService();
});

// listens for login and logout changes.
// returns the user when logged in, or null when logged out.
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// stores the reports collection here so it does not need to be repeated.
final CollectionReference<Map<String, dynamic>> _reportsCollection =
    FirebaseFirestore.instance.collection('reports');

// builds the firestore query based on the filters selected by the user.
Query<Map<String, dynamic>> buildFilteredReportsSelection(ReportFilter filter) {
  Query<Map<String, dynamic>> query = _reportsCollection;

  // filters by lost or found report type.
  if (filter.reportType != null) {
    query = query.where('reportType', isEqualTo: filter.reportType);
  }

  // one category can use a normal equality check.
  if (filter.categories.length == 1) {
    query = query.where('category', isEqualTo: filter.categories.first);
  } else if (filter.categories.length > 1) {
    // whereIn lets the user filter using multiple categories at once.
    final categories = filter.categories.toList()..sort();
    query = query.where('category', whereIn: categories);
  }

  // filters reports by their item condition.
  if (filter.condition != null) {
    query = query.where('condition', isEqualTo: filter.condition);
  }

  // filters reports by their current status.
  if (filter.reportStatus != null) {
    query = query.where('reportStatus', isEqualTo: filter.reportStatus);
  }

  return query;
}

// adds sorting when there are no other filters selected.
// filtered queries are sorted later in dart to avoid needing extra indexes.
Query<Map<String, dynamic>> buildFilteredReportsQuery(ReportFilter filter) {
  final selection = buildFilteredReportsSelection(filter);

  if (filter.hasCriteria) {
    return selection;
  }

  return selection.orderBy(
    'createdAt',
    descending: filter.sortOrder.descending,
  );
}

// firestore streams keep listening for changes.
// this means screens update automatically when data changes.

// gets every report and shows the newest ones first.
final reportsProvider = StreamProvider<List<ItemReport>>((ref) {
  return _reportsCollection
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs
            .map((doc) => ItemReport.fromFirestore(doc))
            .toList();
      });
});

// gets reports using the filters selected by the user.
final filteredReportsProvider = StreamProvider.autoDispose
    .family<List<ItemReport>, ReportFilter>((ref, filter) {
      return buildFilteredReportsQuery(filter).snapshots().map((snapshot) {
        final reports = snapshot.docs
            .map((doc) => ItemReport.fromFirestore(doc))
            .toList();

        // filtered results are sorted here instead of using firestore orderBy.
        // this avoids needing a separate composite index for each filter.
        if (filter.hasCriteria) {
          reports.sort((a, b) {
            final comparison = a.createdAt.compareTo(b.createdAt);
            return filter.sortOrder.descending ? -comparison : comparison;
          });
        }

        return reports;
      });
    });

// gets the number of reports that match the selected filters.
// firestore calculates the count without downloading every report.
final filteredReportCountProvider = FutureProvider.autoDispose
    .family<int, ReportFilter>((ref, filter) async {
      final snapshot = await buildFilteredReportsSelection(
        filter,
      ).count().get();

      return snapshot.count ?? 0;
    });

// listens to one report using its firestore document id.
// any changes to the report appear on the details screen automatically.
final reportProvider = StreamProvider.autoDispose.family<ItemReport?, String>((
  ref,
  id,
) {
  if (id.trim().isEmpty) {
    return Stream.value(null);
  }

  return _reportsCollection.doc(id).snapshots().map((doc) {
    if (!doc.exists) {
      return null;
    }

    return ItemReport.fromFirestore(doc);
  });
});

// gets only reports created by the currently logged in user.
final myReportsProvider = StreamProvider<List<ItemReport>>((ref) {
  // watching auth state makes this refresh when the user logs in or out.
  final authState = ref.watch(authStateProvider);

  return authState.when(
    data: (user) {
      // no logged in user means there are no reports to show.
      if (user == null) {
        return Stream.value(<ItemReport>[]);
      }

      return _reportsCollection
          .where('userId', isEqualTo: user.uid)
          .snapshots()
          .map((snapshot) {
            final reports = snapshot.docs
                .map((doc) => ItemReport.fromFirestore(doc))
                .toList();

            // sorts the user's reports from newest to oldest.
            reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));

            return reports;
          });
    },
    loading: () => Stream.value(<ItemReport>[]),
    error: (e, _) => Stream.error(e),
  );
});

// firestore collection used to store item claims.
final _claimsCollection = FirebaseFirestore.instance.collection('claims');

// converts firestore claim documents into claim objects
// and sorts them from newest to oldest.
List<Claim> _sortedClaims(QuerySnapshot<Map<String, dynamic>> snapshot) {
  final claims = snapshot.docs
      .map((doc) => Claim.fromFirestore(doc))
      .toList();

  claims.sort((a, b) => b.createdAt.compareTo(a.createdAt));

  return claims;
}

// gets every claim submitted for a specific report.
// report owners use this to accept or reject claims.
final claimsForReportProvider = StreamProvider.autoDispose
    .family<List<Claim>, String>((ref, reportId) {
      if (reportId.trim().isEmpty) {
        return Stream.value(<Claim>[]);
      }

      return _claimsCollection
          .where('reportId', isEqualTo: reportId)
          .snapshots()
          .map(_sortedClaims);
    });

// gets claims submitted by the currently logged in user.
final myClaimsProvider = StreamProvider<List<Claim>>((ref) {
  final authState = ref.watch(authStateProvider);

  return authState.when(
    data: (user) {
      if (user == null) {
        return Stream.value(<Claim>[]);
      }

      return _claimsCollection
          .where('claimerId', isEqualTo: user.uid)
          .snapshots()
          .map(_sortedClaims);
    },
    loading: () => Stream.value(<Claim>[]),
    error: (e, _) => Stream.error(e),
  );
});

// gets claims other users submitted for the current user's reports.
final incomingClaimsProvider = StreamProvider<List<Claim>>((ref) {
  final authState = ref.watch(authStateProvider);

  return authState.when(
    data: (user) {
      if (user == null) {
        return Stream.value(<Claim>[]);
      }

      return _claimsCollection
          .where('ownerId', isEqualTo: user.uid)
          .snapshots()
          .map(_sortedClaims);
    },
    loading: () => Stream.value(<Claim>[]),
    error: (e, _) => Stream.error(e),
  );
});

// counts incoming claims that have not been accepted or rejected yet.
// this number is shown on the navigation badge.
final pendingClaimCountProvider = Provider<int>((ref) {
  final claims = ref.watch(incomingClaimsProvider).value ?? <Claim>[];

  return claims.where((claim) => claim.isPending).length;
});

// gets only reports that are still open.
// the ai matching feature uses this so closed reports are not suggested.
final openReportsProvider = StreamProvider<List<ItemReport>>((ref) {
  return _reportsCollection
      .where('reportStatus', isEqualTo: 'open')
      .snapshots()
      .map((snapshot) {
        return snapshot.docs
            .map((doc) => ItemReport.fromFirestore(doc))
            .toList();
      });
});