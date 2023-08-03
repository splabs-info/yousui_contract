module yousui::policy_yousui_nft {
    use sui::vec_set;

    use yousui::utils;
    use yousui::policy::{Self, Policy, Request};
    use yousuinfts::nft::{Self, YOUSUINFT};

    friend yousui::admin;
    friend yousui::ido;

    const EInvalidNftOGType: u64 = 1000+0;

    struct Rule has drop {}

    struct Config has store, drop {}

    public(friend) fun add(
        policy: &mut Policy,
    ) {
        policy::add_rule<Rule, Config>(policy, Config {})
    }

    public(friend) fun check(
        policy: &mut Policy,
        request: &mut Request,
        hold_nft: &YOUSUINFT,
    ) {
        let rule_key = utils::get_key_by_struct<Rule>();
        if (vec_set::contains(policy::rules(policy), &rule_key)) {
            assert!(check_yousui_nft(hold_nft), EInvalidNftOGType);
            policy::add_receipt<Rule>(request);
        }
    }

    public(friend) fun check_tier(
        policy: &mut Policy,
        request: &mut Request,
        hold_nft: &YOUSUINFT,
    ) {
        let rule_key = utils::get_key_by_struct<Rule>();
        if (vec_set::contains(policy::rules(policy), &rule_key)) {
            assert!(check_yousui_nft_tier(hold_nft), EInvalidNftOGType);
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

    fun check_yousui_nft(hold_nft: &YOUSUINFT): bool {
        let nft_type = nft::type(hold_nft);
        nft_type == b"og"
    }

    fun check_yousui_nft_tier(hold_nft: &YOUSUINFT): bool {
        let nft_type = nft::type(hold_nft);
        nft_type == b"4" || nft_type == b"5"
    }
}
