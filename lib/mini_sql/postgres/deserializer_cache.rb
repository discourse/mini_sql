# frozen_string_literal: true

module MiniSql
  module Postgres
    class DeserializerCache

      class SerializableMaterializer < Array
        attr_accessor :materializer, :decorator_module

        def initialize(materializer:, decorator_module: nil)
          @materializer = materializer
          @decorator_module = decorator_module
        end

        def self.build_materializer(fields:)
          i = 0
          while i < fields.length
            # special handling for unamed column
            if fields[i] == "?column?"
              fields[i] = "column#{i}"
            end
            i += 1
          end

          Class.new do
            attr_accessor(*fields)

            # AM serializer support
            alias :read_attribute_for_serialization :send

            def to_h
              r = {}
              self.class.fields.each do |f|
                r[f] = instance_variable_get(:"@#{f}")
              end
              r
            end

            def values
              self.class.fields.map { |f| instance_variable_get(:"@#{f}") }
            end

            def self.materialize_serialized(row_result)
              r = self.new
              fields.each_with_index do |f, col|
                r.public_send("#{f}=", row_result[col])
              end
              r
            end

            def self.materialize(pg_result, index)
              r = self.new
              col = -1
              fields.each do |f|
                r.public_send("#{f}=", pg_result.getvalue(index, col += 1))
              end
              r
            end

            instance_eval <<~RUBY
              def fields
                #{fields.map(&:to_sym)}
              end
            RUBY
          end
        end

        def materialize(result)
          i = 0
          # quicker loop
          while i < result.ntuples
            self << materializer.materialize(result, i)
            i += 1
          end
          self
        end

        def marshal_dump
          {
            result: map(&:values),
            fields: materializer.fields,
            decorator_module: decorator_module,
          }
        end

        def marshal_load(result:, fields:, decorator_module:)
          self.materializer = SerializableMaterializer.build_materializer(fields: fields)
          self.decorator_module = decorator_module

          materializer.include(decorator_module) if decorator_module

          result.each do |row_result|
            self << materializer.materialize_serialized(row_result)
          end

          self
        end
      end

      DEFAULT_MAX_SIZE = 500

      def initialize(max_size = nil)
        @cache = {}
        @max_size = max_size || DEFAULT_MAX_SIZE
      end

      def materializer(result)
        key = result.fields

        # trivial fast LRU implementation
        materializer = @cache.delete(key)
        if materializer
          @cache[key] = materializer
        else
          materializer = @cache[key] = SerializableMaterializer.build_materializer(fields: result.fields)
          @cache.shift if @cache.length > @max_size
        end

        materializer
      end

      def materialize(result, decorator_module = nil)
        return [] if result.ntuples == 0

        cached_materializer = materializer(result)
        cached_materializer.include(decorator_module) if decorator_module

        SerializableMaterializer.new(
          materializer: cached_materializer,
          decorator_module: decorator_module
        ).materialize(result)
      end
    end

  end
end
