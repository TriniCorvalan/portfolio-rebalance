# Rebalanceo de cartera

Módulo Ruby de dominio puro para administrar carteras personales de inversión. Calcula qué acciones vender y cuáles comprar para acercar las posiciones actuales a una asignación objetivo.

Sin Rails ni base de datos: se puede incrustar en una aplicación de inversiones y operaciones más amplia.

## Requisitos

- Ruby 3.x
- Bundler

## Instalación

```bash
bundle install
```

## Uso

```ruby
require_relative "lib/stock"
require_relative "lib/portfolio"

meta = Stock.new(symbol: "META", shares: 10)
aapl = Stock.new(symbol: "AAPL", shares: 5)

portfolio = Portfolio.new(
  holdings: [meta, aapl],
  allocated: { "META" => 0.4, "AAPL" => 0.6 }
)

result = portfolio.rebalance("META" => 500, "AAPL" => 200)

result[:sells]
# => [{ symbol: "META", shares: 5.2, amount: 2600.00 }]

result[:buys]
# => [{ symbol: "AAPL", shares: 13, amount: 2600.00 }]
```

### Conceptos

| Concepto | Descripción |
| --- | --- |
| `holdings` | Posiciones actuales: colección de `Stock` (símbolo y títulos). |
| `allocated` | Distribución objetivo: `Hash` símbolo → ponderación en tanto por uno (`0.4` = 40 %). |
| `current_price` | Método de `Stock` que recibe el último precio disponible y lo guarda. |
| `:sells` / `:buys` | Resultado de `rebalance`: listas de órdenes `{ symbol:, shares:, amount: }`. |

`Stock` modela solo la posición (qué tienes). La asignación objetivo vive en el Hash `allocated`.

Las ponderaciones de `allocated` deben ser positivas y sumar `1`.

## Algoritmo de `rebalance(prices)`

`prices` es un `Hash` símbolo → precio. El módulo **no** consulta ningún mercado: el precio se inyecta desde fuera.

1. Aplica cada precio con `Stock#current_price`.
2. Calcula el valor actual de cada símbolo (`títulos × precio`). Si no hay posición, el valor es `0`.
3. Suma el valor total de la cartera.
4. Calcula el valor objetivo: `valor total × ponderación`. Si el símbolo no está en `allocated`, la ponderación es `0` (se vende toda la posición).
5. Diferencia positiva → compra. Diferencia negativa → venta.
6. Títulos a operar = `|diferencia| / precio`, redondeados a **4 decimales** (`SHARE_SCALE`; fracciones, habituales en inversión personal).
7. Órdenes con importe menor a **un centavo** no se emiten.

## Por qué `BigDecimal`

Precios, títulos, ponderaciones e importes usan `BigDecimal`, no `Float`.

El `Float` de Ruby es coma flotante binaria y no representa bien muchos decimales:

```ruby
0.1 + 0.2
# => 0.30000000000000004
```

En un rebalanceo eso puede distorsionar valores de mercado, hacer que los pesos “no sumen 1” por residuo, o desalinear compras y ventas en centavos.

`BigDecimal` aporta aritmética decimal controlada y redondeo explícito (4 decimales en títulos, 2 en importe).

**Alternativa habitual:** enteros en centavos (`260000` = $2600.00). También evita `Float`. Aquí preferimos `BigDecimal` porque el dominio mezcla precios, fracciones de acción y pesos, y el código queda más legible.

## Ejemplos

Para ver varios escenarios de rebalanceo en consola:

```bash
ruby examples/rebalance_demo.rb
```

## Pruebas

```bash
bundle exec rspec
```

## Escalabilidad futura

Esta versión es deliberadamente pequeña. Posibles extensiones:

- **Servicio de cotizaciones**: arma el `Hash` de precios y lo pasa a `rebalance`.
- **Ejecutor de órdenes**: consume `:sells` y `:buys` para enviar operaciones al broker.
- **Clase `Trade`**: objeto con `symbol`, `action` (`:sell` / `:buy`), `shares` y `amount` que sustituya a los hashes de orden cuando el ejecutador necesite un tipo propio.
- **Caja, comisiones y lotes enteros**: no entran aquí; el efectivo implícito es cero porque las ponderaciones suman `1`. Con lotes enteros, `SHARE_SCALE` pasaría a `0`.
