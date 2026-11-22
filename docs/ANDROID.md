# Android (KAN-50)

A variante de validação usa o pacote `shop.orcex.fera_mobile` e a API
`https://orcex.shop/api`. O aplicativo Android usa o seletor de contas nativo.
O cliente OAuth web já usado pelo backend é passado como `serverClientId`, para
que o token Android tenha a audiência que a API já valida.

## Login Google

No mesmo projeto Google Cloud do ORCEX, crie um cliente OAuth do tipo Android
com o ID do pacote e o SHA-1 do certificado que assina o APK instalado. Para
obter o SHA-1 do APK final, execute `apksigner verify --print-certs <apk>`.
A chave privada fica com o responsável pela assinatura. Se o aplicativo for
distribuído via Google Play App Signing, registre também o SHA-1 do certificado
de assinatura informado pelo Play Console.

## APK de validação

O workflow Android compila o APK. O artefato do CI precisa ser assinado com
a chave estável de validação antes de testar o login. Use `apksigner sign` com
o keystore de validação e confira com `apksigner verify --print-certs` que a
impressão digital corresponde ao cliente OAuth cadastrado.

Em um aparelho com Google Play Services, valide o login, a lista de materiais,
a criação e a reabertura de um orçamento, e então a visualização e o
compartilhamento do PDF. O APK usa a API real, então faça o teste de escrita
apenas com dados de teste autorizados.
