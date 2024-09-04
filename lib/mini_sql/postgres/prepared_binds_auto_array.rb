# frozen_string_literal: true

require "mini_sql/abstract/prepared_binds"

module MiniSql
  module Postgres
    class PreparedBindsAutoArray < ::MiniSql::Abstract::PreparedBinds

      attr_reader :array_encoder

      def initialize(array_encoder)
        @array_encoder = array_encoder
      end

      def bind_hash(sql, hash)
        sql = sql.dup
        binds = []
        bind_names = []
        i = 0

        hash.each do |k, v|
          binds << (v.is_a?(Array) ? array_encoder.encode(v) : v)
          bind_names << [BindName.new(k)]
          bind_outputs = bind_output(i += 1)

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

      def bind_array(sql, array)
        sql = sql.dup
        param_i = -1
        i = 0
        binds = []
        bind_names = []
        sql.gsub!("?") do
          v = array[param_i += 1]
          binds << (v.is_a?(Array) ? array_encoder.encode(v) : v)
          i += 1
          bind_names << [BindName.new("$#{i}")]
          bind_output(i)
        end
        [sql, binds, bind_names]
      end

      def bind_output(i)
        "$#{i}"
      end

    end
  end
end
