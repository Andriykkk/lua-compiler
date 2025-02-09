local tokenizer = {}

function tokenizer.tokenize(input, filename)
    local line = 1
    local column = 1

    local tokens = {}
    local patterns = {
        {"comment", "^%-%-.[^\n]*"},

        -- keywords
        {"keyword", "^(function)[^%s]"},
        {"keyword", "^(local)%s"},
        {"keyword", "^(if)%s"},
        {"keyword", "^(then)%s"},
        {"keyword", "^(else)%s"},
        {"keyword", "^(elseif)%s"},
        {"keyword", "^(end)%s"},
        {"keyword", "^(while)%s"},
        {"keyword", "^(repeat)%s"},
        {"keyword", "^(until)%s"},
        {"keyword", "^(do)%s"},

        -- operators
        {"operator", "^%.%."},
        {"operator", "^=="},
        {"operator", "^<="},
        {"operator", "^>="},
        {"operator", "^~="},
        {"operator", "^[*/=%+%.-%^><]"},
        {"operator", "^(and)%s"},
        {"operator", "^(or)%s"},
        {"operator", "^(not)%s"},

        {"number", "^[+-]?%d+%.?%d*"},

        {"identifier", "^[a-zA-Z_][a-zA-Z0-9_]*"},

        {"delimiter", "^[{}%[%]()%]]"},

        {"string", "^\"[^\"]*\""},

        {"line_break", "^\n"},

        {"whitespace", "^%s+"},
        {"comma", "^,"},
    }

    while #input > 0 do
        local match = false
        for _, pattern in ipairs(patterns) do
            local name, pattern = unpack(pattern)
            local value = input:match(pattern)
            if value then

                -- whitespace
                if name == "whitespace" then
                    column = column + #value
                    input = input:sub(#value + 1)
                    match = true
                    goto continue
                end

                if name == "comment" then
                    input = input:sub(#value + 1)
                    column = column + #value
                    match = true
                    goto continue
                end

                if name == "line_break" then
                    input = input:sub(#value + 1)
                    line = line + 1
                    column = 1
                    match = true
                    if #tokens ~= 0 and tokens[#tokens].type ~= "line_break" then
                        table.insert(tokens, {type = name, value = value, line = line, column = column})
                    end
                    goto continue
                end

                table.insert(tokens, {type = name, value = value, line = line, column = column})
                input = input:sub(#value + 1)
                column = column + #value
                match = true
                break
            end

            ::continue::
        end
        if not match then
            print("Unknown character: " .. filename .. ":" .. line .. ":" .. column .. ": " .. input:sub(1, 1))
            os.exit(1)
        end
    end

    tokens.index = 1
    return tokens
end

return tokenizer