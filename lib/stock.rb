# frozen_string_literal: true

require "bigdecimal"
require "bigdecimal/util"

# Posición en cartera: un símbolo con cantidad de títulos y precio inyectado.
class Stock
  attr_reader :symbol, :shares

  def initialize(symbol:, shares:)
    @symbol = symbol.to_s.upcase
    @shares = BigDecimal(shares.to_s)
    @current_price = nil

    validate!
  end

  # Recibe el último precio disponible, lo guarda y lo devuelve.
  # Sin argumento, devuelve el precio ya recibido.
  def current_price(latest_price = nil)
    unless latest_price.nil?
      price = BigDecimal(latest_price.to_s)
      raise ArgumentError, "price must be positive for #{symbol}" unless price.positive?

      @current_price = price
    end

    @current_price
  end

  # Calcula el valor de mercado para Portfolio#rebalance
  def market_value
    raise ArgumentError, "price is required for #{symbol}" if @current_price.nil?

    shares * @current_price
  end

  private

  def validate!
    raise ArgumentError, "symbol is required" if @symbol.empty?
    raise ArgumentError, "shares must be greater than or equal to 0 for #{symbol}" if shares.negative?
  end
end
