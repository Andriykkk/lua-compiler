local ast = {}

function ast.ast_walker(ast)
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

return ast