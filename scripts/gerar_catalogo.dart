import 'dart:convert';
import 'dart:io';

String normalizar(String texto) {
  return texto.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

double? converterNumero(String texto) {
  var valor = texto.trim().replaceAll('R\$', '').replaceAll(' ', '');

  if (valor.contains(',')) {
    valor = valor.replaceAll('.', '').replaceAll(',', '.');
  }

  return double.tryParse(valor);
}

String campoCsv(Object? valor) {
  final texto = valor?.toString() ?? '';
  return '"${texto.replaceAll('"', '""')}"';
}

Future<void> main() async {
  final pasta = Directory('database/catalogo');
  final entrada = File('${pasta.path}/materiais_originais.csv');
  final saida = File('${pasta.path}/catalogo_materiais.csv');
  final erros = File('${pasta.path}/inconsistencias.csv');

  if (!await entrada.exists()) {
    print('ERRO: materiais_originais.csv não encontrado!');
    return;
  }

  final conteudo = await entrada.readAsString();

  final linhas = const LineSplitter()
      .convert(conteudo.replaceFirst('\uFEFF', ''))
      .where((linha) => linha.trim().isNotEmpty)
      .toList();

  final catalogo = <List<String>>[
    [
      'nome',
      'unidade',
      'quantidade_comprada',
      'valor_compra',
      'custo_unitario',
      'origem_planilha',
    ],
  ];

  final inconsistencias = <List<String>>[
    ['origem', 'problema'],
  ];

  final nomesEncontrados = <String, List<String>>{};

  if (linhas.isEmpty) {
    print('ERRO: arquivo vazio.');
    return;
  }

  final cabecalho = linhas.first.split(';').map(normalizar).toList();

  final colunas = [
    'nome',
    'unidade',
    'quantidade_comprada',
    'valor_compra',
    'origem_planilha',
  ];

  if (!colunas.every(cabecalho.contains)) {
    print('ERRO: colunas obrigatórias não encontradas.');
    print('Esperadas: $colunas');
    return;
  }

  for (var i = 1; i < linhas.length; i++) {
    if (linhas[i].trim().isEmpty) continue;

    final campos = linhas[i].split(';');

    if (campos.length != cabecalho.length) {
      inconsistencias.add([
        'Linha ${i + 1}',
        'Quantidade incorreta de colunas',
      ]);
      continue;
    }

    String obter(String coluna) {
      return campos[cabecalho.indexOf(coluna)].trim();
    }

    final nome = obter('nome');
    final unidade = obter('unidade');
    final quantidadeTexto = obter('quantidade_comprada');
    final valorTexto = obter('valor_compra');
    final origem = obter('origem_planilha').isEmpty
        ? 'Linha ${i + 1}'
        : obter('origem_planilha');

    final quantidade = converterNumero(quantidadeTexto);
    final valor = converterNumero(valorTexto);

    void registrarErro(String problema) {
      inconsistencias.add([origem, problema]);
    }

    if (nome.isEmpty) registrarErro('Nome vazio');
    if (unidade.isEmpty) registrarErro('Unidade vazia');

    if (quantidade == null || quantidade <= 0) {
      registrarErro('Quantidade inválida: $quantidadeTexto');
    }

    if (valor == null || valor < 0) {
      registrarErro('Valor inválido: $valorTexto');
    }

    final chave = normalizar(nome);

    if (chave.isNotEmpty) {
      final anteriores = nomesEncontrados.putIfAbsent(chave, () => []);

      if (anteriores.isNotEmpty) {
        registrarErro(
          'Possível duplicado de $nome. '
          'Encontrado também em ${anteriores.join(", ")}',
        );
      }

      anteriores.add(origem);
    }

    String custo = '';

    if (quantidade != null && quantidade > 0 && valor != null && valor >= 0) {
      custo = (valor / quantidade).toStringAsFixed(6);
    }

    catalogo.add([nome, unidade, quantidadeTexto, valorTexto, custo, origem]);
  }

  String gerarCsv(List<List<String>> dados) {
    return dados.map((linha) => linha.map(campoCsv).join(';')).join('\n');
  }

  await saida.writeAsString('\uFEFF${gerarCsv(catalogo)}', encoding: utf8);

  await erros.writeAsString(
    '\uFEFF${gerarCsv(inconsistencias)}',
    encoding: utf8,
  );

  print('================================');
  print('CATÁLOGO GERADO COM SUCESSO!');
  print('================================');
  print('Materiais: ${catalogo.length - 1}');
  print('Inconsistências: ${inconsistencias.length - 1}');
  print('Arquivo: ${saida.path}');
  print('Relatório: ${erros.path}');
}
