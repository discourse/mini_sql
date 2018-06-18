module MiniSql
  module Coders
    class NumericCoder < PG::SimpleDecoder
      def decode(string, tuple = nil, field = nil)
        BigDecimal.new(string)
      end
    end
    class IPAddrCoder < PG::SimpleDecoder
      def decode(string, tuple = nil, field = nil)
        IPAddr.new(string)
      end
    end
  end
end
