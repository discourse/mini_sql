# frozen_string_literal: true

module MiniSql
  class InlineParamEncoder
    attr_reader :conn

    def initialize(conn)
      @conn = conn
    end

    def encode(sql, *params)
      return sql unless params && params.length > 0

      if Hash === (hash = params[0])
        raise ArgumentError, "Only one hash param is allowed, multiple were sent" if params.length > 1
        encode_hash(sql, hash)
      else
        encode_array(sql, params)
      end
    end

    def encode_hash(sql, hash)
      sql = sql.dup

      hash.each do |k, v|
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
      sql.gsub("?") do |p|
        i += 1
        quote_val(array[i])
      end
    end

    def quoted_date(value)
      value.utc.iso8601
    end

    def quote_val(value)
      case value
      when Array
        value.map do |v|
          quote_val(v)
        end.join(', ')
      when String
        "'#{conn.escape_string(value.to_s)}'"
      when true       then "true"
      when false      then "false"
      when nil        then "NULL"
      when BigDecimal then value.to_s("F")
      when Numeric then value.to_s
      when Date, Time then "'#{quoted_date(value)}'"
      when Symbol     then "'#{conn.escape_string(value.to_s)}'"
      else raise TypeError, "can't quote #{value.class.name}"
      end
    end
  end
end
