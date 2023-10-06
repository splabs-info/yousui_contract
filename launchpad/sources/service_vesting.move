module yousui::service_vesting {
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID, ID};
    use sui::clock::{Self, Clock};
    use sui::package::{Self, Publisher};
    use sui::transfer;
    use sui::vec_set;
    use sui::display;
    use sui::math;
    use sui::dynamic_field as df;

    use std::string::{Self, String};
    use std::vector;

    friend yousui::admin;
    friend yousui::ido;

    use yousui::utils;
    use yousui::project::{ProjectInfo};
    use yousui::service::{
        Self as service,
        Service,
    };
    
    const ETgeUnlockPercentInvalid: u64 = 500+0;
    const ETimestampLtReleaseTime: u64 = 500+1;
    const EClaimed: u64 = 500+2;
    const ETotalUnlockEqZero: u64 = 500+3;
    const ESenderNotHaveVesting: u64 = 500+4;
    const ELockAmountGteSubAmount: u64 = 500+5;
    const EEmptyVector: u64 = 500+6;

    const THIRTY_DAYS: u64 = 2_592_000_000; // 30 DAYS
    // const THIRTY_DAYS: u64 = 300_000; //5 MINUTES

    struct Feature has drop {}

    struct Config has key, store {
        id: UID,
        info: VestingInfo,
        project: ProjectInfo,
        is_open_claim_vesting: bool,
    }

    struct VestingInfo has store, drop{
        tge_time: u64,
        tge_unlock_percent: u64,
        number_of_cliff_months: u64,
        number_of_month: u64,
        number_of_linear: u64,
        token_type: String,
    }

    struct Period has store {
        period_id: u64,
        release_time: u64,
        percentage: u64,
        unlock_amount: u64,
        is_withdrawal: bool,
    }

    struct VestingDetail has store {
        total_lock_mount: u64,
        total_unlock_amount: u64,
        period_list: vector<Period>,
    }

    struct SERVICE_VESTING has drop {}

    fun init(witness: SERVICE_VESTING, ctx: &mut TxContext) {
        let publisher = package::claim(witness, ctx);
        display<Config>(&publisher, ctx);
        transfer::public_transfer(publisher, tx_context::sender(ctx));
    }

    fun display<T: key>(publisher: &Publisher, ctx: &mut TxContext) {
        let keys = vector[
            string::utf8(b"name"),
            string::utf8(b"link"),
            string::utf8(b"image_url"),
            string::utf8(b"description"),
            string::utf8(b"project_url"),
            string::utf8(b"creator"),
        ];
        let values = vector[
            string::utf8(b"YouSUI x {project.name} <> {name}"),
            string::utf8(b"{project.link_url}"),
            string::utf8(b"{project.image_url}"),
            string::utf8(b"{project.description}"),
            string::utf8(b"{project.website}"),
            string::utf8(b"YouSUI Creator")
        ];
        let display = display::new_with_fields<T>(
            publisher, keys, values, ctx
        );
        display::update_version(&mut display);
        transfer::public_transfer(display, tx_context::sender(ctx));
    }

    public(friend) fun get_id(
        service: &Service,
    ): ID {
        let vesting = service::get_feature<Feature, Config>(service);
        object::uid_to_inner(&vesting.id)
    }

    public(friend) fun add(
        service: &mut Service,
        project: ProjectInfo,
        tge_time: u64,
        tge_unlock_percent: u64,
        number_of_cliff_months: u64,
        number_of_month: u64,
        number_of_linear: u64,
        token_type: String,
        ctx: &mut TxContext
    ) {
        assert!(tge_unlock_percent <= utils::max_percent(), ETgeUnlockPercentInvalid);
        service::add_feature<Feature, Config>(
            service,
            Config {
                id: object::new(ctx),
                info: VestingInfo {
                    tge_time,
                    tge_unlock_percent,
                    number_of_cliff_months,
                    number_of_month,
                    number_of_linear,
                    token_type
                },
                project,
                is_open_claim_vesting: false
            }
        )
    }

    public(friend) fun remove(service: &mut Service,) {
        let config = service::remove_feature<Feature, Config>(service);
        let Config { id, info: _, project: _, is_open_claim_vesting: _} = config;
        object::delete(id);
    }

    public(friend) fun set_is_vesting_info(
        service: &mut Service,
        tge_time: u64,
        tge_unlock_percent: u64,
        number_of_cliff_months: u64,
        number_of_month: u64,
        number_of_linear: u64,
        token_type: String
    ) {
        let feature_key = utils::get_key_by_struct<Feature>();
        if (vec_set::contains(service::features(service), &feature_key)) {
            let vesting = service::get_feature_mut<Feature, Config>(service);
            vesting.info = VestingInfo {
                tge_time,
                tge_unlock_percent,
                number_of_cliff_months,
                number_of_month,
                number_of_linear,
                token_type,
            };
        }
    }

    public(friend) fun set_is_open_claim_vesting(
        service: &mut Service,
        is_open_claim_vesting: bool,
    ) {
        let feature_key = utils::get_key_by_struct<Feature>();
        if (vec_set::contains(service::features(service), &feature_key)) {
            let vesting = service::get_feature_mut<Feature, Config>(service);
            vesting.is_open_claim_vesting = is_open_claim_vesting;
        }
    }

    public(friend) fun execute_migrate_vesting(
        service: &mut Service,
        investor: address
    ) {
        let feature_key = utils::get_key_by_struct<Feature>();
        if (vec_set::contains(service::features(service), &feature_key)) {
            migrate_vesting(service, investor);
        }
    }

    public(friend) fun execute_add_vesting(
        service: &mut Service,
        token_amount: u64,
        investor: address
    ) {
        let feature_key = utils::get_key_by_struct<Feature>();
        if (vec_set::contains(service::features(service), &feature_key)) {
            add_vesting(service, token_amount, investor);
        }
    }
    
    public(friend) fun execute_sub_vesting(
        service: &mut Service,
        token_amount: u64,
        investor: address
    ) {
        let feature_key = utils::get_key_by_struct<Feature>();
        if (vec_set::contains(service::features(service), &feature_key)) {
            sub_vesting(service, token_amount, investor);
        }
    }

    public(friend) fun check_is_open_claim_vesting(
        service: &Service,
    ): bool {
        let feature_key = utils::get_key_by_struct<Feature>();
        if (vec_set::contains(service::features(service), &feature_key)) {
            let vesting = service::get_feature<Feature, Config>(service);
            vesting.is_open_claim_vesting
        } else {
            false
        }
    }
    
    public(friend) fun update_withdraw_from_index_by_admin(
        service: &mut Service,
        period_id_list: vector<u64>,
        investor_list: vector<address>
    ) {
        assert!(!vector::is_empty(&period_id_list), EEmptyVector);
        assert!(!vector::is_empty(&investor_list), EEmptyVector);
        let vesting = service::get_feature_mut<Feature, Config>(service);

        while (!vector::is_empty(&investor_list)) {
            let investor = vector::pop_back(&mut investor_list);
            let vesting_detail = df::borrow_mut<address, VestingDetail>(&mut vesting.id, investor);
            let i = 0;
            while (i < vector::length(&period_id_list)) {
                let bm_period = vector::borrow_mut(&mut vesting_detail.period_list, *vector::borrow(&period_id_list, i));
                bm_period.is_withdrawal = true;
                i = i + 1;
            }
        };
    }

    public(friend) fun update_withdraw(
        clock: &Clock,
        service: &mut Service,
        period_id_list: vector<u64>,
        investor: address
    ): u64 {
        let vesting = service::get_feature_mut<Feature, Config>(service);

        let timestamp = clock::timestamp_ms(clock);
        let vesting_detail = df::borrow_mut<address, VestingDetail>(&mut vesting.id, investor);
        let total_unlock_temp: u64 = 0;

        while (!vector::is_empty(&period_id_list)) {
            let period_id = vector::pop_back(&mut period_id_list);
            let bm_period = vector::borrow_mut(&mut vesting_detail.period_list, period_id);
            assert!(timestamp >= bm_period.release_time, ETimestampLtReleaseTime);
            assert!(!bm_period.is_withdrawal, EClaimed);
            bm_period.is_withdrawal = true;
            total_unlock_temp = total_unlock_temp + bm_period.unlock_amount;
        };

        vesting_detail.total_unlock_amount = vesting_detail.total_unlock_amount + total_unlock_temp;
        total_unlock_temp
    }

//------------------------------------------------------------------------------------------------------------------------------------------------

    fun migrate_vesting(service: &mut Service, investor: address) {
        let vesting = service::get_feature_mut<Feature, Config>(service);
        if (df::exists_(&vesting.id, investor)) {
            let vesting_detail = df::borrow_mut<address, VestingDetail>(&mut vesting.id, investor);
            if (vesting_detail.total_unlock_amount == 0 && vesting_detail.total_lock_mount != 0) {
                build_migrate_vesting_period(&mut vesting_detail.period_list, &vesting.info, vesting_detail.total_lock_mount);
            }
        }
    }

    fun build_migrate_vesting_period(period_instance: &mut vector<Period>, vesting_info: &VestingInfo, token_amount: u64) {
        let period = vesting_info.number_of_month / vesting_info.number_of_linear;
        let length = math::max((period + 1), vector::length(period_instance));
        let i = 0;
        while(length > i) {
            if ((period + 1) > i) {
                if (vector::length(period_instance) > i) {
                    let period_sub = vector::borrow_mut(period_instance, i);
                    if (i == 0) {
                        period_sub.release_time = vesting_info.tge_time;
                        period_sub.percentage = vesting_info.tge_unlock_percent;
                        period_sub.unlock_amount = utils::cal_amount_with_percent(token_amount, vesting_info.tge_unlock_percent);
                    } else {
                        let chid_percent = (utils::max_percent() - vesting_info.tge_unlock_percent) / period;
                        period_sub.release_time =  vesting_info.tge_time + ((vesting_info.number_of_cliff_months + (i * vesting_info.number_of_linear)) * THIRTY_DAYS);
                        period_sub.percentage = chid_percent;
                        period_sub.unlock_amount = utils::cal_amount_with_percent(token_amount, chid_percent);
                    };      
                } else {
                    vector::push_back(
                        period_instance,
                        if (i == 0) {
                            Period {
                                    period_id: i,
                                    release_time: vesting_info.tge_time,
                                    percentage: vesting_info.tge_unlock_percent,
                                    unlock_amount: utils::cal_amount_with_percent(token_amount, vesting_info.tge_unlock_percent),
                                    is_withdrawal: false
                                }
                        } else {
                            let chid_percent = (utils::max_percent() - vesting_info.tge_unlock_percent) / period;
                            Period {
                                    period_id: i,
                                    release_time: (vesting_info.tge_time + ((vesting_info.number_of_cliff_months + (i * vesting_info.number_of_linear)) * THIRTY_DAYS)),
                                    percentage: chid_percent,
                                    unlock_amount: utils::cal_amount_with_percent(token_amount, chid_percent),
                                    is_withdrawal: false
                                }
                        }
                    );
                }
            } else {
                let period_sub = vector::borrow_mut(period_instance, i);
                    period_sub.release_time = vesting_info.tge_time + 315576000000; //10 years
                    period_sub.percentage = 0;
                    period_sub.unlock_amount = 0;
            };
            i = i + 1;
        };
    }

    fun add_vesting(service: &mut Service, token_amount: u64, investor: address) {
        let vesting = service::get_feature_mut<Feature, Config>(service);

        if (!df::exists_(&vesting.id, investor)) {
            df::add<address, VestingDetail>(&mut vesting.id, investor, VestingDetail {
                total_lock_mount: token_amount,
                total_unlock_amount: 0,
                period_list: build_vesting_period(&vesting.info, token_amount),
            });
        } else {
            let vesting_detail = df::borrow_mut<address, VestingDetail>(&mut vesting.id, investor);
            assert!(vesting_detail.total_unlock_amount == 0, ETotalUnlockEqZero);
            vesting_detail.total_lock_mount = vesting_detail.total_lock_mount + token_amount;
            update_add_vesting_period(&vesting.info, &mut vesting_detail.period_list, token_amount);
        }
    }

    fun sub_vesting(service: &mut Service, token_amount: u64, investor: address) {
        let vesting = service::get_feature_mut<Feature, Config>(service);

        assert!(df::exists_<address>(&vesting.id, investor), ESenderNotHaveVesting);

        let vesting_detail = df::borrow_mut<address, VestingDetail>(&mut vesting.id, investor);

        assert!(vesting_detail.total_unlock_amount == 0, ETotalUnlockEqZero);
        assert!(vesting_detail.total_lock_mount >= token_amount, ELockAmountGteSubAmount);

        vesting_detail.total_lock_mount = vesting_detail.total_lock_mount - token_amount;
        update_sub_vesting_period(&vesting.info, &mut vesting_detail.period_list, token_amount);
    }

    fun build_vesting_period(vesting_info: &VestingInfo, token_amount: u64): vector<Period> {
        let period_instance = vector::empty<Period>();
        let period = vesting_info.number_of_month / vesting_info.number_of_linear;
        let i = 0;
        while((period + 1) > i) {
            vector::push_back(
                &mut period_instance,
                if (i == 0) {
                    Period {
                            period_id: i,
                            release_time: vesting_info.tge_time,
                            percentage: vesting_info.tge_unlock_percent,
                            unlock_amount: utils::cal_amount_with_percent(token_amount, vesting_info.tge_unlock_percent),
                            is_withdrawal: false
                        }
                } else {
                    let chid_percent = (utils::max_percent() - vesting_info.tge_unlock_percent) / period;
                    Period {
                            period_id: i,
                            release_time: (vesting_info.tge_time + ((vesting_info.number_of_cliff_months + (i * vesting_info.number_of_linear)) * THIRTY_DAYS)),
                            percentage: chid_percent,
                            unlock_amount: utils::cal_amount_with_percent(token_amount, chid_percent),
                            is_withdrawal: false
                        }
                }
            );
            i = i + 1;
        };
        period_instance
    }

    fun update_add_vesting_period(vesting_info: &VestingInfo, latest_period_list: &mut vector<Period>, token_amount: u64) {
        let period = vesting_info.number_of_month / vesting_info.number_of_linear;
        let i = 0;
        while((period + 1) > i) {
            let child_period = vector::borrow_mut(latest_period_list, i);
            if (i == 0) {
                child_period.unlock_amount = child_period.unlock_amount + utils::cal_amount_with_percent(token_amount, vesting_info.tge_unlock_percent);
            } else {
                let chid_percent = (utils::max_percent() - vesting_info.tge_unlock_percent) / period;
                child_period.unlock_amount = child_period.unlock_amount + utils::cal_amount_with_percent(token_amount, chid_percent);
            };
            i = i + 1;
        }
    }

    fun update_sub_vesting_period(vesting_info: &VestingInfo, latest_period_list: &mut vector<Period>, token_amount: u64) {
        let period = vesting_info.number_of_month / vesting_info.number_of_linear;
        let i = 0;
        while((period + 1) > i) {
            let child_period = vector::borrow_mut(latest_period_list, i);
            if (i == 0) {
                child_period.unlock_amount = child_period.unlock_amount - utils::cal_amount_with_percent(token_amount, vesting_info.tge_unlock_percent);
            } else {
                let chid_percent = (utils::max_percent() - vesting_info.tge_unlock_percent) / period;
                child_period.unlock_amount = child_period.unlock_amount - utils::cal_amount_with_percent(token_amount, chid_percent);
            };
            i = i + 1;
        }
    }

//------------------------------------------------------------------------------------------------------------------------------------------------
    
}
