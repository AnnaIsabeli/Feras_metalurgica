#!/usr/bin/env python3
"""Extract the actual generated PDFs and verify customer data and confidentiality."""
import re
import sys
from pathlib import Path
from pypdf import PdfReader

folder = Path(sys.argv[1])
texts = {}
for name in ('orcamento-exemplo', 'orcamento-longo', 'orcamento-sem-prazo', 'orcamento-persistido'):
    reader = PdfReader(folder / (name + '.pdf'))
    assert not reader.is_encrypted
    assert 1 <= len(reader.pages) <= 20
    for page in reader.pages:
        assert abs(float(page.mediabox.width) - 595.28) < 1
        assert abs(float(page.mediabox.height) - 841.89) < 1
    for page in reader.pages:
        page_text = re.sub(r'\s+', '', page.extract_text() or '')
        if 'PRAZODEENTREGA' in page_text:
            assert '20diasúteisapósaaprovação' in page_text, (name, 'orphan delivery heading')
            assert 'VALORTOTAL' in page_text, (name, 'split summary')
    text = ' '.join(' '.join(page.extract_text() or '' for page in reader.pages).split())
    texts[name] = text
    compact = re.sub(r'\s+', '', text)
    for required in ('FERA METALÚRGICA', 'Marina de Souza', 'Portão metálico', 'R$ 3.870,45'):
        assert re.sub(r'\s+', '', required) in compact, (name, required)
    for forbidden in ('unitCost', 'unit_cost', 'CMV', 'markup', 'netProfit',
                      'margem', 'custo unitário', '13.333333', '13,333333',
                      '85.123456', '85,123456', '9876.54321', '9.876,54321',
                      'ALTERADO_NAO_DEVE_APARECER'):
        assert re.sub(r'\s+', '', forbidden).lower() not in compact.lower(), (name, forbidden)
    assert 'VALIDADE' not in compact.upper()
    assert 'PAGAMENTO' not in compact.upper()
    print(f'PASS: {name}: {len(reader.pages)} page(s), saved total and client data, no internal costs/margins')

normal = texts['orcamento-exemplo']
assert len(PdfReader(folder / 'orcamento-exemplo.pdf').pages) == 1
for required in ('Metalon 40 x 30', 'Chapa de aço galvanizado', '1,75', 'm²', 'Tinta esmalte PU', '0,5'):
    assert required in normal, required
assert '20 dias úteis após a aprovação' in normal
assert 'PRAZO DE ENTREGA' not in texts['orcamento-sem-prazo']
assert '20 dias úteis' not in texts['orcamento-sem-prazo']
assert '20diasúteisapósaaprovação' in re.sub(r'\s+', '', texts['orcamento-persistido'])
long = texts['orcamento-longo']
assert len(PdfReader(folder / 'orcamento-longo.pdf').pages) >= 3
for number in range(1, 101):
    assert re.search(rf'Item\s+{number}\s+-', long), number
assert long.count('Descrição com acentuação,') == 70
print('PASS: all 100 long items and full description survived pagination; optional delivery is respected')
