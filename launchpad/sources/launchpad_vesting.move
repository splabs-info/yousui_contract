// SPDX-License-Identifier: Apache-2.0
module yousui::launchpad_vesting {
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID, ID};
    use sui::transfer;
    use sui::display;
    use sui::clock::{Self, Clock};
    use sui::package::{Self, Publisher};
    use sui::dynamic_field as df;

    use std::string::{Self, String};
    use std::vector;

    use yousui::utils;
    use yousui::launchpad_project::{Self, Project, ProjectInfo};

    friend yousui::admin;
    friend yousui::launchpad_ido;
    friend yousui::launchpad_presale;
    

    // const THIRTY_DAYS: u64 = 2_592_000_000; // 30 DAYS
    const THIRTY_DAYS: u64 = 300_000; //5 MINUTES
    const MAX_PERCENT: u64 = 100_000_000_000; // => 100 //decimal 9
    const VESTING_NAME: vector<u8> = b" <> Vesting";

    const ETgeTimeInvalid: u64 = 500+1;
    const ETgeUnlockPercentInvalid: u64 = 500+2;
    const ETotalUnlockEqZero: u64 = 500+3;
    const ETimestampLtReleaseTime: u64 = 500+4;
    const ESenderNotHaveVesting: u64 = 500+5;
    const ELockAmountGteSubAmount: u64 = 500+6;
    const EClaimed: u64 = 500+7;
    
    struct Vesting has key, store {
        id: UID,
        name: String,
        project: ProjectInfo,
        info: VestingInfo,
    }

    struct VestingInfo has store {
        tge_time: u64,
        tge_unlock_percent: u64,
        number_of_cliff_months: u64,
        number_of_month: u64,
        number_of_linear: u64,
        token_type: String,
    }

    struct VestingDetail has store {
        total_lock_mount: u64,
        total_unlock_amount: u64,
        period_list: vector<Period>,
    }

    struct Period has store {
        period_id: u64,
        release_time: u64,
        percentage: u64,
        unlock_amount: u64,
        is_withdrawal: bool,
    }

    struct LAUNCHPAD_VESTING has drop {}

    fun init(witness: LAUNCHPAD_VESTING, ctx: &mut TxContext) {
        let publisher = package::claim(witness, ctx);
        display<Vesting>(&publisher, ctx);
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

    fun convert_to_vesting_string(round_name: String): String {
        string::append_utf8(&mut round_name, VESTING_NAME);
        round_name
    }

    public(friend) fun update_withdraw(
        clock: &Clock,
        project: &mut Project,
        round_name: String,
        period_id_list: vector<u64>,
        ctx: &mut TxContext
    ): u64 {
        let sender = tx_context::sender(ctx);
        let timestamp = clock::timestamp_ms(clock);
        let bm_vesting = borrow_mut_vesting(project, convert_to_vesting_string(round_name));
        let bm_vesting_detail = df::borrow_mut<address, VestingDetail>(&mut bm_vesting.id, sender);
        let total_unlock_temp: u64 = 0;

        while (!vector::is_empty(&period_id_list)) {
            let period_id = vector::pop_back(&mut period_id_list);
            let bm_period = vector::borrow_mut(&mut bm_vesting_detail.period_list, period_id);
            assert!(timestamp >= bm_period.release_time, ETimestampLtReleaseTime);
            assert!(!bm_period.is_withdrawal, EClaimed);
            bm_period.is_withdrawal = true;
            total_unlock_temp = total_unlock_temp + bm_period.unlock_amount;
        };

        bm_vesting_detail.total_unlock_amount = bm_vesting_detail.total_unlock_amount + total_unlock_temp;
        total_unlock_temp
    }

    public(friend) fun new_vesting(
        clock: &Clock,
        project: &Project,
        round_name: String,
        tge_time: u64,
        tge_unlock_percent: u64,
        number_of_cliff_months: u64,
        number_of_month: u64,
        number_of_linear: u64,
        token_type: String,
        ctx: &mut TxContext
    ): (Vesting, String, ID) {
        let timestamp = clock::timestamp_ms(clock);
        let name = convert_to_vesting_string(round_name);

        assert!(tge_time >= timestamp, ETgeTimeInvalid);
        assert!(tge_unlock_percent <= MAX_PERCENT, ETgeUnlockPercentInvalid);

        let vesting_uid = object::new(ctx);
        let vesting_id = object::uid_to_inner(&vesting_uid);

        (Vesting {
            id: vesting_uid,
            name,
            project: launchpad_project::get_project_info(project),
            info: VestingInfo {
                tge_time,
                tge_unlock_percent,
                number_of_cliff_months,
                number_of_month,
                number_of_linear,
                token_type
            },
        }, name, vesting_id )
    }

    fun borrow_mut_vesting(project: &mut Project, round_name: String): &mut Vesting {
        launchpad_project::borrow_mut_dynamic_object_field<Vesting>(project, round_name)
    }

    fun borrow_vesting(project: &Project, round_name: String): &Vesting {
        launchpad_project::borrow_dynamic_object_field<Vesting>(project, round_name)
    }

    public(friend) fun add_vesting(project: &mut Project, round_name: String, token_amount: u64, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        let bm_vesting = borrow_mut_vesting(project, convert_to_vesting_string(round_name));

        if (!df::exists_<address>(&bm_vesting.id, sender)) {
            df::add<address, VestingDetail>(&mut bm_vesting.id, sender, VestingDetail {
                total_lock_mount: token_amount,
                total_unlock_amount: 0,
                period_list: build_vesting_period(&bm_vesting.info, token_amount),
            });
        } else {
            let bm_vesting_detail = df::borrow_mut<address, VestingDetail>(&mut bm_vesting.id, sender);
            assert!(bm_vesting_detail.total_unlock_amount == 0, ETotalUnlockEqZero);
            bm_vesting_detail.total_lock_mount = bm_vesting_detail.total_lock_mount + token_amount;
            update_add_vesting_period(&bm_vesting.info, &mut bm_vesting_detail.period_list, token_amount);
        }
    }

    public(friend) fun sub_vesting(project: &mut Project, round_name: String, token_amount: u64, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        let bm_vesting = borrow_mut_vesting(project, convert_to_vesting_string(round_name));

        assert!(df::exists_<address>(&bm_vesting.id, sender), ESenderNotHaveVesting);

        let bm_vesting_detail = df::borrow_mut<address, VestingDetail>(&mut bm_vesting.id, sender);

        assert!(bm_vesting_detail.total_unlock_amount == 0, ETotalUnlockEqZero);
        assert!(bm_vesting_detail.total_lock_mount >= token_amount, ELockAmountGteSubAmount);

        bm_vesting_detail.total_lock_mount = bm_vesting_detail.total_lock_mount - token_amount;
        update_sub_vesting_period(&bm_vesting.info, &mut bm_vesting_detail.period_list, token_amount);
    }


    fun cal_amount_with_percent(token_amount: u64, percent: u64): u64 {
        utils::mul_u64_div_u64(token_amount, percent, MAX_PERCENT)
    }

    fun update_add_vesting_period(vesting_info: &VestingInfo, latest_period_list: &mut vector<Period>, token_amount: u64) {
        let period = vesting_info.number_of_month / vesting_info.number_of_linear;
        let i = 0;
        while((period + 1) > i) {
            let child_period = vector::borrow_mut(latest_period_list, i);
            if (i == 0) {
                child_period.unlock_amount = child_period.unlock_amount + cal_amount_with_percent(token_amount, vesting_info.tge_unlock_percent);
            } else {
                let chid_percent = (MAX_PERCENT - vesting_info.tge_unlock_percent) / period;
                child_period.unlock_amount = child_period.unlock_amount + cal_amount_with_percent(token_amount, chid_percent);
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
                child_period.unlock_amount = child_period.unlock_amount - cal_amount_with_percent(token_amount, vesting_info.tge_unlock_percent);
            } else {
                let chid_percent = (MAX_PERCENT - vesting_info.tge_unlock_percent) / period;
                child_period.unlock_amount = child_period.unlock_amount - cal_amount_with_percent(token_amount, chid_percent);
            };
            i = i + 1;
        }
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
                            unlock_amount: cal_amount_with_percent(token_amount, vesting_info.tge_unlock_percent),
                            is_withdrawal: false
                        }
                } else {
                    let chid_percent = (MAX_PERCENT - vesting_info.tge_unlock_percent) / period;
                    Period {
                            period_id: i,
                            release_time: (vesting_info.tge_time + ((vesting_info.number_of_cliff_months + i) * THIRTY_DAYS)),
                            percentage: chid_percent,
                            unlock_amount: cal_amount_with_percent(token_amount, chid_percent),
                            is_withdrawal: false
                        }
                }
            );
            i = i + 1;
        };
        period_instance
    }

}