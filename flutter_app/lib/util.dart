import 'package:heritage/api.dart';
import 'package:url_launcher/url_launcher.dart';

String genderedRelationship(Relationship relationship, Gender gender) {
  switch (relationship) {
    case Relationship.parent:
      return gender == Gender.male ? 'Father' : 'Mother';
    case Relationship.sibling:
      return gender == Gender.male ? 'Brother' : 'Sister';
    case Relationship.spouse:
      return gender == Gender.male ? 'Husband' : 'Wife';
    case Relationship.child:
      return gender == Gender.male ? 'Son' : 'Daughter';
  }
}

void launchEmail() {
  final uri = Uri.parse('mailto:tarloksinghfilms@gmail.com?subject=');
  launchUrl(uri);
}
