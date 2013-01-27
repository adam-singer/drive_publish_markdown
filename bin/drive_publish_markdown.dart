import "dart:io";
import "dart:async";
import 'dart:crypto';
import "dart:json" as JSON;
import "package:google_oauth2_client/google_oauth2_console.dart";
import "package:drive_v2_api/drive_v2_api_console.dart" as drivelib;
import "package:urlshortener_v1_api/urlshortener_v1_api_console.dart" as urllib;
import "package:markdown/lib.dart" as markdown;

String identifier = "299615367852-n0kfup30mfj5emlclfgud9g76itapvk9.apps.googleusercontent.com";
String secret = "8ini0niNxsDN0y42ye_UNubw";
List scopes = [drivelib.Drive.DRIVE_FILE_SCOPE, drivelib.Drive.DRIVE_SCOPE, urllib.Urlshortener.URLSHORTENER_SCOPE];
drivelib.Drive drive;
urllib.Urlshortener urlshort;
OAuth2Console auth;

void insertPermissions(drivelib.File file, Completer completer) {
  /**
   * Create new [drivelib.Permission] for insertion to the
   * drive permissions list. This will mark the folder publicly
   * readable by anyone.
   */
  var permissions = new drivelib.Permission.fromJson({
    "value": "",
    "type": "anyone",
    "role": "reader"
  });

  drive.permissions.insert(permissions, file.id).then((drivelib.Permission permission) => completer.complete(file));
}

Future<drivelib.File> createPublicFolder(String folderName) {
  var completer = new Completer();

  /**
   * Create the [drivelib.File] with a web folder app mime type.
   */
  drivelib.File file = new drivelib.File.fromJson({
    'title': folderName,
    'mimeType': "application/vnd.google-apps.folder"
  });

  /**
   * Insert the [drivelib.File] to google drive.
   */
  drive.files.insert(file).then((drivelib.File newfile) => insertPermissions(newfile, completer));

  return completer.future;
}

processMarkdown(drivelib.File folder) {
  /**
   * Read in both markdown and html template
   */
  var markdownFile = new File('markdown.md');
  var templateFile = new File('template.html');
  var markdownStr = markdownFile.readAsStringSync();
  var templateStr = templateFile.readAsStringSync();

  /**
   * Convert markdown to html.
   */
  var page = markdown.markdownToHtml(markdownStr);

  /**
   * Replace $page with converted markdown.
   */
  templateStr = templateStr.replaceFirst('\$page', page);

  /**
   * Create a new [drivelib.File] to hold the html content.
   */
  drivelib.File file = new drivelib.File.fromJson({
    'title': 'index.html',
    'mimeType': "text/html"
  });

  /**
   * Create a new [drivelib.ParentReference] to link the html file to.
   */
  drivelib.ParentReference newParent = new drivelib.ParentReference.fromJson({'id': folder.id});

  /**
   * Encode the content to Base64 for inserting into drive.
   */
  var content = CryptoUtils.bytesToBase64(templateStr.charCodes);

  /**
   * 1) Insert the new file with title index.html and type text/html
   * 2) Insert the new parent of the file (i.e. place the file in the folder)
   * 3) Get the folders web view link
   * 4) Shorten the web view link with UrlShortener
   */
  drive.files.insert(file, content: content).then((drivelib.File insertedFile) {
    drive.parents.insert(newParent, insertedFile.id).then((drivelib.ParentReference parentReference) {
      drive.files.get(folder.id).then((folder) {
        print("Web View Link: ${folder.webViewLink}");
        var url = new urllib.Url.fromJson({'longUrl': folder.webViewLink});
        urlshort.url.insert(url).then((url) {
          print("Short Url ${url.id}");
        });
      });
    });
  });
}

void main() {
  //showAll();

  /**
   * Create new or load existing oauth2 token.
   */
  auth = new OAuth2Console(identifier: identifier, secret: secret, scopes: scopes);

  /**
   * Create a new [drivelib.Drive] object with authenticated requests.
   */
  drive = new drivelib.Drive(auth);
  drive.makeAuthRequests = true;

  /**
   * Create a new [urllib.Urlshortener] object with authenticated requests.
   */
  urlshort = new urllib.Urlshortener(auth);
  urlshort.makeAuthRequests = true;

  /**
   * Create a new 'public_folder' and insert markdown as html
   */
  createPublicFolder("public_folder").then(processMarkdown);
}
