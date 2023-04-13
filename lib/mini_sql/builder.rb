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

  def initialize_copy(_original_builder)
    @args = @args.transform_values { |v| v.dup }
    @sections = @sections.transform_values { |v| v.dup }
  end

  literals1 =
    [:set, :where2, :where2_or, :where, :where_or, :order_by, :left_join, :join, :select, :group_by].each do |k|
      define_method k do |sql_part, *args|
        if Hash === args[0]
          @args.merge!(args[0])
        else # convert simple params to hash
          args.each do |v|
            # for compatability with AR param encoded we keep a non _
            # prefix (must be [a-z])
            param = "mq_auto_#{@count_variables += 1}"
            sql_part = sql_part.sub('?', ":#{param}")
            @args[param.to_sym] = v
          end
        end

        @sections[k] ||= []
        @sections[k] << sql_part
        self
      end
    end

  literals2 =
    [:limit, :offset].each do |k|
      define_method k do |value|
        @args["mq_auto_#{k}".to_sym] = value
        @sections[k] = true
        self
      end
    end

  PREDEFINED_SQL_LITERALS = (literals1 | literals2).to_set

  def sql_literal(literals)
    literals.each do |name, part_sql|
      if PREDEFINED_SQL_LITERALS.include?(name)
        raise "/*#{name}*/ is predefined, use method `.#{name}` instead `sql_literal`"
      end
      @sections[name] = part_sql.respond_to?(:to_sql) ? part_sql.to_sql : part_sql
    end
    self
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

  def count(field = '*')
    dup.select("count(#{field})").query_single.first
  end

  private def connection_switcher
    if @is_prepared
      @connection.prepared
    else
      @connection
    end
  end

  WHERE_SECTIONS = [%i[where where_or], %i[where2 where2_or]]
  private def parametrized_sql
    sql = @sql.dup

    WHERE_SECTIONS.each do |section_and, section_or|
      if (or_values = @sections.delete(section_or))
        @sections[section_and] ||= []
        @sections[section_and] << or_values.map { |c| "(#{c})" }.join(" OR ")
      end
    end

    @sections.each do |k, v|
      joined =
        case k
        when :select
          "SELECT #{v.join(" , ")}"
        when :where, :where2
          "WHERE #{v.map { |c| "(#{c})" }.join(" AND ")}"
        when :join
          v.map { |item| "JOIN #{item}" }.join("\n")
        when :left_join
          v.map { |item| "LEFT JOIN #{item}" }.join("\n")
        when :limit
          "LIMIT :mq_auto_limit"
        when :offset
          "OFFSET :mq_auto_offset"
        when :order_by
          "ORDER BY #{v.join(" , ")}"
        when :group_by
          "GROUP BY #{v.join(" , ")}"
        when :set
          "SET #{v.join(" , ")}"
        else # for sql_literal
          v
        end

      unless sql.sub!("/*#{k}*/", joined)
        raise "The section for the /*#{k}*/ clause was not found!"
      end
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
