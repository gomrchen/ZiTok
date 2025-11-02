package model

import "github.com/mutezebra/tiktok/pkg/errno"

// relation
var (
	GroupNameTooLangError        = errno.New(GroupNameTooLang, "group name too lang")
	GroupAlreadyExistError       = errno.New(GroupAlreadyExist, "group already exist")
	DatabaseCreateChatGroupError = errno.New(DatabaseCreateChatGroup, "database create chat group failed")

	UserNotExistError       = errno.New(UserNotExist, "user not exist")
	DatabaseFollowError     = errno.New(DatabaseFollow, "database follow failed")
	FollowAlreadyExistError = errno.New(FollowAlreadyExist, "follow already exist")

	DatabaseGetFollowListError = errno.New(DatabaseGetFollowList, "database get follow list failed")

	DatabaseGetFansListError = errno.New(DatabaseGetFansList, "database get fans list failed")

	DatabaseGetFriendsListError = errno.New(DatabaseGetFriendsList, "database get friends list failed")
)
