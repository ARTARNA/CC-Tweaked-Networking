local routerID = "Router" .. os.getComputerID()
local routingTable = {} -- Maps destination computerID to next-hop computerID
local neighbors = {} -- Keeps track of neighbor IDs

local assignedAddresses = {}
local nextAddress = 1

function handleDHCPRequest(senderID)
    local address = "192.168." .. os.getComputerID() .. "." .. nextAddress
    assignedAddresses[address] = senderID
    nextAddress = nextAddress + 1
    rednet.send(senderID, address)
end

function handleSendMessage(senderID, message)
    local destinationIP, content = message:match("^(%S+)%s+(.*)$")
    local destinationID = assignedAddresses[destinationIP]
    if destinationID then
        rednet.send(destinationID, content)
    else
        local nextHop = routingTable[destinationIP]
        if nextHop then
            rednet.send(nextHop, message)
        else
            print("Unknown destination:", destinationIP)
        end
    end
end

function handleMessage(senderID, message)
    if message == "DHCP request" then
        handleDHCPRequest(senderID)
    elseif message:find("^192.168.") then
        handleSendMessage(senderID, message)
    else
        -- Handle other message types
    end
end


function handleDiscovery(senderID, message)
    print("Received discovery message:", message, "from:", senderID)
    local senderRouter = message:match("^(%S+)%s*(.*)$")
    if senderRouter and senderRouter ~= routerID then
        -- Update the routing table
        routingTable[senderRouter] = senderID

        -- Forward the discovery message to neighbors
        for _, neighbor in ipairs(neighbors) do
            if neighbor ~= senderID then
                print("Forwarding discovery message to:", neighbor)
                rednet.send(neighbor, message, "networkName")
            end
        end
    end
end

local function broadcastDiscovery()
    local discoveryMessage = routerID
    rednet.broadcast(discoveryMessage, "networkName")
end

local function handleMessage(senderID, message)
    if message:find("^Router") then
        handleDiscovery(senderID, message)
    end
end

local function listenForMessages()
    while true do
        local senderID, message, protocol = rednet.receive()
        if protocol == "networkName" then
            handleMessage(senderID, message)
        end
    end
end

local function printRoutingTable()
    while true do
        os.sleep(5)
        print("Routing Table:")
        for destination, nextHop in pairs(routingTable) do
            print(destination, "->", nextHop)
        end
    end
end

-- Open the rednet interface on all available sides
for _, side in pairs(peripheral.getNames()) do
    if peripheral.getType(side) == "modem" then
        rednet.open(side)
        local neighborID = rednet.lookup("networkName", side)
        if neighborID then
            table.insert(neighbors, neighborID)
        end
    end
end

print("Router ID:", routerID)
print("Neighbors:", table.concat(neighbors, ", "))

-- Initialize the network by broadcasting the router's presence
broadcastDiscovery()

local function periodicBroadcast()
    while true do
        os.sleep(10) -- Wait for 10 seconds
        broadcastDiscovery()
    end
end

-- Add this function to your parallel tasks
parallel.waitForAll(listenForMessages, printRoutingTable, periodicBroadcast)

