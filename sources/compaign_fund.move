#[allow(lint(self_transfer))]
/// Module: compaign_fund
module compaign_fund::compaign_fund {

    use sui::transfer;
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use sui::object::{Self, UID, ID};
    use sui::balance::{Balance};
    use sui::tx_context::{Self, TxContext};
    use std::string::{Self, String};

    // const ENotEnough: u64 = 0;

    struct FundOwner has key {
        id: UID,
        fund_id: ID,
    }

    struct Fund has store, key {
        id: UID,
        company_name: String,
        total_clicks: u64,
        amount_per_click: u64,
        amount: Balance<SUI>, //Balance<SUI> or Coin<SUI> both are same representation is different and Balanace is more efficient and less gas fee than Coin
    }

    struct Reciept has key {
        id: UID,
        company_name: String,
        amount: u64,
    }

    //todo - add one more argument - amount to invest to work
    public entry fun create_campaign(company_name: vector<u8>, amount_per_click: u64, sui_coin_id: Coin<SUI>, ctx: &mut TxContext){
        //todo - split this number of sui_coin_id and 
        let fund_uid = object::new(ctx);
        let id = object::uid_to_inner(&fund_uid);
        let sui_coins_value = coin::value(&sui_coin_id);
        let sui_coins = coin::into_balance(sui_coin_id);
        let total_clicks = 1000;
        
        // assert!(sui_coins_value >= 5000000000u64, ENotEnough);
        
        let fundObject = Fund{
            id: fund_uid,
            company_name: string::utf8(company_name),
            total_clicks: total_clicks,
            amount_per_click: amount_per_click,
            amount: sui_coins,
        };


        let fundOnwer = FundOwner{
            id: object::new(ctx),
            fund_id: id
        };

        let reciept = Reciept{
            id: object::new(ctx),
            company_name: string::utf8(company_name),
            amount: sui_coins_value
        };

        transfer::share_object(fundObject);
        transfer::transfer(fundOnwer, tx_context::sender(ctx));
        transfer::transfer(reciept, tx_context::sender(ctx));
    }

    public entry fun withdraw_amount(fund: &mut Fund, amount_req: u64, ctx: &mut TxContext,) {
        let amount = coin::take(&mut fund.amount, amount_req, ctx);
        transfer::public_transfer(amount, tx_context::sender(ctx));
    }

}


