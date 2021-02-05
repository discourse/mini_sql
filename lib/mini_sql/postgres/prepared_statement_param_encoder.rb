# frozen_string_literal: true

module MiniSql
  module Postgres
    module PreparedStatementParamEncoder

      BindName = Struct.new(:name)

      module_function

      def encode(sql, *params)
        if Hash === (hash = params[0])
          encode_hash(sql, hash)
        else
          encode_array(sql, params)
        end
      end

      def encode_hash(sql, hash)
        sql = sql.dup
        binds = []
        bind_names = []
        i = 0

        hash.each do |k, v|
          sql.gsub!(":#{k}") do
            # ignore ::int and stuff like that
            # $` is previous to match
            if $` && $`[-1] != ":"
              array_wrap(v).map do |vv|
                binds << vv
                bind_names << [BindName.new(k)]
                "$#{i += 1}"
              end.join(', ')
            else
              ":#{k}"
            end
          end
        end
        [sql, binds, bind_names]
      end

      def encode_array(sql, array)
        sql = sql.dup
        param_i = 0
        i = 0
        binds = []
        bind_names = []
        sql.gsub!("?") do
          param_i += 1
          array_wrap(array[param_i - 1]).map do |vv|
            binds << vv
            i += 1
            bind_names << [BindName.new("$#{i}")]
            "$#{i}"
          end.join(', ')
        end
        [sql, binds, bind_names]
      end

      def self.array_wrap(object)
        if object.respond_to?(:to_ary)
          object.to_ary || [object]
        else
          [object]
        end
      end

    end
  end
end
