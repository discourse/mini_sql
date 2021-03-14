# frozen_string_literal: true

module MiniSql
  module Abstract
    class PreparedBinds

      # For compatibility with Active Record
      BindName = Struct.new(:name)

      def bindinize(sql, *params)
        if Hash === (hash = params[0])
          bindinize_hash(sql, hash)
        else
          bindinize_array(sql, params)
        end
      end

      def bindinize_hash(sql, hash)
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
                bind_output(i += 1)
              end.join(', ')
            else
              ":#{k}"
            end
          end
        end
        [sql, binds, bind_names]
      end

      def bindinize_array(sql, array)
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
            bind_output(i)
          end.join(', ')
        end
        [sql, binds, bind_names]
      end

      def array_wrap(object)
        if object.respond_to?(:to_ary)
          object.to_ary || [object]
        else
          [object]
        end
      end

      def bind_output(_)
        raise NotImplementedError, "must be implemented by specific database driver"
      end

    end
  end
end
