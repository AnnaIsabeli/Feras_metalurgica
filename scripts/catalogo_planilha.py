"""Validate the versioned workbook catalogue and emit an additive SQL import."""
import argparse
import json
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def import_sql(path):
    catalogue = json.loads(path.read_text())
    statements = ['BEGIN;']
    seen = set()
    quote = lambda value: "'" + value.replace("'", "''") + "'"
    for item in catalogue['materials']:
        key = (item['name'].strip().casefold(), item['unit'].strip().casefold())
        if key in seen:
            raise ValueError('Duplicate material: ' + str(key))
        seen.add(key)
        purchase = next(p for p in item['purchases'] if p['sourceRow'] == item['selectedSourceRow'])
        quantity, value = Decimal(purchase['quantity']), Decimal(purchase['purchaseValue'])
        if not quantity.is_finite() or quantity <= 0 or not value.is_finite() or value < 0:
            raise ValueError('Invalid purchase: ' + item['name'])
        expected = (value / quantity).quantize(Decimal('.000001'), rounding=ROUND_HALF_UP)
        if Decimal(item['unitCost']) != expected:
            raise ValueError('Unit cost mismatch: ' + item['name'])
        statements.append('INSERT INTO materials (name, unit, unit_cost) VALUES (' +
                          quote(item['name']) + ', ' + quote(item['unit']) + ', ' + str(expected) +
                          ') ON CONFLICT DO NOTHING;')
    statements.append('COMMIT;')
    return '\n'.join(statements) + '\n'

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--catalogue', type=Path, default=ROOT / 'database/catalogo/materiais_planilha.json')
    parser.add_argument('--sql', action='store_true', help='Print SQL; does not connect to or mutate a database')
    args = parser.parse_args()
    sql = import_sql(args.catalogue)
    print(sql if args.sql else 'Catálogo validado; nenhum banco alterado.')
