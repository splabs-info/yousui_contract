// SPDX-License-Identifier: Apache-2.0
module yousui::vault {
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, ID, UID};
    use sui::coin::{Self, Coin};
    use sui::pay;
    use sui::dynamic_object_field as dof;
    use sui::object_bag::{Self, ObjectBag};
    use sui::event::emit;

    use yousui::utils;

    friend yousui::ido;
    friend yousui::admin;

    struct Vaults has key, store {
        id: UID,
        other: ObjectBag,
    }

    // ======== Events =========

    struct InVault has copy, drop {
        vault_id: ID,
        amount: u64,
        sender: address
    }

    struct OutVault has copy, drop {
        vault_id: ID,
        amount: u64,
        sender: address
    }


    public(friend) fun new(ctx: &mut TxContext): (Vaults, ID) {
        let vault = Vaults { id: object::new(ctx), other: object_bag::new(ctx)};
        let id = *object::uid_as_inner(uid(&vault));
        (vault, id)
    }

    public(friend) fun uid(vaults: &Vaults): &UID {
        &vaults.id
    }

    // === Logic ===

    public(friend) fun deposit<T>(
        vaults: &mut Vaults,
        coin: Coin<T>,
        ctx: &mut TxContext
    ) {
        let coin_type = utils::get_full_type<T>();
        let coin_amount = coin::value(&coin);
        if (!dof::exists_(&vaults.id, coin_type)) {
            dof::add(&mut vaults.id, coin_type, coin::zero<T>(ctx));
        };
        coin::join(dof::borrow_mut(&mut vaults.id, coin_type), coin);

        emit(InVault{ vault_id: object::uid_to_inner(&vaults.id), amount: coin_amount, sender: tx_context::sender(ctx)});
    }

    public(friend) fun withdraw<T>(
        vaults: &mut Vaults,
        amount: u64,
        receiver: address,
        ctx: &mut TxContext
    ) {
        let coin_type = utils::get_full_type<T>();
        let coin_balance = dof::borrow_mut(&mut vaults.id, coin_type);

        pay::split_and_transfer<T>(coin_balance, amount, receiver, ctx);

        emit(OutVault{ vault_id: object::uid_to_inner(&vaults.id), amount, sender: tx_context::sender(ctx)});
    }

}
