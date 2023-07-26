module yousui::policy_whitelist {
    use sui::tx_context::{Self, TxContext};
    use sui::vec_set::{Self, VecSet};

    use yousui::utils;
    use yousui::policy::{
        Self,
        Policy,
        Request
    };

    use std::vector;

    friend yousui::admin;
    friend yousui::ido;

    const ESenderNotInWhitelist: u64 = 1100;

    struct Rule has drop {}

    struct Config has store, drop {
        whitelist: VecSet<address>,
    }

    public(friend) fun add(
        policy: &mut Policy,
        investors: vector<address>
    ) {
        let whitelist = vec_set::empty<address>();
        while (!vector::is_empty(&investors)) vec_set::insert(&mut whitelist, vector::pop_back(&mut investors));

        policy::add_rule<Rule, Config>(policy, Config { whitelist })
    }

    public(friend) fun check(
        policy: &mut Policy,
        request: &mut Request,
        ctx: &mut TxContext
    ) {
        let rule_key = utils::get_key_by_struct<Rule>();
        if (vec_set::contains(policy::rules(policy), &rule_key)) {
            let sender = tx_context::sender(ctx);
            assert!(check_in_whitelist(policy, &sender), ESenderNotInWhitelist);
            policy::add_receipt<Rule>(request);
        }
    }

    public(friend) fun pass(
        policy: &mut Policy,
        request: &mut Request,
    ) {
        let rule_key = utils::get_key_by_struct<Rule>();
        if (vec_set::contains(policy::rules(policy), &rule_key)) {
            policy::add_receipt<Rule>(request);
        }
    }

    public fun check_in_whitelist(policy: &Policy, investor: &address): bool {
        let config = policy::get_rule<Rule, Config>(policy);
        vec_set::contains(&config.whitelist, investor)
    }

///////
    public(friend) fun set_whitelist(policy: &mut Policy, investors: vector<address>) {
        let config = policy::get_rule_mut<Rule, Config>(policy);
        while (!vector::is_empty(&investors)) {
            let investor = vector::pop_back(&mut investors);
            if (!vec_set::contains(&config.whitelist, &investor)) {
                vec_set::insert(&mut config.whitelist, investor);
            };
        };
    }

    public(friend) fun remove_whitelist(policy: &mut Policy, investors: vector<address>) {
        let config = policy::get_rule_mut<Rule, Config>(policy);
        while (!vector::is_empty(&investors)) {
            let investor = vector::pop_back(&mut investors);
            if (vec_set::contains(&config.whitelist, &investor)) {
                vec_set::remove(&mut config.whitelist, &investor);
            };
        };
    }

    public(friend) fun clear_whitelist(policy: &mut Policy) {
        let config = policy::get_rule_mut<Rule, Config>(policy);
        config.whitelist = vec_set::empty<address>();
    }
}
