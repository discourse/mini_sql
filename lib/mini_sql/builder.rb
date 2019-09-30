# frozen_string_literal: true

class MiniSql::Builder

  def initialize(connection, template)
    @args = nil
    @sql = template
    @sections = {}
    @connection = connection
  end

  [:set, :where2, :where, :order_by, :limit, :left_join, :join, :offset, :select].each do |k|
    define_method k do |data, *args|
      if args && (args.length == 1) && (Hash === args[0])
        @args ||= {}
        @args.merge!(args[0])
      elsif args && args.length > 0
        data = @connection.param_encoder.encode(data, *args)
      end
      @sections[k] ||= []
      @sections[k] << data
      self
    end
  end

  def to_sql
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
        joined = (+"LIMIT ") << v.last.to_i.to_s
      when :offset
        joined = (+"OFFSET ") << v.last.to_i.to_s
      when :order_by
        joined = (+"ORDER BY ") << v.join(" , ")
      when :set
        joined = (+"SET ") << v.join(" , ")
      end

      sql.sub!("/*#{k}*/", joined)
    end
    sql
  end

  [:query, :query_single, :query_hash, :exec].each do |m|
    class_eval <<~RUBY
      def #{m}(hash_args = nil)
        hash_args = @args.merge(hash_args) if hash_args && @args
        hash_args ||= @args
        if hash_args
          @connection.#{m}(to_sql, hash_args)
        else
          @connection.#{m}(to_sql)
        end
      end
    RUBY
  end

end

