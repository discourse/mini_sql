module MiniSql
  class DeserializerCache
    # method takes a raw result and converts to proper objects
    def materialize(result)
      raise NotImplementedError, "must be implemented by child"
    end
  end
end
