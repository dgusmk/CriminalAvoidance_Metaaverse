local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local DataStoreService = game:GetService("DataStoreService")
local chatDataStore = DataStoreService:GetDataStore("classifiaction")

-- ä�� ���� �̺�Ʈ ����
local ChatEvent = Instance.new("RemoteEvent")
ChatEvent.Name = "ChatEvent"
ChatEvent.Parent = ReplicatedStorage

-- �˸� ���� �̺�Ʈ ����
local NotifyEvent = Instance.new("RemoteEvent")
NotifyEvent.Name = "NotifyEvent"
NotifyEvent.Parent = ReplicatedStorage

-- URL ���� (Ư�� URL�� ��û)
local API_URL = "https://6949-211-108-77-241.ngrok-free.app/classification" -- API URL�� ���⿡ �Է��ϼ���.

-- ���ѵ� �÷��̾ �����ϴ� ���̺�
local restrictedPlayers = {}

-- ä�� ���� �Լ�
local function restrictPlayer(player)
	restrictedPlayers[player.UserId] = os.time() + 600 -- ���� �ð� + 600�� (10��)
	NotifyEvent:FireClient(player, "You have been muted for 10 minutes due to repeated violations.")
end

-- ���� Ȯ�� �Լ�
local function isPlayerRestricted(player)
	local restrictionTime = restrictedPlayers[player.UserId]
	if restrictionTime then
		if os.time() < restrictionTime then
			return true -- ���� ���� �ð��� ���� ����
		else
			restrictedPlayers[player.UserId] = nil -- ���� ����
		end
	end
	return false
end

-- ä�� ���� �Լ�
local function verifyChat(player, message)
	-- API ��û ���� ����
	local requestBody = HttpService:JSONEncode({
		text = message
	})
	-- ��û ������
	local success, response = pcall(function()
		return HttpService:PostAsync(API_URL, requestBody, Enum.HttpContentType.ApplicationJson)
	end)

	if success then
		local data = HttpService:JSONDecode(response)
		return data.result -- API ���信�� 'result' ���� ��ȯ (0 �Ǵ� 1 ����)
	else
		warn("API ��û ����:", response)
		return nil -- ��û ���� �� nil ��ȯ
	end
end

local function saveChatMessage(player, message, messageType)
	local playerKey = player.UserId -- �÷��̾� ���� Ű ����
	local success, errorMessage = pcall(function()
		-- ������ ����
		local chatData = {
			text = message,
			textType = messageType,
			timestamp = os.time(), -- ���� �ð� �߰� (���� ����)
		}
		chatDataStore:UpdateAsync(playerKey, function(existingData)
			existingData = existingData or {} -- ���� ������ ������ �ʱ�ȭ
			table.insert(existingData, chatData) -- ���ο� �޽��� �߰�

			-- ���� ���� Ȯ��
			local mute = 0
			for _, chat in ipairs(existingData) do
				if chat.textType == "bullying" then
					mute = mute + 1
				elseif chat.textType == "sexual" then
					mute = mute + 1
				end
			end

			if mute > 0 and mute % 5 == 0 then
				restrictPlayer(player)
			end

			return existingData
		end)
	end)

	if success then
		print("ä�� �޽����� ����Ǿ����ϴ�: ", player.Name, message, messageType)
	else
		warn("ä�� �޽��� ���� ����: " .. errorMessage)
	end
end

-- �÷��̾ ä���� �� ȣ��
local function onPlayerChatted(player, message)
	if isPlayerRestricted(player) then
		NotifyEvent:FireClient(player, "You are currently muted. Please wait until the mute period ends.")
		return
	end

	print("������2")
	local result = verifyChat(player, message)
	print("������2")

	if result == 0 then
		-- ä�� ��� �� ��� Ŭ���̾�Ʈ�� ����
		ChatEvent:FireAllClients(player.Name, message)
		print(player.Name .. ": " .. message)
	elseif result == 1 then
		-- ä�� ���� �� ��� �޽��� ����
		NotifyEvent:FireClient(player, "Your message was blocked for violating the rules! Bullying detected.")
		print(player.Name .. "�� �޽����� ���ܵǾ����ϴ�. ����: bullying")
		saveChatMessage(player, message, "bullying")
	elseif result == 2 then
		-- ä�� ���� �� ��� �޽��� ����
		NotifyEvent:FireClient(player, "Your message was blocked for violating the rules! Sexual content detected.")
		print(player.Name .. "�� �޽����� ���ܵǾ����ϴ�. ����: sexual")
		saveChatMessage(player, message, "sexual")
	else
		-- API ��û ���� �� �⺻ ���� (���� ����)
		NotifyEvent:FireClient(player, "Error checking your message. Please try again.")
		print("API ��û ���з� �⺻ �޽��� ó��.")
	end
end

-- �÷��̾ ���ӿ� ���� �� ä�� �̺�Ʈ ����
Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(message)
		onPlayerChatted(player, message)
	end)
end)
