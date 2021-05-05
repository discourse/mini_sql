# frozen_string_literal: true

require 'test_helper'

# docker run -e 'ACCEPT_EULA=Y' -e 'SA_PASSWORD=yourStrong(!)Password' -e 'MSSQL_PID=Express' -p 1433:1433 mcr.microsoft.com/mssql/server:2017-latest
class MiniSql::SqlServer::TestConnection < MiniTest::Test
  def setup
    @connection = sqlserver_connection
  end

  def new_connection(opts = {})
    sqlserver_connection(opts)
  end
end
