local parser = {}

-- UTILS
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

function parse_parameters(tokens, ast_node)
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
        elseif current_token.type == "delimiter" and match_token_value(tokens, ":") then
            tokens.index = tokens.index + 1
            if tokens[tokens.index].type == "identifier" then
                local method = { type = "call", value = tokens[tokens.index].value}
                method.left = {type = "identifier", value = tokens[tokens.index].value}
                tokens.index = tokens.index + 1
                parse_parameters(tokens, method)

                root = {type = "method", object = root, method = method}
            else
                print_parse_error("Parse error", "Expected identifier but got " .. tokens[tokens.index].value, tokens)
            end
        else
            break
        end
    end

    return root
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
        if tokens[tokens.index].type == "number" or tokens[tokens.index].type == "string"
        or tokens[tokens.index].type == "boolean" or tokens[tokens.index].type == "nil" then
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
-- UTILS

function parser.parse_return(tokens)
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

function parser.parse_repeat(tokens)
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

function parser.parse_while(tokens)
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

function parser.parse_function(tokens)
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

function parser.parse_block(tokens)
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

function parser.parse_if_statement(tokens)
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

function parser.parse_call(tokens)
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

function parser.parse_assignment(tokens)
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

parser.parse_expression = parse_expression

return parser