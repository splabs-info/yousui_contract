// SPDX-License-Identifier: Apache-2.0
module yousui::launchpad {
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};
    use sui::coin::{Coin};
    use sui::object_bag::{Self, ObjectBag};
    use sui::package::{Self, Publisher};
    use sui::vec_set::{Self, VecSet};
    use sui::clock::{Clock};
    use sui::transfer;
    use sui::display;
    use sui::dynamic_object_field as dof;

    use std::string::{String, utf8};

    use yousui::project::{Self, Project};
    use yousui::ido::{Self, Round};
    use yousuinfts::nft::{YOUSUINFT};

    friend yousui::admin;

    struct LaunchpadStorage has key, store {
        id: UID,
        name: String,
        image: String,
        website: String,
        link: String,
        description: String,
        projects: VecSet<String>,
        other: ObjectBag,
    }

    struct LAUNCHPAD has drop {}

    fun init(witness: LAUNCHPAD, ctx: &mut TxContext) {
        let publisher = package::claim(witness, ctx);
        display<LaunchpadStorage>(&publisher, ctx);
        transfer::public_transfer(publisher, tx_context::sender(ctx));
        transfer::share_object(LaunchpadStorage {
           id: object::new(ctx),
           name: utf8(b"YouSUI Launchpad"),
           image: utf8(b"https://kol-sale.yousui.io/images/background/water-seek.jpg"),
           website: utf8(b"https://yousui.io"),
           link: utf8(b"https://kol-sale.yousui.io"),
           description: utf8(b"YouSUI is an All-In-One platform that runs on the Sui Blockchain and includes DEX, Launchpad, NFT Marketplace and Bridge."),
           projects: vec_set::empty(),
           other: object_bag::new(ctx)
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

    entry public fun purchase_ref<TOKEN, PAYMENT>(
        clock: &Clock,
        launchpad: &mut LaunchpadStorage,
        project_name: String,
        round_name: String,
        token_amount: u64,
        paid: vector<Coin<PAYMENT>>,
        affiliate_code: String,
        ctx: &mut TxContext
    ) {
        let project = borrow_mut_dynamic_object_field<Project>(launchpad, project_name);
        let round = project::borrow_mut_dynamic_object_field<Round>(project, round_name);
        ido::purchase_ref<TOKEN, PAYMENT>(clock, round, token_amount, paid, affiliate_code, ctx);
    }

    entry public fun purchase_nor<TOKEN, PAYMENT>(
        clock: &Clock,
        launchpad: &mut LaunchpadStorage,
        project_name: String,
        round_name: String,
        token_amount: u64,
        paid: vector<Coin<PAYMENT>>,
        ctx: &mut TxContext
    ) {
        let project = borrow_mut_dynamic_object_field<Project>(launchpad, project_name);
        let round = project::borrow_mut_dynamic_object_field<Round>(project, round_name);
        ido::purchase_nor<TOKEN, PAYMENT>(clock, round, token_amount, paid, ctx);
    }

    entry public fun purchase_yousui_og_holder<TOKEN, PAYMENT>(
        clock: &Clock,
        launchpad: &mut LaunchpadStorage,
        project_name: String,
        round_name: String,
        token_amount: u64,
        paid: vector<Coin<PAYMENT>>,
        hold_nft: &YOUSUINFT,
        ctx: &mut TxContext
    ) {
        let project = borrow_mut_dynamic_object_field<Project>(launchpad, project_name);
        let round = project::borrow_mut_dynamic_object_field<Round>(project, round_name);
        ido::purchase_yousui_og_holder<TOKEN, PAYMENT>(clock, round, token_amount, paid, hold_nft, ctx);
    }

    entry public fun claim_vesting<TOKEN>(
        clock: &Clock,
        launchpad: &mut LaunchpadStorage,
        project_name: String,
        round_name: String,
        period_id_list: vector<u64>,
        ctx: &mut TxContext
    ) {
        let project = borrow_mut_dynamic_object_field<Project>(launchpad, project_name);
        let round = project::borrow_mut_dynamic_object_field<Round>(project, round_name);
        ido::claim_vesting<TOKEN>(clock, round, period_id_list, ctx)
    }

    entry public fun claim_refund_preregister<PAYMENT>(
        clock: &Clock,
        launchpad: &mut LaunchpadStorage,
        project_name: String,
        round_name: String,
        ctx: &mut TxContext
    ) {
        let project = borrow_mut_dynamic_object_field<Project>(launchpad, project_name);
        let round = project::borrow_mut_dynamic_object_field<Round>(project, round_name);
        ido::claim_refund_preregister<PAYMENT>(clock, round, ctx)
    }

    public(friend) fun borrow_mut_dynamic_object_field<T: key + store>(launchpad: &mut LaunchpadStorage, project_name: String): &mut T {
        dof::borrow_mut(&mut launchpad.id, project_name)
    }

    public(friend) fun add_project(
        launchpad: &mut LaunchpadStorage,
        project_name: String,
        project: Project
    ) {
        vec_set::insert(&mut launchpad.projects, project_name);
        add_dof<Project>(launchpad, project_name, project);
    }

    fun add_dof<T: key + store>(launchpad: &mut LaunchpadStorage, field_name: String, filed_value: T) {
        dof::add(&mut launchpad.id, field_name, filed_value);
    }

}