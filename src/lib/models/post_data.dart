// data model to store the user's input while creating a lost/found report.
// each step of the post flow fills in part of this object, and the final
// step turns it into an ItemReport and saves it to firestore.
class PostData {
  String reportType = '';

  String itemName = '';
  String category = '';
  String colour = '';
  String brand = '';
  String condition = '';
  String description = '';

  String location = '';

  // Where on campus, dropped as a pin on the map in step 3.
  // Required, because the campus map is only useful if every report is on it.
  double? latitude;
  double? longitude;

  bool get hasLocation => latitude != null && longitude != null;

  // these two stay as strings because they are what the review card displays.
  String date = '';
  String time = '';

  // the same date and time as a real DateTime, so it can be stored in
  // firestore properly instead of being saved as text.
  DateTime? dateLostFound;

  String rewardAmount = '';

  // the photo the user picked, already base64 encoded.
  // empty means the user skipped adding a photo.
  String base64Image = '';
}
