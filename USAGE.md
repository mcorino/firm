
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
class method (this includes the core Ruby classes supported out of the box).

The `#serialize` method has the following signature.

> ```ruby
> def serialize(pretty: false, format: Serializable.default_format)
> def serialize(io, pretty: false, format: Serializable.default_format)
> ```
> Serialize this object.
> 
> **Overloads**
> 
>> `serialize(pretty: false, format: Serializable.default_format)`
>> 
>> Returns serialized data.
>>
>> **Parameters:**
>>
>> - `pretty` (Boolean) (defaults to: `false`) - if true specifies to generate pretty formatted output if possible 
>> - `format` (Symbol, String) (defaults to: `Serializable.default_format`) - specifies output format
>>
>> **Returns:**
>>
>> - (String) - serialized data 
>
> ---
>
>> `serialize(io, pretty: false, format: Serializable.default_format)`
>>
>> Writes serialized data to given stream.
>>
>> **Parameters:**
>>
>> - `io` (IO) - IO(-like) object to write serialized data to 
>> - `pretty` (Boolean) (defaults to: `false`) - if true specifies to generate pretty formatted output if possible
>> - `format` (Symbol, String) (defaults to: `Serializable.default_format`) - specifies output format
>>
>> **Returns:**
>>
>> - (String) - serialized data

Out of the box the default format will be `:json`. This format can be overruled either by providing the `format`
argument to the `#serialize` method or by altering the `FIRM::Serializable.default_form` setting process wide
as follows.

```ruby
require 'firm'

  # application code ...

  # at some setup time  
  FIRM::Serializable.default_format = :yaml
```

Out of the box the formats `:json` and `:yaml` are supported. In case the `nokogiri` gem has been installed _and loaded 
before the `firm` gem_ the `:xml` format will be available as well.

The `#deserialization` class method has the following signature.

> ```ruby
>   def self.deserialize(source, format: Serializable.default_format)
> ```
>  Deserializes object from source data
>
> **Parameters:**
> 
> - `source` (IO,String) - source data (String or IO(-like object))
> - `format` (Symbol, String) - data format of source
> 
> **Returns:** 
> 
> - (Object) - deserialized object

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

> ```ruby
> def self.property(*props, force: false)
> def self.property(hash, force: false)
> def self.property(*props, force: false, handler: nil, &block)
> ```
> Adds (a) serializable property(-ies) for instances of his class (and derived classes)
> 
> **Overloads:**
> 
>> `property(*props, force: false)`
>>
>> Specifies one or more serialized properties.
>>
>> The serialization framework will determine the availability of setter and getter methods
>> automatically by looking for methods <code>"#{prop_id}=(v)"</code>, <code>"#set_{prop_id}(v)"</code> or <code>"#{prop_id}(v)"</code>
>> for setters and <code>"#{prop_id}()"</code> or <code>"#get_{prop_id}"</code> for getters.
>>
>> **Parameters:**
>>
>> - `props` (Symbol,String) - one or more ids of serializable properties
>> - `force` (Boolean) - overrides any `#disable_serialize` for the properties specified
>> 
>> **Returns:**
>>
>> - (undefined)
>
> ---
>
>> `property(hash, force: false)`
>>
>> Specifies one or more serialized properties with associated setter/getter method ids/procs/lambda-s.
>> Procs with setter support MUST accept 1 or 2 arguments (1 for getter, 2 for setter) where the first
>> argument will always be the property owner's object instance and the second (in case of a setter proc) the
>> value to restore.
>> 
>>> **NOTE** Use `*val` to specify the optional value argument for setter requests instead of `val=nil`
>>> to be able to support setting explicit nil values.
>>
>> **Parameters:**
>>
>> - `hash` (Hash) - a hash of pairs of property ids and getter/setter procs
>> - `force` (Boolean) -  overrides any `#disable_serialize` for the properties specified
>>
>> **Returns:**
>>
>> - (undefined)
>
> ---
>
>> `property(*props, force: false, handler: nil, &block)`
>>
>> Specifies one or more serialized properties with a getter/setter handler proc/method/block.
>> The getter/setter proc or block should accept either 2 (property id and object for getter) or 3 arguments
>> (property id, object and value for setter) and is assumed to handle getter/setter requests
>> for all specified properties.
>> The getter/setter method should accept either 1 (property id for getter) or 2 arguments
>> (property id and value for setter) and is assumed to handle getter/setter requests
>> for all specified properties.
>>> **NOTE** Use `*val` to specify the optional value argument for setter requests instead of `val=nil`
>>> to be able to support setting explicit nil values.
>>
>> **Parameters:**
>>
>> - `props` (Symbol,String) - one or more ids of serializable properties
>> - `force` (Boolean) - overrides any `#disable_serialize` for the properties specified
>>
>> **Yield Parameters:**
>>
>> - `id` (Symbol,String) - property id
>> - `obj` (Object) - object instance
>> - `val` (Object) - optional property value to set in case of setter request
>>
>> **Returns:**
>>
>> - (undefined)

There are 2 requirements for declaring a serializable property:

1. the property's data type needs to be serializable (duh!);
2. there need to be appropriate getter & setter methods/procedures defined (see below). 

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
`#get_property_id()` (getter) and `#set_property_id(val)` (or `#property_id(v)`) respectively.

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

#### Serializing without property definitions

It is not mandatory to define properties for a serializable class. In case object existence is all the state that is
required (or such object's state needs to be freshly initialized when restored) including the mixin module is all that
is needed. This will than result in an '_empty_' serialized instance of the particular class that will simply be
recreated when deserialized.

Another situation where it might not be needed to define properties is in the case of a derived class that does not
define any additional state but only additional functionality.

### Excluding a base property

In some cases a derived class may need to suppress serialization of a property of it's base class because the 
derived class may for some reason (re-)initialize this property itself depending on some external factor.
For these cases the `#excluded_property` method is available with the following signature:

> ```ruby
> def self.excluded_property(*props)
> ```
>
> Excludes a serializable property for instances of this class.
> 
> **Parameters:**
> 
> - `props` (Symbol,String) - one or more ids of serializable properties
> 
> **Returns:**
> 
> - (undefined)

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

> ```ruby
> def disable_serialize
> ```
>
> Disables serialization for this object as a single property or as part of a property container
> (array or set).
> 
> **Returns:**
> 
> - (undefined)

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

The requirements in the previous section could also have been met by using persisted object aliases which without FIRM
are only supported with YAML.
FIRM however implements functionality to also support object aliasing with JSON and XML.

When applying aliasing the FIRM code will not serialize multiple copies of an object instance referenced multiple
times in a dataset being serialized but instead it will serialize a single copy the first time the instance is
encountered with a special 'anchor' id attached and serialize only shallow 'alias' references to this 'anchor' id for any
other reference of the same instance encountered while serializing.
On deserialization the same instance will be restored for the 'anchored' copy as well as any 'alias' references.

Aliasing is only supported for **user defined** serializable classes and named Struct (-derived) classes.

The following example showcases this functionality.

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
  
  # declare a serialization property
  property origin: :serialize_origin
  
  def initialize(points = [], origin: nil)
    super(points)
    self.origin = origin
  end
  
  attr_reader :origin
  
  def origin=(org)
    # delete any existing origin
    @points.delete(@origin) if @origin
    # set the new origin
    @origin = org
    if @origin
      # insert this as a origin point
      @points.insert(0, @origin)
    end
  end
  
  def serialize_origin(*val)
    @origin = *val unless val.empty?
    @origin
  end
  
end

# serializing a regular Path will persist all it's points
path = Path.new([Point.new(10,10), Point.new(20,20), Point.new(30,30)])
path_json = path.serialize

# serializing an ExtendedPath will persist all points and the assigned origin as a separate (aliased) property
extpath = ExtendedPath.new([Point.new(15,15), Point.new(25,25), Point.new(35,35)], origin: Point.new(1,2))
extpath_json = extpath.serialize

# deserializing both object will still restore them as they were
path2 = Path.deserialize(path_json)
extpath2 = ExtendedPath.deserialize(extpath_json)
```

#### Cyclic references

FIRM automatically recognizes and handles cyclic references of aliasable objects.

As this support is based on the FIRM aliasing support (except for the YAML format) handling cyclic references is 
restricted to those classes that support aliasing.<br>
In particular users should avoid cyclic references of the following instances:
- Array
- Hash
- Set
- OpenStruct

In practice this should not be a real issue as having cyclic references of these kind of generic container objects
should be considered **BAD** programming.

### Custom initialization for deserialization 

By default FIRM deserialization will initialize class instances for deserialization by calling the `#initialize` instance
method of a class without arguments (default construction), i.e. `instance.__send__(:initialize)`.
This may not always be appropriate for various reasons. For these cases it is possible to overload the default 
initialization method for **user defined** serializable classes.

In case customized initialization is required overload the (protected) `#init_from_serialized(data)` instance method as shown in 
the following example.

```ruby
require 'firm'

# Singleton class without public constructor
class Singleton
  
  include FIRM::Serializable
  
  class << self
    private :new

    def instance
      @instance ||= self.new
    end
    
    # FIRM creates new instances for deserialization by calling #allocate followed by #init_from_serialized 
    def allocate
      instance
    end
  end
  
  
  # Overload the deserialization initializer.

  # Initializes a newly allocated instance for subsequent deserialization (optionally initializing
  # using the given data hash).
  # The default implementation calls the standard #initialize method without arguments (default constructor)
  # and leaves the property restoration to a subsequent call to the instance method #from_serialized(data).
  # Classes that do not support a default constructor can override this class method and
  # implement a custom initialization scheme.
  # implement a custom creation scheme.
  # @param [Object] _data hash-like object containing deserialized property data (symbol keys)
  # @return [self] the object
  def init_from_serialized(_data)
    # nothing to initialize (already done in allocate)
    self
  end
  
end
```

### Deserialization finalizers

User defined classes may also depend on non-trivial initialization at construction time derived from initial 
construction arguments. In these cases simple default construction followed by property restoration may also
not suffice.

In essence there are three options to handle these cases.

The first option is to define customized, non-trivial, serialization handlers for certain properties that will
not only handle property restoration but may also (re-)initialize dependent, non-persisted, attributes (as in the 
case of the first `ExtendedPath` example above).

This approach however has limits in that it does not scale to cases where the dependent, non-persisted, attributes
rely on more than one restored property.
For these cases the approach of overloading the `#create_for_deserialize` method may be more appropriate.

In cases which involve restoring large amounts of persisted properties this may however be cumbersome.
Instead of overloading `#create_for_deserialize` there is therefor another customization option available that
allows to define _deserialization finalizers_.<br>
A deserialization finalizer is a method, proc or block that will be called for a deserialized object after all 
it's serialized properties have been deserialized and restored.

FIRM supports a default finalizer scheme but also allows alternative definitions (or disabling) of deserialization 
finalizers using the `#define_deserialize_finalizer` class method which has the following signature:

> ```ruby
> def self.define_deserialize_finalizer(meth)
> def self.define_deserialize_finalizer(&block)
> ```
>
> Defines a finalizer method/proc/block to be called after all properties
> have been deserialized and restored.
>
> Procs or blocks will be called with the deserialized object as the single argument. <br>
> Unbound methods will be bound to the deserialized object before calling. <br>
> Explicitly specifying nil will undefine the finalizer.
> 
> **Overloads**
> 
>> `define_deserialize_finalizer(meth)`
>> 
>> **Parameters:**
>>
>> - `meth` (Symbol, String, Proc, UnboundMethod, nil) - name of instance method, proc or method to call for finalizing
>> 
>> **Returns:**
>>
>> - (undefined)
> 
> ---
>
>> `define_deserialize_finalizer(&block)`
>>
>> **Yield Parameters:**
>>
>> - `obj` (Object) - deserialized object to finalize
>>
>> **Returns:**
>>
>> - (undefined)

#### Default finalizer

By default FIRM assumes that with any user defined serializable class that defines a `#create` instance method with 
no arguments this method is intended als an initialization finalizer and will use that method as the deserialization
finalizer unless defined differently by a call to `#define_deserialize_finalizer`.

The following example shows a serializable class with a `#create` finalizer.

```ruby
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
```

In case a user defined class defines a matching `#create` method that for some reason is not to be used as a 
deserialization finalizer the default assignment can be disabled by using a call to `#define_deserialize_finalizer`
with a `nil` argument as follows.

```ruby
class SomeClass
  
  include FIRM::Serializable
  
  properties :a, :b, :c
    
  # disable any deserialization finalizer 
  define_deserialize_finalizer nil
  
  # should not be used as finalizer
  def create
    # ...
  end
  
end
```

Instead of disabling `#define_deserialize_finalizer` could also be used to define an alternative finalizer.

#### Alternative finalizer

Alternatively `#define_deserialize_finalizer` can be used to explicitly define a finalizer from:

1. a name (`String` or `Symbol`) identifying an instance method of the serializable class;
2. a lambda or Proc;
3. a block.

Instance methods should not expect any arguments. Procs or blocks should expect the deserialized object instance
to be passed as the single argument.
