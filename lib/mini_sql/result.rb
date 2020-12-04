# frozen_string_literal: true

module MiniSql
  class Result < Array
    attr_reader :decorator_module, :deserializer_class

    def initialize(deserializer_class:, decorator_module: nil)
      @deserializer_class = deserializer_class
      @decorator_module = decorator_module
    end

    def marshal_dump
      {
        deserializer_class: deserializer_class,
        values_rows: map { |row| row.to_h.values },
        fields: first.to_h.keys,
        decorator_module: decorator_module,
      }
    end

    def marshal_load(deserializer_class:, values_rows:, fields:, decorator_module:)
      @deserializer_class = deserializer_class
      @decorator_module = decorator_module

      materializer = deserializer_class.new_row_matrializer(fields: fields)
      materializer.include(decorator_module) if decorator_module

      values_rows.each do |row_result|
        r = materializer.new
        fields.each_with_index do |f, col|
          r.public_send("#{f}=", row_result[col])
        end
        self << r
      end

      self
    end

  end
end
