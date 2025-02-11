local read = {}

function ends_with(str, ending)
    return string.sub(str, -string.len(ending)) == ending
end

function read.parse_args()
    local args = {}
    for i, arg in ipairs(c_args) do
        if i == 1 then
            args.filename = arg
        end
        -- print("Argument " .. i .. ": " .. arg)
    end
    return args
end

function read.read_source(filename)
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

return read