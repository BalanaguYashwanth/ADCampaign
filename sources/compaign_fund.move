//todo - 
//clicks will be in web2 or web3 doubt, because we need to update everytime and sometimes it may not sync with amount, becuase if affiliators drawn the amount then clicks needs to update

module compaign_fund::compaign_fund {

    use sui::transfer;
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use sui::object::{Self, UID, ID};
    use sui::balance::{Self, Balance};
    use sui::tx_context::{Self, TxContext};
     use std::debug;
    use std::string::{Self, String};

    const ENotEnough: u64 = 0;

    struct FundOwner has key {
        id: UID,
        fund_id: ID,
    }

    struct Fund has key {
        id: UID,
        company_name: String,
        total_clicks: u64,
        cost_per_click: u64,
        amount: Balance<SUI>,
    }

    struct Reciept has key {
        id: UID,
        company_name: String,
        amount: u64,
    }

    //here coins and cost_per_click will be unit of (number)*10^9
    public entry fun create_campaign(company_name: vector<u8>, coins: u64, coin_address: &mut Coin<SUI>, cost_per_click: u64, ctx: &mut TxContext){
        let fund_uid = object::new(ctx);
        let id = object::uid_to_inner(&fund_uid);
        let total_coins_balanace = coin::balance_mut(coin_address);

        assert!(coins >= 500_000_000, ENotEnough);
        
        let pay = balance::split(total_coins_balanace, coins);

        assert!(coins >= cost_per_click, ENotEnough); 

        let total_clicks = coins / cost_per_click;
        
        debug::print(&total_clicks);
        
        let fundObject = Fund{
            id: fund_uid,
            company_name: string::utf8(company_name),
            amount:  pay,
            cost_per_click: cost_per_click,
            total_clicks,
        };

        let fundOnwer = FundOwner{
            id: object::new(ctx),
            fund_id: id
        };

        let reciept = Reciept{
            id: object::new(ctx),
            company_name: string::utf8(company_name),
            amount: coins
        };

        transfer::transfer(fundObject, tx_context::sender(ctx));
        transfer::transfer(fundOnwer, tx_context::sender(ctx));
        transfer::transfer(reciept, tx_context::sender(ctx));
    }

    public entry fun withdraw_amount(fund: &mut Fund, amount_req: u64, ctx: &mut TxContext,) {
        let amount = coin::take(&mut fund.amount, amount_req, ctx);
        transfer::public_transfer(amount, tx_context::sender(ctx));
    }

}