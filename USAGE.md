
# Using FIRM

## Loading FIRM

To use FIRM in your application the library must be required like this.

```ruby
require 'firm'
```

Optionally the `nokogiri` gem (if installed) can be required **before** FIRM to enable support for the XML output
format like this.

```ruby
require 'nokogiri'
require 'firm'
```

## Serialization and deserialization

Any class which has FIRM (de-)serialization support will provide a `#serialize` instance method and a `#deserialize`
class method (this includes to core Ruby classes supported out of the box).

The `#serialize` method has the following signature.

```ruby
# Serialize this object
# @overload serialize(pretty: false, format: Serializable.default_format)
#   @param [Boolean] pretty if true specifies to generate pretty formatted output if possible
#   @param [Symbol,String] format specifies output format
#   @return [String] serialized data
# @overload serialize(io, pretty: false, format: Serializable.default_format)
#   @param [IO] io output stream to write serialized data to
#   @param [Boolean] pretty if true specifies to generate pretty formatted output if possible
#   @param [Symbol,String] format specifies output format
#   @return [IO]
def serialize(io = nil, pretty: false, format: Serializable.default_format)
  # ...
end
```

Out of the box the default format will be `:json`. This format can be overruled either by providing the `format`
argument to the `#serialize` method or by altering the `FIRM::Serializable.default_form` setting process wide
as follows.

```ruby
require 'firm'

  # application code ...

  # at some setup time  
  FIRM::Serializable.default_format = :yaml
```

Out of the box the formats `:json` and `:yaml` are supported. In case the `nokogiri` gem has been installed and loaded 
before the `firm` gem the `:xml` format will be available as well.

The `#deserialization` class method has the following signature.

```ruby
  # Deserializes object from source data
  # @param [IO,String] source source data (String or IO(-like object))
  # @param [Symbol, String] format data format of source
  # @return [Object] deserialized object
  def self.deserialize(source, format: Serializable.default_format)
    # ...
  end
```

As said this method is available as a class method on any serializable class but in addition it is also available on the
`FIRM` module itself (see example below).

The following example shows how to serialize an object and deserialize it at a later point.

```ruby
require 'firm'

# initialize settings object

settings = OpenStruct.new({
                            country: 'NL',
                            language: 'EN',
                            defaults: {
                              background: 'GREEN',
                              foreground: 'YELLOW' 
                            }
                            #...
                          })

# serialize settings object to JSON file

File.open('settings.json', 'w+') { |f| settings.serialize(f) }

# ...

# deserialize settings from JSON file

new_settings = File.open('settings.json') { |f| FIRM.deserialize(f) }
```

## Core Ruby class serialization support

FIRM supports (de-)serializing the following core Ruby objects out of the box:

- `NilClass`
- `TrueClass` & `FalseClass`
- `Integer`
- `Float`
- `Rational`
- `Complex`
- `BigDecimal` (if loaded; not default anymore starting from Ruby 3.4)
- `String`
- `Symbol`
- `Array`
- `Hash`
- `Range`
- `Regexp`
- `Time`
- `Struct`
- `Set`
- `OpenStruct`
- `Date`
- `DateTime`

## User defined class serialization

User defined classes can be declared serializable for FIRM by including the `FIRM::Serializable` mixin module.

```ruby
require 'firm'

class Point
  
  # declare serializable
  include FIRM::Serializable

  # ...
  
  
end
```

Of course declaring a class to be serializable has not much use without defining what properties of any instances of 
the class need to be (de-)serialized.
Including the `FIRM::Serializable` module extends the including class with a number of class methods to do just that.

### Define serializable properties

To define a serializable property for a class the `#property` method can be used which has the following signature.

```ruby
      # Adds (a) serializable property(-ies) for instances of his class (and derived classes)
      # @overload property(*props, force: false)
      #   Specifies one or more serialized properties.
      #   The serialization framework will determine the availability of setter and getter methods
      #   automatically by looking for methods <code>"#{prop_id}=(v)"</code>, <code>"set_#{prop_id}(v)"</code> or <code>"#{prop}(v)"</code>
      #   for setters and <code>"#{prop_id}()"</code> or <code>"get_#{prop_id}"</code> for getters.
      #   @param [Symbol,String] props one or more ids of serializable properties
      #   @param [Boolean] force overrides any #disable_serialize for the properties specified
      # @overload property(hash, force: false)
      #   Specifies one or more serialized properties with associated setter/getter method ids/procs/lambda-s.
      #   Procs with setter support MUST accept 1 or 2 arguments (1 for getter, 2 for setter).
      #   @note Use `*val` to specify the optional value argument for setter requests instead of `val=nil`
      #         to be able to support setting explicit nil values.
      #   @param [Hash] hash a hash of pairs of property ids and getter/setter procs
      #   @param [Boolean] force overrides any #disable_serialize for the properties specified
      # @overload property(*props, force: false, handler: nil, &block)
      #   Specifies one or more serialized properties with a getter/setter handler proc/method/block.
      #   The getter/setter proc or block should accept either 2 (property id and object for getter) or 3 arguments
      #   (property id, object and value for setter) and is assumed to handle getter/setter requests
      #   for all specified properties.
      #   The getter/setter method should accept either 1 (property id for getter) or 2 arguments
      #   (property id and value for setter) and is assumed to handle getter/setter requests
      #   for all specified properties.
      #   @note Use `*val` to specify the optional value argument for setter requests instead of `val=nil`
      #         to be able to support setting explicit nil values.
      #   @param [Symbol,String] props one or more ids of serializable properties
      #   @param [Boolean] force overrides any #disable_serialize for the properties specified
      #   @yieldparam [Symbol,String] id property id
      #   @yieldparam [Object] obj object instance
      #   @yieldparam [Object] val optional property value to set in case of setter request
      def self.property(*props, **kwargs, &block)
        # ...
      end
```

The simplest property declaration takes this form.

```ruby
require 'firm'

class Point
  
  # declare serializable
  include FIRM::Serializable

  # define serializable properties
  property :x, :y

  def initialize(*args)
    if args.empty?
      @x = @y = 0
    else
      @x, @y = *args
    end
  end

  attr_accessor :x, :y
  
end
```

This defines the serializable properties `:x` and `:y` for the `Point` class.
By default the FIRM library will identify getter and setter methods by looking for standard attribute accessor methods
named `#property_id()` (getter) and `#property_id=(val)`. If these can not be found the library looks for 
`#get_property_id()` (getter) and `#set_property_id(val)` respectively.

The following example shows usage of the alternative standard getter / setter scheme.

```ruby
require 'firm'

class Point
  
  # declare serializable
  include FIRM::Serializable

  # define serializable properties
  property :x, :y

  def initialize(*args)
    if args.empty?
      @x = @y = 0
    else
      @x, @y = *args
    end
  end

  def get_x
    @x
  end

  def get_y
    @y
  end

  protected
  
  def set_x(val)
    @x = val
  end

  def set_y(val)
    @y = val
  end
  
end
```

This example also shows that getters and setters do not necessarily need to be public. Thus the user defined class
can be immutable from the viewpoint of the application but still be serializable. 

In case the standard getter / setter scheme does not provide an acceptable solution there is another option to define
serializable properties with associated custom setter and setter methods or procs/lambdas using the second form of
the `#property` method.
The following example demonstrates this option.

```ruby
require 'firm'

class Point
  
  # declare serializable
  include FIRM::Serializable

  # define serializable properties
  property x: :serialize_x,         # use instance method #serialize_x 
           y: ->(pt, *val) {        # use given lambda
             if val.empty?
               pt.y
             else
               pt.__send__(:set_y, *val)
             end
           }

  def initialize(*args)
    if args.empty?
      @x = @y = 0
    else
      @x, @y = *args
    end
  end

  attr_reader :x, :y
  
  protected
  
  def serialize_x(*val)
    @x = *val unless val.empty?
    @x
  end

  def set_y(val)
    @y = val
  end
  
end
```

Finally there is a last customization option by using the last form of the `#property` method with which a single
serialization handler (method, proc or block) can be defined for multiple properties.
The following example demonstrates this option.

```ruby
require 'firm'

class Point
  
  # declare serializable
  include FIRM::Serializable

  # define serializable properties
  property :x, :y, handler: :serialize_point      # use instance method #serialize_point 
  
  # alternatively a block-form could be used
  # property(:x, :y) do |pt, prop_id, *val|
  #   case prop_id
  #   when :x     
  #     # ...     
  #   when :y     
  #     # ...     
  #   end
  # end

  def initialize(*args)
    if args.empty?
      @x = @y = 0
    else
      @x, @y = *args
    end
  end

  attr_reader :x, :y
  
  protected
  
  def serialize_point(prop_id, *val)
    case prop_id
    when :x
      @x = *val unless val.empty?
      @x
    when :y
      @y = *val unless val.empty?
      @y
    end
  end
  
end
```

The `#property` method is also aliased as `#properties` and `#contains` for syntactical convenience. 

### Excluding a base property

In some cases a derived class may need to suppress serialization of a property of it's base class because the 
derived class may for some reason (re-)initialize this property itself depending on some external factor.
For these cases the `#excluded_property` method is available with the following signature:

```ruby
# Excludes a serializable property for instances of this class.
# @param [Symbol,String] props one or more ids of serializable properties
def self.excluded_property(*props)
  # ...
end
```

The following example showcases use of this property.

```ruby
require 'firm'

Point = Struct.new(:x, :y) do |struct_klass|
  def +(other)
    Point.new(self.x + other.x, self.y + other.y)
  end
end
Size = Struct.new(:width, :height)

class Rect
  # declare serializable
  include FIRM::Serializable

  # define serializable properties
  property :position, :size

  def initialize(*args)
    if args.empty?
      @position = @size = nil
    else
      @position, @size = *args
    end
  end

  attr_accessor :position, :size
end

class RelativeRect < Rect

  # no need to include mixin since this is inherited

  class << self

    def origin
      @origin ||= Point.new(0, 0)
    end
    
    def origin=(org)
      @origin = org
    end

  end

  # persist new property
  property :offset

  # exclude base property :position
  excluded_property :position

  def initialize(*args)
    super()
    unless args.empty?
      offs, @size = *args
      set_offset(offs)
    end
  end

  attr_reader :offset

  def set_offset(offs)
    @offset = offs
    @position = self.class.origin + @offset
  end

  private :position=

end

# set the current origin for relative rectangles
RelativeRect.origin = Point.new(10,10) 

# serializing a regular Rect instance will persist position and size
rect = Rect.new(Point.new(33,33), Size.new(10, 40))
rect_json = rect.serialize

# while serializing a RelativeRect will persist offset and size
relrect = RelativeRect.new(Point.new(5,5), Size.new(20, 65))
relrect_json = relrect.serialize

# Set new origin for relative rectangles
RelativeRect.origin = Point.new(20,40)

# deserializing the regular Rect will restore it as it was
rect2 = Rect.deserialize(rect_json)

# deserializing the RelativeRect will restore it at a new position
relrect2 = RelativeRect.deserialize(relrect_json)
```

### Selective serialization

In other cases a derived class may add a fixed item to a base class collection. When the base collection
is persisted this fixed item should not be serialized as the derived constructor would always add the fixed item.

For these cases the `#disable_serialize` instance method is available for any **user defined** serializable class. This
method has the following signature.

```ruby
# Disables serialization for this object as a single property or as part of a property container
# (array or set).
# @return [void]
def disable_serialize
  # ...
end
```

The following example showcases using this method.

```ruby
require 'firm'

class Point
  # define the class as serializable 
  include FIRM::Serializable

  # declare the serializable properties of instances of this class
  properties :x, :y

  # allow instantiation using the default ctor (no args)
  # (custom creation schemes can be defined)
  def initialize(*args)
    if args.empty?
      @x = @y = 0
    else
      @x, @y = *args
    end
  end

  # define the default getter/setter support FIRM will use when (de-)serializing properties
  attr_accessor :x, :y
end

class Path
  # declare serializable
  include FIRM::Serializable
  
  property :points
  
  def initialize(points = [])
    @points = points
  end
  
  attr_reader :points
  
  def set_points(pts)
    @points.concat(pts)
  end
  private :set_points
end

class ExtendedPath < Path
  
  def initialize(points = [])
    super
    # create a fixed point
    pt = Point.new(1, 2)
    # disable serializing this instance 
    pt.disable_serialize
    # insert this as a fixed origin point
    @points.insert(0, pt)
  end
  
end

# serializing a regular Path will persist all it's points
path = Path.new([Point.new(10,10), Point.new(20,20), Point.new(30,30)])
path_json = path.serialize

# serializing an ExtendedPath will persist all points except the fixed origin
extpath = ExtendedPath.new([Point.new(15,15), Point.new(25,25), Point.new(35,35)])
extpath_json = extpath.serialize

# deserializing both object will still restore them as they were
path2 = Path.deserialize(path_json)
extpath2 = ExtendedPath.deserialize(extpath_json)
```

An additional requirement may be to persist the additional item from the derived class as it is not fixed but rather
externally defined.
This is where the `:force` parameter of the `#property` method is of use as shown in the following example.

```ruby
require 'firm'

class Point
  # define the class as serializable 
  include FIRM::Serializable

  # declare the serializable properties of instances of this class
  properties :x, :y

  # allow instantiation using the default ctor (no args)
  # (custom creation schemes can be defined)
  def initialize(*args)
    if args.empty?
      @x = @y = 0
    else
      @x, @y = *args
    end
  end

  # define the default getter/setter support FIRM will use when (de-)serializing properties
  attr_accessor :x, :y
end

class Path
  # declare serializable
  include FIRM::Serializable
  
  property :points
  
  def initialize(points = [])
    @points = points
  end
  
  attr_reader :points
  
  def set_points(pts)
    @points.concat(pts)
  end
  private :set_points
end

class ExtendedPath < Path
  
  # declare a serialization property that must **always** be persisted
  property :origin, force: true
  
  def initialize(points = [], origin: nil)
    super(points)
    self.origin = origin
  end
  
  attr_reader :origin
  
  def origin=(org)
    # delete any existing origin
    @points.delete_at(0) if @origin
    # set the new origin
    @origin = org
    if @origin
      # disable serializing this instance if defined
      @origin.disable_serialize
      # insert this as a origin point
      @points.insert(0, @origin)
    end
  end
  
end

# serializing a regular Path will persist all it's points
path = Path.new([Point.new(10,10), Point.new(20,20), Point.new(30,30)])
path_json = path.serialize

# serializing an ExtendedPath will persist all points with the assigned origin as a separate property
extpath = ExtendedPath.new([Point.new(15,15), Point.new(25,25), Point.new(35,35)], origin: Point.new(1,2))
extpath_json = extpath.serialize

# deserializing both object will still restore them as they were
path2 = Path.deserialize(path_json)
extpath2 = ExtendedPath.deserialize(extpath_json)
```

### Object aliases

### Custom construction for deserialization 

### Deserialization finalizers
