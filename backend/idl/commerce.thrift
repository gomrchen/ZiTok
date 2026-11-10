namespace go commerce

include "model.thrift"

struct WalletInfo {
    1: required i64 user_id
    2: required i32 balance
}

struct LedgerItem {
    1: required i64 id
    2: required i64 user_id
    3: required i32 change_amount
    4: required i32 balance_after
    5: required string reason
    6: required string ref_id
    7: required string created_at
}

struct GetWalletRequest {
    1: required i64 user_id
}

struct GetWalletResponse {
    1: required model.BaseResp Base
    2: required WalletInfo wallet
}

struct ListLedgerRequest {
    1: required i64 user_id
    2: optional i32 limit
}

struct ListLedgerResponse {
    1: required model.BaseResp Base
    2: required list<LedgerItem> list
}

struct UnlockEpisodeRequest {
    1: required i64 user_id
    2: required i64 episode_id
}

struct UnlockEpisodeResponse {
    1: required model.BaseResp Base
    2: required i32 balance
    3: required bool unlocked
}

struct UnlockDramaRequest {
    1: required i64 user_id
    2: required i64 drama_id
}

struct UnlockDramaResponse {
    1: required model.BaseResp Base
    2: required i32 balance
    3: required bool unlocked
}

struct AdUnlockRequest {
    1: required i64 user_id
    2: required i64 episode_id
}

struct AdUnlockResponse {
    1: required model.BaseResp Base
    2: required bool unlocked
    3: required i32 expire_hours
}

struct AdRewardRequest {
    1: required i64 user_id
}

struct AdRewardResponse {
    1: required model.BaseResp Base
    2: required i32 balance
    3: required i32 reward
}

// 支付适配：provider=mock|wechat|apple
struct TopupRequest {
    1: required i64 user_id
    2: required i32 amount
    3: optional string provider
    4: optional string receipt
}

struct TopupResponse {
    1: required model.BaseResp Base
    2: required i32 balance
    3: required string provider
    4: required string order_id
}

struct AdjustWalletRequest {
    1: required i64 user_id
    2: required i32 delta
    3: optional string reason
}

struct AdjustWalletResponse {
    1: required model.BaseResp Base
    2: required i32 balance
}

struct HasUnlockRequest {
    1: required i64 user_id
    2: required i64 drama_id
    3: required i64 episode_id
}

struct HasUnlockResponse {
    1: required model.BaseResp Base
    2: required bool unlocked
}

service CommerceService {
    GetWalletResponse GetWallet(1: GetWalletRequest req)
    ListLedgerResponse ListLedger(1: ListLedgerRequest req)
    UnlockEpisodeResponse UnlockEpisode(1: UnlockEpisodeRequest req)
    UnlockDramaResponse UnlockDrama(1: UnlockDramaRequest req)
    AdUnlockResponse AdUnlock(1: AdUnlockRequest req)
    AdRewardResponse AdReward(1: AdRewardRequest req)
    TopupResponse Topup(1: TopupRequest req)
    AdjustWalletResponse AdjustWallet(1: AdjustWalletRequest req)
    HasUnlockResponse HasUnlock(1: HasUnlockRequest req)
}
