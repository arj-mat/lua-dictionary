--[[
    Lua Dictionary - based on Lua Defs
    https://github.com/arj-mat/lua-dictionary
    This source code is licensed under the MIT license found in the LICENSE file in the root directory of this source tree. 
]]

(function()
	--[[
		Lua Defs
		This implementation of Lua Defs does not contains Enumerators or custom Types. Only Classes and Classes inhertitance.
		https://github.com/arj-mat/lua-defs
		v1.0.2
	]]

    local function showWarning(msg)
        print('[Lua-Defs] [Warning] ' .. msg);
    end

    local function DefinitionError(msg)
        error('[Lua-Defs] [Error] ' .. msg, 4);
    end

    local function defineScopeByName(name)
        local scope = _G;
        local lastPathName;
        local pathDepth = 0;
        for path in name:gmatch("(%a+)%.?") do
            pathDepth = pathDepth + 1;
        end
        local scopeDepth = 0;
        for path in name:gmatch("(%a+)%.?") do
            scopeDepth = scopeDepth + 1;
            lastPathName = path;
            if not scope[path] then
                scope[path] = {}
            end
            if not(scopeDepth == pathDepth) then
                scope = scope[path];
            end
        end
        return scope, lastPathName;
    end

    local function indexOverloadProcedure(selfInstance, keyName)
        if (type(selfInstance.class.indexOverload) == 'table') then
            return (selfInstance.class.prototype or (selfInstance.class.extends and selfInstance.class.extends.prototype or {}))[keyName] or selfInstance.class.indexOverload[keyName];
        elseif (type(selfInstance.class.indexOverload) == 'function') then
            return (selfInstance.class.prototype or (selfInstance.class.extends and selfInstance.class.extends.prototype or {}))[keyName] or selfInstance.class.indexOverload(selfInstance, keyName);
        end
    end

    local function createClass(fullClassName, declaration)
        local classEnv, className = defineScopeByName(fullClassName);
        if (classEnv[className].__isDefinition) then
            DefinitionError('"' .. fullClassName .. '" has already been defined.');
            return;
        end

        --- Classes without a parent must have a prototype table declarated
        if not(type(declaration.prototype) == 'table') and not(declaration.extends) then
            DefinitionError('Prototype declaration is missing on the definition of "' .. fullClassName .. '".');
            return;
        end

        if (declaration.prototype and declaration.prototype.class) then
            DefinitionError('Prototype declaration of "' .. fullClassName .. '" contains the reserved field "class".');
            return;
        end

        declaration.__isDefinition = true;
        declaration.__isClassDefinition = true;
        declaration.prototype = declaration.prototype or {};

        declaration.prototype.class = declaration; --- The class properties will be available by the field "class" of it's instance
        declaration.className =className .. "";
        declaration.fullClassName = fullClassName .. "";

        if (declaration.extends and declaration.extends.extends and declaration.extends.extends.onlyExtendsFromItself and declaration.extends.class ~= declaration.extends.extends) then
            DefinitionError("Attempt to extend \"" .. declaration.className .. "\" from " .. declaration.extends.className .. " but base class " .. declaration.extends.extends.className .. " can only extend from itself. \nUse define \"" .. declaration.className .. "\" : extends \"" .. declaration.extends.extends.className .. "\" instead.");
        end

        if (declaration.metatable and declaration.metatable.__index) then
            DefinitionError('Definition of "' .. fullClassName .. '"\'s metatable contains the __index field, which is reserved for the inheritance system. Use it on the class attribute "indexOverload" instead.');
        end

        classEnv[className] = declaration;

        --Resolve chained methods by putting them on the prototype as callable tables:
        if (classEnv[className].chainedMethods) then
            for name, value in next, classEnv[className].chainedMethods do
                if (type(value) == 'function') then
                    classEnv[className].chainedMethods[name] = {value};
                    setmetatable(classEnv[className].chainedMethods[name], {
                        __call = function(methodTable, self, ...)
                            methodTable[1](self, ...);
                            return self;
                        end
                    })
                    classEnv[className].prototype[name] = classEnv[className].chainedMethods[name];
                end
            end
        end

        --- If neither the class or it's parent has a constructor, then assign an empty function:
        if not(declaration.constructor or (declaration.extends and declaration.extends.constructor)) then
            declaration.constructor = function() end
        end

        --- Definition of inheritance methods
        if (classEnv[className].extends) then
            classEnv[className].prototype = classEnv[className].prototype or {};
            setmetatable(classEnv[className].prototype, {
                __index = classEnv[className].extends.prototype
            });
            classEnv[className].prototype.super = function(superInstance, ...)
                superInstance.class.extends.constructor(superInstance, ...);
            end;
        end

        --- Class initialization method:
        classEnv[className].Create = function(class, ...)
            local instance = {
                class = class
            };

            --- Classes' instances can have custom metaevents and metamethods declared on the "metatable" field...
            local metatable = class.metatable or (class.extends and class.extends.metatable or nil) or {};
            metatable.__index = class.prototype or (class.extends and class.extends.prototype or {});

            if (class.indexOverload) then
                metatable.__index = indexOverloadProcedure;
            end
            setmetatable(instance, metatable);

            (class.constructor and class.constructor or class.extends.constructor)(instance, ...); --- Calls for the available constructor method, with the new instance and the first received arguments.

            return instance;
        end

        --- Metamethod for allowing initializating the class by calling it as a function
        setmetatable(classEnv[className], {
            __call = function(refClass, ...)
                return refClass.Create(refClass, ...);
            end
        });
    end

    _G['define'] = function(name)
        local definitions = {
            Class = function(_, declaration)
                createClass(name, declaration);
            end,
            extends = function(_, parentName, ...)
                return function(declaration)
                    declaration.extends = defineScopeByName(parentName)[parentName]; --The class object will contain a referece to it's parent on the"extends" field.
                    if not(type(declaration.extends) == 'table') or not(declaration.extends.__isClassDefinition) then
                        DefinitionError('Definition of "' .. name .. '" extends from an unknown class named "' .. parentName .. '".');
                        return;
                    end
                    createClass(name, declaration);
                end
            end
        };

        setmetatable(definitions, {
            __index = function(_, unknownDefName)
                DefinitionError('Unknown definition type "' .. unknownDefName .. '".');
            end
        });

        return definitions;
    end
end)();

-- Dictionary class declaration:

define "Dictionary" : Class {
    prototype = {
        add = function(self, key, value)
            self[key] = value;
            return self.__table[key];
        end,
        remove = function(self, key)
            self[key] = nil;
        end,
        setTypes = function(self, keyType, valueType)
            rawset(self, '__types', {
                key = keyType,
                value = valueType
            });
        end,
        foreach = function(self, callback)
            local hasStoped = false;
            local iteration = {
                ["stop"] = function()
                    hasStoped = true;
                end,
                ["source"] = self
            };

            for k, v in next, self.__table do
                callback(k, v, iteration);
                if (hasStoped) then
                    break;
                end
            end
        end,
        map = function(self, callback)
            local result = self.class();
            result:setTypes('*', '*');

            local hasStoped = false;
            local iteration = {
                ["stop"] = function()
                    hasStoped = true;
                end,
                ["source"] = self,
                ["target"] = result
            };

            for k, v in next, self.__table do
                result[k] = callback(v, k, iteration);
                if (hasStoped) then
                    break;
                end
            end

            return result;
        end,
        filter = function(self, callback)
            return self:map(function(v, k, iteration)
                return callback(v, k) and v or nil;
            end)
        end,
        sort = function(self, comparator)
            table.sort(self.__table, comparator);
            return self;
        end,
        getKeys = function(self)
            local result = self.class();
            result:setTypes('*', '*');
            self:foreach(function(k, v)
                result:add(result.count + 1, v);
            end)
            return result;
        end,
        getValues = function(self)
            local result = self.class();
            result:setTypes('*', '*');
            self:foreach(function(k, v)
                result:add(result.count + 1, v);
            end)
            return result;
        end,
        concat = function(self, separator)
            local str = "";
            self:foreach(function(k, v)
                str = str .. tostring(v) .. separator;
            end);
            return str:sub(1, #str - #separator);
        end,
        tostring = function(self)
            local str = "{ Dictionary" .. (self.__name ~= "" and " " .. self.__name or "")  .. " ";
            self:foreach(function(k, v)
                str = str ..  string.format("\n    [%s] = %s,", tostring(k), tostring(v));
            end);
            return str .. "\n}";
        end
    },
    constructor = function(self, tableContentOrIndexType, valueType, tableContent)
        if (type(tableContentOrIndexType) == 'string' and type(valueType) == 'string') then
            rawset(self, '__table', tableContent or {});
            self:setTypes(tableContentOrIndexType, valueType);
        else
            rawset(self, '__table', tableContentOrIndexType or {});
            self:setTypes('*', '*');
        end

        rawset(self, '__name', "");
        rawset(self, 'count', #self.__table > 0 and #self.__table or (function()
            local c = 0;
            for k in next, self.__table do
                c = c + 1;
            end
            return c;
        end)());
    end,
    onlyExtendsFromItself = true,
    indexOverload = function(self, key)
        return self.__table[key];
    end,
    metatable = {
        __newindex = function(self, key, value)
            if (self.__types.key ~= '*' and not string.match(self.__types.key, type(key))) then
                error("Index of type \"" .. type(key) .. "\" is not accepted as dictionary" ..  (self.__name ~= "" and ' (' .. self.__name .. ')' or "")  .. " requires it to be " .. self.__types.key .. ".", 2);
            end
            if (self.__types.value ~= '*' and type(value) ~= 'nil' and not string.match(self.__types.value, type(value))) then
                error("Value of type \"" .. type(value) .. "\" is not accepted as dictionary" ..  (self.__name ~= "" and ' (' .. self.__name .. ')' or "")  .. " requires it to be " .. self.__types.value .. ".", 2);
            end

            if (self.__types.key == '*' and type(key) == 'nil') then
                error("Attempt to index nil on a dictionary" ..  (self.__name ~= "" and ' (' .. self.__name .. ')' or "")  .. ".", 2);
            end

            if (type(value) == 'nil' and type(self.__table[key]) ~= 'nil') then
                self.count = self.count - 1;
            elseif (type(value) ~= 'nil' and type(self.__table[key]) == 'nil') then
                self.count = self.count + 1;
            end

            self.__table[key] = value;
        end,
        __tostring = function(self)
            return self:tostring();
        end
    }
}
