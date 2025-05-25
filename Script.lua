local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local DataStoreService = game:GetService("DataStoreService")
local chatDataStore = DataStoreService:GetDataStore("classifiaction")

-- 채팅 감지 이벤트 생성
local ChatEvent = Instance.new("RemoteEvent")
ChatEvent.Name = "ChatEvent"
ChatEvent.Parent = ReplicatedStorage

-- 알림 전송 이벤트 생성
local NotifyEvent = Instance.new("RemoteEvent")
NotifyEvent.Name = "NotifyEvent"
NotifyEvent.Parent = ReplicatedStorage

-- URL 설정 (특정 URL로 요청)
local API_URL = "https://6949-211-108-77-241.ngrok-free.app/classification" -- API URL을 여기에 입력하세요.

-- 제한된 플레이어를 저장하는 테이블
local restrictedPlayers = {}

-- 채팅 제한 함수
local function restrictPlayer(player)
	restrictedPlayers[player.UserId] = os.time() + 600 -- 현재 시간 + 600초 (10분)
	NotifyEvent:FireClient(player, "You have been muted for 10 minutes due to repeated violations.")
end

-- 제한 확인 함수
local function isPlayerRestricted(player)
	local restrictionTime = restrictedPlayers[player.UserId]
	if restrictionTime then
		if os.time() < restrictionTime then
			return true -- 아직 제한 시간이 남아 있음
		else
			restrictedPlayers[player.UserId] = nil -- 제한 해제
		end
	end
	return false
end

-- 채팅 검증 함수
local function verifyChat(player, message)
	-- API 요청 본문 생성
	local requestBody = HttpService:JSONEncode({
		text = message
	})
	-- 요청 보내기
	local success, response = pcall(function()
		return HttpService:PostAsync(API_URL, requestBody, Enum.HttpContentType.ApplicationJson)
	end)

	if success then
		local data = HttpService:JSONDecode(response)
		return data.result -- API 응답에서 'result' 값을 반환 (0 또는 1 예상)
	else
		warn("API 요청 실패:", response)
		return nil -- 요청 실패 시 nil 반환
	end
end

local function saveChatMessage(player, message, messageType)
	local playerKey = player.UserId -- 플레이어 고유 키 생성
	local success, errorMessage = pcall(function()
		-- 데이터 저장
		local chatData = {
			text = message,
			textType = messageType,
			timestamp = os.time(), -- 저장 시간 추가 (선택 사항)
		}
		chatDataStore:UpdateAsync(playerKey, function(existingData)
			existingData = existingData or {} -- 기존 데이터 없으면 초기화
			table.insert(existingData, chatData) -- 새로운 메시지 추가

			-- 제한 조건 확인
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
		print("채팅 메시지가 저장되었습니다: ", player.Name, message, messageType)
	else
		warn("채팅 메시지 저장 실패: " .. errorMessage)
	end
end

-- 플레이어가 채팅할 때 호출
local function onPlayerChatted(player, message)
	if isPlayerRestricted(player) then
		NotifyEvent:FireClient(player, "You are currently muted. Please wait until the mute period ends.")
		return
	end

	print("진행중2")
	local result = verifyChat(player, message)
	print("진행중2")

	if result == 0 then
		-- 채팅 허용 및 모든 클라이언트에 전달
		ChatEvent:FireAllClients(player.Name, message)
		print(player.Name .. ": " .. message)
	elseif result == 1 then
		-- 채팅 차단 및 경고 메시지 전송
		NotifyEvent:FireClient(player, "Your message was blocked for violating the rules! Bullying detected.")
		print(player.Name .. "의 메시지가 차단되었습니다. 사유: bullying")
		saveChatMessage(player, message, "bullying")
	elseif result == 2 then
		-- 채팅 차단 및 경고 메시지 전송
		NotifyEvent:FireClient(player, "Your message was blocked for violating the rules! Sexual content detected.")
		print(player.Name .. "의 메시지가 차단되었습니다. 사유: sexual")
		saveChatMessage(player, message, "sexual")
	else
		-- API 요청 실패 시 기본 동작 (선택 사항)
		NotifyEvent:FireClient(player, "Error checking your message. Please try again.")
		print("API 요청 실패로 기본 메시지 처리.")
	end
end

-- 플레이어가 게임에 들어올 때 채팅 이벤트 연결
Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(message)
		onPlayerChatted(player, message)
	end)
end)
