# frozen_string_literal: true

module MiniSql
  class Result < Array
    attr_reader :decorator_module

    def initialize(decorator_module: nil)
      @decorator_module = decorator_module
    end

    def marshal_dump
      {
        values_rows: map { |row| row.to_h.values },
        fields: first.to_h.keys,
        decorator_module: decorator_module,
      }
    end

    def marshal_load(values_rows:, fields:, decorator_module:)
      @decorator_module = decorator_module

      materializer = Matrializer.build(fields)
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
