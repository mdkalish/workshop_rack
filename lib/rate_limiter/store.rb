class Store
  def initialize
    @store = {}
  end

  def get(key)
    @store[key].dup if @store.key?(key)
  end

  def set(key, value)
    @store[key] ||= {}
    @store[key][value.keys[0]] = value.values[0]
  end
end
