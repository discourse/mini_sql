class MiniSql::Builder

  def initialize(connection, template)
    @args = nil
    @sql = template
    @sections = {}
    @connection = connection
  end

  [:set, :where2, :where, :order_by, :limit, :left_join, :join, :offset, :select].each do |k|
    define_method k do |data, args = {}|
      @args ||= {}
      @args.merge!(args)
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
        joined = "SELECT " << v.join(" , ")
      when :where, :where2
        joined = "WHERE " << v.map { |c| "(" << c << ")" }.join(" AND ")
      when :join
        joined = v.map { |item| "JOIN " << item }.join("\n")
      when :left_join
        joined = v.map { |item| "LEFT JOIN " << item }.join("\n")
      when :limit
        joined = "LIMIT " << v.last.to_i.to_s
      when :offset
        joined = "OFFSET " << v.last.to_i.to_s
      when :order_by
        joined = "ORDER BY " << v.join(" , ")
      when :set
        joined = "SET " << v.join(" , ")
      end

      sql.sub!("/*#{k}*/", joined)
    end
    sql
  end

  def query(args = nil)
    if args
      @args.merge!(args)
    end
    sql = to_sql
    @connection.query(sql, @args)
  end

  def exec(args = nil)
    if args
      @args.merge!(args)
    end
    sql = to_sql
    @connection.exec(sql, @args)
  end

end

