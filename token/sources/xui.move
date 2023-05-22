// SPDX-License-Identifier: Apache-2.0
module yousui::xui {
    use std::option;
    use sui::coin;
    use sui::transfer;
    use sui::url;
    use sui::tx_context::{Self, TxContext};

    const DECIMAL: u8 = 9;
    const SYMBOL: vector<u8> = b"XUI";
    const NAME: vector<u8> = b"YouSUI";
    const DESCRIPTION: vector<u8> = b"XUI is YouSUI's utility token, and by staking it, user get the opportunity to participate in IDO and INO. In addition, user can participate in the governance that determines the direction of the project by using the XUI Token. It can be used as currency in DEX and NFT Marketplace, and liquidity can be supplied along with YouXUI. On social platforms, it can be used when clicking likes or making donations. By staking XUI Tokens, user not only get staking rewards, but also become an early investor in cutting-edge and high-potential projects.";
    const ICON_URL: vector<u8> = b"https://yousui.io/images/coins/XUI.png";
    const TOTAL_SUPPLY: u64 = 100000000000000000; // 100M XUI

    struct XUI has drop {}

    fun init(witness: XUI, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency<XUI>(witness, DECIMAL, SYMBOL, NAME, DESCRIPTION, option::some(url::new_unsafe_from_bytes(ICON_URL)), ctx);
        coin::mint_and_transfer(&mut treasury_cap, TOTAL_SUPPLY, tx_context::sender(ctx), ctx);
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury_cap, tx_context::sender(ctx))
    }
}