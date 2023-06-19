// SPDX-License-Identifier: Apache-2.0
module yousui::whitelist {
    use sui::tx_context::{TxContext};
    use sui::object::{Self, UID};
    use sui::vec_set::{Self, VecSet};

    use std::vector;

    const WHITELIST_NAME: vector<u8> = b" <> Whitelist";

    friend yousui::admin;

    struct Whitelist has key, store {
        id: UID,
        address_list: VecSet<address>,
    }

    public fun get_name(): vector<u8> {
        WHITELIST_NAME
    }

    public(friend) fun new_whitelist(investors: vector<address>, ctx: &mut TxContext): Whitelist {
        let address_list = vec_set::empty<address>();
        while (!vector::is_empty(&investors)) vec_set::insert(&mut address_list, vector::pop_back(&mut investors));

        Whitelist {
            id: object::new(ctx),
            address_list,
        }
    }

    public(friend) fun set_whitelist(bm_whitelist: &mut Whitelist, investors: vector<address>) {
        while (!vector::is_empty(&investors)) {
            let investor = vector::pop_back(&mut investors);
            if (!vec_set::contains(&bm_whitelist.address_list, &investor)) {
                vec_set::insert(&mut bm_whitelist.address_list, investor);
            };
        };
    }

    public(friend) fun remove_whitelist(bm_whitelist: &mut Whitelist, investors: vector<address>) {
        while (!vector::is_empty(&investors)) {
            let investor = vector::pop_back(&mut investors);
            if (vec_set::contains(&bm_whitelist.address_list, &investor)) {
                vec_set::remove(&mut bm_whitelist.address_list, &investor);
            };
        };
    }

    public(friend) fun clear_whitelist(bm_whitelist: &mut Whitelist) {
        bm_whitelist.address_list = vec_set::empty<address>() 
        // vec_set::into_keys(whitelist.address_list);
    }

    public fun check_in_whitelist(b_whitelist: &Whitelist, b_investor: &address): bool {
        vec_set::contains(&b_whitelist.address_list, b_investor)
    }
}