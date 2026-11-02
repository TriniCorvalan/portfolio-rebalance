# frozen_string_literal: true

require "bigdecimal"
require "bigdecimal/util"
require_relative "stock"

# Cartera con posiciones actuales (holdings) y distribución objetivo (allocated).
class Portfolio
  SHARE_SCALE = 4
  MIN_ORDER_AMOUNT = BigDecimal("0.01")
  WEIGHT_TOLERANCE = BigDecimal("0.0001")

  attr_reader :holdings, :allocated

  def initialize(holdings:, allocated:)
    @holdings = Array(holdings)
    @allocated = normalize_allocated(allocated)
    validate!
  end

  # Calcula ventas y compras para acercar la cartera a la asignación objetivo.
  # +prices+ es un Hash símbolo → precio; no consulta ningún mercado.
  #
  # Devuelve { sells: [...], buys: [...] } donde cada orden es
  # { symbol:, shares:, amount: }.
  def rebalance(prices)
    prices = normalize_prices(prices)
    apply_prices!(prices)

    current_values = current_values_by_symbol
    total_value = current_values.values.sum(BigDecimal("0"))
    return empty_result if total_value.zero?

    symbols = (current_values.keys + allocated.keys).uniq

    sells = []
    buys = []

    symbols.each do |symbol|
      price = prices.fetch(symbol)
      current_value = current_values.fetch(symbol, BigDecimal("0"))
      target_value = total_value * allocated.fetch(symbol, BigDecimal("0"))
      delta = target_value - current_value

      next if delta.abs < MIN_ORDER_AMOUNT

      shares = (delta.abs / price).round(SHARE_SCALE)
      amount = (shares * price).round(2)
      next if amount < MIN_ORDER_AMOUNT

      order = { symbol: symbol, shares: shares, amount: amount }
      if delta.negative?
        sells << order
      else
        buys << order
      end
    end

    { sells: sells, buys: buys }
  end

  private

  def normalize_allocated(allocated)
    raise ArgumentError, "allocated must be a Hash" unless allocated.is_a?(Hash)

    allocated.each_with_object({}) do |(symbol, weight), normalized|
      key = symbol.to_s.upcase
      value = BigDecimal(weight.to_s)
      raise ArgumentError, "weight must be positive for #{key}" unless value.positive?
      raise ArgumentError, "duplicate symbol in allocated: #{key}" if normalized.key?(key)

      normalized[key] = value
    end
  end

  def validate!
    raise ArgumentError, "allocated cannot be empty" if allocated.empty?

    symbols = holdings.map(&:symbol)
    duplicates = symbols.group_by(&:itself).select { |_, list| list.size > 1 }.keys
    unless duplicates.empty?
      raise ArgumentError, "duplicate symbols in holdings: #{duplicates.join(", ")}"
    end

    total = allocated.values.sum(BigDecimal("0"))
    return if (total - BigDecimal("1")).abs <= WEIGHT_TOLERANCE

    raise ArgumentError, "allocated weights must sum to 1 (got #{total})"
  end

  def normalize_prices(prices)
    raise ArgumentError, "prices must be a Hash" unless prices.is_a?(Hash)

    prices.each_with_object({}) do |(symbol, price), normalized|
      key = symbol.to_s.upcase
      value = BigDecimal(price.to_s)
      raise ArgumentError, "price must be positive for #{key}" unless value.positive?

      normalized[key] = value
    end
  end

  def apply_prices!(prices)
    required_symbols = (holdings.map(&:symbol) + allocated.keys).uniq
    missing = required_symbols - prices.keys
    unless missing.empty?
      raise ArgumentError, "missing prices for: #{missing.join(", ")}"
    end

    holdings.each do |stock|
      stock.current_price(prices.fetch(stock.symbol))
    end
  end

  def current_values_by_symbol
    holdings.each_with_object({}) do |stock, values|
      values[stock.symbol] = stock.market_value
    end
  end

  def empty_result
    { sells: [], buys: [] }
  end
end
