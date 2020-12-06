# frozen_string_literal: true

module MiniSql
  class Result < Array
    attr_reader :decorator_module

    def initialize(decorator_module = nil)
      @decorator_module = decorator_module
    end

    def marshal_dump
      [
        first.to_h.keys,
        map { |row| row.to_h.values },
        decorator_module,
      ]
    end

    def marshal_load(args)
      fields, values_rows, decorator_module = args

      @decorator_module = decorator_module

      materializer = MiniSql::Matrializer.build(fields)
      materializer.include(decorator_module) if decorator_module

      values_rows.each do |row_result|
        r = materializer.new
        fields.each_with_index do |f, col|
          r.instance_variable_set(:"@#{f}", row_result[col])
        end
        self << r
      end

      self
    end

  end
end
