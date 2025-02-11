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
    elseif ast.type == "for" then
        local left_str = print_expression(ast.left)
        local start_str = print_expression(ast.start)
        local stop_str = print_expression(ast.stop)
        local step_str = print_expression(ast.step)
        local body_str = print_expression(ast.body)
        return BOLD .. "For: " .. RESET .. left_str .. " = " .. start_str .. " to " .. stop_str .. " step " .. step_str .. BOLD .. "\nDo:\n" .. RESET .. body_str .. BOLD .. ":Close For" .. RESET
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

function ast_walker(ast)
    local result = {start = ast, functions = {}}

    function walker(ast) 
        if ast == nil then
            return 
        end

        if ast.type == "number" then
            return
        elseif ast.type == "string" then
            return 
        elseif ast.type == "boolean" then
            return 
        elseif ast.type == "for" then
            return
        elseif ast.type == "nil" then
            return  
        elseif ast.type == "table" then
            return  
        elseif ast.type == "while" then
            return  
        elseif ast.type == "method" then
            return 
        elseif ast.type == "member" then 
            return 
        elseif ast.type == "index" then
            return
        elseif ast.type == "repeat" then
            return 
        elseif ast.type == "block" then
            return
        elseif ast.type == "if" then
            return 
        elseif ast.type == "elseif" then
            return 
        elseif ast.type == "else" then
            return 
        elseif ast.type == "function" then
            result.functions[ast.value] = ast
            return
        elseif ast.type == "return" then
            return 
        elseif ast.type == "call" then
            return
        elseif ast.type == "parameters" then
            return
        elseif ast.type == "glue" then
            local left_str = walker(ast.left)
            local right_str = walker(ast.right)
            return 
        elseif ast.type == "binary" then
            return
        elseif ast.type == "assignment" then
            return 
        elseif ast.type == "identifier" then
            return
        else
            return
        end
    end

    walker(ast)
    return result
end

-- globals
args = {}
-- 

function main()
    args = read.parse_args()

    local content = read.read_source(args.filename)
    local tokens = tokenizer.tokenize(content, args.filename)
    local ast = parser.parse(tokens)
    tokens = nil

    local ast_walker = ast_walker(ast)
    -- print(print_expression(ast)) 
    -- for _, func in pairs(ast_walker.functions) do
    --     -- print(print_expression(func))
    --     print(func.value.value)
    -- end

end