function tokenize(input, filename)
    local line = 1
    local column = 1

    local tokens = {}
    local patterns = {
        -- keywords
        {"keyword", "^(function)[^%s]"},
        {"keyword", "^(local)%s"},

        {"number", "^[+-]?%d+%.?%d*"},

        {"identifier", "^[a-zA-Z_][a-zA-Z0-9_]*"},

        {"comment", "^^--[^\n]*"},

        {"delimiter", "^[{}%[%]()%]]"},

        {"string", "^\"[^\"]*\""},

        {"concat", "^%.%."},

        -- operators
        {"operator", "^=="},
        {"operator", "^[*/=%+-%.]"},

        {"line_break", "^\n"},

        {"whitespace", "^%s+"},
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
                    table.insert(tokens, {type = name, value = value, line = line, column = column})
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

function print_parse_error(error, message, tokens)
    print(error .. " " .. args.filename .. ":" .. tokens[tokens.index].line .. ":" .. tokens[tokens.index].column .. ": " .. message)
    os.exit(1)
end

function parse(tokens)
    local ast = {}
    -- parse assignment
    if (tokens[tokens.index].type == "keyword" and tokens[tokens.index].value == "local") or
    (tokens[tokens.index].type == "identifier" and tokens[tokens.index + 1].type == "operator" and tokens[tokens.index + 1].value == "=") then
        return parse_assignment(tokens, ast)
    end
end

function parse_assignment(tokens)
    local ast_node = {
        type = "assignment",
    }

    if tokens[tokens.index].value == "local" then
        tokens.index = tokens.index + 1
    end

    ast_node.left = {type = "identifier", value = tokens[tokens.index].value}
    tokens.index = tokens.index + 1

    if tokens[tokens.index].value == "=" then
        tokens.index = tokens.index + 1
    else
        print_parse_error("Parse error", "Expected '=' but got " .. tokens[tokens.index].value, tokens)
    end

    ast_node.right = parse_expression(tokens, 1)

    return ast_node
end

function parse_infix(left, tokens)
    
end

function get_precedence(token, tokens)
    local precedence_table = {
        ["+"] = 1,
        ["-"] = 1,
        ["*"] = 2,
        ["/"] = 2,
        ["."] = 7
    }
    if precedence_table[token] then
        return precedence_table[token]
    else
        print_parse_error("Parse error", "Unknown operator in expression: " .. token, tokens)
    end
end

function parse_expression(tokens, precedence)
    local left = {}
    if tokens[tokens.index].type == "delimiter" and tokens[tokens.index].value == "(" then
        tokens.index = tokens.index + 1  
        left = parse_expression(tokens, 0)  
        if tokens[tokens.index].type == "delimiter" and tokens[tokens.index].value == ")" then
            tokens.index = tokens.index + 1  
        else
            print_parse_error("Parse error", "Expected ')':", tokens)
        end
    end

    if tokens[tokens.index].type == "number" or tokens[tokens.index].type == "identifier" then
        left = {type = tokens[tokens.index].type, value = tokens[tokens.index].value}
        tokens.index = tokens.index + 1
    end

    while true do
        local current_token = tokens[tokens.index]
        if current_token.type == "line_break" then
            break
        end
        local current_precedence = get_precedence(current_token.value, tokens)

        if current_precedence < precedence then
            break
        end

        if current_token.type == "operator" then
            local operator = current_token.value
            tokens.index = tokens.index + 1

            local right = parse_expression(tokens, current_precedence + 1)
            left = {type = "binary", left = left, operator = operator, right = right}
        end
    end

    return left 
end

function print_expression(ast)
    if ast.type == "number" then
        return tostring(ast.value)
    elseif ast.type == "binary" then
        local left = print_expression(ast.left)
        local right = print_expression(ast.right)
        
        return "(" .. left .. " " .. ast.operator .. " " .. right .. ")"
    elseif ast.type == "assignment" then
        local left = print_expression(ast.left)
        local right = print_expression(ast.right)
        return left .. " = " .. right
    elseif ast.type == "identifier" then
        return ast.value
    else
        return ""
    end
end


function ends_with(str, ending)
    return string.sub(str, -string.len(ending)) == ending
end

function parse_args()
    local args = {}
    for i, arg in ipairs(c_args) do
        if i == 1 then
            args.filename = arg
        end
        -- print("Argument " .. i .. ": " .. arg)
    end
    return args
end

function read_source(filename)
    if filename == nil then
        print("Usage: ./main <filename>")
        return
    end

    local input
    if ends_with(filename, ".lua") then
        input = io.open(filename, "r")
    else
        args.filename = filename .. ".lua"
        input = io.open(filename .. ".lua", "r")
    end

    if input == nil then
        print("File not found: " .. filename)
        return
    end

    local content = input:read("*a")
    input:close()
    return content
end

-- globals
args = {}
-- 



function main()
    args = parse_args()

    local content = read_source(args.filename)
    local tokens = tokenize(content, args.filename)
    local ast = parse(tokens)
    print(print_expression(ast)) 
end