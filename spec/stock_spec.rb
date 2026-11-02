# frozen_string_literal: true

require "spec_helper"

RSpec.describe Stock do
  describe "#initialize" do
    it "normaliza el símbolo a mayúsculas y guarda shares como BigDecimal" do
      stock = described_class.new(symbol: "meta", shares: 10)

      expect(stock.symbol).to eq("META")
      expect(stock.shares).to eq(BigDecimal("10"))
    end

    it "permite cero acciones" do
      stock = described_class.new(symbol: "AAPL", shares: 0)

      expect(stock.shares).to eq(BigDecimal("0"))
    end

    it "rechaza acciones negativas" do
      expect do
        described_class.new(symbol: "AAPL", shares: -1)
      end.to raise_error(ArgumentError, /shares must be greater than or equal to 0/)
    end

    it "rechaza símbolo vacío" do
      expect do
        described_class.new(symbol: "", shares: 1)
      end.to raise_error(ArgumentError, /symbol is required/)
    end
  end

  describe "#current_price" do
    let(:stock) { described_class.new(symbol: "META", shares: 2) }

    it "guarda y devuelve el último precio recibido" do
      expect(stock.current_price(500)).to eq(BigDecimal("500"))
      expect(stock.current_price).to eq(BigDecimal("500"))
    end

    it "rechaza precios no positivos" do
      expect { stock.current_price(0) }.to raise_error(ArgumentError, /price must be positive/)
    end
  end

  describe "#market_value" do
    it "multiplica títulos por precio" do
      stock = described_class.new(symbol: "META", shares: 10)
      stock.current_price(500)

      expect(stock.market_value).to eq(BigDecimal("5000"))
    end

    it "exige precio previo" do
      stock = described_class.new(symbol: "META", shares: 10)

      expect { stock.market_value }.to raise_error(ArgumentError, /price is required/)
    end
  end
end
