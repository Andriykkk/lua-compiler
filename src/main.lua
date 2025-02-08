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

function peek_token_type(tokens, shift)
    local index = tokens.index
    if shift ~= nil then
        index = index + shift
    end
    return tokens[index].type
end

function match_token_type(tokens, type, shift)
    if type ~= peek_token_type(tokens, shift) then
        return false
    else
        return true
    end
end

function peek_token_value(tokens, shift)
    local index = tokens.index
    if shift ~= nil then
        index = index + shift
    end
    return tokens[index].value
end

function match_token_value(tokens, value, shift)
    if value ~= peek_token_value(tokens, shift) then
        return false
    else
        return true
    end
end

function parse(tokens)
    local root = { type = "glue" }
    local current = root

    while true do
        if (tokens[tokens.index].type == "keyword" and tokens[tokens.index].value == "local") or
        (tokens[tokens.index].type == "identifier" and tokens[tokens.index + 1].type == "operator" and tokens[tokens.index + 1].value == "=") then
            current.right = parse_assignment(tokens)
            current.left = { type = "glue" }
            current = current.left
        end

        if (match_token_type(tokens, "identifier") and match_token_value(tokens, "(", 1)) then
            current.right = parse_call(tokens)
            current.left = { type = "glue" }
            current = current.left
        end
        
        if tokens[tokens.index].type == "line_break" then
            tokens.index = tokens.index + 1
        end
        
        if tokens.index >= #tokens then
            break
        end
    end

    return root
end

function parse_call(tokens)
    local ast_node = {
        type = "call",
    }

    ast_node.left = {type = "identifier", value = tokens[tokens.index].value}
    tokens.index = tokens.index + 1

    if match_token_value(tokens, "(") then
        tokens.index = tokens.index + 1
    else
        print_parse_error("Parse error", "Expected '(' but got " .. tokens[tokens.index + 1].value, tokens)
    end

    local start = true
    ast_node.right = {type="parameters", value = {}}

    while match_token_value(tokens, ",", 0) or start do
        start = false
        if match_token_value(tokens, ",", 0) then
            tokens.index = tokens.index + 1
        end
            

        ast_node.right.value[#ast_node.right.value + 1] = parse_expression(tokens, 1)
        -- table.insert(ast_node.right.value, parse_expression(tokens, 1))
    end

    if match_token_value(tokens, ")") then
        tokens.index = tokens.index + 1
    else
        print_parse_error("Parse error", "Expected ')' but got " .. tokens[tokens.index].value, tokens)
    end

    return ast_node
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
        return -1
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
    else
        print_parse_error("Parse error", "Expected number or identifier but got " .. tokens[tokens.index].value, tokens)
    end
    
    while true do
        local current_token = tokens[tokens.index]

        local current_precedence = get_precedence(current_token.value, tokens)

        if tokens[tokens.index].type == "line_break" or match_token_type(tokens, "comma") then
            break
        end

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
    if ast == nil then
        return ""
    end
    
    if ast.type == "number" then
        return tostring(ast.value)
    elseif ast.type == "call" then
        local left_str = print_expression(ast.left)
        local right_str = print_expression(ast.right)
        return "Call: " .. left_str .. " " .. right_str
    elseif ast.type == "parameters" then
        local right_str = ""
        for i, param in ipairs(ast.value) do
            right_str = right_str .. print_expression(param) .. (ast.value[i + 1] ~= nil and ", " or "")
        end
        return right_str
    elseif ast.type == "glue" then
        local left_str = print_expression(ast.left)
        local right_str = print_expression(ast.right)
        return right_str .. (right_str ~= "" and "\n" or "") .. left_str
    elseif ast.type == "binary" then
        local left = print_expression(ast.left)
        local right = print_expression(ast.right)
        
        return "(" .. left .. " " .. ast.operator .. " " .. right .. ")"
    elseif ast.type == "assignment" then
        local left = print_expression(ast.left)
        local right = print_expression(ast.right)
        return "Assign: " .. left .. " = " .. right
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