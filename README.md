[![Tests](https://github.com/mcorino/firm/actions/workflows/ruby.yml/badge.svg)](https://github.com/mcorino/firm/actions/workflows/ruby.yml)

[![License](https://img.shields.io/badge/license-MIT-yellowgreen.svg)](LICENSE)
[![Gem Version](https://badge.fury.io/rb/firm.svg)](https://badge.fury.io/rb/firm)
[![Documentation](https://img.shields.io/badge/docs-pages-blue.svg)](https://mcorino.github.io/firm)

# FIRM - Format Independent Ruby Marshalling

## Introduction

FIRM is a pure Ruby library that works across different Ruby implementations like MRI Ruby and JRuby providing format 
independent object (de-)serialization support.

FIRM is explicitly **NOT** intended as a non-discriminative marshaling library (dumping any object's attributes)
but rather as a structured and safe serialization library requiring users to think about what state they want
persisted (and possibly in what form) and what not.
Straightforward attribute serialization is simple with minimal intrusion on user code.
In addition various customization options are available to tweak (de-)serialization for a perfect fit if needed. 

Out of the box (de-)serializing Ruby objects to(from) JSON and YAML is supported without any additional
dependencies.
When the `nokogiri` gem is installed (and loaded before FIRM) XML (de-)serializing will also be available.

FIRM supports (de-)serializing many core Ruby objects out of the box including:

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

For simplicity and security reasons FIRM does **not** support direct (de-)serializing of `Class` objects but will rather
serialize (and deserialize) these as their scoped string names. Customized property setters can be used to
resolve Class objects from these names if really needed.

Serialization support for user defined classes is available through a simple DSL scheme.

FIRM provides object aliasing support for JSON and XML in a similar fashion as the standard support provided
by YAML.<br>
In addition FIRM automatically recognizes and handles cyclic references of aliasable objects.

FIRM serialization is also thread safe and supports re-entrancy (i.e. nested serialization).

## Installing FIRM

FIRM is distributed as a Ruby gem on [RubyGems](https://rubygems.org). This gem can also be downloaded from the release
assets on [Github](https://github.com/mcorino/firm/releases).

Installing the gem requires no additional installation steps and/or additional software to be installed except for a
supported version of the Ruby interpreter. So the following command is all it takes to install:

```shell
gem install firm
```

Installing the `nokogiri` gem is optional to enable the XML serialization format.   

## Usage examples

### Serialize an array of objects to JSON string

```
ruby
require 'firm'

a = [1, '2', :three, 4.321]
json = a.serialize
FIRM.deserialize(json)
```

IRB output:

```shell
=> true
=> 
[1,
 "2",
 :three,
 4.321]
=> "[1,\"2\",{\"json_class\":\"Symbol\",\"s\":\"three\"},4.321]"
=> 
[1,
 "2",
 :three,
 4.321]
```

Alternatively the object can be serialized to the YAML or XML (if the `nokogiri` gem is installed) format like this.

```ruby
require 'firm'

a = [1, '2', :three, 4.321]
json = a.serialize(format: :yaml)
FIRM.deserialize(json, format: :yaml)
```

IRB output:

```shell
=> true
=> 
[1,
 "2",
 :three,
 4.321]
=> "---\n- 1\n- '2'\n- :three\n- 4.321\n"
=> 
[1,
 "2",
 :three,
 4.321]
```

### Serialize a user defined object

```ruby
require 'nokogiri' # enable XML output format
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
  # (customization options are available)
  attr_accessor :x, :y

end

rect = {topleft: Point.new(1,1), bottomright: Point.new(32, 64)}
xml = rect.serialize(format: :xml)
# all serializable classes provide the #deserialize class method
Hash.deserialize(xml, format: :xml)
```

IRB output:

```shell
=> true
=> true
=> 
[:x,
 :x=,
 :y,
 :y=]
=> 
{:topleft=>
  #<Point:0x00007f6da9902518
   @x=
    1,
   @y=
    1>,
 :bottomright=>
  #<Point:0x00007f6da9902450
   @x=
    32,
   @y=
    64>}
=> "<?xml version=\"1.0\"?>\n<Hash><P><Symbol>topleft</Symbol><Object class=\"Point\"><x><Integer>1</Integer></x><y><Integer>1</Integer></y></Object></P><P><Symbol>bottomright</Symbol><Object class=\"Point\"><x><Integer>32</Integer></x><y><Integer>64</Integer></y></Object></P></Hash>\n"
=> nil
=> 
{:topleft=>
  #<Point:0x00007f6da98f2208
   @x=
    1,
   @y=
    1>,
 :bottomright=>
  #<Point:0x00007f6da98f0d90
   @x=
    32,
   @y=
    64>}
```

See [USAGE](USAGE.md) for more information.

## FIRM licence

FIRM is free and open-source. It is distributed under the liberal
MIT licence which is compatible with both free and commercial development.
See [LICENSE](LICENSE) for more details.

### Required Credits and Attribution

FIRM requires no attribution, beyond retaining existing copyright notices.
