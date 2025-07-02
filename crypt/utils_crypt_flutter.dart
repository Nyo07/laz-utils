import 'dart:convert';
import 'dart:typed_data';

class UtilsCrypt {
  static const String _chaveDefault = '3tic@S3nh@';

  /// Gera uma chave estendida repetindo a chave original
  static String _gerarChaveExtendida(String chave, int tamanhoTexto) {
    if (chave.isEmpty || tamanhoTexto <= 0) return '';

    StringBuffer buffer = StringBuffer();
    for (int i = 0; i < tamanhoTexto; i++) {
      buffer.write(chave[i % chave.length]);
    }
    return buffer.toString();
  }

  /// Criptografa um texto usando XOR com chave e posição
  static String criptografar(String texto, [String? chave]) {
    chave ??= _chaveDefault;

    // Verifica se a chave está vazia
    if (chave.trim().isEmpty) {
      return texto;
    }

    // Verifica se o texto está vazio
    if (texto.isEmpty) {
      return '';
    }

    try {
      // Gera uma chave do mesmo tamanho do texto
      String chaveExtendida = _gerarChaveExtendida(chave, texto.length);

      // Lista para armazenar os bytes criptografados
      List<int> bytesCriptografados = [];

      // Criptografa cada caractere
      for (int i = 0; i < texto.length; i++) {
        // Aplica XOR com a chave e adiciona um deslocamento adicional
        int valorCriptografado = texto.codeUnitAt(i) ^ 
                                chaveExtendida.codeUnitAt(i) ^ 
                                ((i + 1) % 256);
        bytesCriptografados.add(valorCriptografado & 0xFF);
      }

      // Converte para Base64 para evitar caracteres especiais
      return base64Encode(Uint8List.fromList(bytesCriptografados));
    } catch (e) {
      return '';
    }
  }

  /// Descriptografa um texto criptografado
  static String descriptografar(String textoCriptografado, [String? chave]) {
    chave ??= _chaveDefault;

    // Verifica se a chave está vazia
    if (chave.trim().isEmpty) {
      return textoCriptografado;
    }

    // Verifica se o texto está vazio
    if (textoCriptografado.isEmpty) {
      return '';
    }

    try {
      // Decodifica de Base64
      Uint8List bytesDecodificados = base64Decode(textoCriptografado);

      // Gera uma chave do mesmo tamanho do texto
      String chaveExtendida = _gerarChaveExtendida(chave, bytesDecodificados.length);

      // Lista para armazenar os caracteres descriptografados
      List<int> caracteresDescriptografados = [];

      // Descriptografa cada byte
      for (int i = 0; i < bytesDecodificados.length; i++) {
        // Reverte o processo de criptografia
        int valorDescriptografado = bytesDecodificados[i] ^ 
                                   chaveExtendida.codeUnitAt(i) ^ 
                                   ((i + 1) % 256);
        caracteresDescriptografados.add(valorDescriptografado & 0xFF);
      }

      // Converte de volta para string
      return String.fromCharCodes(caracteresDescriptografados);
    } catch (e) {
      return ''; // Retorna vazio se não conseguir decodificar
    }
  }

  /// Método de teste para verificar se a criptografia está funcionando
  static bool testarCriptografia() {
    const String textoTeste = 'Teste de criptografia 123!@#';
    const String chaveTeste = 'minhaChave';

    try {
      String textoCriptografado = criptografar(textoTeste, chaveTeste);
      String textoDescriptografado = descriptografar(textoCriptografado, chaveTeste);

      return textoTeste == textoDescriptografado;
    } catch (e) {
      return false;
    }
  }
}

// Exemplo de uso:
void main() {
  // Teste básico
  String texto = 'Olá, mundo!';
  String criptografado = UtilsCrypt.criptografar(texto);
  String descriptografado = UtilsCrypt.descriptografar(criptografado);

  print('Texto original: $texto');
  print('Texto criptografado: $criptografado');
  print('Texto descriptografado: $descriptografado');
  print('Teste passou: ${texto == descriptografado}');

  // Teste com chave personalizada
  String chavePersonalizada = 'minhaChaveSecreta';
  String criptografadoPersonalizado = UtilsCrypt.criptografar(texto, chavePersonalizada);
  String descriptografadoPersonalizado = UtilsCrypt.descriptografar(criptografadoPersonalizado, chavePersonalizada);

  print('\nCom chave personalizada:');
  print('Texto criptografado: $criptografadoPersonalizado');
  print('Texto descriptografado: $descriptografadoPersonalizado');
  print('Teste passou: ${texto == descriptografadoPersonalizado}');

  // Teste automático
  print('\nTeste automático: ${UtilsCrypt.testarCriptografia()}');
}