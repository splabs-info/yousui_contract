// SPDX-License-Identifier: Apache-2.0
module yousui::policy {
    use std::vector;
    use sui::tx_context::{TxContext};
    use sui::object::{Self, ID, UID};
    use sui::vec_set::{Self, VecSet};
    use sui::dynamic_field as df;
    use sui::object_bag::{Self, ObjectBag};

    use std::string::{String};

    use yousui::utils;

    friend yousui::ido;
    friend yousui::policy_purchase;
    friend yousui::policy_yousui_nft;
    friend yousui::policy_whitelist;
    friend yousui::admin;

    const EPolicyNotSatisfied: u64 = 400+0;
    const EIllegalRule: u64 = 400+1;
    const ERuleAlreadySet: u64 = 400+2;


    struct Request {
        round_id: ID,
        receipts: VecSet<String>
    }

    struct Policy has key, store {
        id: UID,
        rules: VecSet<String>,
        other: ObjectBag,
    }

    public(friend) fun new_request(
        round_id: ID
    ): Request {
        Request { round_id, receipts: vec_set::empty() }
    }

    public(friend) fun new(ctx: &mut TxContext): (Policy, ID) {
        let policy = Policy { id: object::new(ctx), rules: vec_set::empty(), other: object_bag::new(ctx)};
        let id = *object::uid_as_inner(uid(&policy));
        (policy, id)
    }

    public(friend) fun uid(policy: &Policy): &UID {
        &policy.id
    }

    public(friend) fun confirm_request(policy: &Policy, request: Request): ID {
        let Request { round_id, receipts } = request;
        let completed = vec_set::into_keys(receipts);
        let total = vector::length(&completed);

        assert!(total == vec_set::size(&policy.rules), EPolicyNotSatisfied);

        while (vector::length(&completed) != 0) {
            let rule_key = vector::pop_back(&mut completed);
            assert!(vec_set::contains(&policy.rules, &rule_key), EIllegalRule);
        };

        round_id
    }

    public(friend) fun add_rule<Rule, Config: store + drop>(
        policy: &mut Policy, cfg: Config
    ) {
        let rule_key = utils::get_key_by_struct<Rule>();
        assert!(!has_rule(policy, rule_key), ERuleAlreadySet);
        vec_set::insert(&mut policy.rules, rule_key);
        df::add(&mut policy.id, rule_key, cfg);
    }

    public(friend) fun remove_rule<Rule, Config: store + drop>(
        policy: &mut Policy
    ) {
        let rule_key = utils::get_key_by_struct<Rule>();
        vec_set::remove(&mut policy.rules, &rule_key);
        let _: Config = df::remove(&mut policy.id, rule_key);
    }

    public(friend) fun get_rule<Rule, Config: store + drop>(policy: &Policy)
    : &Config {
        let rule_key = utils::get_key_by_struct<Rule>();
        df::borrow(&policy.id, rule_key)
    }

    public(friend) fun get_rule_mut<Rule, Config: store + drop>(policy: &mut Policy)
    : &mut Config {
        let rule_key = utils::get_key_by_struct<Rule>();
        df::borrow_mut(&mut policy.id, rule_key)
    }

    public(friend) fun add_receipt<Rule>(
        request: &mut Request
    ) {
        let rule_key = utils::get_key_by_struct<Rule>();
        vec_set::insert(&mut request.receipts, rule_key);
    }
    
    public(friend) fun has_rule(policy: &Policy, rule_key: String): bool {
        vec_set::contains(&policy.rules, &rule_key)
    }

    public(friend) fun rules(self: &Policy): &VecSet<String> {
        &self.rules
    }


}
