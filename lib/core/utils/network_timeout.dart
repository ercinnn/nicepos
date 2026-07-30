/// Mobil çevrimdışı destek: `ProductRepository`'nin ağ çağrılarının (bugün
/// timeout'suz) bir "sahte bağlı" dead-zone'da askıda kalmaması için ortak
/// süre sınırı. `TimeoutException` bu şekilde bir ağ hatası olarak
/// sınıflandırılır (bkz. product_form_screen.dart `_save`/`_loadProduct`/
/// `_fetchByBarcode` — offline kuyruk/cache fallback'i bu istisnayı yakalar).
const kNetworkOpTimeout = Duration(seconds: 6);

Future<T> withNetworkTimeout<T>(Future<T> future) => future.timeout(kNetworkOpTimeout);
