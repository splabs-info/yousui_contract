module yousui::policy_purchase {
    use sui::vec_set;

    use yousui::utils;
    use yousui::policy::{Self, Policy, Request};

    friend yousui::admin;
    friend yousui::ido;

    const EInvalidMinMaxPurchase: u64 = 200+0;
    const EInvalidAmountPurchase: u64 = 200+1;

    struct Rule has drop {}

    struct Config has store, drop {
        min_purchase: u64,
        max_purchase: u64,
    }

    public(friend) fun add(
        policy: &mut Policy,
        min_purchase: u64,
        max_purchase: u64,
    ) {
        assert!(min_purchase <= max_purchase, EInvalidMinMaxPurchase);
        policy::add_rule<Rule, Config>(policy, Config { min_purchase, max_purchase })
    }


    public(friend) fun check(
        policy: &mut Policy,
        request: &mut Request,
        amount_purchase: u64,
    ) {
        let rule_key = utils::get_key_by_struct<Rule>();
        if (vec_set::contains(policy::rules(policy), &rule_key)) {
            assert!(validate_amount_purchase(policy, amount_purchase), EInvalidAmountPurchase);
            policy::add_receipt<Rule>(request);
        }
    }

    public(friend) fun validate_amount_purchase(policy: &Policy<>, amount_purchase: u64): bool {
        let config: &Config = policy::get_rule<Rule, Config>(policy);
        config.min_purchase <= amount_purchase && amount_purchase <= config.max_purchase
    }
}
