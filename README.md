# lua-dictionary
Typed dictionary implementation for Lua

Requires **Lua-Defs**, a pure Lua classes implementation script: https://github.com/arj-mat/lua-defs.

## Usage example
```lua
require "lua-dictionary"; --or copy-paste the contnt of lua-dictionar.lua into your script;

players = Dictionary('string', 'table');
players["Guest 1"] = {};
players["Guest 2"] = {};
players["moderator 1"] = {};
```

This example will be used for the following documentation.

## Initialization
Supported initialization methods are the following:
```lua
Dictionary()
```
```lua
Dictionary({ foo = "bar" })
 ```
```lua
Dictionary('string', 'string')
```
 ```lua
Dictionary('string', 'string', { foo = "bar" })
```
**How it works**: the Dictionary instance relies on it's prototype methods, on it's index metatable pointing to it's *\_\_table*, which is the table that stores all the keys and values and on it's \_\_newindex meta event.

___
## Typed Dictionaries
When passing the two first arguments as strings, you're telling your Dictionary to only accept keys and values that matches the given types. The first argument will set the allowed types for the index key; the second one, for the value.

You can also change the allowed types at any moment using the method `:setTypes()`, documented bellow.

Those arguments are processed as Lua patterns, wich mean that you can allow multiple types by ussing the `|` pattern operator, like `string|number`, `string|table|boolean`.

You can also use `*` for allowing any kind of data for both the keys or values.

Considering that you have defined your typed dictionary as in the usage example and try to index a key with a number or set a value as a string, (like `players[123] = {}` or `players["guest"] = "abc"`), it will throw the following errors:

*Index of type "number" is not accepted as dictionary requires it to be string.*

*Value of type "string" is not accepted as dictionary requires it to be table.*

___
## Dictionary attributes
**number count**
Dictionary will always have the count attribute as the number of fields that it has.

If you do `print(players.count)` on the usage example, the output result will be `3`.

If you pass any table on the Dictionary initialization, it will list it's elements for updating the count attribute.

Whenever an field that was *nil* is set to any other type, the count is increased; and when a non-nil field is set to *nil*, it's decreased.
___
**string \_\_name**
Setting your dictionary's \_\_name attribute will help you to better identify bugs as it will be shown on the error messages related with the dictionary, specially while working with a typed one. 

___
## Dictionary methods and types
:**add(**`key, value`**)** - literal method for performing `dictionary[key] = value` and returns the added value.

:**remove(** `key`**)** - literal method for performing `dictionary[key] = nil` and returns the removed value.

:**setTypes(**`string keyTypesPattern, string valueTypesPattern`**)** - define the allowed types for keys and values. Returns nil.

:**foreach(**`function callback(key, value, IterationInterface`**)** - performs an iteration over the dictionary fields passing then and the IterationInterface for the given function. Returns nil. See *IterationInterface* bellow.

:**map(**`function callback(value, key, IterationInterface)`**)** - returns a new dictionary after applying the given function on the current dictionary fields. Returns non-typed Dictionary. See *IterationInterface* bellow.

:**filter(**`function callback(value, key)`**)** - returns a new dictionary containing all the fields that have been caused a positive return value on the given function. Returns non-typed Dictionary.

:**sort(**`function callback(a, b)`**)** - sort the dictionary source table using the given comparation function. Returns nil.

:**getKeys()** - return a new dictionary as an array containing the keys. Returns non-typed Dictionary.

:**getValues()** - return a new dictionary as an array containing the values. Returns non-typed Dictionary.

:**concat(**`string separator`**)** - concatenate all the dictionary values as strings separated by the given argument. Returns string.

:**tostring()** - the dictionary keys and values represented as strings on a readable format. This method is also called when requesting the dictionary as a string (it's the \_\_tostring meta event). Returns a string.

You can implement your own methods without having to declare another class of Dictionary by simply putting them on *Dictionary.prototype*, as this example: 
```lua
Dictionary.prototype.myMethod = function(self)
  --do something with self
  return "something";
end

myDictionary = Dictionary();
myDictionary:myMethod();
```
___
## Iteration Interface
```lua
 {
    stop = function, -- stops the iteration loop, exactly the same what "break" would do. Returns nil.
    source = Dictionary, -- the current dictionary where's the iteration is performed.
    target = Dictionary, -- only available on the map method. It's the new dictionary that will be returned once the map method is completed.
 }
```

An iteration interface is a table passed as the 3rd argument of the callback for **foreach** and **map** methods.

Example of how to break a foreach method using the iteration interface:
```lua
Dictionary({"one", "two", "three", "four", "five"}):foreach(function(key, value, iteration)
  if (value == "four") then
    iteration:stop();
  else
    print(value);
  end
end);
```
The printed result on this example will be:
```
one
two
three
```
___
## Dictionary class inheritance
Example:
```lua
define "DictionaryOfFruits" : extends "Dictionary" {
    prototype = {
        filterAllRed = function(self)
            return self:filter(function(fruit)
                return fruit.color == "red";
            end);
        end,
        getFruitNames = function(self)
            return self:getValues():map(function(fruit)
                return fruit.name;
            end);
        end
    },
    constructor = function(self)
        self:super('number', 'table');
    end
}

myFruits = DictionaryOfFruits();
myFruits[1] = {name = "banana", color = "yellow"};
myFruits[2] = {name = "strawberry", color = "red"};
myFruits[3] = {name = "apple", color = "red"};

print( myFruits:getFruitNames():concat(", ") );
print( myFruits:filterAllRed():getFruitNames():concat(", ") );
```
Printed lines from this example will be: `banana, strawberry, apple` and `strawberry, apple`.

Dictionaries can be extended in another custom class as using Lua Defs define method. However, it cannot be extended multiple times.

For example, this means that you can create a class `DictionaryOfFruits` extending from Dictionary, but you can't create another class named `DictionaryOfRedFruits` extending from DictionaryOfFruits. In this case, "DictionaryOfRedFruits" must be extended from Dictionary.
