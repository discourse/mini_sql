# frozen_string_literal: true

module MiniSql
  module Abstract
    class PreparedCache

      DEFAULT_MAX_SIZE = 500

      def initialize(connection, max_size = nil)
        @connection = connection
        @max_size = max_size || DEFAULT_MAX_SIZE
        @cache = {}
        @counter = 0
      end

      def prepare_statement(sql)
        stm_key = "#{raw_connection.object_id}-#{sql}"
        statement = @cache.delete(stm_key)
        if statement
          @cache[stm_key] = statement
        else
          statement = @cache[stm_key] = alloc(sql)
          dealloc(@cache.shift.last) if @cache.length > @max_size
        end

        statement
      end

      private

      def raw_connection
        @connection.raw_connection
      end

      def next_key
        "s#{@counter += 1}"
      end

      def alloc(_)
        raise NotImplementedError, "must be implemented by specific database driver"
      end

      def dealloc(_)
        raise NotImplementedError, "must be implemented by specific database driver"
      end

    end
  end
end
