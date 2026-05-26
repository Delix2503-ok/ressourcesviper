SQL = {}

Require("lib/MySQL.lua", "oxmysql")

--- Creates a table in the database if it does not exist.
-- @param tableName The name of the table to create. Example: {{ name = "identifier", type = "VARCHAR(50)", primary = true }}
-- @param columns A table containing column definitions, where each column is a table with 'name' and 'type'.
---@return nil

function SQL.Create(tableName, columns)
    assert(MySQL, "Tried using module SQL without MySQL being loaded")
    local columnsList = {}
    for i, column in pairs(columns) do
        table.insert(columnsList, string.format("%s %s", column.name, column.type))
    end

    local query = string.format("CREATE TABLE IF NOT EXISTS %s (%s);",
        tableName,
        table.concat(columnsList, ", ")
    )

    MySQL.query.await(query)
end

--  insert if not exist otherwise update
function SQL.InsertOrUpdate(tableName, data)
    assert(MySQL, "Tried using module SQL without MySQL being loaded")
    local columns = {}
    local values = {}
    local updates = {}

    for column, value in pairs(data) do
        table.insert(columns, column)
        table.insert(values, "'" .. value .. "'")                      -- Ensure values are properly quoted
        table.insert(updates, column .. " = VALUES(" .. column .. ")") -- Use VALUES() for update
    end

    local query = string.format(
        "INSERT INTO %s (%s) VALUES (%s) ON DUPLICATE KEY UPDATE %s;",
        tableName,
        table.concat(columns, ", "),
        table.concat(values, ", "),
        table.concat(updates, ", ")
    )

    MySQL.query.await(query)
end

function SQL.Get(tableName, where)
    assert(MySQL, "Tried using module SQL without MySQL being loaded")
    local query = string.format("SELECT * FROM %s WHERE %s;", tableName, where)
    local result = MySQL.query.await(query)
    return result
end

function SQL.GetAll(tableName)
    assert(MySQL, "Tried using module SQL without MySQL being loaded")
    local query = string.format("SELECT * FROM %s;", tableName)
    local result = MySQL.query.await(query)
    return result
end

function SQL.Delete(tableName, where)
    assert(MySQL, "Tried using module SQL without MySQL being loaded")
    local query = string.format("DELETE FROM %s WHERE %s;", tableName, where)
    MySQL.query.await(query)
end

exports('SQL', function()
    return SQL
end)

return SQL
