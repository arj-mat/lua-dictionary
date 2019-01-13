--[[
    Lua Dictionary
    https://github.com/arj-mat/lua-dictionary
    This source code is licensed under the MIT license found in the LICENSE file in the root directory of this source tree. 
]]

if not(define) then
    require "lua-defs"; -- https://github.com/arj-mat/lua-defs
end

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
            local result = Dictionary();

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
            return self:map(function(v, k)
                return callback(v, k) and v or nil;
            end)
        end,
        sort = function(self, comparator)
            table.sort(self.__table, comparator);
        end,
        getKeys = function(self)
            local result = {};
            self:foreach(function(k, v)
                table.insert(result, k);
            end)
            return result;
        end,
        getValues = function(self)
            local result = {};
            self:foreach(function(k, v)
                table.insert(result, v);
            end)
            return result;
        end,
        tostring = function(self)
            local str = "{ Dictionary" .. (self.name ~= "" and " " .. self.name or "")  .. " ";
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

        rawset(self, 'name', "");
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
                error("Index of type \"" .. type(key) .. "\" is not accepted as dictionary" ..  (self.name ~= "" and ' (' .. self.name .. ')' or "")  .. " requires it to be " .. self.__types.key .. ".", 2);
            end
            if (self.__types.value ~= '*' and type(value) ~= 'nil' and not string.match(self.__types.value, type(value))) then
                error("Value of type \"" .. type(value) .. "\" is not accepted as dictionary" ..  (self.name ~= "" and ' (' .. self.name .. ')' or "")  .. " requires it to be " .. self.__types.value .. ".", 2);
            end

            if (self.__types.key == '*' and type(key) == 'nil') then
                error("Attempt to index nil on a dictionary" ..  (self.name ~= "" and ' (' .. self.name .. ')' or "")  .. ".", 2);
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
