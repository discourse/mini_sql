# frozen_string_literal: true

require "mini_sql/abstract/prepared_binds"

module MiniSql
  module Mysql
    class PreparedBinds < ::MiniSql::Abstract::PreparedBinds

      def bind_output(i)
        '?'
      end

    end
  end
end
