import 'package:cloud_firestore/cloud_firestore.dart';

// model class for one lost/found item report.
// this maps to one document in the 'reports' collection in firestore.
// the field names follow the ItemReport data dictionary from part 1.
class ItemReport {
  // firestore document id. this is not stored inside the document itself,
  // it comes from doc.id and is needed for update and delete.
  String id;

  // who created the report. used to filter "my reports".
  String userId;
  String userEmail;

  // core item details
  String name;
  String category;
  String colour;
  String description;
  String location;

  // Where on campus the item was lost or found.
  //
  // Nullable so documents written before the map existed still load, but
  // every new report is required to drop a pin, so in practice these are
  // always set.
  double? latitude;
  double? longitude;

  // optional details the user may not know
  String brand;
  String condition;

  // 'Lost' or 'Found'. this used to be called 'status' in the old model.
  String reportType;

  // 'open', 'claimed' or 'resolved'. this is the workflow status.
  String reportStatus;

  // when the item was actually lost or found (user picks this)
  DateTime dateLostFound;

  // when the report document was created (set automatically)
  DateTime createdAt;

  // photo stored as a base64 string inside the document.
  // firebase cloud storage needs the paid blaze plan, so we store the
  // encoded image directly in firestore instead (same approach as mini-project 9).
  String base64Image;

  // fallback bundled asset, used for the sample/demo reports that have no photo.
  String imagePath;

  // only lost reports should have a reward.
  double? reward;

  // true once the reward has been paid through NETS QR and is being held
  // by findr until the item is returned.
  bool rewardPaid;

  // the NETS transaction reference for that payment, kept as a receipt.
  String paymentTxnRef;

  // set when the held reward has been released to the finder.
  bool rewardReleased;

  ItemReport({
    this.id = '',
    this.userId = '',
    this.userEmail = '',
    required this.name,
    required this.category,
    this.colour = '',
    required this.description,
    required this.location,
    this.latitude,
    this.longitude,
    this.brand = '',
    this.condition = '',
    required this.reportType,
    this.reportStatus = 'open',
    DateTime? dateLostFound,
    DateTime? createdAt,
    this.base64Image = '',
    this.imagePath = '',
    this.reward,
    this.rewardPaid = false,
    this.paymentTxnRef = '',
    this.rewardReleased = false,
  }) : dateLostFound = dateLostFound ?? DateTime.now(),
       createdAt = createdAt ?? DateTime.now();

  // builds an ItemReport out of a firestore document.
  // every field has a fallback so a missing field cannot crash the app.
  static ItemReport fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    // a bad value in one older document should not break the whole live list.
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

    double? readReward() {
      final value = data['reward'];

      if (value is num) {
        return value.toDouble();
      }

      if (value is String) {
        return double.tryParse(value);
      }

      return null;
    }

    return ItemReport(
      id: doc.id,
      userId: readString('userId'),
      userEmail: readString('userEmail'),
      name: readString('name'),
      category: readString('category'),
      colour: readString('colour'),
      description: readString('description'),
      location: readString('location'),
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      brand: readString('brand'),
      condition: readString('condition'),
      reportType: readString('reportType', 'Lost'),
      reportStatus: readString('reportStatus', 'open'),
      dateLostFound: readDate('dateLostFound'),
      createdAt: readDate('createdAt'),
      base64Image: readString('base64Image'),
      imagePath: readString('imagePath'),
      reward: readReward(),
      rewardPaid: data['rewardPaid'] == true,
      paymentTxnRef: readString('paymentTxnRef'),
      rewardReleased: data['rewardReleased'] == true,
    );
  }

  // turns the object into a map that firestore can store.
  // the id is left out on purpose because it is the document id.
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userEmail': userEmail,
      'name': name,
      'category': category,
      'colour': colour,
      'description': description,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'brand': brand,
      'condition': condition,
      'reportType': reportType,
      'reportStatus': reportStatus,
      'dateLostFound': dateLostFound,
      'createdAt': createdAt,
      'base64Image': base64Image,
      'imagePath': imagePath,
      'reward': reward,
      'rewardPaid': rewardPaid,
      'paymentTxnRef': paymentTxnRef,
      'rewardReleased': rewardReleased,
    };
  }

  // true when a reward has been paid and is still waiting to be handed over.
  bool get hasEscrow => rewardPaid && !rewardReleased;

  // True when this report has a pin and can be drawn on the map.
  bool get hasLocation => latitude != null && longitude != null;

  // true when the user actually uploaded a photo.
  // the ui uses this to decide between Image.memory and Image.asset.
  bool get hasPhoto => base64Image.isNotEmpty;

  // true when the report is still active.
  bool get isOpen => reportStatus == 'open';

  // the cards show something like "2h ago", so this works it out from createdAt
  // instead of it being typed in by hand like it was before.
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
