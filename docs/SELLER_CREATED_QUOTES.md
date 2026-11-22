# Atendimento iniciado pelo vendedor

O vendedor aprovado pode usar **Criar orçamento**, informar nome do cliente, contato opcional, produto, descrição e quantidade. Em seguida abre o pedido e continua a precificação existente. O cliente atendido pelo WhatsApp não precisa criar conta nem instalar o aplicativo. Não há leitura ou envio automático de mensagens pelo WhatsApp.

O cliente que quiser usar o sistema continua com **Solicitar orçamento** e só vê seus próprios pedidos. A API ignora identificadores de dono, criador e status enviados pelo navegador. O criador é o usuário autenticado; vendedor sem aprovação é recusado. Pedidos criados pela equipe têm `buyer_id` nulo e dados de atendimento guardados no próprio orçamento. Não são criadas contas fictícias de clientes nem vínculos automáticos com futuras contas Google.

A migration 004 mantém os pedidos existentes, preenche o criador com o comprador original e permite cliente sem conta. Não altera migrations anteriores, não apaga dados e não exige recriar volumes. Testes cobrem permissão, titularidade, visibilidade, validação e persistência no PostgreSQL. A integração do PDF continua em sua branch própria.
