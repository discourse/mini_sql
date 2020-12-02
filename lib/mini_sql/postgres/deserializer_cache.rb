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
              instance_variables.each do |f|
                r[f.to_s.sub('@', '').to_sym] = instance_variable_get(f)
              end
              r
            end

            def self.materialize_hash(result_hash)
              r = self.new
              result_hash.each do |field, value|
                r.send(:"#{field}=", value)
              end
              r
            end

            instance_eval <<~RUBY
              def materialize(pg_result, index)
                r = self.new
                #{col = -1; fields.map { |f| "r.#{f} = pg_result.getvalue(index, #{col += 1})" }.join("; ")}
                r
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
            result: map(&:to_h),
            decorator_module: decorator_module,
          }
        end

        def marshal_load(result:, decorator_module:)
          materializer = SerializableMaterializer.build_materializer(fields: result[0].keys)
          materializer.include(decorator_module) if decorator_module
          result.each do |deserialized_result|
            self << materializer.materialize_hash(deserialized_result)
          end
          self.decorator_module = decorator_module
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
