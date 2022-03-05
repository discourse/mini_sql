# frozen_string_literal: true

require "mini_sql/abstract/prepared_binds"

module MiniSql
  module Postgres
    class PreparedBinds < ::MiniSql::Abstract::PreparedBinds

      def bind_hash(sql, hash)
        sql = sql.dup
        binds = []
        bind_names = []
        i = 0

        hash.each do |k, v|
          bind_outputs =
            array_wrap(v).map { |vv|
              binds << vv
              bind_names << [BindName.new(k)]
              bind_output(i += 1)
            }.join(', ')

          sql.gsub!(":#{k}") do
            # ignore ::int and stuff like that
            # $` is previous to match
            if $` && $`[-1] != ":"
              bind_outputs
            else
              ":#{k}"
            end
          end
        end
        [sql, binds, bind_names]
      end

      def bind_output(i)
        "$#{i}"
      end

    end
  end
end
