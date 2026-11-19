final _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// Evita que um id malformado chegue ao PostgreSQL (erro de cast vira 500).
bool isUuid(String value) => _uuid.hasMatch(value);
