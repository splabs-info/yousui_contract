// SPDX-License-Identifier: Apache-2.0
module yousui_staking::certificate {
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::display;
    use sui::clock::{Self, Clock};
    use sui::package::{Self, Publisher};
    use sui::dynamic_field as df;

    use std::string::{String, utf8};

    friend yousui_staking::staking;

    struct InvestmentCertificate has key {
        id: UID,
        name: String,
        image: String,
        website: String,
        link: String,
        description: String,
        issue_date: u64,
    }

    struct CERTIFICATE has drop {}

    fun init(witness: CERTIFICATE, ctx: &mut TxContext) {
        let publisher = package::claim(witness, ctx);
        display<InvestmentCertificate>(&publisher, ctx);
        transfer::public_transfer(publisher, tx_context::sender(ctx));
        // transfer::share_object(InvestmentCertificate {
        //    id: object::new(ctx),
        //    name: utf8(b"YouSUI Launchpad"),
        //    image: utf8(b"https://kol-sale.yousui.io/images/background/water-seek.jpg"),
        //    website: utf8(b"https://yousui.io"),
        //    link: utf8(b"https://kol-sale.yousui.io"),
        //    description: utf8(b"YouSUI is an All-In-One platform that runs on the Sui Blockchain and includes DEX, Launchpad, NFT Marketplace and Bridge."),
        //    other: object_bag::new(ctx)
        // });
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

    public(friend) fun issue_investment_certificate<T: store>(clock: &Clock, name: String, image: String, website: String, link: String, description: String, info: T, ctx: &mut TxContext) {
        let id = object::new(ctx);
        df::add(&mut id, utf8(b"info"), info);
        transfer::transfer(
            InvestmentCertificate {
                id,
                name,
                image,
                website,
                link,
                description,
                issue_date: clock::timestamp_ms(clock),
            },
            tx_context::sender(ctx)
        )
    }

    // public(friend) fun remove_investment_certificate<T: store + drop>(cert: InvestmentCertificate) {
    //     df::remove<String, T>(&mut cert.id, utf8(b"info"));
    //     let InvestmentCertificate { id, name: _, image: _, website: _ , link: _, description: _, issue_date: _} = cert;
    //     object::delete(id);
    // }

    public(friend) fun get_df_info<T: store>(cert: &InvestmentCertificate): &T {
        df::borrow<String, T>(&cert.id, utf8(b"info"))
    }

    public(friend) fun get_mut_df_info<T: store>(cert: &mut InvestmentCertificate): &mut T {
        df::borrow_mut<String, T>(&mut cert.id, utf8(b"info"))
    }
}