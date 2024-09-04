require 'firm'

module SerializerTestMixin

  class PropTest

    include FIRM::Serializable

    property :prop_a
    property prop_b: ->(obj, *val) { obj.instance_variable_set(:@prop_b, val.first) unless val.empty?; obj.instance_variable_get(:@prop_b) }
    property prop_c: :serialize_prop_c
    property(:prop_d, :prop_e) do |id, obj, *val|
      case id
      when :prop_d
        obj.instance_variable_set('@prop_d', val.first) unless val.empty?
        obj.instance_variable_get('@prop_d')
      when :prop_e
        obj.instance_variable_set('@prop_e', val.first) unless val.empty?
        obj.instance_variable_get('@prop_e')
      end
    end
    property :prop_f, :prop_g, handler: :serialize_props_f_and_g

    def initialize
      @prop_a = 'string'
      @prop_b = 123
      @prop_c = :symbol
      @prop_d = 100.123
      @prop_e = [1,2,3]
      @prop_f = {_1: 1, _2: 2, _3: 3}
      @prop_g = 1..10
    end

    attr_accessor :prop_a

    def serialize_prop_c(*val)
      @prop_c = val.first unless val.empty?
      @prop_c
    end
    private :serialize_prop_c

    def serialize_props_f_and_g(id, *val)
      case id
      when :prop_f
        @prop_f = val.shift unless val.empty?
        @prop_f
      when :prop_g
        @prop_g = val.shift unless val.empty?
        @prop_g
      end
    end

    def ==(other)
      self.class === other &&
        @prop_a == other.prop_a &&
        @prop_b == other.instance_variable_get('@prop_b') &&
        @prop_c == other.instance_variable_get('@prop_c') &&
        @prop_d == other.instance_variable_get('@prop_d') &&
        @prop_e == other.instance_variable_get('@prop_e') &&
        @prop_g == other.instance_variable_get('@prop_g') &&
        @prop_f == other.instance_variable_get('@prop_f')
    end
  end

  def test_properties
    obj = PropTest.new
    obj_serial = obj.serialize
    obj_new = nil
    assert_nothing_raised { obj_new = FIRM::Serializable.deserialize(obj_serial) }
    assert_instance_of(PropTest, obj_new)
    assert_equal(obj, obj_new)
  end

  class Point

    include Comparable

    include FIRM::Serializable

    properties :x, :y

    def initialize(*args)
      if args.empty?
        @x = @y = 0
      else
        @x, @y = *args
      end
    end

    attr_accessor :x, :y

    def <=>(other)
      if other.is_a?(self.class)
        if @x == other.x
          @y <=> other.y
        else
          @x <=> other.x
        end
      else
        nil
      end
    end

    def eql?(other)
      other.is_a?(self.class) ? @x.eql?(other.x) && @y.eql?(other.y) : false
    end

    def hash
      "#{@x}x#{@y}".hash
    end

  end

  class Rect

    include FIRM::Serializable

    properties :x, :y, :width, :height

    def initialize(x, y, w, h)
      @x = x
      @y = y
      @width = w
      @height = h
    end

    attr_reader :x, :y, :width, :height

    def ==(other)
      if other.is_a?(self.class)
        @x == other.x && @y == other.y && @width == other.width && @height == other.height
      else
        false
      end
    end

    # Noop
    # @param [Hash] _hash ignored
    # @return [self]
    def from_serialized(_hash)
      # no deserializing necessary
      self
    end
    protected :from_serialized

    def self.create_for_deserialize(data)
      self.new(data[:x], data[:y], data[:width], data[:height])
    end

  end

  class Colour

    include FIRM::Serializable

    property :colour => ->(col, *val) { col.set(*val.first) unless val.empty?; [col.red, col.green, col.blue, col.alpha] }

    def initialize(*args)
      if args.empty?
        @red, @green, @blue, @alpha = *args
        @alpha ||= 255
      else
        @red = @green = @blue = 0
        @alpha = 255
      end
    end

    def set(r, g, b, a)
      @red = r
      @green = g
      @blue = b
      @alpha = a
    end

    attr_reader :red, :green, :blue, :alpha

    def ==(other)
      if other.is_a?(self.class)
        @red == other.red && @green == other.green && @blue == other.blue
      else
        false
      end
    end

  end

  def test_data
    obj = Point.new(10, 90)
    obj_serial = obj.serialize
    obj_new = nil
    assert_nothing_raised { obj_new = FIRM::Serializable.deserialize(obj_serial) }
    assert_instance_of(Point, obj_new)
    assert_equal(obj, obj_new)

    obj = Rect.new(10, 20, 100, 900)
    obj_serial = obj.serialize
    assert_nothing_raised { obj_new = FIRM::Serializable.deserialize(obj_serial) }
    assert_instance_of(Rect, obj_new)
    assert_equal(obj, obj_new)

    obj = Colour.new('red')
    obj_serial = obj.serialize
    assert_nothing_raised { obj_new = FIRM::Serializable.deserialize(obj_serial) }
    assert_instance_of(Colour, obj_new)
    assert_equal(obj, obj_new)
  end

  def test_core
    obj = [Point.new(10, 90), Point.new(20, 80)]
    obj_serial = obj.serialize
    obj_new = nil
    assert_nothing_raised { obj_new = FIRM::Serializable.deserialize(obj_serial) }
    assert_equal(obj, obj_new)

    obj = { '1' => Point.new(10, 90), '2' => Point.new(20, 80) }
    obj_serial = obj.serialize
    assert_nothing_raised { obj_new = FIRM::Serializable.deserialize(obj_serial) }
    assert_equal(obj, obj_new)

    Struct.new('MyStruct', :one, :two) unless defined? Struct::MyStruct
    obj = Struct::MyStruct.new(one: Point.new(10, 90), two: Point.new(20, 80))
    obj_serial = obj.serialize
    assert_nothing_raised { obj_new = FIRM::Serializable.deserialize(obj_serial) }
    assert_equal(obj, obj_new)

    obj = ::Set.new(%i[one two three])
    obj_serial = obj.serialize
    assert_nothing_raised { obj_new = FIRM::Serializable.deserialize(obj_serial) }
    assert_equal(obj, obj_new)

    obj = OpenStruct.new(one: Point.new(10, 90), two: Point.new(20, 80))
    obj_serial = obj.serialize
    assert_nothing_raised { obj_new = FIRM::Serializable.deserialize(obj_serial) }
    assert_equal(obj, obj_new)

    obj = [1, nil, 2]
    obj_serial = obj.serialize
    assert_nothing_raised { obj_new = FIRM::Serializable.deserialize(obj_serial) }
    assert_equal(obj, obj_new)
  end

  class PointsOwner
    include FIRM::Serializable

    property :points

    def initialize(points = [])
      @points = points
    end

    attr_accessor :points

    def ==(other)
      self.class === other && @points == other.points
    end
  end

  def test_composition
    obj = PointsOwner.new([Point.new(10, 90), Point.new(20, 80)])
    obj_serial = obj.serialize
    obj_new = nil
    assert_nothing_raised { obj_new = FIRM::Serializable.deserialize(obj_serial) }
    assert_equal(obj, obj_new)
  end

  class SerializedBase
    include FIRM::Serializable

    property :a
    property :b
    property :c

    def initialize(a=nil, b=nil, c=nil)
      @a = a
      @b = b
      @c = c
    end

    attr_accessor :a, :b, :c

    def ==(other)
      self.class === other && self.a == other.a && self.b == other.b && self.c == other.c
    end
  end

  class SerializedDerived < SerializedBase
    contains :d
    excludes :c

    def initialize(a=nil, b=nil, d=nil)
      super(a, b)
      @d = d
      self.c = 'FIXED'
    end

    attr_accessor :d

    def ==(other)
      super && self.d == other.d
    end
  end

  def test_exclusion
    obj = SerializedBase.new(1, :hello, 'World')
    obj_serial = obj.serialize
    obj_new = nil
    assert_nothing_raised { obj_new = FIRM::Serializable.deserialize(obj_serial) }
    assert_equal(obj, obj_new)

    obj = SerializedDerived.new(2, :derived, 103.50)
    obj_serial = obj.serialize
    assert_nothing_raised { obj_new = FIRM::Serializable.deserialize(obj_serial) }
    assert_equal(obj, obj_new)
  end

  class SerializedBase2
    include FIRM::Serializable

    property :list

    def initialize(list = [])
      @list = list
    end

    attr_reader :list

    def set_list(list)
      @list.insert(0, *(list || []))
    end
    private :set_list

    def ==(other)
      self.class === other && self.list == other.list
    end
  end

  class SerializedDerived2 < SerializedBase2

    def initialize(list = [])
      super
      @fixed_item = Point.new(30, 30)
      @fixed_item.disable_serialize
      self.list << @fixed_item
    end

  end

  class SerializedDerived2_1 < SerializedBase2
    property :extra_item, force: true

    def initialize(list = [], extra = nil)
      super(list)
      set_extra_item(extra)
    end

    attr_reader :extra_item

    def set_extra_item(extra)
      @extra_item = extra
      if @extra_item
        @extra_item.disable_serialize
        list << @extra_item
      end
    end
    private :set_extra_item

    def ==(other)
      super(other) && @extra_item == other.extra_item
    end
  end

  class SerializedBase3
    include FIRM::Serializable

    property :list

    def initialize(list = ::Set.new)
      @list = ::Set === list ? list : ::Set.new(list)
    end

    attr_reader :list

    def set_list(list)
      @list.merge(list || [])
    end
    private :set_list

    def ==(other)
      self.class === other && self.list == other.list
    end
  end

  class SerializedDerived3 < SerializedBase3

    def initialize(list = [])
      super
      @fixed_item = Point.new(30, 30)
      @fixed_item.disable_serialize
      self.list << @fixed_item
    end

  end

  def test_disable
    obj = SerializedBase2.new([Point.new(1,1), Point.new(2,2), Point.new(3,3)])
    obj_serial = obj.serialize
    obj_new = nil
    assert_nothing_raised { obj_new = FIRM::Serializable.deserialize(obj_serial) }
    assert_equal(obj, obj_new)

    obj = SerializedDerived2.new([Point.new(1,1), Point.new(2,2), Point.new(3,3)])
    obj_serial = obj.serialize
    assert_nothing_raised { obj_new = FIRM::Serializable.deserialize(obj_serial) }
    assert_equal(obj, obj_new)

    obj = SerializedDerived2_1.new([Point.new(1,1), Point.new(2,2), Point.new(3,3)], Rect.new(1, 1, 40, 40))
    obj_serial = obj.serialize
    assert_nothing_raised { obj_new = FIRM::Serializable.deserialize(obj_serial) }
    assert_equal(obj, obj_new)

    obj = SerializedDerived3.new([Point.new(1,1), Point.new(2,2), Point.new(3,3)])
    obj_serial = obj.serialize
    assert_nothing_raised { obj_new = FIRM::Serializable.deserialize(obj_serial) }
    assert_equal(obj, obj_new)
  end

  class Identifiable
    include FIRM::Serializable

    property :id, :sym

    def initialize(sym = nil)
      @id = sym ? FIRM::Serializable::ID.new : nil
      @sym = sym
    end

    attr_accessor :sym
    attr_reader :id

    def set_id(id)
      @id = id
    end
    private :set_id
  end

  class Container
    include FIRM::Serializable

    property :map

    def initialize(map = {})
      @map = map
    end

    attr_reader :map

    def set_map(map)
      @map.replace(map)
    end
    private :set_map
  end

  class RefUser
    include FIRM::Serializable

    property :ref1, :ref2, :ref3

    def initialize(*rids)
      @ref1, @ref2, @ref3 = *rids
    end

    attr_accessor :ref1, :ref2, :ref3
  end

  def test_ids
    container = Container.new
    id_obj = Identifiable.new(:one)
    container.map[id_obj.id] = id_obj
    id_obj = Identifiable.new(:two)
    container.map[id_obj.id] = id_obj
    id_obj = Identifiable.new(:three)
    container.map[id_obj.id] = id_obj
    ref_obj = RefUser.new(*container.map.keys)
    obj_serial = [container, ref_obj].serialize
    obj_new = nil
    assert_nothing_raised { obj_new = FIRM::Serializable.deserialize(obj_serial) }
    assert_instance_of(Array, obj_new)
    assert_instance_of(Container, obj_new.first)
    assert_instance_of(RefUser, obj_new.last)
    assert_instance_of(FIRM::Serializable::ID, obj_new.last.ref1)
    assert_instance_of(FIRM::Serializable::ID, obj_new.last.ref2)
    assert_instance_of(FIRM::Serializable::ID, obj_new.last.ref3)
    assert_equal(:one, obj_new.first.map[obj_new.last.ref1].sym)
    assert_equal(:two, obj_new.first.map[obj_new.last.ref2].sym)
    assert_equal(:three, obj_new.first.map[obj_new.last.ref3].sym)
  end

  class Aliasable
    include FIRM::Serializable

    property :name, :description

    allow_aliases

    def initialize(*args)
      @name, @description = *args
    end

    attr_accessor :name, :description
  end

  class DerivedAliasable < Aliasable

    property :extra

    def initialize(*args)
      @extra = args.pop if args.size>2
      super
    end

    attr_accessor :extra

  end

  def test_aliases
    container = Container.new
    container.map[:one] = Aliasable.new('one', 'First aliasable')
    container.map[:two] = Aliasable.new('two', 'Second aliasable')
    container.map[:three] = container.map[:one]
    container.map[:four] = container.map[:two]
    container.map[:five] = DerivedAliasable.new('three', 'Third aliasable', 'Derived aliasable')
    container.map[:six] = container.map[:five]
    obj_serial = container.serialize
    obj_new = nil
    assert_nothing_raised { obj_new = FIRM::Serializable.deserialize(obj_serial) }
    assert_instance_of(Container, obj_new)
    assert_instance_of(Aliasable, obj_new.map[:one])
    assert_instance_of(Aliasable, obj_new.map[:two])
    assert_instance_of(Aliasable, obj_new.map[:three])
    assert_equal(obj_new.map[:one].object_id, obj_new.map[:three].object_id)
    assert_instance_of(Aliasable, obj_new.map[:four])
    assert_equal(obj_new.map[:two].object_id, obj_new.map[:four].object_id)
    assert_instance_of(DerivedAliasable, obj_new.map[:five])
    assert_instance_of(DerivedAliasable, obj_new.map[:six])
    assert_equal(obj_new.map[:five].object_id, obj_new.map[:six].object_id)
  end

  def test_nested_hash_with_complex_keys
    id_obj = Identifiable.new(:one)
    id_obj2 = Identifiable.new(:two)
    h = {
      [
        { id_obj.id => id_obj }
      ] => 'one',
      [
        { id_obj2.id => id_obj2 }
      ] => 'two'
    }
    obj_serial = h.serialize
    obj_new = nil
    assert_nothing_raised { obj_new = FIRM::Serializable.deserialize(obj_serial) }
    assert_instance_of(::Hash, obj_new)
    obj_new.each_pair do |k,v|
      assert_instance_of(::Array, k)
      assert_instance_of(::String, v)
      assert_instance_of(::Hash, k.first)
      assert_instance_of(FIRM::Serializable::ID, k.first.first.first)
      assert_equal(v, k.first[k.first.first.first].sym.to_s)
    end
  end

  class NestedSerializer
    include FIRM::Serializable

    property :nested, handler: :marshall_nested

    def initialize(serializable=nil)
      @nested = serializable
    end

    attr_reader :nested

    protected

    def marshall_nested(_id, *val)
      if val.empty?
        @nested.serialize
      else
        @nested = FIRM::Serializable.deserialize(val.first)
        nil
      end
    end

  end

  def test_nested_serialize
    container = Container.new
    container.map[:one] = Aliasable.new('one', 'First aliasable')
    container.map[:two] = Aliasable.new('two', 'Second aliasable')
    container.map[:three] = container.map[:one]
    container.map[:four] = container.map[:two]
    container.map[:five] = DerivedAliasable.new('three', 'Third aliasable', 'Derived aliasable')
    container.map[:six] = container.map[:five]
    id_obj = Identifiable.new(:seven)
    container.map[id_obj.sym] = id_obj
    id_obj = Identifiable.new(:eight)
    container.map[id_obj.sym] = id_obj
    id_obj = Identifiable.new(:nine)
    container.map[id_obj.sym] = id_obj
    ref_obj = RefUser.new(container.map[:seven].id, container.map[:eight].id, container.map[:nine].id)
    container.map[:ten] = ref_obj
    nest_obj = NestedSerializer.new(container)
    obj_serial = [nest_obj, container.map[:one], container.map[:two], container.map[:five], [container.map[:three], container.map[:four], container.map[:six]], ref_obj].serialize(nil, pretty: true)
    obj_new = nil
    assert_nothing_raised { obj_new = FIRM::Serializable.deserialize(obj_serial) }
    assert_instance_of(::Array, obj_new)
    assert_instance_of(NestedSerializer, obj_new[0])
    container = obj_new[0].nested
    assert_instance_of(Container, container)
    assert_instance_of(Aliasable, container.map[:one])
    assert_instance_of(Aliasable, container.map[:two])
    assert_instance_of(Aliasable, container.map[:three])
    assert_equal(container.map[:one].object_id, container.map[:three].object_id)
    assert_instance_of(Aliasable, container.map[:four])
    assert_equal(container.map[:two].object_id, container.map[:four].object_id)
    assert_instance_of(DerivedAliasable, container.map[:five])
    assert_instance_of(DerivedAliasable, container.map[:six])
    assert_equal(container.map[:five].object_id, container.map[:six].object_id)

    assert_instance_of(RefUser, container.map[:ten])
    assert_instance_of(FIRM::Serializable::ID, container.map[:ten].ref1)
    assert_instance_of(FIRM::Serializable::ID, container.map[:ten].ref2)
    assert_instance_of(FIRM::Serializable::ID, container.map[:ten].ref3)
    assert_equal(:seven, container.map[:seven].sym)
    assert_equal(container.map[:ten].ref1, container.map[:seven].id)
    assert_equal(:eight, container.map[:eight].sym)
    assert_equal(container.map[:ten].ref2, container.map[:eight].id)
    assert_equal(:nine, container.map[:nine].sym)
    assert_equal(container.map[:ten].ref3, container.map[:nine].id)

    assert_instance_of(Aliasable, obj_new[1])
    assert_instance_of(Aliasable, obj_new[2])
    assert_instance_of(DerivedAliasable, obj_new[3])
    assert_instance_of(::Array, obj_new[4])
    assert_instance_of(Aliasable, obj_new[4][0])
    assert_instance_of(Aliasable, obj_new[4][1])
    assert_instance_of(DerivedAliasable, obj_new[4][2])
    assert_equal(obj_new[1].object_id, obj_new[4][0].object_id)
    assert_equal(obj_new[2].object_id, obj_new[4][1].object_id)
    assert_equal(obj_new[3].object_id, obj_new[4][2].object_id)

    assert_equal(container.map[:one].name, obj_new[4][0].name)
    assert_not_equal(container.map[:one].object_id, obj_new[4][0].object_id)
    assert_equal(container.map[:two].name, obj_new[4][1].name)
    assert_not_equal(container.map[:two].object_id, obj_new[4][1].object_id)
    assert_equal(container.map[:five].name, obj_new[4][2].name)
    assert_not_equal(container.map[:five].object_id, obj_new[4][2].object_id)

    assert_not_equal(container.map[:ten].ref1, obj_new.last.ref1)
    assert_not_equal(container.map[:ten].ref2, obj_new.last.ref2)
    assert_not_equal(container.map[:ten].ref3, obj_new.last.ref3)
  end

end