class Store
  def initialize
    @store = {}
  end

  def get(key)
    @store[key].dup if @store.key?(key)
  end

  def set(key, inner_key, value)
    @store[key] ||= {}
    @store[key][inner_key] = value
  end
end
