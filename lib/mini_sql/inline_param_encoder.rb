# frozen_string_literal: true

module MiniSql
  class InlineParamEncoder
    attr_reader :conn, :array_encoder

    def initialize(conn, array_encoder = nil)
      @conn = conn
      @array_encoder = array_encoder
    end

    def encode(sql, *params)
      if Hash === (hash = params[0])
        raise ArgumentError, "Only one hash param is allowed, multiple were sent" if params.length > 1
        encode_hash(sql, hash)
      else
        encode_array(sql, params)
      end
    end

    def encode_hash(sql, hash)
      sql = sql.dup

      # longest key first for gsub to work
      # in an expected way
      hash.sort do |(k, _), (k1, _)|
        k1.to_s.length <=> k.to_s.length
      end.each do |k, v|
        sql.gsub!(":#{k}") do
          # ignore ::int and stuff like that
          # $` is previous to match
          if $` && $`[-1] != ":"
            quote_val(v)
          else
            ":#{k}"
          end
        end
      end
      sql
    end

    def encode_array(sql, array)
      i = -1
      sql.gsub("?") do
        i += 1
        quote_val(array[i])
      end
    end

    def quoted_time(value)
      value.utc.iso8601
    end

    def quoted_native_array(arr)
      array_encoder.encode(arr.map { |v| v.is_a?(String) ? conn.escape_string(v) : v }, Encoding::UTF_8)
    end

    EMPTY_ARRAY = [].freeze

    def quote_val(value)
      case value
      when String       then "'#{conn.escape_string(value.to_s)}'"
      when Numeric      then value.to_s
      when BigDecimal   then value.to_s("F")
      when Time         then "'#{quoted_time(value)}'"
      when Date         then "'#{value.to_s}'"
      when Symbol       then "'#{conn.escape_string(value.to_s)}'"
      when true         then "true"
      when false        then "false"
      when nil          then "NULL"
      when EMPTY_ARRAY  then array_encoder ? "'{}'" : "NULL"
      when Array        then array_encoder ? "'#{quoted_native_array(value)}'" : value.map { |v| quote_val(v) }.join(', ')
      else raise TypeError, "can't quote #{value.class.name}"
      end
    end
  end
end
