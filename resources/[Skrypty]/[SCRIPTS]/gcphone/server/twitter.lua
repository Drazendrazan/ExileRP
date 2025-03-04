--====================================================================================
-- #Author: Jonathan D @ Gannon
--====================================================================================
local ESX = nil
TriggerEvent('esx:getShtestaredObjtestect', function(obj) 
    ESX = obj 
end)

function TwitterGetTweets (accountId, cb)
  if accountId == nil then
    MySQL.Async.fetchAll([===[
      SELECT twitter_tweets.*,
        twitter_accounts.username as author,
        twitter_accounts.avatar_url as authorIcon
      FROM twitter_tweets
        LEFT JOIN twitter_accounts
        ON twitter_tweets.authorId = twitter_accounts.id
      ORDER BY time DESC LIMIT 130
      ]===], {}, cb)
  else
    MySQL.Async.fetchAll([===[
      SELECT twitter_tweets.*,
        twitter_accounts.username as author,
        twitter_accounts.avatar_url as authorIcon,
        twitter_likes.id AS isLikes
      FROM twitter_tweets
        LEFT JOIN twitter_accounts
          ON twitter_tweets.authorId = twitter_accounts.id
        LEFT JOIN twitter_likes
          ON twitter_tweets.id = twitter_likes.tweetId AND twitter_likes.authorId = @accountId
      ORDER BY time DESC LIMIT 130
    ]===], { ['@accountId'] = accountId }, cb)
  end
end

function TwitterGetFavotireTweets (accountId, cb)
  if accountId == nil then
    MySQL.Async.fetchAll([===[
      SELECT twitter_tweets.*,
        twitter_accounts.username as author,
        twitter_accounts.avatar_url as authorIcon
      FROM twitter_tweets
        LEFT JOIN twitter_accounts
          ON twitter_tweets.authorId = twitter_accounts.id
      WHERE twitter_tweets.TIME > CURRENT_TIMESTAMP() - INTERVAL '15' DAY
      ORDER BY likes DESC, TIME DESC LIMIT 30
    ]===], {}, cb)
  else
    MySQL.Async.fetchAll([===[
      SELECT twitter_tweets.*,
        twitter_accounts.username as author,
        twitter_accounts.avatar_url as authorIcon,
        twitter_likes.id AS isLikes
      FROM twitter_tweets
        LEFT JOIN twitter_accounts
          ON twitter_tweets.authorId = twitter_accounts.id
        LEFT JOIN twitter_likes
          ON twitter_tweets.id = twitter_likes.tweetId AND twitter_likes.authorId = @accountId
      WHERE twitter_tweets.TIME > CURRENT_TIMESTAMP() - INTERVAL '15' DAY
      ORDER BY likes DESC, TIME DESC LIMIT 30
    ]===], { ['@accountId'] = accountId }, cb)
  end
end

function getUser(username, password, cb)
  MySQL.Async.fetchAll("SELECT id, username as author, avatar_url as authorIcon FROM twitter_accounts WHERE twitter_accounts.username = @username AND twitter_accounts.password = @password", {
    ['@username'] = username,
    ['@password'] = password
  }, function (data)
    cb(data[1])
  end)
end

function TwitterPostTweet(username, password, message, sourcePlayer, realUser, cb)
	local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)		
	getUser(username, password, function (user)
		if user == nil then
			if sourcePlayer ~= nil then
				TriggerClientEvent("route68:shownotif", sourcePlayer,"Nieprawidłowy Login lub Hasło!")
			end
			return
		end
		MySQL.Async.insert("INSERT INTO twitter_tweets (`authorId`, `message`, `realUser`) VALUES(@authorId, @message, @realUser);", {
			['@authorId'] = user.id,
			['@message'] = message,
			['@realUser'] = realUser
		}, function (id)
			MySQL.Async.fetchAll('SELECT * from twitter_tweets WHERE id = @id', {
				['@id'] = id
			}, function (tweets)
				tweet = tweets[1]
				tweet['author'] = user.author
				tweet['authorIcon'] = user.authorIcon
				TriggerClientEvent('gcPhone:twitter_newTweets', -1, tweet)
				TriggerEvent('gcPhone:twitter_newTweets', tweet)
				TriggerClientEvent('gcPhone:nowyPost', -1, username, message)
			end)
		end)
	end)
end

function TwitterToogleLike (username, password, tweetId, sourcePlayer)
  getUser(username, password, function (user)
    if user == nil then
      if sourcePlayer ~= nil then
		TriggerClientEvent("route68:shownotif", sourcePlayer,"Nieprawidłowy Login lub Hasło!")
      end
      return
    end
    MySQL.Async.fetchAll('SELECT * FROM twitter_tweets WHERE id = @id', {
      ['@id'] = tweetId
    }, function (tweets)
      if (tweets[1] == nil) then return end
      local tweet = tweets[1]
      MySQL.Async.fetchAll('SELECT * FROM twitter_likes WHERE authorId = @authorId AND tweetId = @tweetId', {
        ['authorId'] = user.id,
        ['tweetId'] = tweetId
      }, function (row)
        if (row[1] == nil) then
          MySQL.Async.insert('INSERT INTO twitter_likes (`authorId`, `tweetId`) VALUES(@authorId, @tweetId)', {
            ['authorId'] = user.id,
            ['tweetId'] = tweetId
          }, function (newrow)
            MySQL.Async.execute('UPDATE `twitter_tweets` SET `likes`= likes + 1 WHERE id = @id', {
              ['@id'] = tweet.id
            }, function ()
              TriggerClientEvent('gcPhone:twitter_updateTweetLikes', -1, tweet.id, tweet.likes + 1)
              TriggerClientEvent('gcPhone:twitter_setTweetLikes', sourcePlayer, tweet.id, true)
              TriggerEvent('gcPhone:twitter_updateTweetLikes', tweet.id, tweet.likes + 1)
            end)
          end)
        else
          MySQL.Async.execute('DELETE FROM twitter_likes WHERE id = @id', {
            ['@id'] = row[1].id,
          }, function (newrow)
            MySQL.Async.execute('UPDATE `twitter_tweets` SET `likes`= likes - 1 WHERE id = @id', {
              ['@id'] = tweet.id
            }, function ()
              TriggerClientEvent('gcPhone:twitter_updateTweetLikes', -1, tweet.id, tweet.likes - 1)
              TriggerClientEvent('gcPhone:twitter_setTweetLikes', sourcePlayer, tweet.id, false)
              TriggerEvent('gcPhone:twitter_updateTweetLikes', tweet.id, tweet.likes - 1)
            end)
          end)
        end
      end)
    end)
  end)
end

function TwitterCreateAccount(username, password, avatarUrl, cb)
  if avatarUrl == '' or avatarUrl == 'https://imgur.com/' or avatarUrl == 'https://i.imgur.com/' or avatarUrl == nil then 
  MySQL.Async.insert('INSERT IGNORE INTO twitter_accounts (`username`, `password`, `avatar_url`) VALUES(@username, @password, @avatarUrl)', {
    ['username'] = username,
    ['password'] = password,
    ['avatarUrl'] = 'https://imgur.com/Ox2VyCo.png'
  }, cb)
  else
  MySQL.Async.insert('INSERT IGNORE INTO twitter_accounts (`username`, `password`, `avatar_url`) VALUES(@username, @password, @avatarUrl)', {
    ['username'] = username,
    ['password'] = password,
    ['avatarUrl'] = avatarUrl
  }, cb)
  end
end
-- ALTER TABLE `twitter_accounts`	CHANGE COLUMN `username` `username` VARCHAR(50) NOT NULL DEFAULT '0' COLLATE 'utf8_general_ci';

function TwitterShowError (sourcePlayer, title, message)
  TriggerClientEvent('gcPhone:twitter_showError', sourcePlayer, message)
end
function TwitterShowSuccess (sourcePlayer, title, message)
  TriggerClientEvent('gcPhone:twitter_showSuccess', sourcePlayer, title, message)
end

RegisterServerEvent('gcPhone:twitter_login')
AddEventHandler('gcPhone:twitter_login', function(username, password)
  local sourcePlayer = tonumber(source)
  getUser(username, password, function (user)
    if user == nil then
	  TriggerClientEvent("route68:shownotif", sourcePlayer,"Nieprawidłowy Login lub Hasło!")
    else
	  TriggerClientEvent("route68:shownotif", sourcePlayer,"Zalogowano Pomyślnie!")
      TriggerClientEvent('gcPhone:twitter_setAccount', sourcePlayer, username, password, user.authorIcon)
    end
  end)
end)

RegisterServerEvent('gcPhone:twitter_changePassword')
AddEventHandler('gcPhone:twitter_changePassword', function(username, password, newPassword)
  local sourcePlayer = tonumber(source)
  getUser(username, password, function (user)
    if user == nil then
	  TriggerClientEvent("route68:shownotif", sourcePlayer,"Wystąpił błąd podczas zmiany Hasła. Spróbuj ponownie za kilka sekund!")
    else
      MySQL.Async.execute("UPDATE `twitter_accounts` SET `password`= @newPassword WHERE twitter_accounts.username = @username AND twitter_accounts.password = @password", {
        ['@username'] = username,
        ['@password'] = password,
        ['@newPassword'] = newPassword
      }, function (result)
        if (result == 1) then
          TriggerClientEvent('gcPhone:twitter_setAccount', sourcePlayer, username, newPassword, user.authorIcon)
		  TriggerClientEvent("route68:shownotif", sourcePlayer,"Twoje hasło zostało zmienione!")
        else
          TriggerClientEvent("sendProximityMessageTweet", -1, sourcePlayer, "Wystąpił błąd podczas zmiany Hasła. Spróbuj ponownie za kilka sekund!")
        end
      end)
    end
  end)
end)


RegisterServerEvent('gcPhone:twitter_createAccount')
AddEventHandler('gcPhone:twitter_createAccount', function(username, password, avatarUrl)
  local sourcePlayer = tonumber(source)
  TwitterCreateAccount(username, password, avatarUrl, function (id)
    if (id ~= 0) then
      TriggerClientEvent('gcPhone:twitter_setAccount', sourcePlayer, username, password, avatarUrl)
	  TriggerClientEvent("route68:shownotif", sourcePlayer,"Twoje konto na Twitterze zostało utworzone!")
    else
	  TriggerClientEvent("route68:shownotif", sourcePlayer,"Nazwa użytkownika jest zajęta!")
    end
  end)
end)

RegisterServerEvent('gcPhone:twitter_getTweets')
AddEventHandler('gcPhone:twitter_getTweets', function(username, password)
  local sourcePlayer = tonumber(source)
  if username ~= nil and username ~= "" and password ~= nil and password ~= "" then
    getUser(username, password, function (user)
      local accountId = user and user.id
      TwitterGetTweets(accountId, function (tweets)
        TriggerClientEvent('gcPhone:twitter_getTweets', sourcePlayer, tweets)
      end)
    end)
  else
    TwitterGetTweets(nil, function (tweets)
      TriggerClientEvent('gcPhone:twitter_getTweets', sourcePlayer, tweets)
    end)
  end
end)

RegisterServerEvent('gcPhone:twitter_getFavoriteTweets')
AddEventHandler('gcPhone:twitter_getFavoriteTweets', function(username, password)
  local sourcePlayer = tonumber(source)
  if username ~= nil and username ~= "" and password ~= nil and password ~= "" then
    getUser(username, password, function (user)
      local accountId = user and user.id
      TwitterGetFavotireTweets(accountId, function (tweets)
        TriggerClientEvent('gcPhone:twitter_getFavoriteTweets', sourcePlayer, tweets)
      end)
    end)
  else
    TwitterGetFavotireTweets(nil, function (tweets)
      TriggerClientEvent('gcPhone:twitter_getFavoriteTweets', sourcePlayer, tweets)
    end)
  end
end)

RegisterServerEvent('gcPhone:twitter_postTweets')
AddEventHandler('gcPhone:twitter_postTweets', function(username, password, message)
  local sourcePlayer = tonumber(source)
  local srcIdentifier = getPlayerID(source)
  TwitterPostTweet(username, password, message, sourcePlayer, srcIdentifier)
end)


RegisterServerEvent('gcPhone:twitter_setAvatarUrl')
AddEventHandler('gcPhone:twitter_setAvatarUrl', function(username, password, avatarUrl)
  local sourcePlayer = tonumber(source)
  MySQL.Async.execute("UPDATE `twitter_accounts` SET `avatar_url`= @avatarUrl WHERE twitter_accounts.username = @username AND twitter_accounts.password = @password", {
    ['@username'] = username,
    ['@password'] = password,
    ['@avatarUrl'] = avatarUrl
  }, function (result)
    if (result == 1) then
      TriggerClientEvent('gcPhone:twitter_setAccount', sourcePlayer, username, password, avatarUrl)
	   TriggerClientEvent("route68:shownotif", sourcePlayer,"Twóje zdjęcie zostało zmienione!")
    else
	   TriggerClientEvent("route68:shownotif", sourcePlayer,"Nieprawidłowy Login lub Hasło!")
    end
  end)
end)