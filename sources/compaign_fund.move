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

//status => Scheduled - 1, Started - 2, End / Expired - 3,

module campaign_fund::campaign_fund {

    use sui::transfer;
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use sui::object::{Self, UID, ID};
    use sui::balance::{Self, Balance};
    use sui::tx_context::{Self, TxContext};
    use sui::dynamic_object_field as ofield;
    use std::string::{Self, String};
    use std::debug;

    const ENotEnough: u64 = 0;
    
    struct CampaignConfig has key{
        id: UID,
        minimum_coins_limit: u64,
        platform_fees: u64,
        fees_wallet_address: address,
    }

    struct CampaignOwner has key {
        id: UID,
        fund_id: ID,
    }

    struct Campaign has key {
        id: UID,
        name: String,
        company_name: String,
        category: String,
        original_url: String,
        campaign_url: String,
        total_clicks: u64,
        cost_per_click: u64,
        budget: u64,
        distribute_funds: Balance<SUI>,
        wallet_address: address,
        fees_wallet_address: address,
        status: u64,
        start_date: u64,
        end_date: u64,
        timestamp: u64,
    }

    //why store - dynamic filed b/w parent
    struct Affiliate has key, store{
        id: UID,
        click_counts: u64,
        earnings: u64,
        campaign_url: String,
        profile: address,
        wallet_address: address,
    }

    struct AffiliateProfile has key{
        id: UID,
        participated_campagins_count: u64,
        total_clicks: u64,
        total_earnings: u64,
        twitter_x: String,
    }

    struct Reciept has key {
        id: UID,
        company_name: String,
        campaign_name: String,
        campaign_budget: u64,
        timestamp: u64,
    }

    public fun campaign_config(minimum_coins_limit: u64, platform_fees: u64, fees_wallet_address: address, ctx: &mut TxContext){
        let campaignLimitObject = CampaignConfig{
            id: object::new(ctx),
            minimum_coins_limit,
            platform_fees,
            fees_wallet_address,
        };
        transfer::share_object(campaignLimitObject)
    }

    //todo - keep transfer instead of public transfer, check transfer more details
    public fun collect_fees(campaign_config: &mut CampaignConfig,coin_address: &mut Coin<SUI>, ctx: &mut TxContext){
        let coin_balance = coin::balance_mut(coin_address);
        let amount = coin::take(coin_balance, campaign_config.platform_fees , ctx);
        transfer::public_transfer(amount, campaign_config.fees_wallet_address)
    }

    // coins and cost_per_click will be unit of (number)*10^9
    // start date & end date will be epoch
    public entry fun create_campaign(
            campaign_name: vector<u8>,
            company_name: vector<u8>,
            category: vector<u8>,
            original_url: vector<u8>,
            campaign_url: vector<u8>,
            coin_address: &mut Coin<SUI>,
            coins: u64,
            cost_per_click: u64,
            start_date: u64,
            end_date: u64,
            wallet_address: address,
            campaign_config: &mut CampaignConfig,
            ctx: &mut TxContext
        ){
        let fund_uid = object::new(ctx);
        let id = object::uid_to_inner(&fund_uid);
        let coin_balance = coin::balance_mut(coin_address);

        //todo - keep these below condition and division if possible in seperate module
        assert!(coins >= campaign_config.minimum_coins_limit, ENotEnough);
        
        assert!(coins >= cost_per_click, ENotEnough); 

        let total_clicks = coins / cost_per_click;

        let pay = balance::split(coin_balance, coins);

        collect_fees(campaign_config, coin_address, ctx);
        
        let fundObject = Campaign{
            id: fund_uid,
            name: string::utf8(campaign_name),
            company_name: string::utf8(company_name),
            category: string::utf8(category),
            original_url: string::utf8(original_url),
            campaign_url: string:: utf8(campaign_url),
            cost_per_click: cost_per_click,
            budget : coins,
            distribute_funds:  pay,
            total_clicks,
            start_date,
            end_date,
            status: 2,
            wallet_address,
            fees_wallet_address: campaign_config.fees_wallet_address,
            timestamp:  tx_context::epoch(ctx),
        };

        let fundOnwer = CampaignOwner{
            id: object::new(ctx),
            fund_id: id
        };

        let reciept = Reciept{
            id: object::new(ctx),
            company_name: string::utf8(company_name),
            campaign_name: string::utf8(campaign_name),
            campaign_budget: coins,
            timestamp:  tx_context::epoch(ctx),
        };

        transfer::share_object(fundObject);
        transfer::transfer(fundOnwer, campaign_config.fees_wallet_address);
        //todo - make it immutable
        transfer::transfer(reciept, tx_context::sender(ctx))
    }

    //todo - here earning will be an number will increment according to the click_counts and initially both 0 and based on the increment fn these update
    // after that when withdraw loop they will pass into it
    public entry fun create_affiliate(click_counts: u64, earnings: u64, campaign_url: vector<u8> , profile: address, wallet_address: address, campaign_config: &mut CampaignConfig ,ctx: &mut TxContext){
        //add campaign url
        //add their profile
        let affiliatesObject = Affiliate{
            id: object::new(ctx),
            click_counts,
            earnings,
            campaign_url: string::utf8(campaign_url),
            profile,
            wallet_address: wallet_address,
        };
        transfer::transfer(affiliatesObject, campaign_config.fees_wallet_address);
    }

    //todo -  whenever user connected wallet - check in web2 db - whether details there or not, if not then trigger these.
    //todo - during web2 signup or in db - check whether it has affiliate profile address, if not then call this function
    public fun create_affiliate_profile(campaign_config: &mut CampaignConfig ,twitter_x: vector<u8>, ctx: &mut TxContext){
        let profileObj = AffiliateProfile{
            id: object::new(ctx),
            participated_campagins_count:1,
            total_clicks:0,
            total_earnings:0,
            twitter_x: string::utf8(twitter_x),
        };
        transfer::transfer(profileObj, campaign_config.fees_wallet_address);
    }

    public fun increment_affiliate_participate_count(profile: &mut AffiliateProfile){
        profile.participated_campagins_count = profile.participated_campagins_count + 1;
    }

    // restrict it - no one should not use it
    public fun add_affiliate_to_campaign(fund: &mut Campaign, affiliate: Affiliate){
        //todo - need to check whether company has campaignFund or not 
        assert!(fund.wallet_address != affiliate.wallet_address, ENotEnough);
        let affiliate_id = object::id(&affiliate);
        ofield::add(&mut fund.id, affiliate_id, affiliate)
    }

    fun mutate_affiliate_child(affiliate: &mut Affiliate): address{
        affiliate.click_counts =  affiliate.click_counts + 1;
        affiliate.wallet_address
        // affiliate.earnings =  affiliate.earnings + campaign.cost_per_click;
    }
    //todo - convert into private
    //todo - get affiliate via parent instead of affiliate directly
    public fun click_counter(campaign: &mut Campaign, affiliate_link_id: address, profile :&mut AffiliateProfile, ctx: &mut TxContext){
        let wallet_address = mutate_affiliate_child(ofield::borrow_mut(
            &mut campaign.id,
            affiliate_link_id
        ));
        debug::print(&wallet_address);
        let cpc = campaign.cost_per_click;
        increment_affiliate_profile_count(campaign, profile);
        withdraw_amount(campaign, cpc, wallet_address, ctx)
    }

    public fun increment_affiliate_profile_count(campaign: &mut Campaign, profile: &mut AffiliateProfile){
        profile.total_clicks = profile.total_clicks + 1;
        profile.total_earnings  = profile.total_earnings + campaign.cost_per_click;
    }

    //todo - check end campaign
    public fun end_campaign(campaign: &mut Campaign, ctx: &mut TxContext ){
        campaign.status = 3;
        let total_balance = balance::value(&campaign.distribute_funds);
        //todo - change value
        let amount = coin::take(&mut campaign.distribute_funds, total_balance, ctx);
        transfer::public_transfer(amount, campaign.wallet_address);
    }

    //todo - convert into private
    // restrict it - no one should not use it
    public fun withdraw_amount(campaign: &mut Campaign, amount_req: u64, reciept_address: address ,ctx: &mut TxContext) {
        let amount = coin::take(&mut campaign.distribute_funds, amount_req, ctx);
        transfer::public_transfer(amount, reciept_address);
    }

}