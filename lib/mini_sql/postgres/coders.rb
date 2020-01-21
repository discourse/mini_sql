# frozen_string_literal: true

module MiniSql
  module Postgres
    module Coders
      class NumericCoder < PG::SimpleDecoder
        def decode(string, _tuple = nil, _field = nil)
          BigDecimal(string)
        end
      end

      class IPAddrCoder < PG::SimpleDecoder
        def decode(string, _tuple = nil, _field = nil)
          IPAddr.new(string)
        end
      end

      class TimestampUtc < PG::SimpleDecoder
        # exact same implementation as Rails here
        ISO_DATETIME = /\A(\d{4})-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)(\.\d+)?\z/.freeze

        def decode(string, _tuple = nil, _field = nil)
          if string =~ ISO_DATETIME
            microsec = (Regexp.last_match(7).to_r * 1_000_000).to_i
            Time.utc Regexp.last_match(1).to_i, Regexp.last_match(2).to_i, Regexp.last_match(3).to_i, Regexp.last_match(4).to_i, Regexp.last_match(5).to_i, Regexp.last_match(6).to_i, microsec
          else
            warn "unexpected date time format #{string}"
            string
          end
        end
      end
    end
  end
end
