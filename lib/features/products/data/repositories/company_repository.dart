import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/company.dart';

class CompanyRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Company>> fetchAll() async {
    final rows = await _client.from('companies').select('*').order('name');
    return (rows as List)
        .map((row) => Company.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<void> create(Company company) async {
    await _client.from('companies').insert(company.toInsertMap());
  }

  Future<void> update(String id, Company company) async {
    await _client.from('companies').update(company.toInsertMap()).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('companies').delete().eq('id', id);
  }
}
