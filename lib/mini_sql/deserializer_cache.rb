module MiniSql
  class DeserializerCache

    DEFAULT_MAX_SIZE = 500

    def initialize(max_size = nil)
      @cache = {}
      @max_size = max_size || DEFAULT_MAX_SIZE
    end

    def materialize(result)

      return [] if result.ntuples == 0

      key = result.fields

      # trivial fast LRU implementation
      materializer = @cache.delete(key)
      if materializer
        @cache[key] = materializer
      else
        materializer = @cache[key] = new_row_matrializer(result)
        @cache.shift if @cache.length > @max_size
      end

      i = 0
      r = []
      # quicker loop
      while i < result.ntuples
        r << materializer.materialize(result, i)
        i += 1
      end
      r
    end

    private

    def new_row_matrializer(result)
      fields = result.fields

      Class.new do
        attr_accessor(*fields)
        alias :read_attribute_for_serialization :send

        instance_eval <<~RUBY
        def materialize(pg_result, index)
          r = self.new
          #{col=-1; fields.map{|f| "r.#{f} = pg_result.getvalue(index, #{col+=1})"}.join("; ")}
          r
        end
        RUBY
      end
    end
  end
end
