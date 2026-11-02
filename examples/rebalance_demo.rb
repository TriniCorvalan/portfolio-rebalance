# frozen_string_literal: true

# Demostración de Portfolio#rebalance con escenarios habituales.
# Ejecutar desde la raíz del proyecto:
#   ruby examples/rebalance_demo.rb

require_relative "../lib/stock"
require_relative "../lib/portfolio"

def stock(symbol, shares)
  Stock.new(symbol: symbol, shares: shares)
end

def print_orders(label, orders)
  puts "  #{label}:"
  if orders.empty?
    puts "    (ninguna)"
    return
  end

  orders.each do |order|
    puts "    #{order[:symbol]} — #{order[:shares].to_f} títulos — $#{order[:amount].to_f}"
  end
end

def run_scenario(title, portfolio:, prices:)
  puts "=" * 60
  puts title
  puts "-" * 60

  result = portfolio.rebalance(prices)
  print_orders("Ventas", result[:sells])
  print_orders("Compras", result[:buys])
  puts
end

# 1. Rebalanceo 40/60
# Valor total: 10*500 + 5*200 = 6000
# NVDA objetivo 2400 → vender 5.2; MSFT objetivo 3600 → comprar 13
run_scenario(
  "1. Rebalanceo 40/60 (NVDA sobreponderada, MSFT infraponderada)",
  portfolio: Portfolio.new(
    holdings: [stock("NVDA", 10), stock("MSFT", 5)],
    allocated: { "NVDA" => 0.4, "MSFT" => 0.6 }
  ),
  prices: { "NVDA" => 500, "MSFT" => 200 }
)

# 2. Ya equilibrada — sin órdenes
# GOOG 4*500=2000, AMZN 15*200=3000 → total 5000 → 40/60
run_scenario(
  "2. Cartera ya equilibrada (sin órdenes)",
  portfolio: Portfolio.new(
    holdings: [stock("GOOG", 4), stock("AMZN", 15)],
    allocated: { "GOOG" => 0.4, "AMZN" => 0.6 }
  ),
  prices: { "GOOG" => 500, "AMZN" => 200 }
)

# 3. Vender símbolo fuera de allocated
run_scenario(
  "3. Liquidar símbolo ausente en allocated (NFLX)",
  portfolio: Portfolio.new(
    holdings: [stock("NVDA", 10), stock("MSFT", 5), stock("NFLX", 2)],
    allocated: { "NVDA" => 0.4, "MSFT" => 0.6 }
  ),
  prices: { "NVDA" => 500, "MSFT" => 200, "NFLX" => 250 }
)

# 4. Comprar símbolo ausente en holdings
# Valor total 5000 → TSLA objetivo 2000, AMD objetivo 3000
run_scenario(
  "4. Comprar símbolo objetivo ausente en holdings (AMD)",
  portfolio: Portfolio.new(
    holdings: [stock("TSLA", 10)],
    allocated: { "TSLA" => 0.4, "AMD" => 0.6 }
  ),
  prices: { "TSLA" => 500, "AMD" => 200 }
)

# 5. Error esperado: faltan precios
puts "=" * 60
puts "5. Validación: precios faltantes (error esperado)"
puts "-" * 60

begin
  portfolio = Portfolio.new(
    holdings: [stock("JPM", 10), stock("V", 5)],
    allocated: { "JPM" => 0.4, "V" => 0.6 }
  )
  portfolio.rebalance("JPM" => 500)
rescue ArgumentError => e
  puts "  ArgumentError: #{e.message}"
end

puts
puts "Listo."
