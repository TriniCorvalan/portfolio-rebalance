# frozen_string_literal: true

require "spec_helper"

RSpec.describe Portfolio do
  def stock(symbol, shares)
    Stock.new(symbol: symbol, shares: shares)
  end

  describe "validaciones" do
    it "rechaza símbolos duplicados en holdings" do
      expect do
        described_class.new(
          holdings: [stock("META", 1), stock("META", 2)],
          allocated: { "META" => 1 }
        )
      end.to raise_error(ArgumentError, /duplicate symbols in holdings/)
    end

    it "rechaza ponderaciones que no suman 1" do
      expect do
        described_class.new(
          holdings: [stock("META", 1)],
          allocated: { "META" => 0.4, "AAPL" => 0.4 }
        )
      end.to raise_error(ArgumentError, /allocated weights must sum to 1/)
    end

    it "rechaza allocated que no es un Hash" do
      expect do
        described_class.new(
          holdings: [stock("META", 1)],
          allocated: [["META", 1]]
        )
      end.to raise_error(ArgumentError, /allocated must be a Hash/)
    end
  end

  describe "#rebalance" do
    it "no emite órdenes cuando la cartera ya está equilibrada" do
      # META 4*500=2000, AAPL 15*200=3000 → total 5000 → 40/60
      portfolio = described_class.new(
        holdings: [stock("META", 4), stock("AAPL", 15)],
        allocated: { "META" => 0.4, "AAPL" => 0.6 }
      )

      result = portfolio.rebalance("META" => 500, "AAPL" => 200)

      expect(result[:sells]).to eq([])
      expect(result[:buys]).to eq([])
    end

    it "vende lo sobreponderado y compra lo infraponderado (40/60)" do
      # Valor total: 10*500 + 5*200 = 6000
      # META objetivo 2400 (actual 5000) → vender 2600 / 500 = 5.2
      # AAPL objetivo 3600 (actual 1000) → comprar 2600 / 200 = 13
      portfolio = described_class.new(
        holdings: [stock("META", 10), stock("AAPL", 5)],
        allocated: { "META" => 0.4, "AAPL" => 0.6 }
      )

      result = portfolio.rebalance("META" => 500, "AAPL" => 200)

      expect(result[:sells]).to contain_exactly(
        hash_including(
          symbol: "META",
          shares: BigDecimal("5.2"),
          amount: BigDecimal("2600.00")
        )
      )
      expect(result[:buys]).to contain_exactly(
        hash_including(
          symbol: "AAPL",
          shares: BigDecimal("13"),
          amount: BigDecimal("2600.00")
        )
      )
    end

    it "vende por completo un símbolo que no está en allocated" do
      portfolio = described_class.new(
        holdings: [stock("META", 10), stock("AAPL", 5), stock("TSLA", 2)],
        allocated: { "META" => 0.4, "AAPL" => 0.6 }
      )

      result = portfolio.rebalance("META" => 500, "AAPL" => 200, "TSLA" => 250)

      tsla_sell = result[:sells].find { |order| order[:symbol] == "TSLA" }
      expect(tsla_sell[:shares]).to eq(BigDecimal("2"))
      expect(tsla_sell[:amount]).to eq(BigDecimal("500.00"))
    end

    it "compra un símbolo objetivo ausente en holdings" do
      portfolio = described_class.new(
        holdings: [stock("META", 10)],
        allocated: { "META" => 0.4, "AAPL" => 0.6 }
      )

      result = portfolio.rebalance("META" => 500, "AAPL" => 200)

      # Valor total 5000 → AAPL objetivo 3000 → comprar 15
      expect(result[:buys]).to contain_exactly(
        hash_including(
          symbol: "AAPL",
          shares: BigDecimal("15"),
          amount: BigDecimal("3000.00")
        )
      )
      expect(result[:sells]).to contain_exactly(
        hash_including(
          symbol: "META",
          shares: BigDecimal("6"),
          amount: BigDecimal("3000.00")
        )
      )
    end

    it "exige precios para todos los símbolos involucrados" do
      portfolio = described_class.new(
        holdings: [stock("META", 10), stock("AAPL", 5)],
        allocated: { "META" => 0.4, "AAPL" => 0.6 }
      )

      expect do
        portfolio.rebalance("META" => 500)
      end.to raise_error(ArgumentError, /missing prices for: AAPL/)
    end

    it "rechaza precios no positivos" do
      portfolio = described_class.new(
        holdings: [stock("META", 10)],
        allocated: { "META" => 1 }
      )

      expect do
        portfolio.rebalance("META" => 0)
      end.to raise_error(ArgumentError, /price must be positive/)
    end
  end
end
