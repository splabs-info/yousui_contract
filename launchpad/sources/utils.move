// SPDX-License-Identifier: Apache-2.0
module yousui::utils {
    use sui::tx_context::{TxContext};
    use sui::coin::{Self, Coin};
    use sui::pay;
    use sui::math;
    use std::string::{Self, String};
    use std::type_name;
    use std::vector;

    const MAX_U64: u128 = 18446744073709551615;
    const MAX_PERCENT: u64 = 100_000_000_000; // => 100 //decimal 9

    const EAmountPayCoinInvalid: u64 = 800+0;

    public fun mul_u64_div_decimal(x: u64, y: u64, z: u8): u64 {
        let rs = (((x as u128) * (y as u128)) / (math::pow(10, z) as u128));
        assert!(rs <= MAX_U64, 1);
        (rs as u64)
    }

    public fun mul_u64_div_u64(x: u64, y: u64, z: u64): u64 {
        let rs = (((x as u128) * (y as u128)) / (z as u128));
        assert!(rs <= MAX_U64, 1);
        (rs as u64)
    }

    public fun get_full_type<T>(): String {
        string::from_ascii(*type_name::borrow_string(&type_name::get<T>()))
    }

    public fun get_module_type<T>(): String {
        string::from_ascii(type_name::get_address(&type_name::get<T>()))
    }

    public fun merge_and_split<T>(
        coins: vector<Coin<T>>, amount: u64, ctx: &mut TxContext
    ): (Coin<T>, Coin<T>) {
        let base = vector::pop_back(&mut coins);
        assert!(coin::value(&base) >= amount, EAmountPayCoinInvalid);
        pay::join_vec(&mut base, coins);
        if(coin::value(&base) > amount) (coin::split(&mut base, amount, ctx), base)
        else (base, coin::zero<T>(ctx))
    }

    public fun get_key_by_struct<Rule>(): String {
        string::from_ascii(type_name::get_module(&type_name::get<Rule>()))
    }

    public fun cal_amount_with_percent(token_amount: u64, percent: u64): u64 {
        mul_u64_div_u64(token_amount, percent, MAX_PERCENT)
    }


    public fun max_percent(): u64 {
        MAX_PERCENT
    }
}