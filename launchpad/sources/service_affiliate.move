module yousui::service_affiliate {
    use sui::tx_context::{TxContext};
    use sui::object::{Self, UID};
    use sui::vec_map::{Self, VecMap};
    use sui::vec_set;
    use sui::address;
    use sui::dynamic_field as df;

    use std::string::{Self, String};

    friend yousui::admin;
    friend yousui::ido;

    use yousui::utils;
    use yousui::service::{
        Self as service,
        Service,
    };

    const EAffiliateCodeNotExist: u64 = 700+0;
    const EAffiliatorLocked: u64 = 700+1;
    const ENotSupportAffiliate: u64 = 700+2;


    struct Feature has drop {}

    struct Config has key, store {
        id: UID,
        affiliate: VecMap<address, String>
    }

    struct Affiliator has store, drop {
        user: address,
        nation: String,
        affiliate_code: String,
        is_lock: bool,
        accumulate: VecMap<String, Fund>,
    }

    struct Fund has store, drop {
        token_type: String,
        amount: u64,
    }

    public(friend) fun add(
        service: &mut Service,
        ctx: &mut TxContext
    ) {
        service::add_feature<Feature, Config>(
            service,
            Config {
                id: object::new(ctx),
                affiliate: vec_map::empty()
            }
        )
    }

    public(friend) fun remove(service: &mut Service) {
        let config = service::remove_feature<Feature, Config>(service);
        let Config { id, affiliate: _ } = config;
        object::delete(id);
    }

    public(friend) fun check_valid_affiliate_code(
        service: &Service,
        affiliate_code: String,
    ) {
        let feature_key = utils::get_key_by_struct<Feature>();
        if (vec_set::contains(service::features(service), &feature_key)) {
            let config = service::get_feature<Feature, Config>(service);
            assert!(df::exists_(&config.id, affiliate_code), EAffiliateCodeNotExist);

            let affiliator = df::borrow<String, Affiliator>(&config.id, affiliate_code);
            assert!(!affiliator.is_lock, EAffiliatorLocked);
        };
    }

    fun get_affiliate_code(user: address, nation: String): String {
        let affiliate_code = nation;
        let user_string = address::to_string(user);
        let sub_user_string = string::sub_string(&user_string, 39, 64);
        string::append(&mut affiliate_code, sub_user_string);
        affiliate_code
    }

    public(friend) fun add_affiliator_list(service: &mut Service, affiliator_list: VecMap<address, String>) {
        let feature_key = utils::get_key_by_struct<Feature>();
        assert!(vec_set::contains(service::features(service), &feature_key), ENotSupportAffiliate);
        let config = service::get_feature_mut<Feature, Config>(service);

        while (!vec_map::is_empty(&affiliator_list)) {
            let (user, nation) = vec_map::pop(&mut affiliator_list);
            let affiliate_code = get_affiliate_code(user, nation);
            
            if (!df::exists_(&config.id, affiliate_code)) {
                vec_map::insert(&mut config.affiliate, user, affiliate_code);
                df::add(&mut config.id, affiliate_code, Affiliator {
                    user,
                    nation,
                    affiliate_code,
                    is_lock: false,
                    accumulate: vec_map::empty(),
                });
            };
        };
    }

    public(friend) fun remove_affiliator_list(service: &mut Service, affiliator_list: VecMap<address, String>) {
        let feature_key = utils::get_key_by_struct<Feature>();
        assert!(vec_set::contains(service::features(service), &feature_key), ENotSupportAffiliate);
        let config = service::get_feature_mut<Feature, Config>(service);

        while (!vec_map::is_empty(&affiliator_list)) {
            let (user, nation) = vec_map::pop(&mut affiliator_list);
            let affiliate_code = get_affiliate_code(user, nation);

            if (df::exists_(&config.id, affiliate_code)) {
                vec_map::remove(&mut config.affiliate, &user);
                df::remove<String, Affiliator>(&mut config.id, affiliate_code);
            };
        };
    }

    public(friend) fun add_profit_by_affiliate<PAYMENT>(service: &mut Service, affiliate_code: String, payment_amount: u64) {
        check_valid_affiliate_code(service, affiliate_code);
        let payment_method_type = utils::get_full_type<PAYMENT>();
        let feature_key = utils::get_key_by_struct<Feature>();
        if (vec_set::contains(service::features(service), &feature_key)) {
            let config = service::get_feature_mut<Feature, Config>(service);
            let affiliator = df::borrow_mut<String, Affiliator>(&mut config.id, affiliate_code);

            if (vec_map::contains(&affiliator.accumulate, &payment_method_type)) {
                let accumulate_fund = vec_map::get_mut(&mut affiliator.accumulate, &payment_method_type);
                let latest_accumulate_amount = accumulate_fund.amount;
                accumulate_fund.amount = latest_accumulate_amount + payment_amount;
            } else {
                vec_map::insert(
                    &mut affiliator.accumulate,
                    payment_method_type,
                    Fund {
                        token_type: payment_method_type,
                        amount: payment_amount,
                    }
                );
            };
        };
    }
    
}
