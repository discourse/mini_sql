module MiniSql
  module Postgres
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

      class TimestampUtc < PG::SimpleDecoder
        # exact same implementation as Rails here
        ISO_DATETIME = /\A(\d{4})-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)(\.\d+)?\z/

        def decode(string, tuple = nil, field = nil)
          if string =~ ISO_DATETIME
            microsec = ($7.to_r * 1_000_000).to_i
            Time.utc $1.to_i, $2.to_i, $3.to_i, $4.to_i, $5.to_i, $6.to_i, microsec
          else
            STDERR.puts "unexpected date time format #{string}"
            string
          end
        end
      end
    end
  end
end
