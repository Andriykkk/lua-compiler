local tokenizer = require("tokenizer")
local parser = require("parser")
local read = require("read")
local ast_tree = require("ast")

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

function executor(ast)
    local functions = ast.functions
    local standart_functions = {
        print = print
    }
    local start = ast.start

    local current_scope = {father = nil, variables = {}}

    local operators = {
        ['or'] = function(a, b) return a or b end,
        ['and'] = function(a, b) return a and b end,
        ["<"] = function(a, b) return a < b end,
        [">"] = function(a, b) return a > b end,
        ["<="] = function(a, b) return a <= b end,
        [">="] = function(a, b) return a >= b end,
        ["=="] = function(a, b) return a == b end,
        ["~="] = function(a, b) return a ~= b end,
        [".."] = function(a, b) return a .. b end,
        ["+"] = function(a, b) return a + b end,
        ["-"] = function(a, b) return a - b end,
        ["*"] = function(a, b) return a * b end,
        ["/"] = function(a, b) return a / b end,
        ['%'] = function(a, b) return a % b end,
        -- ['not'] = function(a) return not a end,
        -- ['-'] = function(a) return -a end,
        ['^'] = function(a, b) return a ^ b end,
        ['.'] = function(a, b) return a[b] end
    }

    local types = {
        ["number"] = function(value) return value.value end,
        ["string"] = function(value) return value.value end,
        ["call"] = function(ast)
            if standart_functions[ast.left.value] ~= nil then
                local params = {}
                for i, param in ipairs(ast.right.value) do
                    params[i] = walker(param)
                end
                return standart_functions[ast.left.value](unpack(params))
            end
        end,
        ["block"] = function(ast)
            local scope = { father = current_scope, variables = {}}
            current_scope = scope
            local body = walker(ast.body)
            return body
        end,
        ["glue"] = function(ast)
            local right = walker(ast.right)
            local left = walker(ast.left)
            return 
        end,
        ["binary"] = function(ast)
            local left = walker(ast.left)
            local right = walker(ast.right)
            return operators[ast.operator](left, right)
        end,
        ["assignment"] = function(ast)
            -- current_scope[ast.left.value] = ast.left.value
            local left = walker(ast.left)
            local right = walker(ast.right)
            current_scope.variables[left] = right
            return right
        end,
        ["identifier"] = function(ast)
            local scope = current_scope
            local variable = nil
            while scope ~= nil do
                variable = scope.variables[ast.value]
                if variable ~= nil then
                    break
                end
                scope = scope.father
            end
            return variable
        end
    }

    function walker(ast)
        if ast ~=nil then
            return types[ast.type](ast)
        end
    end

    walker(start)
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

    local ast_walker = ast_tree.ast_walker(ast)
    
    -- executor(ast_walker)
    print(print_expression(ast)) 
    -- for i, token in ipairs(tokens) do
    --     print(token.type, token.value)
    -- end
    -- for _, func in pairs(ast_walker.functions) do
    --     -- print(print_expression(func))
    --     print(func.value.value)
    -- end
end