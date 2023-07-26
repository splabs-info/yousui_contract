// SPDX-License-Identifier: Apache-2.0
module yousui_staking::admin {
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};
    use sui::coin::{Coin};
    use sui::transfer;

    use std::string::{String};
    use std::vector;

    use yousui_staking::staking::{Self, StakingStorage};
    use yousui_staking::vault;


    const ESetterIsNotSetted: u64 = 2100+0;

    struct AdminCap has key, store {
        id: UID,
    }

    struct AdminStorage has key, store {
        id: UID,
        setters: vector<address>,
    }
    
    fun init(ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);

        // Sender Admin cap to sender
        transfer::public_transfer(
            AdminCap {
                id: object::new(ctx),
            },
            sender
        );

        let setters = vector::empty<address>();

        vector::push_back(&mut setters, sender);

        // Share Admin storage
        transfer::share_object(AdminStorage {
           id: object::new(ctx),
           setters,
        });

    }


//------------------------------------------------------------------------ Begin Admin actions ------------------------------------------------------------------------

    entry public fun add_staking_package<T>(
        admin_storage: &AdminStorage,
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
        is_pause: bool,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        staking::add_staking_package<T>(
            staking_storage,
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
        );
    }

    entry public fun remove_staking_package<T>(
        admin_storage: &AdminStorage,
        staking_storage: &mut StakingStorage,
        key: String,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        staking::remove_staking_package<T>(
            staking_storage,
            key
        );
    }


//
    entry public fun set_name<T>(
        admin_storage: &AdminStorage,
        staking_storage: &mut StakingStorage,
        key: String,
        new_name: String,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        staking::set_name<T>(
            staking_storage,
            key,
            new_name
        );
    }

    entry public fun set_image<T>(
        admin_storage: &AdminStorage,
        staking_storage: &mut StakingStorage,
        key: String,
        new_image: String,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        staking::set_image<T>(
            staking_storage,
            key,
            new_image
        );
    }

    entry public fun set_website<T>(
        admin_storage: &AdminStorage,
        staking_storage: &mut StakingStorage,
        key: String,
        new_website: String,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        staking::set_website<T>(
            staking_storage,
            key,
            new_website
        );
    }

    entry public fun set_link<T>(
        admin_storage: &AdminStorage,
        staking_storage: &mut StakingStorage,
        key: String,
        new_link: String,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        staking::set_link<T>(
            staking_storage,
            key,
            new_link
        );
    }

    entry public fun set_description<T>(
        admin_storage: &AdminStorage,
        staking_storage: &mut StakingStorage,
        key: String,
        new_description: String,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        staking::set_description<T>(
            staking_storage,
            key,
            new_description
        );
    }
//

    entry public fun set_days<T>(
        admin_storage: &AdminStorage,
        staking_storage: &mut StakingStorage,
        key: String,
        days: u64,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        staking::set_days<T>(
            staking_storage,
            key,
            days
        );
    }

    entry public fun set_apr<T>(
        admin_storage: &AdminStorage,
        staking_storage: &mut StakingStorage,
        key: String,
        apr: u64,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        staking::set_apr<T>(
            staking_storage,
            key,
            apr
        );
    }

    entry public fun set_min_stake_amount<T>(
        admin_storage: &AdminStorage,
        staking_storage: &mut StakingStorage,
        key: String,
        min_stake_amount: u64,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        staking::set_min_stake_amount<T>(
            staking_storage,
            key,
            min_stake_amount
        );
    }

    entry public fun set_unstake_soon_fee<T>(
        admin_storage: &AdminStorage,
        staking_storage: &mut StakingStorage,
        key: String,
        unstake_soon_fee: u64,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        staking::set_unstake_soon_fee<T>(
            staking_storage,
            key,
            unstake_soon_fee
        );
    }

    entry public fun set_is_open<T>(
        admin_storage: &AdminStorage,
        staking_storage: &mut StakingStorage,
        key: String,
        is_open: bool,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        staking::set_is_open<T>(
            staking_storage,
            key,
            is_open
        );
    }

    entry public fun set_is_pause<T>(
        admin_storage: &AdminStorage,
        staking_storage: &mut StakingStorage,
        key: String,
        is_pause: bool,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        staking::set_is_pause<T>(
            staking_storage,
            key,
            is_pause
        );
    }

    public entry fun set_access_range_limit(
        admin_storage: &AdminStorage,
        staking_storage: &mut StakingStorage,
        access_range_limit: u64,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        staking::set_access_range_limit(
            staking_storage,
            access_range_limit
        );
    }

    public entry fun deposit_round<T>(
        admin_storage: &AdminStorage,
        staking_storage: &mut StakingStorage,
        coin: Coin<T>,
        ctx: &mut TxContext
    ) {

        check_is_setter(admin_storage, ctx);

        let vaults = staking::get_mut_vault(staking_storage);
        vault::deposit<T>(vaults, coin, ctx)
    }

    public entry fun withdraw_round<T>(
        admin_storage: &AdminStorage,
        staking_storage: &mut StakingStorage,
        amount: u64,
        ctx: &mut TxContext
    ) {
        check_is_setter(admin_storage, ctx);

        let vaults = staking::get_mut_vault(staking_storage);
        vault::withdraw<T>(vaults, amount, tx_context::sender(ctx), ctx)
    }

//------------------------------------------------------------------------ End Admin actions ------------------------------------------------------------------------

    fun check_is_setter(
        admin_storage: &AdminStorage,
        ctx: &mut TxContext
    ) {
        assert!(vector::contains(&admin_storage.setters, &tx_context::sender(ctx)), ESetterIsNotSetted);
    }
}
