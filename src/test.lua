-- local x = x.g[5].h < some:print(15)[5] + 'sdf'
local x = {something = "something",
            something2 = {
                something3 = "something4"
            },
            ["string"] = "string",
                fields = {
                    key = "string",
                    {
                        key = { type = "string", value = "c" },
                        value = { type = "number", value = 2 }
                    },
                    {
                        key = { type = "string", value = "d" },
                        value = { type = "number", value = 3 }
                    }
                }
        }
local x = {
    type = "table",
    fields = {
        some = {
            key = { type = "string", value = "a" },
            value = { type = "number", value = 1 }
        },
        some = {
            key = { type = "string", value = "b" },
            value = {
                type = "table",
                fields = {
                    {
                        key = { type = "string", value = "c" },
                        value = { type = "number", value = 2 }
                    },
                    {
                        key = { type = "string", value = "d" },
                        value = { type = "number", value = 3 }
                    }
                }
            }
        },
        {
            key = { type = "number", value = 4 },
            value = { type = "number", value = 5 }
        }
    }
}
function print(a, b, c)
    some(a, b, c)
    do
        some(a, b, c)
        some(a, b, c)
    end
end
repeat
    if x.g[5].h > 10 then
        print(1, 2, 2 / 5)
    else
        print(5)
    end
until x > 10
some:print(15)
print(3)