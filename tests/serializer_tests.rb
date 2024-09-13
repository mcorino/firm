begin
  require 'bigdecimal'
rescue LoadError
end
begin
  require 'nokogiri'
rescue LoadError
end
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
    assert_nothing_raised { obj_new = FIRM.deserialize(obj_serial) }
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
    assert_nothing_raised { obj_new = FIRM.deserialize(obj_serial) }
    assert_instance_of(Point, obj_new)
    assert_equal(obj, obj_new)

    obj = Rect.new(10, 20, 100, 900)
    obj_serial = obj.serialize
    assert_nothing_raised { obj_new = FIRM.deserialize(obj_serial) }
    assert_instance_of(Rect, obj_new)
    assert_equal(obj, obj_new)

    obj = Colour.new('red')
    obj_serial = obj.serialize
    assert_nothing_raised { obj_new = FIRM.deserialize(obj_serial) }
    assert_instance_of(Colour, obj_new)
    assert_equal(obj, obj_new)
  end

  def test_core
    obj = [Point.new(10, 90), Point.new(20, 80)]
    obj_serial = obj.serialize
    obj_new = nil
    assert_nothing_raised { obj_new = FIRM.deserialize(obj_serial) }
    assert_equal(obj, obj_new)

    obj = { '1' => Point.new(10, 90), '2' => Point.new(20, 80) }
    obj_serial = obj.serialize
    assert_nothing_raised { obj_new = FIRM.deserialize(obj_serial) }
    assert_equal(obj, obj_new)

    Struct.new('MyStruct', :one, :two) unless defined? Struct::MyStruct
    obj = Struct::MyStruct.new(one: Point.new(10, 90), two: Point.new(20, 80))
    obj_serial = obj.serialize
    assert_nothing_raised { obj_new = FIRM.deserialize(obj_serial) }
    assert_equal(obj, obj_new)

    obj = ::Set.new(%i[one two three])
    obj_serial = obj.serialize
    assert_nothing_raised { obj_new = FIRM.deserialize(obj_serial) }
    assert_equal(obj, obj_new)

    obj = OpenStruct.new(one: Point.new(10, 90), two: Point.new(20, 80))
    obj_serial = obj.serialize
    assert_nothing_raised { obj_new = FIRM.deserialize(obj_serial) }
    assert_equal(obj, obj_new)

    obj = [1, nil, 2]
    obj_serial = obj.serialize
    assert_nothing_raised { obj_new = FIRM.deserialize(obj_serial) }
    assert_equal(obj, obj_new)

    obj = (0..10)
    obj_serial = obj.serialize
    assert_nothing_raised { obj_new = FIRM.deserialize(obj_serial) }
    assert_equal(obj, obj_new)

    obj = Rational(5, 3)
    obj_serial = obj.serialize
    assert_nothing_raised { obj_new = FIRM.deserialize(obj_serial) }
    assert_equal(obj, obj_new)

    obj = /\Ahello.*/i
    obj_serial = obj.serialize
    assert_nothing_raised { obj_new = FIRM.deserialize(obj_serial) }
    assert_equal(obj, obj_new)

    obj = Time.now - 999
    obj_serial = obj.serialize
    assert_nothing_raised { obj_new = FIRM.deserialize(obj_serial) }
    assert_equal(obj, obj_new)

    obj = Date.today - 33
    obj_serial = obj.serialize
    assert_nothing_raised { obj_new = FIRM.deserialize(obj_serial) }
    assert_equal(obj, obj_new)

    obj = DateTime.now
    obj_serial = obj.serialize
    assert_nothing_raised { obj_new = FIRM.deserialize(obj_serial) }
    assert_equal(obj, obj_new)

    if ::Object.const_defined?(:BigDecimal)
      obj = BigDecimal(2**64 + 0.1234, 4)
      obj_serial = obj.serialize
      assert_nothing_raised { obj_new = FIRM.deserialize(obj_serial) }
      assert_equal(obj, obj_new)
    end

    obj = Complex(0.5, 0.75)
    obj_serial = obj.serialize
    assert_nothing_raised { obj_new = FIRM.deserialize(obj_serial) }
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
    assert_nothing_raised { obj_new = FIRM.deserialize(obj_serial) }
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
    assert_nothing_raised { obj_new = FIRM.deserialize(obj_serial) }
    assert_equal(obj, obj_new)

    obj = SerializedDerived.new(2, :derived, 103.50)
    obj_serial = obj.serialize
    assert_nothing_raised { obj_new = FIRM.deserialize(obj_serial) }
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
    assert_nothing_raised { obj_new = SerializedBase2.deserialize(obj_serial) }
    assert_equal(obj, obj_new)

    obj = SerializedDerived2.new([Point.new(1,1), Point.new(2,2), Point.new(3,3)])
    obj_serial = obj.serialize
    assert_nothing_raised { obj_new = FIRM.deserialize(obj_serial) }
    assert_equal(obj, obj_new)

    obj = SerializedDerived2_1.new([Point.new(1,1), Point.new(2,2), Point.new(3,3)], Rect.new(1, 1, 40, 40))
    obj_serial = obj.serialize
    assert_nothing_raised { obj_new = SerializedDerived2_1.deserialize(obj_serial) }
    assert_equal(obj, obj_new)

    obj = SerializedDerived3.new([Point.new(1,1), Point.new(2,2), Point.new(3,3)])
    obj_serial = obj.serialize
    assert_nothing_raised { obj_new = SerializedDerived3.deserialize(obj_serial) }
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
    assert_nothing_raised { obj_new = FIRM.deserialize(obj_serial) }
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
    assert_nothing_raised { obj_new = FIRM.deserialize(obj_serial) }
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

  class House

    include FIRM::Serializable

    attr_accessor :address, :city
    attr_reader :owners

    properties :address, :city, :owners

    allow_aliases

    def initialize(*args)
      @address, @city = *args
      @owners = []
    end

    def add_owner(owner)
      @owners << owner
      owner.houses << self
    end

    def set_owners(owners)
      @owners = owners
    end
    private :set_owners

  end

  class Person

    include FIRM::Serializable

    attr_accessor :name, :tax_id, :houses

    properties :name, :tax_id, :houses

    allow_aliases

    def initialize(*args)
      @name, @tax_id = *args
      @houses = []
    end

  end

  def test_cyclic_references
    person_a = Person.new('Max A', 123456)
    person_b = Person.new('Joe B', 234567)

    house_1 = House.new('The street 1', 'Nowhere')
    house_1.add_owner(person_a)
    house_2 = House.new('The lane 2', 'Somewhere')
    house_2.add_owner(person_b)
    house_3 = House.new('The promenade 3', 'ThisPlace')
    house_3.add_owner(person_a)
    house_3.add_owner(person_b)

    obj_serial = [house_1, house_2, house_3].serialize
    h1_new, h2_new, h3_new = nil
    assert_nothing_raised { h1_new, h2_new, h3_new = *FIRM.deserialize(obj_serial) }
    assert_instance_of(House, h1_new)
    assert_instance_of(House, h2_new)
    assert_instance_of(House, h3_new)
    assert_true(house_1.address == h1_new.address && house_1.city == h1_new.city)
    assert_true(house_2.address == h2_new.address && house_2.city == h2_new.city)
    assert_true(house_3.address == h3_new.address && house_3.city == h3_new.city)
    assert_equal(h1_new.owners[0].object_id, h3_new.owners[0].object_id)
    assert_equal(h2_new.owners[0].object_id, h3_new.owners[1].object_id)
    pa_new, pb_new = *h3_new.owners
    assert_instance_of(Person, pa_new)
    assert_instance_of(Person, pb_new)
    assert_equal(h1_new.object_id, pa_new.houses[0].object_id)
    assert_equal(h2_new.object_id, pb_new.houses[0].object_id)
    assert_equal(h3_new.object_id, pa_new.houses[1].object_id)
    assert_equal(h3_new.object_id, pb_new.houses[1].object_id)
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
    assert_nothing_raised { obj_new = FIRM.deserialize(obj_serial) }
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
        @nested = FIRM.deserialize(val.first)
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
    assert_nothing_raised { obj_new = FIRM.deserialize(obj_serial) }
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

  class CreateFinalizer

    include FIRM::Serializable

    property :value

    def initialize(val = nil)
      @value = val
      create if val
    end

    # default finalizer
    def create
      @symbol = case @value
                when 1
                  :one
                when 2
                  :two
                when 3
                  :three
                else
                  :none
                end
    end

    attr_reader :value, :symbol

    def set_value(v)
      @value = v
    end
    private :set_value

  end

  class BlockFinalizer

    include FIRM::Serializable

    property :value

    define_deserialize_finalizer do |obj|
      obj.symbol = case obj.value
                   when 1
                     :one
                   when 2
                     :two
                   when 3
                     :three
                   else
                     :none
                   end
    end

    def initialize(val = 0)
      @value = val
      @symbol = case @value
                when 1
                  :one
                when 2
                  :two
                when 3
                  :three
                else
                  :none
                end
    end

    attr_reader :value
    attr_accessor :symbol

    def set_value(v)
      @value = v
    end
    private :set_value
  end

  class MethodFinalizer

    include FIRM::Serializable

    property :value

    define_deserialize_finalizer :finalize_deserialize

    def initialize(val = 0)
      @value = val
      @symbol = case @value
                when 1
                  :one
                when 2
                  :two
                when 3
                  :three
                else
                  :none
                end
    end

    attr_reader :value, :symbol

    # default finalizer
    def finalize_deserialize
      @symbol = case @value
                when 1
                  :one
                when 2
                  :two
                when 3
                  :three
                else
                  :none
                end
    end
    private :finalize_deserialize

    def set_value(v)
      @value = v
    end
    private :set_value

  end

  def test_deserialize_finalizers
    obj = CreateFinalizer.new(2)
    obj_serial = obj.serialize
    obj_new = nil
    assert_nothing_raised { obj_new = FIRM.deserialize(obj_serial) }
    assert_equal(obj.value, obj_new.value)
    assert_equal(obj.symbol, obj_new.symbol)

    obj = BlockFinalizer.new(2)
    obj_serial = obj.serialize
    obj_new = nil
    assert_nothing_raised { obj_new = FIRM.deserialize(obj_serial) }
    assert_equal(obj.value, obj_new.value)
    assert_equal(obj.symbol, obj_new.symbol)

    obj = MethodFinalizer.new(2)
    obj_serial = obj.serialize
    obj_new = nil
    assert_nothing_raised { obj_new = FIRM.deserialize(obj_serial) }
    assert_equal(obj.value, obj_new.value)
    assert_equal(obj.symbol, obj_new.symbol)
  end

end
