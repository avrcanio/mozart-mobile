import '../data/http/api_client.dart';

const String connectivityIssueMessage =
    'Veza s Mozart servisom trenutno nije dostupna. Pokusajte ponovno za nekoliko trenutaka.';
const String slowConnectionMessage =
    'Veza s Mozart servisom je prespora ili privremeno nedostupna. Pokusajte ponovno za nekoliko trenutaka.';

bool isConnectivityIssue(Object error) {
  return error is ApiException && error.isConnectivityIssue;
}
