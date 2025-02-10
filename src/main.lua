local tokenizer = require("tokenizer")

local RESET = "\27[0m"
local BOLD = "\27[1m"
local RED = "\27[31m"
local GREEN = "\27[32m"
local BLUE = "\27[34m"

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

function parse(tokens, params)
    local root = { type = "glue" }
    local current = root

    if params == nil then
        params = {}
    end
    while true do
        if tokens[tokens.index] == nil then
            break
        end
        if (tokens[tokens.index].type == "keyword" and tokens[tokens.index].value == "local") or
        (tokens[tokens.index].type == "identifier" and tokens[tokens.index + 1] ~= nil and tokens[tokens.index + 1].type == "operator" and tokens[tokens.index + 1].value == "=") then
            current.right = parse_assignment(tokens)
            current.left = { type = "glue" }
            current = current.left
            goto continue

        elseif params.inside_block and tokens[tokens.index].type == "keyword" and match_token_value(tokens, "end") then
            break
        elseif params.inside_branch and tokens[tokens.index].type == "keyword" and 
            (match_token_value(tokens, "elseif") or match_token_value(tokens, "else")) then
            break
        elseif params.inside_block and tokens[tokens.index].type == "keyword" and match_token_value(tokens, "until") then
            break
        elseif params.inside_branch and tokens[tokens.index].type == "keyword" and match_token_value(tokens, "end") then
            tokens.index = tokens.index + 1
            break

        elseif (match_token_type(tokens, "identifier") and match_token_value(tokens, "(", 1)) then
            current.right = parse_call(tokens)
            current.left = { type = "glue" }
            current = current.left
            goto continue
        elseif match_token_type(tokens, "keyword") and tokens[tokens.index].value == "return" then
            current.right = parse_return(tokens)
            current.left = { type = "glue" }
            current = current.left
            goto continue
        elseif match_token_type(tokens, "keyword") and tokens[tokens.index].value == "do" then
            current.right = parse_block(tokens)
            current.left = { type = "glue" }
            current = current.left
            goto continue
        elseif match_token_type(tokens, "keyword") and tokens[tokens.index].value == "while" then
            current.right = parse_while(tokens)
            current.left = { type = "glue" }
            current = current.left
            goto continue
        elseif match_token_type(tokens, "keyword") and tokens[tokens.index].value == "function" then
            current.right = parse_function(tokens)
            current.left = { type = "glue" }
            current = current.left
            goto continue
        elseif match_token_type(tokens, "keyword") and tokens[tokens.index].value == "repeat" then
            current.right = parse_repeat(tokens)
            current.left = { type = "glue" }
            current = current.left
            goto continue
        elseif match_token_type(tokens, "keyword") and tokens[tokens.index].value == "if" then
            current.right = parse_if_statement(tokens)
            current.left = { type = "glue" }
            current = current.left
            goto continue
        elseif tokens[tokens.index].type == "line_break" then
            tokens.index = tokens.index + 1
            goto continue
        else
            print_parse_error("Parse error", "Unexpected keyword: " .. tokens[tokens.index].value, tokens)
            break        
        end

        ::continue::
    end

    return root
end

function parse_block(tokens)
    local ast_node = {
        type = "block",
    }

    if match_token_value(tokens, "do") then
        tokens.index = tokens.index + 1
    end

    ast_node.body = parse(tokens, {inside_block = true})

    if match_token_value(tokens, "end") then
        tokens.index = tokens.index + 1
    else
        print_parse_error("Parse error", "Expected 'end' but got " .. tokens[tokens.index].value, tokens)
    end

    return ast_node
end

function parse_return(tokens)
    local ast_node = {
        type = "return",
    }

    if match_token_value(tokens, "return") then
        tokens.index = tokens.index + 1
    end

    if match_token_type(tokens, "line_break") then
        tokens.index = tokens.index + 1
        return ast_node
    end

    ast_node.value = parse_expression(tokens, 0)

    return ast_node
end

function parse_repeat(tokens)
    local ast_node = {
        type = "repeat",
        expression = {},
        body = {},
    }

    if match_token_value(tokens, "repeat") then
        tokens.index = tokens.index + 1
    end

    ast_node.body = parse(tokens, {inside_block = true})

    if match_token_value(tokens, "until") then
        tokens.index = tokens.index + 1
    else
        print_parse_error("Parse error", "Expected 'until' but got " .. tokens[tokens.index].value, tokens)
    end

    ast_node.expression = parse_expression(tokens, 0)

    return ast_node

end

function parse_while(tokens)
    local ast_node = {
        type = "while",
        expression = {},
        body = {},
    }

    if match_token_value(tokens, "while") then
        tokens.index = tokens.index + 1
    end

    ast_node.expression = parse_expression(tokens, 0)

    if match_token_type(tokens, "line_break") then
        tokens.index = tokens.index + 1
    end

    if match_token_value(tokens, "do") then
        tokens.index = tokens.index + 1
    else
        print_parse_error("Parse error", "Expected 'do' but got " .. tokens[tokens.index].value, tokens)
    end

    ast_node.body = parse(tokens, {inside_block = true})

    if match_token_value(tokens, "end") then
        tokens.index = tokens.index + 1
    else
        print_parse_error("Parse error", "Expected 'end' but got " .. tokens[tokens.index].value, tokens)
    end

    return ast_node
end

function parse_if_statement(tokens)
    local root ={
        type = "if",
        expression = {},
        body = {},
    }
    local ast_node = root

    if match_token_value(tokens, "if") then
        tokens.index = tokens.index + 1
    end

    ast_node.expression = parse_expression(tokens, 0)

    if match_token_value(tokens, "then") then
        tokens.index = tokens.index + 1
    else
        print_parse_error("Parse error", "Expected 'then' but got " .. tokens[tokens.index].value, tokens)
    end

    ast_node.body = parse(tokens, {inside_branch = true})
    
    while match_token_value(tokens, "elseif") do
        tokens.index = tokens.index + 1
        local elseif_node = {
            type = "elseif",
            expression = parse_expression(tokens, 0),
        }
        
        if match_token_value(tokens, "then") then
            tokens.index = tokens.index + 1
        else
            print_parse_error("Parse error", "Expected 'then' but got " .. tokens[tokens.index].value, tokens)
        end
        
        elseif_node.body = parse(tokens, {inside_branch = true})
        ast_node.else_body = elseif_node
        ast_node = elseif_node
    end

    if match_token_value(tokens, "else") then
        tokens.index = tokens.index + 1

        local else_node = {
            type = "else",
        }

        else_node.body = parse(tokens, {inside_branch = true})
        ast_node.else_body = else_node
        ast_node = else_node
    end

    return root
end

function parse_function(tokens)
    local ast_node = {
        type = "function",
    }

    if match_token_value(tokens, "function") then
        tokens.index = tokens.index + 1
    end

    if match_token_type(tokens, "identifier") then
        ast_node.value = {type = "identifier", value = tokens[tokens.index].value}
        tokens.index = tokens.index + 1
    else
        print_parse_error("Parse error", "Expected identifier but got " .. tokens[tokens.index].value, tokens)
    end

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
    end

    if match_token_value(tokens, ")") then
        tokens.index = tokens.index + 1
    else
        print_parse_error("Parse error", "Expected ')' but got " .. tokens[tokens.index].value, tokens)
    end

    ast_node.body = parse(tokens, {inside_block = true})

    if match_token_value(tokens, "end") then
        tokens.index = tokens.index + 1
    else
        print_parse_error("Parse error", "Expected 'end' but got " .. tokens[tokens.index].value, tokens)
    end

    return ast_node
end


function parse_call(tokens)
    local ast_node = {
        type = "call",
    }

    if match_token_type(tokens, "identifier") then
        ast_node.left = {type = "identifier", value = tokens[tokens.index].value}
        tokens.index = tokens.index + 1
    else
        print_parse_error("Parse error", "Expected identifier but got " .. tokens[tokens.index].value, tokens)
    end

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
        ["or"] = 1,
        ["and"] = 2,
        ["<"] = 3,
        [">"] = 3,
        ["<="] = 3,
        [">="] = 3,
        ["=="] = 3,
        ["~="] = 3,
        [".."] = 4,
        ["+"] = 5,
        ["-"] = 5,
        ["*"] = 6,
        ["/"] = 6,
        ["not"] = 7,
        ["-"] = 8,
        ["^"] = 9,
        ["."] = 10
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
    else
        if tokens[tokens.index].type == "number" then
            left = {type = tokens[tokens.index].type, value = tokens[tokens.index].value}
            tokens.index = tokens.index + 1
        elseif tokens[tokens.index].type == "identifier" then
            left = parse_complex_identifier(tokens)
        else
            print_parse_error("Parse error", "Expected number or identifier but got " .. tokens[tokens.index].value, tokens)
        end
    end

    while true do
        local current_token = tokens[tokens.index]

        if not current_token or tokens[tokens.index].type == "line_break" or match_token_type(tokens, "comma") then
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
        else
            break
        end
    end

    return left 
end

function parse_complex_identifier(tokens)
    local root = {type = "identifier", value = tokens[tokens.index].value}
    tokens.index = tokens.index + 1
    local current_token = tokens[tokens.index]
    
    while true do 
        if current_token.type == "delimiter" and match_token_value(tokens, ".") then
            tokens.index = tokens.index + 1
            if tokens[tokens.index].type == "identifier" then
                root = {type = "member", object = root, property = { type = "identifier", value = tokens[tokens.index].value}}
                tokens.index = tokens.index + 1
            else 
                print_parse_error("Parse error", "Expected identifier but got " .. tokens[tokens.index].value, tokens)
            end
        elseif current_token.type == "delimiter" and match_token_value(tokens, "[") then
            tokens.index = tokens.index + 1
            local index = parse_expression(tokens, 0)

            if match_token_type(tokens, "delimiter") and tokens[tokens.index].value == "]" then
                tokens.index = tokens.index + 1
                root = {type = "index", object = root, index = index} 
            else
                print_parse_error("Parse error", "Expected ']' but got " .. tokens[tokens.index].value, tokens)
            end
        else
            break
        end
    end

    return root
end


-- function parse_expression(tokens, precedence)
--     local left = {}
    
--     if tokens[tokens.index].type == "delimiter" and tokens[tokens.index].value == "(" then
--         tokens.index = tokens.index + 1  
--         left = parse_expression(tokens, 0)  
--         if tokens[tokens.index].type == "delimiter" and tokens[tokens.index].value == ")" then
--             tokens.index = tokens.index + 1  
--             if tokens[tokens.index].type == "line_break" or match_token_type(tokens, "comma") then
--                 return left
--             end

--             local current_token = tokens[tokens.index]
--             local current_precedence = get_precedence(current_token.value, tokens)
--             if current_token.type == "operator" then
--                 local operator = current_token.value
--                 tokens.index = tokens.index + 1

--                 local right = parse_expression(tokens, current_precedence + 1)
--                 left = {type = "binary", left = left, operator = operator, right = right}
--             end
--         else
--             print_parse_error("Parse error", "Expected ')':", tokens)
--         end
--     end

--     if tokens[tokens.index].type == "number" or tokens[tokens.index].type == "identifier" then
--         left = {type = tokens[tokens.index].type, value = tokens[tokens.index].value}
--         tokens.index = tokens.index + 1
--     elseif tokens[tokens.index].type == "line_break" or match_token_type(tokens, "comma") then
--         return left
--     else
--         print_parse_error("Parse error", "Expected number or identifier but got " .. tokens[tokens.index].value, tokens)
--     end
    
--     while true do
--         local current_token = tokens[tokens.index]

--         local current_precedence = get_precedence(current_token.value, tokens)

--         if tokens[tokens.index].type == "line_break" or match_token_type(tokens, "comma") then
--             break
--         end

--         if current_precedence < precedence then
--             break
--         end

--         if current_token.type == "operator" then
--             local operator = current_token.value
--             tokens.index = tokens.index + 1

--             local right = parse_expression(tokens, current_precedence + 1)
--             left = {type = "binary", left = left, operator = operator, right = right}
--         end
--     end

--     return left 
-- end

function print_expression(ast)
    if ast == nil then
        return ""
    end
    
    if ast.type == "number" then
        return tostring(ast.value)
    elseif ast.type == "while" then
        local expression_str = print_expression(ast.expression)
        local body_str = print_expression(ast.body)
        local result = BOLD .. "While: " .. RESET .. expression_str .. BOLD .. "\nDo:\n" .. RESET .. body_str .. ":Close While" .. RESET
        return result
    elseif ast.type == "member" then
        local object_str = print_expression(ast.object)
        local property_str = print_expression(ast.property)
        local result = object_str .. "." .. property_str
        return result
    elseif ast.type == "index" then
        local object_str = print_expression(ast.object)
        local index_str = print_expression(ast.index)
        local result = object_str .. "[" .. index_str .. "]"
        return result
    elseif ast.type == "repeat" then
        local body_str = print_expression(ast.body)
        local expression_str = print_expression(ast.expression)
        local result = BOLD .. "Repeat: " .. RESET .. BOLD .. "\nUntil:\n" .. RESET .. body_str .. ":Close Repeat" .. expression_str .. RESET
        return result
    elseif ast.type == "block" then
        local body_str = print_expression(ast.body)
        local result = BOLD .. "Block:\n" .. RESET .. body_str .. BOLD .. ":Close Block" .. RESET
        return result
    elseif ast.type == "if" then
        local expression_str = print_expression(ast.expression)
        local body_str = print_expression(ast.body)
        local else_body_str = print_expression(ast.else_body)
        local result = BOLD .."If: " .. RESET .. expression_str .. BOLD .. "\nThen:\n" .. RESET .. body_str .. BOLD .. else_body_str
        return result
    elseif ast.type == "elseif" then
        local expression_str = print_expression(ast.expression)
        local body_str = print_expression(ast.body)
        local else_body_str = print_expression(ast.else_body)
        local result = BOLD .. "Elseif: " .. RESET .. expression_str .. BOLD .. "\nThen:\n" .. RESET .. body_str .. BOLD .. else_body_str
        return result
    elseif ast.type == "else" then
        local body_str = print_expression(ast.body)
        local else_body_str = print_expression(ast.else_body)
        local result = BOLD .. "Else:\n" .. RESET .. body_str .. BOLD .. else_body_str
        return result
    elseif ast.type == "function" then
        local body_str = print_expression(ast.body)
        local value = print_expression(ast.value)
        local result = BOLD .. "Function: " .. value .. "\nBody:\n" .. RESET .. body_str .. BOLD .. ":Close Function" .. RESET
        return result
    elseif ast.type == "return" then
        local value = print_expression(ast.value)
        return "Return: " .. value
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
    local tokens = tokenizer.tokenize(content, args.filename)
    local ast = parse(tokens)
    print(print_expression(ast)) 
    -- for i, token in ipairs(tokens) do
    --     print(token.type .. ": " .. token.value)
    -- end

end