// SPDX-License-Identifier: Apache-2.0
module yousui_staking::staking {
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID, ID};
    use sui::coin::{Self, Coin};
    use sui::object_bag::{Self, ObjectBag};
    use sui::package::{Self, Publisher};
    use sui::vec_map::{Self, VecMap};
    use sui::clock::{Self, Clock};
    use sui::transfer;
    use sui::math;
    use sui::display;
    use sui::event::emit;
    use sui::dynamic_field as df;

    use std::string::{String, utf8};
    use std::option::{Self, Option};

    use yousui_staking::certificate::{Self, InvestmentCertificate};
    use yousui_staking::utils;
    use yousui_staking::vault::{Self, Vaults};

    friend yousui_staking::admin;

    const EStakingPackageNotOpen: u64 = 2000+0;
    const EStakingAmountExceedMin: u64 = 2000+1;
    const EStakingPackageIsPaused: u64 = 2000+2;
    const EActionTimeLimit: u64 = 2000+3;
    const ENoProfit: u64 = 2000+4;
    const EUnstakedCert: u64 = 2000+5;

    const ONE_DAY: u64 = 86_400_000; // 1 DAY
    // const ONE_DAY: u64 = 300_000; // 5 MINUTES
    const HUNDRED_PERCENT: u64 = 100;
    const ONE_YEAR_BY_DAYS: u64 = 365;
    const COMMON_DECIMAL: u8 = 9;
    const VAULT: vector<u8> = b"VAULT";
    const ACTION_STAKE: vector<u8> = b"ACTION_STAKE";
    const ACTION_UNSTAKE: vector<u8> = b"ACTION_UNSTAKE";

    struct STAKING has drop {}
    
    struct StakingStorage has key {
        id: UID,
        name: String,
        image: String,
        website: String,
        link: String,
        description: String,
        access_range_limit: u64, // miliseconds
        invest_list: VecMap<address, VecMap<String, u64>>,
        // access_list: VecMap<address, u64>,
        access_list: VecMap<address, VecMap<String, u64>>,
        core: VecMap<String, ID>,
        other: ObjectBag,
    }

    struct StakingPackage<phantom T> has store, drop {
        key: String,
        name: String,
        image: String,
        website: String,
        link: String,
        description: String,
        days: u64,
        apr: u64, //percent
        min_stake_amount: u64,
        unstake_soon_fee: u64, //percent
        is_open: bool,
        is_pause: bool,
    }

    struct ProofOfStake has store {
        staker: address,
        stake_token: String,
        stake_amount: u64,
        stake_date: u64,
        unstake_date: Option<u64>,
        latest_claim_date: Option<u64>,
        profit_claimed_amount: u64,
        stake_package_key: String,
        apr_at_moment: u64, //percent
        days_at_moment: u64,
        name_at_moment: String,
    }

    // ======== Events =========

    struct Stake has copy, drop {
        sender: address,
        epoch_time: u64,
        package_key: String,
        apr: u64,
        days: u64,
        stake_amount: u64
    }

    struct Unstake has copy, drop {
        sender: address,
        epoch_time: u64,
        package_key: String,
        apr: u64,
        accumulated_days: u64,
        profit: u64,
        stake_amount: u64
    }

    struct Claim has copy, drop {
        sender: address,
        epoch_time: u64,
        package_key: String,
        apr: u64,
        accumulated_days: u64,
        profit: u64,
        stake_amount: u64
    }
    
    fun init(witness: STAKING, ctx: &mut TxContext) {
        let publisher = package::claim(witness, ctx);
        display<StakingStorage>(&publisher, ctx);
        transfer::public_transfer(publisher, tx_context::sender(ctx));

        let core = vec_map::empty<String, ID>();
        let other = object_bag::new(ctx);

        new_vault(&mut core, &mut other, ctx);

        transfer::share_object(StakingStorage {
            id: object::new(ctx),
            name: utf8(b"YouSUI Staking"),
            image: utf8(b"https://yousui.io/images/staking/water-seek.jpg"),
            website: utf8(b"https://yousui.io"),
            link: utf8(b"https://yousui.io/staking"),
            description: utf8(b"YouSUI is an All-In-One platform that runs on the Sui Blockchain and includes DEX, Launchpad, NFT Marketplace and Bridge."),
            access_range_limit: ONE_DAY,
            invest_list: vec_map::empty<address, VecMap<String, u64>>(),
            //    access_list: vec_map::empty<address, u64>(),
            access_list: vec_map::empty<address, VecMap<String, u64>>(),
            core,
            other
        });
    }

    fun display<T: key>(publisher: &Publisher, ctx: &mut TxContext) {
        let keys = vector[
            utf8(b"name"),
            utf8(b"link"),
            utf8(b"image_url"),
            utf8(b"description"),
            utf8(b"project_url"),
            utf8(b"creator"),
        ];
        let values = vector[
            utf8(b"{name}"),
            utf8(b"{link}"),
            utf8(b"{image}"),
            utf8(b"{description}"),
            utf8(b"{website}"),
            utf8(b"YouSUI Creator")
        ];
        let display = display::new_with_fields<T>(
            publisher, keys, values, ctx
        );
        display::update_version(&mut display);
        transfer::public_transfer(display, tx_context::sender(ctx));
    }

    // fun add_df_<T: store>(staking_storage: &mut StakingStorage, field_key: String, filed_value: T) {
    //     df::add(&mut staking_storage.id, field_key, filed_value);
    // }

    fun new_vault(core: &mut VecMap<String, ID>, other: &mut ObjectBag, ctx: &mut TxContext) {
        let key = utf8(b"VAULT");

        let (vault, vault_id) = vault::new(ctx);
        vec_map::insert(core, key, vault_id);
        object_bag::add(other, key, vault);
    }

    public(friend) fun add_staking_package<T>(
        staking_storage: &mut StakingStorage,
        key: String,
        name: String,
        image: String,
        website: String,
        link: String,
        description: String,
        days: u64,
        apr: u64,
        min_stake_amount: u64,
        unstake_soon_fee: u64,
        is_open: bool,
        is_pause: bool
    ) {
        df::add(
            &mut staking_storage.id,
            key,
            StakingPackage<T> {
                key,
                name,
                image,
                website,
                link,
                description,
                days,
                apr,
                min_stake_amount,
                unstake_soon_fee,
                is_open,
                is_pause
            }
        );
    }

    public(friend) fun remove_staking_package<T>(
        staking_storage: &mut StakingStorage,
        key: String,
    ) {
        df::remove<String, StakingPackage<T>>(
            &mut staking_storage.id,
            key
        );
    }

    public(friend) fun set_name<T>(
        staking_storage: &mut StakingStorage,
        key: String,
        new_name: String,
    ) {
        let staking_package = df::borrow_mut<String, StakingPackage<T>>(&mut staking_storage.id, key);
        staking_package.name = new_name;
    }

    public(friend) fun set_image<T>(
        staking_storage: &mut StakingStorage,
        key: String,
        new_image: String,
    ) {
        let staking_package = df::borrow_mut<String, StakingPackage<T>>(&mut staking_storage.id, key);
        staking_package.image = new_image;
    }

    public(friend) fun set_website<T>(
        staking_storage: &mut StakingStorage,
        key: String,
        new_website: String,
    ) {
        let staking_package = df::borrow_mut<String, StakingPackage<T>>(&mut staking_storage.id, key);
        staking_package.website = new_website;
    }

    public(friend) fun set_link<T>(
        staking_storage: &mut StakingStorage,
        key: String,
        new_link: String,
    ) {
        let staking_package = df::borrow_mut<String, StakingPackage<T>>(&mut staking_storage.id, key);
        staking_package.link = new_link;
    }

    public(friend) fun set_description<T>(
        staking_storage: &mut StakingStorage,
        key: String,
        new_description: String,
    ) {
        let staking_package = df::borrow_mut<String, StakingPackage<T>>(&mut staking_storage.id, key);
        staking_package.description = new_description;
    }

    public(friend) fun set_days<T>(
        staking_storage: &mut StakingStorage,
        key: String,
        days: u64,
    ) {
        let staking_package = df::borrow_mut<String, StakingPackage<T>>(&mut staking_storage.id, key);
        staking_package.days = days;
    }

    public(friend) fun set_apr<T>(
        staking_storage: &mut StakingStorage,
        key: String,
        apr: u64,
    ) {
        let staking_package = df::borrow_mut<String, StakingPackage<T>>(&mut staking_storage.id, key);
        staking_package.apr = apr;
    }

    public(friend) fun set_min_stake_amount<T>(
        staking_storage: &mut StakingStorage,
        key: String,
        min_stake_amount: u64,
    ) {
        let staking_package = df::borrow_mut<String, StakingPackage<T>>(&mut staking_storage.id, key);
        staking_package.min_stake_amount = min_stake_amount;
    }

    public(friend) fun set_unstake_soon_fee<T>(
        staking_storage: &mut StakingStorage,
        key: String,
        unstake_soon_fee: u64,
    ) {
        let staking_package = df::borrow_mut<String, StakingPackage<T>>(&mut staking_storage.id, key);
        staking_package.unstake_soon_fee = unstake_soon_fee;
    }

    public(friend) fun set_is_open<T>(
        staking_storage: &mut StakingStorage,
        key: String,
        is_open: bool,
    ) {
        let staking_package = df::borrow_mut<String, StakingPackage<T>>(&mut staking_storage.id, key);
        staking_package.is_open = is_open;
    }

    public(friend) fun set_is_pause<T>(
        staking_storage: &mut StakingStorage,
        key: String,
        is_pause: bool,
    ) {
        let staking_package = df::borrow_mut<String, StakingPackage<T>>(&mut staking_storage.id, key);
        staking_package.is_pause = is_pause;
    }

    public(friend) fun set_access_range_limit(
        staking_storage: &mut StakingStorage,
        access_range_limit: u64,
    ) {
        staking_storage.access_range_limit = access_range_limit;
    }

    public(friend) fun get_mut_vault(staking_storage: &mut StakingStorage): &mut Vaults {
        object_bag::borrow_mut(&mut staking_storage.other, utf8(VAULT))
    }

    public fun get_staking_point_by_address(
        staking_storage: &StakingStorage,
        investor: address,
        token_type: String
    ): u64 {
        if (vec_map::contains(&staking_storage.invest_list, &investor)) {     
            let all_accumulate_stake = vec_map::get(&staking_storage.invest_list, &investor);
            let token_accumulate_stake = vec_map::get(all_accumulate_stake, &token_type);
            *token_accumulate_stake
        } else 0
    }

    entry public fun stake<T>(
        clock: &Clock,
        staking_storage: &mut StakingStorage,
        key: String,
        coins: Coin<T>,
        ctx: &mut TxContext
    ) {

        let now = clock::timestamp_ms(clock);
        let sender = tx_context::sender(ctx);
        let token_type = utils::get_full_type<T>();
        let staking_package = df::borrow<String, StakingPackage<T>>(&staking_storage.id, key);
        let stake_vault = object_bag::borrow_mut(&mut staking_storage.other, utf8(VAULT));
        let stake_amount = coin::value(&coins);

        // handle count staked accumulate
        if (vec_map::contains(&staking_storage.invest_list, &sender)) {
            let all_accumulate_stake = vec_map::get_mut(&mut staking_storage.invest_list, &sender);
            let token_accumulate_stake = vec_map::get_mut(all_accumulate_stake, &token_type);
            *token_accumulate_stake = *token_accumulate_stake + stake_amount;
        } else {
            let token_accumulate_stake = vec_map::empty<String, u64>();
            vec_map::insert(&mut token_accumulate_stake, token_type, stake_amount);
            vec_map::insert(&mut staking_storage.invest_list, sender, token_accumulate_stake);
        };

        if (vec_map::contains(&staking_storage.access_list, &sender)) {
            let action_access_list = vec_map::get(&mut staking_storage.access_list, &sender);
            if (vec_map::contains(action_access_list, &utf8(ACTION_UNSTAKE))) {
                let action_access_time = *vec_map::get(action_access_list, &utf8(ACTION_UNSTAKE));
                assert!(is_access_granted(now, action_access_time, staking_storage.access_range_limit), EActionTimeLimit);
            }
        };
        assert!(staking_package.is_open, EStakingPackageNotOpen);
        assert!(stake_amount >= staking_package.min_stake_amount, EStakingAmountExceedMin);

        // //handle access
        // if (vec_map::contains(&staking_storage.access_list, &sender)) {
        //     let action_access_list = vec_map::get_mut(&mut staking_storage.access_list, &sender);
        //     let action_access_time = vec_map::get_mut(action_access_list, &utf8(ACTION_STAKE));
        //     *action_access_time = now;
        // } else {
        //     let action_access_time = vec_map::empty<String, u64>();
        //     vec_map::insert(&mut action_access_time, utf8(ACTION_STAKE), now);
        //     vec_map::insert(&mut staking_storage.access_list, sender, action_access_time);
        // };
        if (vec_map::contains(&staking_storage.access_list, &sender)) {
            let action_access_list = vec_map::get_mut(&mut staking_storage.access_list, &sender);
            if (vec_map::contains(action_access_list, &utf8(ACTION_STAKE))) {
                let action_access_time = vec_map::get_mut(action_access_list, &utf8(ACTION_STAKE));
                *action_access_time = now;
            } else {
                vec_map::insert(action_access_list, utf8(ACTION_STAKE), now);
            }
        } else {
            let action_access_time = vec_map::empty<String, u64>();
            vec_map::insert(&mut action_access_time, utf8(ACTION_STAKE), now);
            vec_map::insert(&mut staking_storage.access_list, sender, action_access_time);
        };

        vault::deposit<T>(stake_vault, coins, ctx);

        certificate::issue_investment_certificate<ProofOfStake>(
            clock,
            staking_package.name,
            staking_package.image,
            staking_package.website,
            staking_package.link,
            staking_package.description,
            ProofOfStake {
                staker: tx_context::sender(ctx),
                stake_token: utils::get_full_type<T>(),
                stake_amount,
                stake_date: now,
                unstake_date: option::none<u64>(),
                latest_claim_date: option::none<u64>(),
                profit_claimed_amount: 0,
                stake_package_key: key,
                apr_at_moment: staking_package.apr,
                days_at_moment: staking_package.days,
                name_at_moment: staking_package.name
            },
            ctx
        );

        emit(
            Stake {
                sender,
                epoch_time: now,
                package_key: key,
                apr: staking_package.apr,
                days: staking_package.days,
                stake_amount
            }
        );
    }

    entry public fun unstake<T>(
        clock: &Clock,
        staking_storage: &mut StakingStorage,
        cert: &mut InvestmentCertificate,
        ctx: &mut TxContext
    ) {

        let now = clock::timestamp_ms(clock);
        let sender = tx_context::sender(ctx);
        let token_type = utils::get_full_type<T>();
        let pos: &mut ProofOfStake = certificate::get_mut_df_info<ProofOfStake>(cert);
        let staking_package = df::borrow<String, StakingPackage<T>>(&staking_storage.id, pos.stake_package_key);

        if (vec_map::contains(&staking_storage.access_list, &sender)) {
            let action_access_list = vec_map::get(&mut staking_storage.access_list, &sender);
            if (vec_map::contains(action_access_list, &utf8(ACTION_STAKE))) {
                let action_access_time = *vec_map::get(action_access_list, &utf8(ACTION_STAKE));
                assert!(is_access_granted(now, action_access_time, staking_storage.access_range_limit), EActionTimeLimit);
            }
        };
        assert!(!staking_package.is_pause, EStakingPackageIsPaused);
        assert!(option::is_none(&pos.unstake_date), EUnstakedCert);

        let (claim_time, accumulated_days) = cal_time_and_days(
            now,
            if (option::is_none(&pos.latest_claim_date)) pos.stake_date else option::extract(&mut pos.latest_claim_date)
        );

        let profit = accumulated_days * cal_profit_per_day(pos.stake_amount, pos.apr_at_moment);
        let revenue = pos.stake_amount + profit;
        if (accumulated_days < pos.days_at_moment) {
            let penalty = utils::mul_u64_div_decimal(pos.stake_amount, parse_percent(staking_package.unstake_soon_fee), COMMON_DECIMAL);
            revenue = revenue - penalty;
        };

        // handle accumulate stake
        let all_accumulate_stake = vec_map::get_mut(&mut staking_storage.invest_list, &sender);
        let token_accumulate_stake = vec_map::get_mut(all_accumulate_stake, &token_type);
        *token_accumulate_stake = *token_accumulate_stake - pos.stake_amount;

        //handle access
        // if (vec_map::contains(&staking_storage.access_list, &sender)) {
        //     let action_access_list = vec_map::get_mut(&mut staking_storage.access_list, &sender);
        //     let action_access_time = vec_map::get_mut(action_access_list, &utf8(ACTION_UNSTAKE));
        //     *action_access_time = now;
        // } else {
        //     let action_access_time = vec_map::empty<String, u64>();
        //     vec_map::insert(&mut action_access_time, utf8(ACTION_UNSTAKE), now);
        //     vec_map::insert(&mut staking_storage.access_list, sender, action_access_time);
        // };
        let action_access_list = vec_map::get_mut(&mut staking_storage.access_list, &sender);
        if (vec_map::contains(action_access_list, &utf8(ACTION_UNSTAKE))) {
            let action_access_time = vec_map::get_mut(action_access_list, &utf8(ACTION_UNSTAKE));
            *action_access_time = now;   
        } else {
            vec_map::insert(action_access_list, utf8(ACTION_UNSTAKE), now);
        };

        //handle update latest claim pos
        option::fill(&mut pos.latest_claim_date, claim_time);

        //handle unstake day
        option::fill(&mut pos.unstake_date, now);

        //hanlde update profit claimed
        pos.profit_claimed_amount = pos.profit_claimed_amount + profit;

        let stake_vault = object_bag::borrow_mut(&mut staking_storage.other, utf8(VAULT));

        vault::withdraw<T>(stake_vault, revenue, sender, ctx);

        emit(
            Unstake {
                sender,
                epoch_time: now,
                package_key: pos.stake_package_key,
                apr: pos.apr_at_moment,
                accumulated_days,
                profit,
                stake_amount: pos.stake_amount
            }
        );
    }

    entry public fun claim<T>(
        clock: &Clock,
        staking_storage: &mut StakingStorage,
        cert: &mut InvestmentCertificate,
        ctx: &mut TxContext
    ) {

        let now = clock::timestamp_ms(clock);
        let sender = tx_context::sender(ctx);
        let pos: &mut ProofOfStake = certificate::get_mut_df_info<ProofOfStake>(cert);
        let staking_package = df::borrow<String, StakingPackage<T>>(&staking_storage.id, pos.stake_package_key);

        assert!(!staking_package.is_pause, EStakingPackageIsPaused);
        assert!(option::is_none(&pos.unstake_date), EUnstakedCert);


        let (claim_time, accumulated_days) = cal_time_and_days(
            now,
            if (option::is_none(&pos.latest_claim_date)) pos.stake_date else option::extract(&mut pos.latest_claim_date)
        );

        let profit = accumulated_days * cal_profit_per_day(pos.stake_amount, pos.apr_at_moment);

        assert!(profit > 0, ENoProfit);

        //handle update latest claim pos
        option::fill(&mut pos.latest_claim_date, claim_time);

        //hanlde update profit claimed
        pos.profit_claimed_amount = pos.profit_claimed_amount + profit;

        let stake_vault = object_bag::borrow_mut(&mut staking_storage.other, utf8(VAULT));

        vault::withdraw<T>(stake_vault, profit, sender, ctx);

        emit(
            Claim {
                sender,
                epoch_time: now,
                package_key: pos.stake_package_key,
                apr: pos.apr_at_moment,
                accumulated_days,
                profit,
                stake_amount: pos.stake_amount
            }
        );
    }

    fun cal_profit_per_day(stake_amount: u64, apr: u64): u64 {
        utils::mul_u64_div_u64(stake_amount, parse_percent(apr), (ONE_YEAR_BY_DAYS * math::pow(10, COMMON_DECIMAL)))
    }

    fun parse_percent(percent: u64): u64 {
        percent / HUNDRED_PERCENT
    }

    fun cal_time_and_days(now: u64, base_time: u64): (u64,u64) {
        let range_time = math::diff(now, base_time);
        let days = range_time / ONE_DAY;
        let time = days * ONE_DAY;
        (base_time + time, days)
    }

    fun is_access_granted(now: u64, latest_access: u64, range_limit: u64): bool {
        (now - latest_access) > range_limit
    }
}