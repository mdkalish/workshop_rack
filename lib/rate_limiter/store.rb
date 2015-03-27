class Store
  def initialize
    @store = {}
  end

  def get(key)
    @store[key].dup if @store.key?(key)
  end

  def set(key, value)
    @store[key] = value
  end
end
