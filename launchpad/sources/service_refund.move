module yousui::service_refund {
    use sui::tx_context::{TxContext};
    use sui::object::{Self, UID};
    use sui::vec_set::{Self, VecSet};
    use sui::clock::{Self, Clock};

    friend yousui::admin;
    friend yousui::ido;

    use yousui::utils;
    use yousui::service::{
        Self as service,
        Service,
    };

    const ENowLtStart: u64 = 1300+0;
    const ENowGtEnd: u64 = 1300+1;
    const ERoundNotUseRefund: u64 = 1300+2;


    struct Feature has drop {}

    struct Config has key, store {
        id: UID,
        start_refund_time: u64,
        refund_range_time: u64,
        arr_claimed_address: VecSet<address>,
    }

    public(friend) fun add(
        service: &mut Service,
        start_refund_time: u64,
        refund_range_time: u64,
        ctx: &mut TxContext
    ) {
        service::add_feature<Feature, Config>(
            service,
            Config {
                id: object::new(ctx),
                start_refund_time,
                refund_range_time,
                arr_claimed_address: vec_set::empty<address>()
            }
        )
    }

    public(friend) fun remove(service: &mut Service) {
        let config = service::remove_feature<Feature, Config>(service);
        let Config { id, start_refund_time: _, refund_range_time: _, arr_claimed_address: _ } = config;
        object::delete(id);
    }

    public(friend) fun check_valid_refund(
        service: &Service,
        clock: &Clock,
    ) {
        let feature_key = utils::get_key_by_struct<Feature>();
        if (vec_set::contains(service::features(service), &feature_key)) {
            let timestamp = clock::timestamp_ms(clock);
            let config = service::get_feature<Feature, Config>(service);
            assert!( timestamp >= config.start_refund_time, ENowLtStart);
            assert!( timestamp <= (config.start_refund_time + config.refund_range_time), ENowGtEnd);
        } else {
            abort(ERoundNotUseRefund)
        };
    }
    
    public(friend) fun set_start_refund_time(
        service: &mut Service,
        start_refund_time: u64,
    ) {
        let config = service::get_feature_mut<Feature, Config>(service);
        config.start_refund_time = start_refund_time;
    }

    public(friend) fun set_refund_range_time(
        service: &mut Service,
        refund_range_time: u64,
    ) {
        let config = service::get_feature_mut<Feature, Config>(service);
        config.refund_range_time = refund_range_time;
    }

    public(friend) fun insert_refund_address(
        service: &mut Service,
        investor: address,
    ) {
        let feature_key = utils::get_key_by_struct<Feature>();
        if (vec_set::contains(service::features(service), &feature_key)) {
            let config = service::get_feature_mut<Feature, Config>(service);
            if (!vec_set::contains(&config.arr_claimed_address, &investor)) {
                vec_set::insert(&mut config.arr_claimed_address, investor);
            };
        };
    }
}
