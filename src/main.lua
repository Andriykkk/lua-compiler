local tokenizer = require("tokenizer")
local parser = require("parser")
local read = require("read")

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
    if tokens[index] == nil then
        print_parse_error("Parse error", "Unexpected end of file", tokens)
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
    if tokens[index] == nil then
        print_parse_error("Parse error", "Unexpected end of file", tokens)
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
            if match_token_type(tokens, "keyword") and tokens[tokens.index].value == "local" then
                tokens.index = tokens.index + 1
            end
            if match_token_type(tokens, "delimiter", 2) and match_token_value(tokens, "{", 2) then
                tokens.index = tokens.index + 2
                current.right = parse_table(tokens)
                current.left = { type = "glue" }
                current = current.left
                goto continue
            end
            current.right = parser.parse_assignment(tokens)
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
            current.right = parser.parse_call(tokens)
            current.left = { type = "glue" }
            current = current.left
            goto continue
        elseif match_token_type(tokens, "keyword") and tokens[tokens.index].value == "return" then
            current.right = parser.parse_return(tokens)
            current.left = { type = "glue" }
            current = current.left
            goto continue
        elseif match_token_type(tokens, "keyword") and tokens[tokens.index].value == "do" then
            current.right = parser.parse_block(tokens)
            current.left = { type = "glue" }
            current = current.left
            goto continue
        elseif match_token_type(tokens, "keyword") and tokens[tokens.index].value == "while" then
            current.right = parser.parse_while(tokens)
            current.left = { type = "glue" }
            current = current.left
            goto continue
        elseif match_token_type(tokens, "keyword") and tokens[tokens.index].value == "function" then
            current.right = parser.parse_function(tokens)
            current.left = { type = "glue" }
            current = current.left
            goto continue
        elseif match_token_type(tokens, "keyword") and tokens[tokens.index].value == "repeat" then
            current.right = parser.parse_repeat(tokens)
            current.left = { type = "glue" }
            current = current.left
            goto continue
        elseif match_token_type(tokens, "keyword") and tokens[tokens.index].value == "if" then
            current.right = parser.parse_if_statement(tokens)
            current.left = { type = "glue" }
            current = current.left
            goto continue
        elseif match_token_type(tokens, "identifier") and match_token_type(tokens, "delimiter", 1) and 
        match_token_value(tokens, ":", 1) then
            current.right = parser.parse_expression(tokens, 0)
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

function parse_table(tokens, params)
    if params == nil then
        params = {}
    end
    local root = { type = "table", fields = {} }

    if  match_token_type(tokens, "delimiter") and match_token_value(tokens, "{") then
        tokens.index = tokens.index + 1
    else 
        print_parse_error("Parse error", "Expected '{' but got " .. tokens[tokens.index].value, tokens)
    end

    local implicit_key = 1

    while true do 
        local current_token = tokens[tokens.index]

        if match_token_type(tokens, "line_break") then
            tokens.index = tokens.index + 1
        end

        if match_token_type(tokens, "delimiter") and match_token_value(tokens, "}") then
            tokens.index = tokens.index + 1
            break
        end

        local field = {}
        
        if match_token_type(tokens, "identifier") then
            field.key = {type="identifier", value=tokens[tokens.index].value}
            tokens.index = tokens.index + 1

            if match_token_type(tokens, "operator") and match_token_value(tokens, "=") then
                tokens.index = tokens.index + 1
            else 
                print_parse_error("Parse error", "Expected '=' but got " .. tokens[tokens.index].value, tokens)
            end
        elseif match_token_type(tokens, "delimiter") and match_token_value(tokens, "[") then
            tokens.index = tokens.index + 1
            field.key = parse_expression(tokens, 0)
            
            if match_token_type(tokens, "delimiter") and match_token_value(tokens, "]") then
                tokens.index = tokens.index + 1
            else
                print_parse_error("Parse error", "Expected ']' but got " .. tokens[tokens.index].value, tokens)
            end

            if match_token_type(tokens, "operator") and match_token_value(tokens, "=") then
                tokens.index = tokens.index + 1
            else
                print_parse_error("Parse error", "Expected '=' but got " .. tokens[tokens.index].value, tokens)
            end
        elseif match_token_type(tokens, "delimiter") and match_token_value(tokens, "{") then
            field.key = { type = "number", value = implicit_key }
            implicit_key = implicit_key + 1
        else
            print_parse_error("Parse error", "Expected identifier or '[' but got " .. tokens[tokens.index].value, tokens)
        end
        
        if match_token_type(tokens, "delimiter") and match_token_value(tokens, "{") then
            field.value = parse_table(tokens)
        else
            field.value = parse_expression(tokens, 0)
        end

        root.fields[#root.fields + 1] = field
        
        -- if match_token_type(tokens, "delimiter") and (match_token_value(tokens, ",") or
        -- match_token_value(tokens, ";")) then
        --     tokens.index = tokens.index + 1
        -- end 
        if match_token_type(tokens, "delimiter") and (match_token_value(tokens, ",") or match_token_value(tokens, ";")) then
            tokens.index = tokens.index + 1
        elseif not (match_token_type(tokens, "delimiter") and match_token_value(tokens, "}")) then
            -- If the next token is not a comma or the end of the table, raise an error
            print_parse_error("Parse error", "Expected ',' or '}' but got " .. tokens[tokens.index].value, tokens)
        end
    end

    return root
end

function print_expression(ast)
    if ast == nil then
        return ""
    end
    
    if ast.type == "number" then
        return tostring(ast.value)
    elseif ast.type == "string" then
        return ast.value
    elseif ast.type == "boolean" then
        return ast.value
    elseif ast.type == "nil" then
        return "nil"
    elseif ast.type == "table" then
        local fields_str = ""
        for _, field in ipairs(ast.fields) do
            local key_str = print_expression(field.key)
            local value_str = print_expression(field.value)
            fields_str = fields_str .. key_str .. " = " .. value_str .. "\n"
        end
        return  BOLD .. "Table: \n" .. RESET .. fields_str .. BOLD .. ":Close Table" .. RESET
    elseif ast.type == "while" then
        local expression_str = print_expression(ast.expression)
        local body_str = print_expression(ast.body)
        local result = BOLD .. "While: " .. RESET .. expression_str .. BOLD .. "\nDo:\n" .. RESET .. body_str .. ":Close While" .. RESET
        return result
    elseif ast.type == "method" then
        local object_str = print_expression(ast.object)
        local method_str = print_expression(ast.method)
        local result = object_str .. ":" .. method_str
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
        return "Call: " .. left_str .. " (" .. right_str .. ")"
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

-- globals
args = {}
-- 

function main()
    args = read.parse_args()

    local content = read.read_source(args.filename)
    local tokens = tokenizer.tokenize(content, args.filename)
    local ast = parse(tokens)
    print(print_expression(ast)) 
    -- for i, token in ipairs(tokens) do
    --     print(token.type .. ": " .. token.value)
    -- end

end