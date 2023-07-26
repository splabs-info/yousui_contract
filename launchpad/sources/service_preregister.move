module yousui::service_preregister {
    use sui::tx_context::{TxContext};
    use sui::object::{Self, UID};
    use sui::vec_set;

    friend yousui::admin;
    friend yousui::ido;

    use yousui::utils;
    use yousui::service::{
        Self as service,
        Service,
    };
    
    const EClaimRefundNotSupport: u64 = 900+0;
    const EClaimRefundOpening: u64 = 900+1;
    const ETgeUnlockPercentInvalid: u64 = 900+2;
    const ETotalUnlockEqZero: u64 = 900+3;
    const ESenderNotHaveVesting: u64 = 900+4;
    const ELockAmountGteSubAmount: u64 = 900+5;
    const ETimestampLtReleaseTime: u64 = 900+6;
    const EClaimed: u64 = 900+7;
    const ETotalSoldExceedSupply: u64 = 900+8;

    struct Feature has drop {}

    struct Config has key, store {
        id: UID,
        is_open_claim_refund: bool,
    }

    public(friend) fun add(
        service: &mut Service,
        ctx: &mut TxContext
    ) {
        service::add_feature<Feature, Config>(
            service,
            Config {
                id: object::new(ctx),
                is_open_claim_refund: false
            }
        )
    }

    public(friend) fun set_is_open_claim_refund(
        service: &mut Service,
        is_open_claim_refund: bool,
    ) {
        let feature_key = utils::get_key_by_struct<Feature>();
        if (vec_set::contains(service::features(service), &feature_key)) {
            let config = service::get_feature_mut<Feature, Config>(service);
            config.is_open_claim_refund = is_open_claim_refund;
        }
    }

    public(friend) fun remove(service: &mut Service) {
        let config = service::remove_feature<Feature, Config>(service);
        let Config { id, is_open_claim_refund: _} = config;
        object::delete(id)
    }

    public(friend) fun validate_purchase(
        service: &Service,
        total_sold: u64,
        total_supply: u64
    ) {
        let feature_key = utils::get_key_by_struct<Feature>();
        if (vec_set::contains(service::features(service), &feature_key)) {
            let config: &Config = service::get_feature<Feature, Config>(service);
            assert!(!config.is_open_claim_refund, EClaimRefundOpening);
        } else {
            assert!(total_sold <= total_supply, ETotalSoldExceedSupply);
        }
    }

    public(friend) fun is_use_preregister(
        service: &Service,
    ): bool {
        let feature_key = utils::get_key_by_struct<Feature>();
        vec_set::contains(service::features(service), &feature_key)
    }

    public(friend) fun validate_claim_refund(
        service: &Service,
    ) {
        let feature_key = utils::get_key_by_struct<Feature>();
        if (vec_set::contains(service::features(service), &feature_key)) {
            let config: &Config = service::get_feature<Feature, Config>(service);
            assert!(config.is_open_claim_refund, EClaimRefundOpening);
        } else {
            abort(EClaimRefundNotSupport)
        }
    }
    
}
