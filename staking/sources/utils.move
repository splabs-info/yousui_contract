// SPDX-License-Identifier: Apache-2.0
module yousui_staking::utils {
    use sui::math;
    use std::string::{Self, String};
    use std::type_name;

    const MAX_U64: u128 = 18446744073709551615;

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
}