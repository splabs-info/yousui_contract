module yousui::policy_staking_tier {
    use sui::vec_set;

    use std::string::{String};

    use yousui::utils;
    use yousui::policy::{Self, Policy, Request};
    use yousui_staking::staking::{Self, StakingStorage};

    friend yousui::admin;
    friend yousui::ido;

    const EInvalidStakingPoint: u64 = 1200+0;

    struct Rule has drop {}

    struct Config has store, drop {
        min_stake: u64,
        token_type: String
    }

    public(friend) fun add(
        policy: &mut Policy,
        min_stake: u64,
        token_type: String
    ) {
        policy::add_rule<Rule, Config>(policy, Config { min_stake, token_type })
    }

    public(friend) fun check(
        policy: &mut Policy,
        request: &mut Request,
        staking_storage: &StakingStorage,
        sender: address
    ) {
        let rule_key = utils::get_key_by_struct<Rule>();
        if (vec_set::contains(policy::rules(policy), &rule_key)) {
            assert!(check_yousui_staking(policy, staking_storage, sender), EInvalidStakingPoint);
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

    fun check_yousui_staking(policy: &Policy, staking_storage: &StakingStorage, sender: address): bool {
        let config: &Config = policy::get_rule<Rule, Config>(policy);
        staking::get_staking_point_by_address(staking_storage, sender, config.token_type) >= config.min_stake
    }    
}