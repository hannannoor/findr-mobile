import 'package:cloud_firestore/cloud_firestore.dart';

// model class for one claim made against a lost/found report.
// this maps to one document in the 'claims' collection in firestore and
// follows the Claims data dictionary from part 1.
class Claim {
  // firestore document id, needed to accept, reject or withdraw a claim.
  String id;

  // which report this claim is against.
  String reportId;

  // copied from the report at claim time so the claim can be listed without
  // having to read the report document again for every row.
  String reportName;
  String reportType;
  String reportImagePath;

  // the person making the claim.
  String claimerId;
  String claimerEmail;

  // the person who owns the report, so incoming claims can be queried.
  String ownerId;

  // why the claimer believes the item is theirs.
  String claimMessage;

  // 'pending', 'accepted' or 'rejected'.
  String claimStatus;

  DateTime createdAt;

  Claim({
    this.id = '',
    required this.reportId,
    this.reportName = '',
    this.reportType = '',
    this.reportImagePath = '',
    required this.claimerId,
    this.claimerEmail = '',
    required this.ownerId,
    required this.claimMessage,
    this.claimStatus = 'pending',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // builds a Claim from a firestore document, with a fallback on every field
  // so one bad document cannot break the whole list.
  static Claim fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    String readString(String key, [String fallback = '']) {
      final value = data[key];
      return value is String ? value : fallback;
    }

    DateTime readDate(String key) {
      final value = data[key];

      if (value is Timestamp) {
        return value.toDate();
      }
      if (value is DateTime) {
        return value;
      }
      return DateTime.now();
    }

    return Claim(
      id: doc.id,
      reportId: readString('reportId'),
      reportName: readString('reportName'),
      reportType: readString('reportType'),
      reportImagePath: readString('reportImagePath'),
      claimerId: readString('claimerId'),
      claimerEmail: readString('claimerEmail'),
      ownerId: readString('ownerId'),
      claimMessage: readString('claimMessage'),
      claimStatus: readString('claimStatus', 'pending'),
      createdAt: readDate('createdAt'),
    );
  }

  // turns the claim into a map firestore can store.
  // the id is left out because it is the document id.
  Map<String, dynamic> toMap() {
    return {
      'reportId': reportId,
      'reportName': reportName,
      'reportType': reportType,
      'reportImagePath': reportImagePath,
      'claimerId': claimerId,
      'claimerEmail': claimerEmail,
      'ownerId': ownerId,
      'claimMessage': claimMessage,
      'claimStatus': claimStatus,
      'createdAt': createdAt,
    };
  }

  bool get isPending => claimStatus == 'pending';
  bool get isAccepted => claimStatus == 'accepted';
  bool get isRejected => claimStatus == 'rejected';

  // the part before the @ in the email, used as a display name since there
  // is no separate profile name stored yet.
  String get claimerName {
    if (claimerEmail.isEmpty) {
      return 'A student';
    }
    return claimerEmail.split('@').first;
  }

  // how long ago the claim was submitted, shown on the claim cards.
  String get timeAgo {
    final Duration diff = DateTime.now().difference(createdAt);

    if (diff.inSeconds < 60) {
      return 'Just now';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    }
    return '${(diff.inDays / 7).floor()}w ago';
  }
}
