# frozen_string_literal: true

require 'mini_sql'
require 'active_record'

module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapter

      # https://github.com/rails/rails/blob/master/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb#L672

      def exec_mini_sql_prepare_statement(sql, binds, bind_names)
        stmt_key = prepare_statement(sql, binds)

        log(sql, 'sql', bind_names, binds, stmt_key) do
          ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
            @connection.exec_prepared(stmt_key, binds)
          end
        end
      rescue ActiveRecord::StatementInvalid => e
        raise unless is_cached_plan_failure?(e)

        # Nothing we can do if we are in a transaction because all commands
        # will raise InFailedSQLTransaction
        if in_transaction?
          raise ActiveRecord::PreparedStatementCacheExpired.new(e.cause.message)
        else
          @lock.synchronize do
            # outside of transactions we can simply flush this query and retry
            @statements.delete sql_key(sql)
          end
          retry
        end
      end
    end
  end
end

module MiniSql
  class Postgres::Connection
    def self.instance
      new(nil)
    end

    # correct for AR connection pool
    def raw_connection
      ActiveRecord::Base.connection.raw_connection
    end

    private def run(sql, params)
      sql = param_encoder.encode(sql, *params)
      ActiveRecord::Base.connection.send(:log, sql) do
        raw_connection.async_exec(sql)
      end
    end
  end

  class Postgres::ConnectionPrepared
    private def run(sql, params)
      prepared_sql, binds, bind_names = MiniSql::Postgres::PreparedStatementParamEncoder.encode(sql, *params)
      ActiveRecord::Base.connection.exec_mini_sql_prepare_statement(prepared_sql, binds, bind_names)
    end
  end
end
