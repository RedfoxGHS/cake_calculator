# Custo do Bolo

App Android (Flutter) para saber quanto custa fazer um bolo e quanto cobrar por ele.

## O que faz

- **Mercados**: cadastre os mercados e o preço de cada produto (preço da embalagem + tamanho, o app mostra quanto sai o kg / L / unidade). Ao criar um mercado novo, o app oferece puxar os produtos que já existem nos outros, para só ajustar o preço.
- **Receitas**: livro de receitas separado em massa, recheio, cobertura e outro, com ingredientes, forma de referência e modo de preparo.
- **Simular**: escolha a forma e quantas formas, junte as receitas do bolo e veja:
  - o custo comprando tudo em cada mercado;
  - o custo pegando cada item no mercado mais barato (usando no máximo 3 mercados);
  - a lista de compras com quantas embalagens levar;
  - o preço sugerido com gás/luz, embalagem, % de mão de obra e % de lucro (editáveis).
- **Ajustes**: valores padrão, formas personalizadas (redonda, quadrada, retangular) e lista de produtos.

As receitas são ajustadas pela área do fundo da forma: uma receita feita para forma redonda de 20 cm vira ×1,56 numa de 25 cm.

Os dados ficam salvos no próprio aparelho (`shared_preferences`), sem conta e sem internet.

## Rodando

```bash
flutter pub get
flutter run -d chrome     # testar rápido no navegador
flutter run               # celular Android conectado
flutter build apk         # gerar o APK
flutter test              # testes das contas
```
