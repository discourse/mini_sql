# frozen_string_literal: true

class MiniSql::Builder

  def initialize(connection, template)
    @args = {}
    @sql = template
    @sections = {}
    @connection = connection
    @count_variables = 1
    @is_prepared = false
  end

  [:set, :where2, :where, :order_by, :left_join, :join, :select, :group_by].each do |k|
    define_method k do |sql_part, *args|
      if Hash === args[0]
        @args.merge!(args[0])
      else # convert simple params to hash
        args.each do |v|
          param = "_m_#{@count_variables += 1}"
          sql_part = sql_part.sub('?', ":#{param}")
          @args[param] = v
        end
      end

      @sections[k] ||= []
      @sections[k] << sql_part
      self
    end
  end

  [:limit, :offset].each do |k|
    define_method k do |value|
      @args["_m_#{k}"] = value
      @sections[k] = true
      self
    end
  end

  [:query, :query_single, :query_hash, :query_array, :exec].each do |m|
    class_eval <<~RUBY
      def #{m}(hash_args = nil)
        connection_switcher.#{m}(parametrized_sql, union_parameters(hash_args))
      end
    RUBY
  end

  def query_decorator(decorator, hash_args = nil)
    connection_switcher.query_decorator(decorator, parametrized_sql, union_parameters(hash_args))
  end

  def prepared(condition = true)
    @is_prepared = condition

    self
  end

  def to_sql(hash_args = nil)
    @connection.param_encoder.encode(parametrized_sql, union_parameters(hash_args))
  end

  private def connection_switcher
    if @is_prepared
      @connection.prepared
    else
      @connection
    end
  end

  private def parametrized_sql
    sql = @sql.dup

    @sections.each do |k, v|
      joined = nil
      case k
      when :select
        joined = (+"SELECT ") << v.join(" , ")
      when :where, :where2
        joined = (+"WHERE ") << v.map { |c| (+"(") << c << ")" }.join(" AND ")
      when :join
        joined = v.map { |item| (+"JOIN ") << item }.join("\n")
      when :left_join
        joined = v.map { |item| (+"LEFT JOIN ") << item }.join("\n")
      when :limit
        joined = (+"LIMIT :_m_limit")
      when :offset
        joined = (+"OFFSET :_m_offset")
      when :order_by
        joined = (+"ORDER BY ") << v.join(" , ")
      when :group_by
        joined = (+"GROUP BY ") << v.join(" , ")
      when :set
        joined = (+"SET ") << v.join(" , ")
      end

      sql.sub!("/*#{k}*/", joined)
    end

    sql
  end

  private def union_parameters(hash_args)
    if hash_args
      @args.merge(hash_args)
    else
      @args
    end
  end

end
