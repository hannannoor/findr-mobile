import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:findr_application/models/claim.dart';
import 'package:findr_application/models/item_report.dart';
import 'package:findr_application/services/notification_service.dart';

// this service keeps all firebase auth code in one place.
// screens call these functions through the provider instead of calling firebase directly.
class FirebaseService {
  // creates a new account using email and password.
  Future<UserCredential> register(String email, String password) {
    return FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // logs the user in using email and password.
  Future<UserCredential> login(String email, String password) {
    return FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // gets the current logged in user.
  // this is used in profile screen to show the email and account details.
  User? getCurrentUser() {
    return FirebaseAuth.instance.currentUser;
  }

  // logs the user out from firebase.
  // also tries to log out from google if google sign in was used.
  Future<void> logOut() async {
    await FirebaseAuth.instance.signOut();

    try {
      await GoogleSignIn().signOut();
    } catch (_) {
      // ignore this because it only matters if google login was used.
    }
  }

  // sends a reset password email to the user.
  // the screen will show the snackbar after this runs.
  Future<void> forgotPassword(String email) {
    return FirebaseAuth.instance.sendPasswordResetEmail(email: email);
  }

  // sends an email verification link to the current user.
  // this is used after signup or from the profile screen.
  Future<void> sendEmailVerification() {
    return FirebaseAuth.instance.currentUser!.sendEmailVerification();
  }

  // checks if the current user's email is already verified.
  bool isEmailVerified() {
    return FirebaseAuth.instance.currentUser?.emailVerified ?? false;
  }

  // changes the password for the current user.
  // firebase may reject this if the user has not logged in recently.
  Future<void> changePassword(String newPassword) {
    return FirebaseAuth.instance.currentUser!.updatePassword(newPassword);
  }

  // signs in using google.
  // web and android need slightly different setup.
  Future<UserCredential?> signInWithGoogle() async {
    GoogleSignIn googleSignIn;

    if (kIsWeb) {
      // web needs the web client id from firebase/google cloud.
      googleSignIn = GoogleSignIn(
        clientId:
            '1002480421775-0oj9ku2fj8aakmrkvuqbmdf9c9hbrlmh.apps.googleusercontent.com',
      );
    } else {
      // android does not need the web client id here.
      googleSignIn = GoogleSignIn();
    }

    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

    // if the user cancels the google popup, stop here.
    if (googleUser == null) {
      return null;
    }

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return FirebaseAuth.instance.signInWithCredential(credential);
  }

  // permanently removes the account along with everything it created.
  //
  // the firestore data is cleared first, because once the auth user is gone
  // the security rules would block the app from touching those documents.
  Future<void> deleteAccount() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError('You must be logged in to delete your account.');
    }

    final String uid = user.uid;
    final firestore = FirebaseFirestore.instance;

    final reports = await firestore
        .collection('reports')
        .where('userId', isEqualTo: uid)
        .get();

    final claims = await firestore
        .collection('claims')
        .where('claimerId', isEqualTo: uid)
        .get();

    final chats = await firestore
        .collection('chats')
        .where('participants', arrayContains: uid)
        .get();

    final notifications = await firestore
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .get();

    final WriteBatch batch = firestore.batch();

    for (final doc in reports.docs) {
      batch.delete(doc.reference);
    }
    for (final doc in claims.docs) {
      batch.delete(doc.reference);
    }
    for (final doc in chats.docs) {
      batch.delete(doc.reference);
    }
    for (final doc in notifications.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();

    // this throws requires-recent-login if the session is old, which the
    // settings screen turns into a readable message.
    await user.delete();
  }

  // signs in using github.
  // this is the second extra authentication method for the rubric.
  Future<UserCredential> signInWithGitHub() async {
    GithubAuthProvider githubProvider = GithubAuthProvider();

    if (kIsWeb) {
      // chrome/web uses a popup login window.
      return FirebaseAuth.instance.signInWithPopup(githubProvider);
    } else {
      // android/ios uses provider sign in.
      return FirebaseAuth.instance.signInWithProvider(githubProvider);
    }
  }

  // ---------------------------------------------------------------------
  // cloud firestore: item report CRUD
  //
  // create, update and delete are one-time actions so they return Future.
  // the read side is not here, it lives in firebase_provider.dart as a
  // Stream so the ui updates by itself whenever the data changes.
  // ---------------------------------------------------------------------

  // shortcut to the reports collection so the path is not typed out everywhere.
  final CollectionReference<Map<String, dynamic>> _reports = FirebaseFirestore
      .instance
      .collection('reports');

  // CREATE: adds a new lost/found report document.
  // the owner and the created date are stamped on here rather than in the ui,
  // so a report can never be saved without knowing who made it.
  Future<void> addReport(ItemReport report) async {
    final User? user = getCurrentUser();

    if (user == null) {
      throw StateError('A user must be logged in before creating a report.');
    }

    if (report.dateLostFound.isAfter(DateTime.now())) {
      throw ArgumentError('The lost or found time cannot be in the future.');
    }

    if (report.reward != null &&
        (!report.reward!.isFinite || report.reward! <= 0)) {
      throw ArgumentError('A reward must be greater than zero.');
    }

    if (report.base64Image.length > 700000) {
      throw ArgumentError('The report photo is too large for Firestore.');
    }

    // every report has to say where on campus it happened, because the map
    // is only useful if nothing is missing from it.
    if (!report.hasLocation) {
      throw ArgumentError('Please drop a pin for where this happened.');
    }

    report.userId = user.uid;
    report.userEmail = user.email ?? '';
    report.createdAt = DateTime.now();

    final data = report.toMap();

    // firestore's clock is used for the creation time so reports from
    // different devices still sort consistently.
    data['createdAt'] = FieldValue.serverTimestamp();

    await _reports.add(data);
  }

  // UPDATE: changes only fields that belong to the editable report form.
  // ownership, creation time and workflow status are deliberately left alone.
  Future<void> updateReport(ItemReport report) {
    if (report.id.trim().isEmpty) {
      throw ArgumentError('A report id is required before updating.');
    }

    if (report.dateLostFound.isAfter(DateTime.now())) {
      throw ArgumentError('The lost or found time cannot be in the future.');
    }

    if (report.reward != null &&
        (!report.reward!.isFinite || report.reward! <= 0)) {
      throw ArgumentError('A reward must be greater than zero.');
    }

    if (report.base64Image.length > 700000) {
      throw ArgumentError('The report photo is too large for Firestore.');
    }

    return _reports.doc(report.id).update({
      'name': report.name,
      'category': report.category,
      'colour': report.colour,
      'description': report.description,
      'location': report.location,
      'latitude': report.latitude,
      'longitude': report.longitude,
      'brand': report.brand,
      'condition': report.condition,
      'reportType': report.reportType,
      'dateLostFound': report.dateLostFound,
      'base64Image': report.base64Image,
      'imagePath': report.imagePath,
      'reward': report.reward,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // UPDATE (single field): used when a report moves from open to claimed
  // or resolved, so the whole document does not have to be rewritten.
  Future<void> updateReportStatus(String id, String newStatus) {
    const allowedStatuses = {'open', 'claimed', 'resolved'};

    if (id.trim().isEmpty) {
      throw ArgumentError('A report id is required before updating.');
    }

    if (!allowedStatuses.contains(newStatus)) {
      throw ArgumentError('Unknown report status: $newStatus');
    }

    return _reports.doc(id).update({
      'reportStatus': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // DELETE: removes a report the user posted by mistake or no longer needs.
  // any claims made against the report are removed with it so the claims
  // collection does not keep rows pointing at a report that is gone.
  Future<void> deleteReport(String id) async {
    if (id.trim().isEmpty) {
      throw ArgumentError('A report id is required before deleting.');
    }

    final claimDocs = await _claims.where('reportId', isEqualTo: id).get();

    // conversations are keyed by report, so they are found by query rather
    // than by guessing the id.
    final chatDocs = await FirebaseFirestore.instance
        .collection('chats')
        .where('reportId', isEqualTo: id)
        .get();

    final WriteBatch batch = FirebaseFirestore.instance.batch();

    for (final doc in claimDocs.docs) {
      batch.delete(doc.reference);
    }

    for (final doc in chatDocs.docs) {
      batch.delete(doc.reference);
    }

    batch.delete(_reports.doc(id));

    await batch.commit();
  }

  // releases a held reward to the finder.
  //
  // findr holds the reward from the moment the lost report is posted until
  // the owner confirms the item has been returned. this marks that handover
  // as done so the reward is no longer shown as being held.
  Future<void> releaseReward(String reportId) async {
    if (reportId.trim().isEmpty) {
      throw ArgumentError('A report id is required.');
    }

    await _reports.doc(reportId).update({
      'rewardReleased': true,
      'rewardReleasedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // whoever had their claim accepted is the one being paid, so they are
    // the person to tell.
    final claimDocs = await _claims
        .where('reportId', isEqualTo: reportId)
        .get();

    final reportDoc = await _reports.doc(reportId).get();
    final reportData = reportDoc.data() ?? {};
    final num? reward = reportData['reward'] as num?;
    final String reportName = reportData['name'] as String? ?? 'your item';

    for (final doc in claimDocs.docs) {
      if (doc.data()['claimStatus'] != 'accepted') continue;

      await NotificationService().create(
        userId: doc.data()['claimerId'] as String? ?? '',
        type: 'reward',
        title: 'Reward released',
        body: reward == null
            ? 'The reward for $reportName has been released to you.'
            : 'The \$${reward.toStringAsFixed(2)} reward for $reportName '
                  'has been released to you.',
        reportId: reportId,
        claimId: doc.id,
      );
    }
  }

  // ---------------------------------------------------------------------
  // cloud firestore: claims
  //
  // a claim is submitted by someone who believes a reported item is theirs,
  // or who has found an item another student reported as lost. the report
  // owner then accepts or rejects it.
  // ---------------------------------------------------------------------

  final CollectionReference<Map<String, dynamic>> _claims = FirebaseFirestore
      .instance
      .collection('claims');

  // CREATE: submits a claim against someone else's report.
  Future<void> submitClaim(ItemReport report, String message) async {
    final User? user = getCurrentUser();

    if (user == null) {
      throw StateError('A user must be logged in before making a claim.');
    }

    if (user.uid == report.userId) {
      throw StateError('You cannot claim your own report.');
    }

    if (report.reportStatus == 'resolved') {
      throw StateError('This report has already been resolved.');
    }

    final String trimmed = message.trim();

    if (trimmed.length < 10) {
      throw ArgumentError(
        'Please describe the item in at least 10 characters.',
      );
    }

    // one pending claim per person per report, so a report cannot be spammed.
    //
    // only reportId is filtered on in the query and the rest is checked in
    // dart. stacking three where clauses would make firestore demand a
    // composite index, which is not worth it for such a small collection.
    final existing = await _claims.where('reportId', isEqualTo: report.id).get();

    final bool alreadyClaimed = existing.docs.any((doc) {
      final data = doc.data();
      return data['claimerId'] == user.uid && data['claimStatus'] == 'pending';
    });

    if (alreadyClaimed) {
      throw StateError('You already have a pending claim on this report.');
    }

    final Claim claim = Claim(
      reportId: report.id,
      reportName: report.name,
      reportType: report.reportType,
      reportImagePath: report.imagePath,
      claimerId: user.uid,
      claimerEmail: user.email ?? '',
      ownerId: report.userId,
      claimMessage: trimmed,
    );

    final data = claim.toMap();
    data['createdAt'] = FieldValue.serverTimestamp();

    final newClaim = await _claims.add(data);

    // tell the report owner that someone has come forward.
    await NotificationService().create(
      userId: report.userId,
      type: 'claim',
      title: 'New claim on ${report.name}',
      body: '${claim.claimerName} says: $trimmed',
      reportId: report.id,
      claimId: newClaim.id,
      chatId: newClaim.id,
    );

    // the report moves to 'claimed' so other users can see someone has
    // already come forward.
    if (report.reportStatus == 'open') {
      await _reports.doc(report.id).update({
        'reportStatus': 'claimed',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // UPDATE: the report owner accepts a claim.
  // accepting one claim rejects the others, because only one person can be
  // the real owner of the item.
  Future<void> acceptClaim(Claim claim) async {
    if (claim.id.trim().isEmpty) {
      throw ArgumentError('A claim id is required.');
    }

    // single filter only, then the pending check happens in dart, so that
    // firestore does not need a composite index for this query.
    final others = await _claims
        .where('reportId', isEqualTo: claim.reportId)
        .get();

    final WriteBatch batch = FirebaseFirestore.instance.batch();

    for (final doc in others.docs) {
      if (doc.data()['claimStatus'] != 'pending') {
        continue;
      }

      batch.update(doc.reference, {
        'claimStatus': doc.id == claim.id ? 'accepted' : 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // make sure the chosen claim is updated even if it was not in the
    // pending list because of a timing difference.
    batch.update(_claims.doc(claim.id), {
      'claimStatus': 'accepted',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.update(_reports.doc(claim.reportId), {
      'reportStatus': 'claimed',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    await NotificationService().create(
      userId: claim.claimerId,
      type: 'claim_accepted',
      title: 'Your claim was accepted',
      body: 'Message ${claim.reportName.isEmpty ? 'the owner' : 'about '
          '${claim.reportName}'} to arrange the handover.',
      reportId: claim.reportId,
      claimId: claim.id,
      chatId: claim.id,
    );
  }

  // UPDATE: the report owner rejects a claim.
  // if that was the last pending claim, the report goes back to open so
  // other students can still come forward.
  Future<void> rejectClaim(Claim claim) async {
    if (claim.id.trim().isEmpty) {
      throw ArgumentError('A claim id is required.');
    }

    await _claims.doc(claim.id).update({
      'claimStatus': 'rejected',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await NotificationService().create(
      userId: claim.claimerId,
      type: 'claim_rejected',
      title: 'Claim not accepted',
      body: 'Your claim on ${claim.reportName} was rejected.',
      reportId: claim.reportId,
      claimId: claim.id,
    );

    // filtered on one field only so no composite index is needed.
    final remaining = await _claims
        .where('reportId', isEqualTo: claim.reportId)
        .get();

    final bool anyPending = remaining.docs.any(
      (doc) => doc.data()['claimStatus'] == 'pending',
    );

    if (!anyPending) {
      final reportDoc = await _reports.doc(claim.reportId).get();
      final currentStatus = reportDoc.data()?['reportStatus'];

      // a resolved report is left alone.
      if (currentStatus == 'claimed') {
        await _reports.doc(claim.reportId).update({
          'reportStatus': 'open',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  // DELETE: lets a claimer withdraw a claim they made by mistake.
  Future<void> withdrawClaim(Claim claim) async {
    final User? user = getCurrentUser();

    if (user == null || user.uid != claim.claimerId) {
      throw StateError('You can only withdraw your own claim.');
    }

    await _claims.doc(claim.id).delete();

    // the conversation is deliberately kept. it belongs to the two people
    // rather than to the claim, so withdrawing a claim should not wipe the
    // messages they exchanged about the item.

    // filtered on one field only so no composite index is needed.
    final remaining = await _claims
        .where('reportId', isEqualTo: claim.reportId)
        .get();

    final bool anyPending = remaining.docs.any(
      (doc) => doc.data()['claimStatus'] == 'pending',
    );

    if (!anyPending) {
      final reportDoc = await _reports.doc(claim.reportId).get();

      if (reportDoc.data()?['reportStatus'] == 'claimed') {
        await _reports.doc(claim.reportId).update({
          'reportStatus': 'open',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }
}
