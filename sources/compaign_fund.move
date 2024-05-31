//todo - 
//clicks will be in web2 or web3 doubt, because we need to update everytime and sometimes it may not sync with amount, becuase if affiliators drawn the amount then clicks needs to update
// update minimum to start range fn
// affiliators with partners section
// add clicks counter

//asset ownership
//transferrability
//dynamic objects

//todo - take care of security side and contract audit

//todo - not safe to keep as shared object please change them

//status => Scheduled - 1, Ongoing - 2, End / Expired - 3,

module campaign_fund::campaign_fund {

    use std::vector;
    // use std::debug;
    use sui::transfer;
    use sui::sui::SUI;
    use sui::vec_map::{Self, VecMap};
    use sui::coin::{Self, Coin};
    use std::string::{Self, String};
    use sui::object::{Self, UID, ID};
    use sui::balance::{Self, Balance};
    use sui::tx_context::{Self, TxContext};
   
    const ENotEnough: u64 = 0;
    const ENotMatch: u64 = 1;

    // const SCHEDULED : u64 = 1;
    const ONGOING : u64 = 2;
    const EXPIRED : u64 = 3;


    struct AffiliateHistory has store {
        company_name: String,
        campaign_url: String,
        clicks: u64,
        earnings: u64,
    }

    struct CampaignConfig has key{
        id: UID,
        minimum_coins_limit: u64,
        platform_fees_percent: u64,
        fees_wallet_address: address,
    }

    struct Fan has key, store{
        id: UID,
        donated: u64,
        message: String,
        wallet_address: address,
        timestamp: u64,
    }

    struct Campaign has key {
        id: UID,
        share_id: ID,
        company_name: String,
        category: String,
        original_url: String,
        total_clicks: u64,
        remaining_clicks: u64,
        cost_per_click: u64,
        budget: u64,
        distribute_funds: Balance<SUI>,
        wallet_address: address,
        fees_wallet_address: address,
        status: u64,
        start_date: u64,
        end_date: u64,
        supporters: vector<Fan>,
        timestamp: u64,
        affiliates: VecMap<ID, Affiliate>,
    }

    struct Affiliate has key, store{
        id: UID,
        click_counts: u64,
        earnings: u64,
        campaign_url: String,
        wallet_address: address,
        timestamp: u64,
    }

    struct AffiliateProfile has key{
        id: UID,
        share_id: ID,
        participated_campagins_count: u64,
        total_clicks: u64,
        total_earnings: u64,
        history: VecMap<ID, AffiliateHistory>,
        timestamp: u64,
    }

    //todo - Is it necessary
    struct Reciept has key {
        id: UID,
        company_name: String,
        budget: u64,
        timestamp: u64,
    }

    public fun get_epoch_seconds(ctx: &TxContext): u64 {
        let current_epoch_ms = tx_context::epoch_timestamp_ms(ctx);
        let current_epoch_s = current_epoch_ms/1000;
        current_epoch_s
    }

    public fun campaign_config(minimum_coins_limit: u64, platform_fees_percent: u64, fees_wallet_address: address, ctx: &mut TxContext){
        let campaignLimitObject = CampaignConfig{
            id: object::new(ctx),
            minimum_coins_limit,
            platform_fees_percent,
            fees_wallet_address,
        };
        transfer::share_object(campaignLimitObject)
    }

    //todo - keep transfer instead of public transfer, check transfer more details
    public fun collect_fees(campaign_config: &mut CampaignConfig, coin_address: &mut Coin<SUI>, coins: u64,  ctx: &mut TxContext){
        let coin_balance = coin::balance_mut(coin_address);
        let fees = (coins * campaign_config.platform_fees_percent) / 100;
        let amount = coin::take(coin_balance, fees , ctx);
        transfer::public_transfer(amount, campaign_config.fees_wallet_address)
    }

    // coins and cost_per_click will be unit of (number)*10^9
    // start date & end date will be epoch
    public entry fun create_campaign(
            campaign_config: &mut CampaignConfig,
            company_name: vector<u8>,
            category: vector<u8>,
            original_url: vector<u8>,
            coin_address: &mut Coin<SUI>,
            coins: u64,
            cost_per_click: u64,
            start_date: u64,
            end_date: u64,
            status: u64,
            wallet_address: address,
            ctx: &mut TxContext
        ){
        let coin_balance = coin::balance_mut(coin_address);

        assert!(coins >= campaign_config.minimum_coins_limit, ENotEnough);
        
        assert!(coins >= cost_per_click, ENotEnough);

        assert!(end_date >= start_date, ENotEnough);

        let total_clicks = coins / cost_per_click;

        let pay = balance::split(coin_balance, coins);

        collect_fees(campaign_config, coin_address, coins, ctx);

        let uid = object::new(ctx);
        let share_id = object::uid_to_inner(&uid);
        
        let campaignObject = Campaign{
            id: uid,
            share_id,
            company_name: string::utf8(company_name),
            category: string::utf8(category),
            original_url: string::utf8(original_url),
            cost_per_click: cost_per_click,
            budget : coins,
            distribute_funds:  pay,
            total_clicks,
            remaining_clicks: total_clicks,
            start_date,
            end_date,
            status,
            wallet_address,
            fees_wallet_address: campaign_config.fees_wallet_address,
            supporters: vector::empty<Fan>(),
            timestamp:  get_epoch_seconds(ctx),
            affiliates: vec_map::empty(),
        };

        let reciept = Reciept{
            id: object::new(ctx),
            company_name: string::utf8(company_name),
            budget: coins,
            timestamp:  get_epoch_seconds(ctx),
        };

        transfer::share_object(campaignObject);
        //todo - make it immutable
        transfer::transfer(reciept, tx_context::sender(ctx))
    }

    //todo - minum pool can add it should be more than cpc
    public fun update_campaign_pool(
            campaign_config: &mut CampaignConfig, 
            campaign: &mut Campaign, 
            message: vector<u8>, 
            coins: u64, 
            coin_address: &mut Coin<SUI>, 
            ctx: &mut TxContext
        ) {
            
        assert!(campaign.status == ONGOING, ENotMatch);

        let coin_balance = coin::balance_mut(coin_address);
        let pay = balance::split(coin_balance, coins);

        collect_fees(campaign_config, coin_address, coins , ctx);

        balance::join(&mut campaign.distribute_funds, pay);
        campaign.budget = campaign.budget + coins;
        campaign.total_clicks = campaign.total_clicks + (coins/campaign.cost_per_click);
        campaign.remaining_clicks = campaign.remaining_clicks +  (coins/campaign.cost_per_click);

        let fan_object = Fan{
            id: object::new(ctx),
            donated: coins,
            message: string::utf8(message),
            wallet_address: tx_context::sender(ctx),
            timestamp: get_epoch_seconds(ctx),
        };

        vector::push_back(&mut campaign.supporters, fan_object);
    }

    //todo -  whenever user connected wallet - check in web2 db - whether details there or not, if not then trigger these.
    //todo - during web2 signup or in db - check whether it has affiliate profile address, if not then call this function
    public fun create_affiliate_profile(
            campaign_config: &mut CampaignConfig,
            campaign: &mut Campaign,
            campaign_url: vector<u8>,
            ctx: &mut TxContext
        ) {
        let history_map = vec_map::empty<ID, AffiliateHistory>();
        
        let affiliateHistoryObject = AffiliateHistory{
            company_name: campaign.company_name,
            campaign_url: string::utf8(campaign_url),
            clicks: 0,
            earnings: 0
        };
        
        vec_map::insert(&mut history_map, campaign.share_id, affiliateHistoryObject);

        let uid = object::new(ctx);

        let share_id = object::uid_to_inner(&uid);
        
        let profileObj = AffiliateProfile{
            id: uid,
            share_id,
            participated_campagins_count:1,
            total_clicks:0,
            total_earnings:0,
            history: history_map,
            timestamp: get_epoch_seconds(ctx),
        };
        
        transfer::transfer(profileObj, campaign_config.fees_wallet_address);
    }

    public fun update_affiliate_profile(campaign: &mut Campaign, campaign_url: vector<u8> ,profile: &mut AffiliateProfile){
        let affiliateHistoryObject = AffiliateHistory{
            company_name: campaign.company_name,
            campaign_url: string::utf8(campaign_url),
            clicks: 0,
            earnings: 0
        };
        vec_map::insert(&mut profile.history, campaign.share_id, affiliateHistoryObject);
        profile.participated_campagins_count = profile.participated_campagins_count + 1;
    }

    //todo - here earning will be an number will increment according to the click_counts and initially both 0 and based on the increment fn these update
    // after that when withdraw loop they will pass into it
    public entry fun create_affiliate_campaign(
            campaign: &mut Campaign,
            campaign_url: vector<u8>,
            profile: &mut AffiliateProfile,
            wallet_address: address,
            ctx: &mut TxContext
        ) {

        assert!(campaign.status == ONGOING, ENotMatch);

        let affiliate_uid = object::new(ctx);
        let affiliatesObject = Affiliate{
            id: affiliate_uid,
            click_counts:0,
            earnings:0,
            campaign_url: string::utf8(campaign_url),
            wallet_address: wallet_address,
            timestamp: get_epoch_seconds(ctx),
        };
        vec_map::insert(&mut campaign.affiliates, profile.share_id, affiliatesObject);
    }

    fun increment_affiliate_profile(campaign_share_id: &ID, cpc: u64, profile: &mut AffiliateProfile){
        let participating_campaign = vec_map::get_mut(&mut profile.history, campaign_share_id);
        participating_campaign.clicks = participating_campaign.clicks + 1;
        participating_campaign.earnings = participating_campaign.earnings + cpc;
        profile.total_clicks = profile.total_clicks + 1;
        profile.total_earnings  = profile.total_earnings + cpc;
    }

    //todo - convert into private
    //todo - get affiliate via parent instead of affiliate directly
    public fun update_affiliate_via_campaign(campaign_config: &mut CampaignConfig, campaign: &mut Campaign, profile: &mut AffiliateProfile, ctx: &mut TxContext){

        let total_balance_value = balance::value(&campaign.distribute_funds);
        let sender_address = tx_context::sender(ctx);
        
        assert!(campaign.status == 2, ENotEnough);

        assert!(total_balance_value >= campaign.cost_per_click, ENotEnough);

        assert!(campaign_config.fees_wallet_address == sender_address, ENotMatch );

        let affiliate = vec_map::get_mut(&mut campaign.affiliates, &profile.share_id);
        affiliate.click_counts = affiliate.click_counts + 1;
        affiliate.earnings =  affiliate.earnings + campaign.cost_per_click;
        campaign.remaining_clicks  = campaign.remaining_clicks - 1;
        let cpc = campaign.cost_per_click;
        increment_affiliate_profile(&campaign.share_id, cpc, profile);
        withdraw_amount(campaign, cpc, affiliate.wallet_address, ctx);
    }

    //todo - check end campaign
    public fun end_campaign(campaign_config: &mut CampaignConfig, campaign: &mut Campaign, ctx: &mut TxContext ){

        let current_epoch = get_epoch_seconds(ctx);
    
        let sender_address = tx_context::sender(ctx);

        assert!(current_epoch >= campaign.end_date, ENotEnough);

        assert!( sender_address == campaign.wallet_address || sender_address == campaign_config.fees_wallet_address, ENotMatch);

        campaign.status = EXPIRED;
        let total_balance = balance::value(&campaign.distribute_funds);

        assert!(total_balance > 0, ENotEnough);

        //todo - change value
        let amount = coin::take(&mut campaign.distribute_funds, total_balance, ctx);
        transfer::public_transfer(amount, campaign.wallet_address);
    }

    //todo - convert into private
    // restrict it - no one should not use it
    fun withdraw_amount(campaign: &mut Campaign, amount_req: u64, reciept_address: address, ctx: &mut TxContext) {
        let amount = coin::take(&mut campaign.distribute_funds, amount_req, ctx);
        transfer::public_transfer(amount, reciept_address);
    }

}